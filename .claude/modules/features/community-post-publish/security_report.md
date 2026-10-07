# Security Audit & Vulnerability Report

## Executive Summary
- **Audit Date:** 2026-10-06
- **Feature:** community-post-publish — migrate the legacy webMethods `pushCommunityPost` flow into
  `POST /api/v1/community/posts` in `utility-service`, publishing an admin post to Finoux
  `InsertPostData` with HTML sanitisation, timeout/no-retry hardening, typed error handling, and the
  DB-audit-log changeset needed to make the service's already-enabled audit logging actually work.
- **Target Service(s):** `utility-service` (per `execution_plan.json`'s `target_services`)
- **Files Audited:** 25 (23 from `implementation-report.md` §2 "Files Touched" + the 2 deviation
  rows it already logs — `src/test/resources/application.yml` and the restored
  `src/test/resources/db/changelog/test/sql/002-jwt-tables.sql` — all confirmed present in the live
  working tree via `git status`/`git diff --stat`, no additional scope-creep files found)
- **Audit Status:** PASSED WITH FIXES

## Severity Summary
| Severity | Found | Fixed | Remaining |
|---|---|---|---|
| Critical | 0 | 0 | 0 |
| High | 1 | 1 | 0 |
| Medium | 4 | 0 | 4 |
| Low | ~132 | 0 | ~132 |

(Low count is dominated by PMD Code Style/Design findings on new files, listed in aggregate below,
not individually — see Automated Tooling Summary.)

## Detailed Findings & Remediation

### 1. `AccessDeniedException` from role check silently downgraded from 403 to 500 (fixed)
- **Severity / OWASP category:** High / OWASP A01 Broken Access Control (secondary: A09 Security
  Logging and Alerting Failures — authorization denials lose their distinct signal)
- **Location:** `services/utility-service/src/main/java/com/alramz/exception/GlobalExceptionHandler.java`
  (new file, this feature) — originally had no handler for
  `org.springframework.security.access.AccessDeniedException`.
- **Issue:** `JwtSecuredAspect` (`alramz-api-starter`, pre-existing, out of scope) throws Spring
  Security's `AccessDeniedException` from an `@Before` AOP advice wrapping the controller method
  when a valid JWT lacks `ROLE_APP_UTILITY` (spec.md §6 edge case #12, expected: `403 Forbidden`).
  Because this exception is thrown *during* `DispatcherServlet`'s handler invocation (not by a
  Spring Security filter), Spring's `ExceptionHandlerExceptionResolver` resolves it against
  registered `@ControllerAdvice` beans *before* it can ever propagate back out to
  `ExceptionTranslationFilter` (the component that would normally produce Spring Security's own 403
  response). `GlobalExceptionHandler`'s pre-existing catch-all `@ExceptionHandler(Exception.class)`
  — a direct, is-a match for `AccessDeniedException` — was the only handler that matched, so every
  role-check failure was silently turned into `500 Internal Server Error` / `FNX013` instead of the
  contractually-required `403`. This is exactly the "confirm the handler that actually fires (by
  `@Order`)" pitfall the exception-handling howto calls out (the `OnboardingExceptionHandler`
  dead-code case) — here the risk runs the other direction: a *generic* handler unintentionally
  swallows a *security-relevant* exception type it was never meant to catch. Impact: no privilege
  escalation (the controller method body never executes either way — access is still denied), but
  the wrong status code masks authorization-denial visibility for monitoring/alerting and fails the
  implementation report's own (incorrectly checked-off) acceptance criterion for edge case #12.
  Confirmed, not hypothetical: `data-validation-service` and `reference-data-service` both combine
  the same `@JwtSecured(roles=...)` + catch-all-`Exception.class`-`GlobalExceptionHandler` pattern,
  so the same latent defect likely exists there too — but those files are outside this feature's
  diff and are correctly left unfixed here (see Residual Risks).
- **Fix applied:** added an explicit
  `@ExceptionHandler(org.springframework.security.access.AccessDeniedException.class)` method to
  `GlobalExceptionHandler`, returning `403 Forbidden` with a generic `"Access denied"` body (not
  `ex.getMessage()`, which would otherwise echo the required role name — kept consistent with F-07's
  no-internal-detail-leakage principle). Added a regression test,
  `GlobalExceptionHandlerTest.handleAccessDenied_shouldReturn403NotBeSwallowedByGenericHandler`,
  asserting the 403 status, the generic message, and that the required-role string is not echoed.
  Re-ran `mvn -pl services/utility-service -am clean test`: **exit code 0, 36 tests (35 + 1 new), 0
  failures/errors.**

## Repo Convention Checks (step 5)

- **JWT** (`jwt-security-and-public-endpoints.md`): PASS. `POST /community/posts` is secured, not
  public (matches spec.md's decision); `@JwtSecured(roles = "APP_UTILITY")` used, not
  `@PermitAll`; no new entry needed in `company.jwt.permit-all-urls` (confirmed unchanged in all
  five `application-*.yml`); `APP_UTILITY` follows the `APP_<SERVICE_CONCERN>` convention
  (matches `APP_DATA_VALIDATION`/`APP_REFERENCE_DATA`), not an ad hoc name; no hand-rolled
  `SecurityFilterChain`/`@EnableWebSecurity` added. The `postedUserId`/`username`/`postedBy`
  body-trust gap is pre-acknowledged in spec.md as this migration's interim mitigation and is not
  re-flagged here. One genuine defect found and fixed in this area: the role-check's own
  `AccessDeniedException` was not correctly surfaced as 403 — see Finding 1 above.
- **Masking** (`request-response-and-db-audit-logging.md`): PASS. None of
  `postedUserId`/`username`/`postedBy`/`postDesc`/`tagSymbol` are secrets; none are in
  `SensitiveDataMasker`'s hardcoded key set or `company.logging.masking.sensitive-keys`, and none
  needed to be added — `postDesc` is public community content by design (sanitised, not masked).
  Confirmed no change was made to either masking surface.
- **Exception handling** (`exception-handling.md`): PASS WITH FIX. One `GlobalExceptionHandler`,
  `@RestControllerAdvice(basePackages = "com.alramz.controllers")`, `@Order(0)`, one method per
  typed exception, correlation ID populated from `X-Correlation-Id` on every response, no stack
  trace/SQL/internal path ever leaked (verified via `handleGeneric`'s fixed `"Internal Server
  Error"` string and the regression test asserting the raw message is never echoed). Confirmed via
  direct reasoning about Spring's `ExceptionHandlerExceptionResolver` matching order (not an
  assumption) which handler actually fires for each exception type — this is what surfaced Finding
  1. No `HttpStatus` baked into any exception class (status mapping lives entirely in the handler,
  per the howto's explicit rule).
- **Datasource credentials** (`multi-datasource-and-jpa.md`): PASS. No `plainPassword` in any
  non-dev/test file touched by this feature (`application-dev.yml`/`-docker.yml`/`-preprod.yml`/
  `-prod.yml` only add the new `adapter.finoux.*` block, using `${FINOUX_BASE_URL:}`/
  `${FINOUX_API_KEY:}` env-var placeholders, no literal secret). `DatasourceConfiguration`'s two
  `@Qualifier("middlewareDataSource")`/`@Qualifier("middlewareTransactionManager")` injections are
  correctly qualified (copied verbatim from `reference-data-service`'s own working pattern) — no
  silent cross-datasource read/write risk. `src/test/resources/application.yml`'s
  `plainPassword: sa` is confined to the test profile, matching the howto's stated exception.
- **SQL** (`multi-datasource-and-jpa.md`): N/A — this feature adds no new JDBC/JPA query of any
  kind; Finoux remains the system of record, and the only DB write is the pre-existing, unmodified
  `ApiAuditLogService.log()` path (starter-owned, out of scope).
- **Liquibase** (`liquibase-migrations.md`): PASS. `001-api-audit-log.sql` (all 4 main profiles +
  test copy) contains only `CREATE TABLE IF NOT EXISTS`/`CREATE INDEX IF NOT EXISTS` DDL — no seed
  `INSERT` of any kind, so no secret/PII-in-seed-data risk. The one destructive statement
  (`--rollback DROP TABLE IF EXISTS api_audit_log;`) has a rollback, as required. Confirmed
  byte-identical across all 5 copies via `diff`. The restored, pre-existing
  `002-jwt-tables.sql` (test-profile only, not newly authored by this feature, restored to recover a
  file lost mid-feature) has a minor internal naming inconsistency (changeset IDs `001/002/003-jwt-*`
  inside a file numbered `002-`) — cosmetic, test-profile-only, no secret/PII content, not a
  security finding; noted under Residual Risks only because it sits in an in-scope file.

## Scope Check (step 2)

`git status`/`git diff --name-only` (working tree, no base-branch ref — per instructions, this
feature has no commits yet) matches `implementation-report.md` §2 "Files Touched" exactly: the same
9 modified files and the same new files/directories, including both of the report's own
already-logged deviations (`src/test/resources/application.yml`,
`src/test/resources/db/changelog/test/sql/002-jwt-tables.sql`). **No undisclosed scope creep
found.** The only additional change made during this audit is the Finding-1 fix, confined to two
files already in scope (`GlobalExceptionHandler.java`, `GlobalExceptionHandlerTest.java`), which is
remediation this stage is explicitly chartered to make, not scope creep.

## Automated Tooling Summary

- **`spring-boot-security` skill:** scanner run against `services/utility-service` (whole module,
  then manually filtered to in-scope files). Raw hits: 4× `S1` (literal `cipher.password` in
  `application-{dev,preprod,prod,test}.yml`) and 5× `S3` (Actuator `include: "*"`) — all at lines
  this feature did not touch (pre-existing, outside the diff; confirmed via `git diff` context —
  this feature's only additions to those files are the `adapter.finoux.*` blocks near the bottom),
  so correctly out of scope per this audit's charter, not fixed here. 1× `D1` (no dependency
  scanner wired into CI) — repo-wide, out of scope. 1× `E3` (catch-all `Exception.class` handler,
  flagged for manual verification of `AccessDeniedException` handling) — **confirmed exploitable as
  a real defect by tracing Spring's exception-resolution order** (not just the regex lead) and
  fixed as Finding 1 above.
- **Checkstyle:** 1 in-scope finding — `ClassFanOutComplexity is 31 (max allowed is 30)` in
  `CommunityPostServiceImpl.java:35`. Per this report's severity mapping, complexity violations are
  Medium (not because complexity is itself insecure, but because it makes the class harder to
  audit). Not in a strictly auth/input-validation/exception-handling hot path (it's the
  sanitise→dispatch→map orchestration method), so not bumped further or blocked on. All other
  Checkstyle warnings in the module (`UtilityServiceApplication.java` tab characters, etc.) are
  pre-existing, outside this feature's diff.
- **PMD:** ran with `-Dpmd.skip=false` (confirmed via console: "PMD 7.10.0 has found 145
  violations"). 131 of those 145 are in this feature's in-scope files (filtered from
  `target/pmd.xml` by path, not by category name). **Zero are from the `category/java/security.xml`
  ruleset** — confirmed by checking every distinct `ruleset` attribute present in the report
  (`Best Practices`, `Code Style`, `Design`, `Error Prone` only; no `Security` ruleset hit anywhere
  in the module, in-scope or not). All but one in-scope finding are PMD priority 3-4 (→ Low per this
  report's mapping): `AtLeastOneConstructor`, `LongVariable`, `MethodArgumentCouldBeFinal`,
  `OnlyOneReturn`, `MissingSerialVersionUID` (on the 3 new unchecked exception classes — matches the
  pre-existing style, since `data-validation-service`'s own exception classes don't set one either),
  `CommentDefaultAccessModifier`, `TooManyMethods`/`ExcessiveImports`/`CouplingBetweenObjects`/
  `LawOfDemeter` (all `Design`-category complexity nits on `CommunityPostServiceImpl`, consistent
  with the Checkstyle fan-out finding above), `AvoidDuplicateLiterals` (`"FNX090"` repeated 4× in
  `GlobalExceptionHandler.java`). One priority-1 finding (→ Medium):
  `ReturnEmptyCollectionRatherThanNull` on `CommunityPostServiceImpl.firstRow()` (line 185) —
  reviewed directly: the `null` return is deliberately handled by its one caller
  (`row == null || row.get("post_ID") == null`), so this is a style preference, not a live
  null-dereference bug; not fixed, logged as residual.
- **SpotBugs:** ran with `-Dspotbugs.skip=false` (confirmed via console: "Error size is 0" build
  gate, but 14 real findings printed, all explicitly "Medium" priority). 13× `EI_EXPOSE_REP`/
  `EI_EXPOSE_REP2` (mutable-field exposure on `FinouxProperties`, `ExternalFinouxServiceConfig`,
  `CommunityPostResponse`, `FinouxData`, `FinouxInsertPostDataRequest`,
  `FinouxResult.Unavailable.cause()`, `CommunityPostServiceImpl`'s stored `finouxProperties`) — the
  standard SpotBugs record/DTO/config-holder pattern, not an exploitable vulnerability (these are
  config singletons and internal DTOs, not objects crossing a trust boundary as shared mutable
  state); none sit in an auth/token/datasource path, so none are bumped above Medium. 1×
  `NP_NULL_ON_SOME_PATH_FROM_RETURN_VALUE` in `CommunityPostServiceImpl.buildFinouxRequest()` at the
  `tagSymbol` null-check line — read directly: the code already null-checks before dereferencing
  (`request.getTagSymbol() != null && !request.getTagSymbol().isBlank()`), consistent with a known
  SpotBugs false-positive pattern on repeated getter calls inside one `&&` expression; not a live
  bug, not fixed. **This repo runs plain SpotBugs core, with no FindSecBugs plugin** — its
  security-pattern coverage (injection, crypto, deserialization-specific bug patterns) is limited to
  generic bug-pattern detectors, not security-specific ones; this is a tooling gap worth recommending
  before `05_pr`, not a claim that SpotBugs cleared the code of security defects.
- **OWASP dependency-check:** attempted (`mvn org.owasp:dependency-check-maven:check -pl
  services/utility-service`, no plugin registered in this repo so run as the unbound goal per the
  task's own instructions). **Could not run**: failed with `NvdApiException: Invalid API Key` /
  `NoDataException: No documents exist` — this sandboxed environment has no NVD API key and the
  local vulnerability database is empty, so there is no cached data to fall back to. No findings to
  report either way; this is a tooling gap, not a clean result. For the one genuinely new dependency
  this feature adds (`owasp-java-html-sanitizer:20220608.1`), I could not independently verify its
  current CVE status without network access — recommend a manual Maven Central / GitHub Advisory
  check before `05_pr` given the tool couldn't run.

## Residual Risks & Recommendations

1. **Outbound JWT bearer-token forwarding to Finoux (not fixed, by design — out of scope).**
   `CommunityPostServiceImpl` extends `AbstractRestClient`, whose `execute()` method
   (`alramz-api-starter`, not touched by this feature) automatically attaches the *caller's own*
   internal JWT bearer token to every outbound call on any non-`local` profile, in addition to
   whatever `adapter.finoux.api-key` header is configured. This means utility-service's own internal
   service-to-service auth token would be sent to the external Finoux vendor on every live call.
   This is **pre-existing, shared-starter behavior** (the IBAN external call in
   `data-validation-service` has the identical behavior today) — not a regression this feature
   introduces, and `spec.md` §5 already names it as the spec's "weakest part," deferred to whoever
   owns `AbstractRestClient`. It meets this stage's own "blocking gap" criteria (more than one valid
   fix — e.g. a non-forwarding `WebClient` wrapper, a flag on `AbstractRestClient`, or omitting the
   token for designated third-party-vendor calls — and touching a shared starter class used by other
   services is outside a single feature's scope), so it is correctly left as a flagged
   recommendation for human review before `05_pr`, not something this stage fixes or blocks on.
2. **Pre-existing literal `cipher.password`/unrestricted Actuator exposure** in
   `application-{dev,preprod,prod,test}.yml` (S1/S3 from the scanner) — confirmed via `git diff`
   context to be lines this feature did not touch. Out of scope for this audit; noted for whoever
   owns a future repo-wide security pass.
3. **Same `AccessDeniedException`-swallowing pattern likely also exists in
   `data-validation-service` and `reference-data-service`** (both combine `@JwtSecured(roles=...)`
   with an identically-shaped catch-all `GlobalExceptionHandler`). Those files are outside this
   feature's diff and were not touched or fixed here, per this audit's scoped charter — flagged as a
   recommendation for a follow-up pass on those two services.
4. **`CommunityPostServiceImpl`'s class-level complexity** (Checkstyle `ClassFanOutComplexity`=31,
   PMD `TooManyMethods`/`ExcessiveImports`/`CouplingBetweenObjects`=22) is Medium per this report's
   mapping — it's the sanitise→build→dispatch→map orchestration class for the feature's one real
   integration point, so some coupling is structurally expected; not blocking, but worth a look if
   the class grows further.
5. **`owasp-java-html-sanitizer:20220608.1` dependency CVE status unverified** — OWASP
   dependency-check could not run in this sandboxed environment (no NVD API key/network). Recommend
   a manual check against Maven Central/GitHub Advisories before `05_pr`.
6. **This repo runs plain SpotBugs core with no FindSecBugs plugin** — a tooling gap for
   security-specific static analysis (taint tracking, crypto/deserialization-specific bug patterns),
   not covered by this audit's available tools; worth flagging for whoever owns the shared
   `spotbugs-exclude.xml`/plugin configuration.
7. **F-06's "a real request produces an `api_audit_log` row" acceptance criterion remains
   manually-verified only** (per `implementation-report.md`'s own note — no repo precedent exists for
   asserting a written audit row from an automated test). Not a security defect; flagged so whoever
   deploys to a real dev environment actually performs that manual check before relying on the
   audit trail for this endpoint.
8. **Restored `002-jwt-tables.sql`'s internal changeset IDs (`001/002/003-jwt-user-table`
   etc.) don't match its filename's `002-` prefix** — cosmetic liquibase-hygiene nit, test-profile
   only, no secret/PII content, not fixed (this file's content was restored verbatim from the
   service's original scaffolding, not newly authored).
