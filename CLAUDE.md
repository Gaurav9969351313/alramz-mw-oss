# CLAUDE.md

This file provides context and operational rules for Claude Code (claude.ai/code) when working with code in this repository.

## 0. Claude Agent Protocols & Guardrails

- **Scope boundary:** don't touch `infra/` (Terraform) or `.github/workflows/` unless the task explicitly requires it. Keep edits inside the requested `services/<service>` (or the starter) unless the change genuinely spans layers.
- **Verification rule:** before reporting a task done, run the targeted test or compile check for the impacted service — at minimum `mvn -pl services/<service> -am test-compile`, and `mvn -pl services/<service> -am test` for behavioral changes.
- **Minimal diffs:** match existing style/structure; don't refactor unrelated code or rewrite whole files when a targeted edit will do.
- **No unsafe git commands:** never `git add .` / `git add -A` (see §4 — stray tracked `target/` files make this dangerous here); stage the specific files you changed.

## 1. Project Overview & Quick Reference

Al Ramz Middleware & Infrastructure: Java/Spring Boot microservices (payload validation, notifications) plus the Terraform + Kubernetes IaC that deploys them to Azure, all in one Maven-reactor monorepo.

| | |
|---|---|
| Language / runtime | Java 21, Maven 3.9+ |
| Core stack | Spring Boot 4.1.0, Spring Framework 7.0.8, Liquibase, HikariCP, JWT (`jjwt`), Lombok |
| Runnable services | `data-validation-service` (port `5001`), `alramz-notification-service` (port `8082`) |
| Shared library | `alramz-api-starter` — Spring Boot auto-config starter (JWT, logging, multi-datasource, DB audit, scheduler) |
| Parent/BOM | `alramz-common-bom` — parent POM + dependency management + shared plugin config |
| Infra | Terraform (`infra/`) on Azure; Kubernetes via Kustomize + ArgoCD (`k8s/`) |
| CI/CD | GitHub Actions, path-filtered per service; auto-promotes `feature/* → dev → qa → preprod → prod` |
| DB (local) | H2 in-memory (tests); Postgres/Oracle in real envs; `release/docker-compose.yml` for local Postgres/Redis |

## 2. Frequent CLI Commands

Run Maven from the **repo root** so the reactor resolves `alramz-common-bom`/`alramz-api-starter` without needing GitHub Packages auth.

| Task | Command |
|---|---|
| Build everything | `mvn clean package` |
| Build/test one service (+ its reactor deps) | `mvn -pl services/data-validation-service -am clean test` |
| Fast compile check | `mvn -pl services/<service> -am clean test-compile -Dmaven.compiler.useIncrementalCompilation=false` |
| Run a single test class | `mvn -pl services/<service> -am test -Dtest=DataValidationControllerTest` |
| Run a single test method | `mvn -pl services/<service> -am test -Dtest=DataValidationControllerTest#shouldValidateIban` |
| Install BOM/starter locally (outside full reactor) | `mvn -pl services/alramz-common-bom install -DskipTests && mvn -pl services/alramz-api-starter -am install -DskipTests` |
| Static analysis (console output) | `mvn -pl services/<service> -am verify -Dcheckstyle.consoleOutput=true -Dpmd.consoleOutput=true -Dspotbugs.consoleOutput=true -Djacoco.skip=false` |
| Run `data-validation-service` locally | `cd services/data-validation-service && ./mvnw spring-boot:run` (has wrapper) |
| Run `alramz-notification-service` locally | `cd services/alramz-notification-service && mvn spring-boot:run` (no wrapper — use system `mvn`) |
| Build a Docker image | `mvn clean package -DskipTests -pl services/<service> -am && docker build -t <service>:latest services/<service>` |
| Local Postgres/Redis stack | `cd release && cp .env.example .env` (fill in values) `&& docker compose --env-file .env up` |
| Local Seq log server | `docker run -d --name seq -e ACCEPT_EULA=Y -e SEQ_FIRSTRUN_ADMINPASSWORD=admin123 -p 5341:80 -p 5342:5341 datalust/seq:latest` |
| Dry-run a Kustomize overlay | `kubectl kustomize k8s/overlays/dev` (verified working; `k8s/environments/<env>/` holds only namespace manifests, not a kustomize root) |
| Terraform plan (per stack) | `cd infra/stacks/dev && terraform init && terraform plan -var-file="../../environments/dev.tfvars"` |

> **Caveat:** Checkstyle runs but doesn't fail the build (`failOnViolation=false`); PMD/SpotBugs are `<skip>true</skip>` by default; JaCoCo's `check` minimums are all `0.00`. A green `mvn verify` does **not** mean clean lint/coverage — read the console output.

## 3. Architecture & Repository Layout

```
alramz-mw-oss/
├── services/
│   ├── alramz-common-bom/       # Parent POM + BOM + shared plugin config (Checkstyle/PMD/SpotBugs/JaCoCo/Enforcer)
│   ├── alramz-api-starter/      # Reusable Spring Boot auto-config starter (library, not an app)
│   ├── data-validation-service/ # Payload/IBAN/phone validation service (:5001) — the only module using Liquibase
│   └── alramz-notification-service/ # Email/notification service via MS Graph (:8082)
├── infra/                       # Terraform: modules/, stacks/<env>/, environments/<env>.tfvars
├── k8s/                         # Kustomize base + overlays/<env> (kustomize roots), environments/<env> (namespace manifests only), argocd/
├── .github/                     # workflows/, composite actions/, service-deployment-catalogue/, SECRETS.md
├── config/                      # Shared checkstyle.xml, pmd.xml, spotbugs-exclude.xml
├── docs/                        # Architecture diagrams
├── release/                     # docker-compose.yml, .env.example, release.sh
└── scripts/                     # Local dev helper scripts (e.g. API docs generation)
```

**Starter auto-configuration mechanics.** `alramz-api-starter` auto-configurations are registered in `services/alramz-api-starter/src/main/resources/META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports` — a new `@AutoConfiguration` class is inert unless listed there. Each feature activates only when its property/class/bean is present:

| Feature | Property | Notes |
|---|---|---|
| JWT security | `company.jwt.enabled` (default `true`) | Wires a stateless `SecurityFilterChain` authenticating **every** request except `login-url`/`register-url`/`refresh-url` and `company.jwt.permit-all-urls`. New public endpoints must be added to that list. |
| Named datasources | `company.datasource.{middleware,brok,integration}.enabled` | Each is an independent Hikari pool + `JdbcTemplate`/`NamedParameterJdbcTemplate`/`TransactionManager`, qualified by name (e.g. `@Qualifier("middlewareNamedParameterJdbcTemplate")`). |
| Password encryption | `cipher.password` | Activates `PWProtector`; use encrypted `password`+`passwordVector` in real envs. `plainPassword` is dev-only and logs a warning. |
| DB audit logging | `company.logging.database-logging.enabled` | Writes to `api_audit_log` **through the `middleware` datasource specifically**; no-ops silently if that bean is absent. |
| Method-execution logging | `company.logging.aspect.enabled` | AOP logging via `@Loggable`, separate from always-on request/response filters. |
| Log/audit masking | `company.logging.masking.*` | `SensitiveDataMasker` hardcodes sensitive keys (passwords, tokens, EID/passport fields) — extend the key set, don't hand-roll masking. |

**Build ordering:** both services depend on `alramz-api-starter`, which inherits from `alramz-common-bom`. Building a service in isolation needs those resolvable — either run Maven from the repo root (reactor) or `mvn install -DskipTests` the BOM/starter first. CI does the latter before every test/build (`.github/actions/maven-test`).

**Entry points:** `DataValidationServiceApplication.java`, `AlramzNotificationServiceApplication.java`, `App.java` (starter's own harness). Per-service deployment sizing (cpu/memory/replicas) lives in `services/<service>/service.yaml`, separate from Spring's `application*.yml`. OpenAPI specs live at `services/<service>/specs/*.yaml`.

## 4. Code Style & Conventions

- **Package-by-feature**, not by layer: `com.alramz.<feature>.{config,controller(s),service,repository,model|entity,exception}`.
- **Config classes**: `@ConfigurationProperties(prefix = "...")` on Lombok `@Getter @Setter` classes, with a `public static final String PREFIX` constant and nested static classes for grouped settings (see `DatasourceProperties`, `JwtProperties`, `LoggingProperties`).
- **Auto-config classes**: `@AutoConfiguration` + `@ConditionalOnProperty`/`@ConditionalOnClass`/`@ConditionalOnBean`; default to safe/off so upgrading the starter never silently breaks a consuming service.
- **Multi-datasource injection**: always use an explicit `@Qualifier` (e.g. `@Qualifier("middlewareNamedParameterJdbcTemplate")`) when injecting `JdbcTemplate`/`NamedParameterJdbcTemplate`/`DataSource`/`TransactionManager` — the starter registers up to three of each, unqualified injection is ambiguous or silently wrong. Exception: standard Spring Data JPA repositories don't need this in `data-validation-service`, since `DatasourceConfiguration` marks the middleware datasource `@Primary`.
- **Liquibase migrations** (`data-validation-service` only): changesets live in `src/main/resources/db/changelog/sql/`, one file per change, named `NNN-short-description.sql`, using Liquibase "formatted SQL" (`--liquibase formatted sql` + `--changeset <author>:<unique-id>` header), pulled in via profile-specific masters under `db/changelog/{dev,test,preprod,prod,docker}/db.changelog-master.yaml`. Each profile master includes the shared `db/changelog/sql` plus a profile-specific `db/changelog/{profile}/sql/` folder for environment-only changes. Add `--rollback` statements where practical. **Never edit or renumber an already-applied changeset** — Liquibase tracks checksums; append a new one instead.
- **Error handling**: each service defines typed exceptions in its own `exception` package plus a `GlobalExceptionHandler` (`data-validation-service` also has `OnboardingExceptionHandler`) — add new failure modes as typed exceptions, not generic `RuntimeException`.
- **Request-scoped context**: use `JwtContext`/`UserRequestContext` for the authenticated caller rather than re-parsing tokens/headers in controllers.
- **Lombok everywhere**: `@Getter`/`@Setter`/`@Slf4j`/builders — don't hand-write getters/setters/loggers.
- **Profiles**: `application.yml` + `application-{dev,docker,test,preprod,prod}.yml` per service, selected via `SPRING_PROFILES_ACTIVE`.

### Do Not Use / Anti-Patterns

- Do **not** write ad hoc Spring Security config in a service to expose a new endpoint — add it to `company.jwt.permit-all-urls` instead.
- Do **not** inject `JdbcTemplate`/`NamedParameterJdbcTemplate`/`DataSource` without an explicit `@Qualifier` in a multi-datasource module.
- Do **not** hardcode datasource passwords in non-dev profiles — use `cipher.password` + encrypted `password`/`passwordVector`.
- Do **not** add a new `@AutoConfiguration` class without registering it in `AutoConfiguration.imports` — it will silently never load.
- Do **not** assume `mvn verify` gates quality — Checkstyle/PMD/SpotBugs/JaCoCo are currently non-blocking (see §2 caveat).
- Do **not** run `git add -A` / `git add .` — `services/alramz-api-starter/target/**` has stray tracked compiled classes despite `target/` being gitignored; stage files explicitly.
- Do **not** hand-edit `.github/service-deployment-catalogue/service-register.yml` or manually open promotion PRs — CI owns both.
- Do **not** copy Azure subscription/tenant IDs or other identifiers out of root `README.md`/`commands.md`/`notes.md` into new files, code, or commits.
- Do **not** log or audit sensitive fields directly — extend `SensitiveDataMasker`'s key set instead of bypassing masking.
- Do **not** modify an already-applied Liquibase changeset — add a new numbered file instead.

## 5. Workflow & Safety Guardrails

- **Branch/promotion flow**: `feature/* → dev → qa → preprod → prod`. Pushing to `dev`/`feature/*` triggers `.github/workflows/cicd.yml`, which tests + publishes only changed `services/*` modules, builds/pushes Docker images, deploys to AKS dev, smoke-tests, updates the deployment catalogue, and auto-opens promotion PRs to the next stage.
- **Commit messages**: short, imperative, present tense (e.g. `Fix spec file path resolution`); no enforced conventional-commit prefixes for humans (automation uses `chore(catalogue): ...`). No commit hooks/linting configured.
- **Testing**: run `mvn -pl services/<service> -am clean test` for the module you touched before proposing a change as done; CI re-runs this per changed service, and static analysis separately via `maven-static-analysis`.
- **Terraform**: state is a shared remote Azure Storage backend per environment. Only `infra/stacks/dev` is for routine iteration — never run `terraform apply`/`destroy` against `shared-platform`, `qa`, `preprod`, or `prod` without explicit, environment-specific instruction.
- **Secrets management**:
  - Local secrets live in `release/.env` (gitignored) copied from the committed `release/.env.example` template — never commit a filled-in `.env`.
  - CI/CD secrets (Azure OIDC creds, registry creds, managed identity client IDs, DB credentials) are GitHub Actions secrets documented in `.github/SECRETS.md`; non-secret env names/resource IDs live in `.github/config/environments.json`.
  - Runtime secrets in Azure envs come from Key Vault via the platform managed identity / CSI driver, not from files in the repo.
  - Root `README.md`/`commands.md`/`notes.md` already contain real historical Azure identifiers from past setup — treat as sensitive, don't propagate them further, and never add new real secrets to any tracked file.
