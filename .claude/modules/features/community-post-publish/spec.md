# Community Post Publish (Finoux `InsertPostData` migration) — Spec

Source: `FinouxIntegrations-API-Design-Document` v0.1 (webMethods IS 10.7 `FinouxIntegrations`
package → Java 21 / Spring Boot 3), with an "Explicit decisions for this migration task" section
that pre-resolves every open item the legacy document itself left unagreed (its own Appendix E).
This spec treats those pre-resolutions as settled inputs, not open questions, and re-grounds every
one of them in this repo's actual code (not just restating the request).

## 1. Feature Objective & Scope

**Problem**: migrate the legacy webMethods `FinouxIntegrations.services:pushCommunityPost` Flow
service — which publishes an admin post to the Finoux community platform via
`POST {FINOUX_API_BASE_URL}/api/market` (`METHOD=InsertPostData`) — into a Spring Boot REST
endpoint in `utility-service`, fixing six defects the legacy flow carried (F-01..F-08 in the source
doc: body-trusted admin identity, unsanitised HTML, ignored business failures, no timeout, no
outbound auth, leaked exception detail, non-standard transport status).

**Target service**: `utility-service` (already scaffolded per `alramz-service-scaffold`; currently
has exactly one endpoint, a hand-written `GET /api/v1/info` in
`services/utility-service/src/main/java/com/alramz/controllers/ApplicationController.java`). This
feature is the service's **first real business endpoint**.

**In scope**:
- `POST /api/v1/community/posts` — create/publish a community post, calling Finoux
  `InsertPostData` v2.0 synchronously and returning its outcome.
- HTML sanitisation of `postDesc` before it is forwarded to Finoux.
- Outbound timeout + circuit breaker + explicit no-retry on the Finoux call.
- Typed exceptions + `GlobalExceptionHandler` mapping every Finoux/validation failure to a proper
  HTTP status (no more legacy always-200 / non-standard 402).
- Config (`adapter.finoux.*`), JWT role gating (`@JwtSecured(roles = "APP_UTILITY")`), and the
  Liquibase changeset needed to make `utility-service`'s **already-enabled**
  `company.logging.database-logging` actually persist audit rows (see §2 — this table does not
  exist yet in `utility-service`).

**Out of scope** (explicitly, per the source doc and/or CLAUDE.md guardrails):
- *getPortfolioPerformance (community)* and any other Finoux community API — different package per
  the source doc §1.2.
- *FINOUX to CRM* integration — separate Confluence page, not this package.
- Deriving `postedUserId`/`username` from an OAuth2/user-identity token claim — this repo's JWT
  starter (`company.jwt.*`) has no user-identity-claim mechanism beyond role/environment checks
  today; building one is a larger auth project, not this migration (see "Explicit decisions" in the
  source doc, carried into §5 below as a documented gap, not solved here).
- Idempotency-key infrastructure / auto-retry of the outbound POST — the source doc explicitly
  says not to add this.
- Any new `@AutoConfiguration`, new datasource, or new service — not needed; `utility-service`
  already has `alramz-api-starter` (JWT, logging/audit, resilience4j via transitive deps) and the
  `middleware` datasource wired.
- Editing `infra/`, `.github/workflows/`, or any already-applied Liquibase changeset.

## 2. Repository Grounding

| Concern | Real file/class this builds on |
|---|---|
| Contract file | `services/utility-service/specs/apiSpecs.yaml` — **amend**, it already exists (one operation, `getInfo`) |
| Codegen plugin | `services/utility-service/pom.xml:161-196` — `openapi-generator-maven-plugin`, `apiPackage=com.alramz.api`, `modelPackage=com.alramz.model`, identical to the other two services |
| Controller layer convention | `com.alramz.controllers` is **flat by technical layer, not package-by-feature** in both reference services (`data-validation-service`/`reference-data-service` put every feature's config/service/exception classes in shared `com.alramz.config`/`com.alramz.service`/`com.alramz.exception` packages, e.g. `IbanServiceProperties`, `PhoneServiceProperties`, `ETradeProperties` all sit together in `com.alramz.config`). New classes for this feature follow that same flat-by-layer convention, not a nested `com.alramz.community.*` package (CLAUDE.md's "package-by-feature" description does not match what's actually on disk; the flat layout is the real, observed precedent and is what this spec follows). |
| Outbound external-call pattern | `services/data-validation-service/src/main/java/com/alramz/service/impl/IBANValidationServiceImpl.java` — a `@Service` that **extends `AbstractRestClient`** (`com.alramz.client.AbstractRestClient`, from `alramz-api-starter`) and calls a third-party API directly via injected `WebClient`/`CircuitBreaker`/`Retry`/`TimeLimiter` beans built in `services/data-validation-service/src/main/java/com/alramz/config/ExternalIbanServiceConfig.java`. This feature mirrors that exact shape for the Finoux call (not a separate `client` package layer, despite the source doc's own `ae.alramz.finoux.client` proposal — the real precedent folds client + service into one impl class). |
| Typed exceptions + handler | `services/data-validation-service/src/main/java/com/alramz/exception/{ApplicationException,ExternalSystemException,GlobalExceptionHandler}.java` — `ApplicationException(field, message, serviceErrorResponseCode)` is the exact existing shape for a "client-input failure that carries an internal error code," reused here for FNX00x codes. `utility-service` has **no** `com.alramz.exception` package yet; this feature creates its first one, modeled on `services/reference-data-service/src/main/java/com/alramz/exception/GlobalExceptionHandler.java` (the simpler single-envelope-family handler, since — like `reference-data-service` — this feature has exactly one response envelope, `GenericResponse`, no per-path branching needed). |
| Config properties convention | `.claude/howtos/configuration-properties.md` — service-level adapter config as `adapter.<name>.*`, matching `adapter.external-iban-service` (`IbanServiceProperties`) and `adapter.etrade` (`ETradeProperties`). New: `adapter.finoux.*`. Per the howto's own stated preference (not the legacy record-without-`PREFIX`-constant style those two classes use), this spec's new `FinouxProperties` uses the **recommended** Lombok `@Getter/@Setter` + `PREFIX` constant shape instead. |
| JWT security | `.claude/howtos/jwt-security-and-public-endpoints.md` — `@JwtSecured(roles = "APP_<SERVICE_CONCERN>")`; `utility-service` has no existing role yet (first secured endpoint), so this mints `APP_UTILITY` following the convention (`APP_DATA_VALIDATION`, `APP_REFERENCE_DATA`). `company.jwt.permit-all-urls` in every `services/utility-service/src/main/resources/application-{dev,docker,preprod,prod}.yml` is **unchanged** — this endpoint is secured, not public. |
| DB audit logging (F-06) | `services/utility-service/src/main/resources/application-{dev,docker,preprod,prod}.yml` already set `company.logging.database-logging.enabled: true` **and** `company.datasource.middleware.enabled: true` — so F-06 ("add audit logging") is *already configured on*, service-wide, pre-existing this feature. **But** `services/utility-service/src/main/resources/db/changelog/{dev,docker,preprod,prod}/` has no `sql/` subfolder at all today (confirmed via glob — zero changesets exist for `utility-service`), so the `api_audit_log` table `ApiAuditLogService.log()` (`services/alramz-api-starter/src/main/java/com/alramz/audit/ApiAuditLogService.java:48-78`) inserts into **does not exist yet**. Per that method's own `catch (Exception e)` (line 75-77), a missing table does not break the request — it just silently never writes a row (the documented "silent no-op" from `.claude/howtos/request-response-and-db-audit-logging.md` §2.2/§4). This feature must ship the changeset, or F-06 is not actually satisfied despite the config already being "on." |
| Masking | `services/alramz-api-starter/src/main/java/com/alramz/audit/SensitiveDataMasker.java:23-28` — hardcoded sensitive-key set. None of this endpoint's fields (`postedUserId`, `username`, `postedBy`, `postDesc`, `tagSymbol`) are in that set or in `company.logging.masking.sensitive-keys` today; none are secrets, so no masking addition is needed (see §5). |
| Service sizing | `services/utility-service/service.yaml` — single-record, synchronous, admin-only endpoint; no bulk/scheduled-job throughput profile. No sizing change needed (determination, not a question). |

## 3. Interface Contracts

### 3.1 Endpoint

Resolved per `.claude/howtos/new-endpoint-elicitation-checklist.md` — every fact below came from
either the source doc's own "Explicit decisions" section (①) or this repo's stated standard default
(③); none needed `AskUserQuestion`.

| Fact | Value | How resolved |
|---|---|---|
| HTTP verb + bare path | `POST /community/posts` (source doc §2.5/§4.1 fixes the target operation at `/api/v1/community/posts`; the spec path omits the `/api/v1` prefix the controller's class-level `@RequestMapping("/api/v1")` adds, matching `/iban/validate` in `data-validation-service/specs/apiSpecs.yaml`) | ① explicit in request |
| Tag | `Community` | ③ default: one tag per feature area, matching `IBAN`/`VeriPhone`/`ExistingData` style |
| `operationId` | `createCommunityPost` | ③ default: camelCase verb+noun, matching `validateIBAN`/`verifyPhone`/`onboard` |
| Security | JWT-secured, role `APP_UTILITY` | ③ default: secured-by-default; `utility-service` has no existing role to reuse (first secured endpoint), so a new `APP_<SERVICE_CONCERN>`-convention role is minted, same granularity as `APP_DATA_VALIDATION`/`APP_REFERENCE_DATA` (service-level, not feature-level) |
| Response envelope | `GenericResponse`, extended with `correlationId`/`errorCode`/`errorMsg` (all nullable) | ③ default `GenericResponse`; the three extra fields are added to `utility-service`'s own `components.schemas.GenericResponse` (currently only `responseCode`/`responseMessage`/`response`) because `data-validation-service`'s `GenericResponse` already carries `correlationId` (direct precedent) and the source doc's envelope (§2.4.1) explicitly requires `errorCode`/`errorMsg` for every status — each service's spec defines its own copy of this schema, so extending `utility-service`'s copy doesn't affect the other services |
| Success status | `201 Created`, `Location: /api/v1/community/posts/{postId}` | ① explicit in request |
| Status codes | `201`, `400`, `401`, `403`, `500`, `503` (no boilerplate — justified per code below) | ③ default `401`/`400`/`500` (secured JSON endpoint) + `403` (role-restricted) + `503` (calls an external system, Finoux) |
| Internal error codes | `FNX0xx`, new prefix minted for this feature (not borrowed from `ONB0xx`) | ① explicit in request (§2.4.2/§4.6), ③ "mint a new one, don't borrow" |

### 3.2 `specs/apiSpecs.yaml` amendment (not a new file — `services/utility-service/specs/apiSpecs.yaml` already exists)

```yaml
paths:
  /community/posts:
    post:
      tags: [Community]
      summary: Publish a community post
      description: Publishes an admin post to the Finoux community platform (InsertPostData).
      operationId: createCommunityPost
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CommunityPostRequest'
            example:
              postedUserId: 2
              username: admin
              postedBy: admin
              postDesc: "<p>Market update: DFM index closes higher</p>"
              tagSymbol: "1234"
      responses:
        '201':
          description: Post published successfully
          headers:
            Location:
              schema: { type: string }
              example: /api/v1/community/posts/4747
          content:
            application/json:
              schema: { $ref: '#/components/schemas/GenericResponse' }
              example:
                responseCode: "201"
                responseMessage: "Created"
                errorCode: null
                errorMsg: null
                correlationId: "2afe4a42-44f7-4e12-aae7-df0e42d4d757"
                response:
                  post:
                    postId: 4747
                    postedUserId: 2
                    postedBy: admin
                    status: ACTIVE
                    createdAt: "2025-07-24T16:40:42+00:00"
                    publishedAt: "2025-07-24T16:40:42+00:00"
                    postType: "2"
        '400':
          description: Request validation failure
          content:
            application/json:
              schema: { $ref: '#/components/schemas/GenericResponse' }
              example:
                responseCode: "400"
                responseMessage: "Bad Request"
                errorCode: "FNX003"
                errorMsg: "postedBy must be at most 45 characters"
                correlationId: "2afe4a42-44f7-4e12-aae7-df0e42d4d757"
        '401':
          description: Unauthorized - Missing or invalid JWT bearer token
        '403':
          description: Forbidden - caller lacks APP_UTILITY role
        '500':
          description: Internal server error or Finoux reported a backend/business failure
          content:
            application/json:
              schema: { $ref: '#/components/schemas/GenericResponse' }
              example:
                responseCode: "500"
                responseMessage: "Internal Server Error"
                errorCode: "FNX011"
                errorMsg: "Finoux did not confirm the post (isSuccess=false)"
                correlationId: "2afe4a42-44f7-4e12-aae7-df0e42d4d757"
        '503':
          description: Finoux unreachable or timed out
          content:
            application/json:
              schema: { $ref: '#/components/schemas/GenericResponse' }
              example:
                responseCode: "503"
                responseMessage: "Service Unavailable"
                errorCode: "FNX012"
                errorMsg: "Finoux community service unavailable"
                correlationId: "2afe4a42-44f7-4e12-aae7-df0e42d4d757"

components:
  schemas:
    GenericResponse:
      type: object
      properties:
        responseCode: { type: string }
        responseMessage: { type: string }
        response: { type: object }
        correlationId: { type: string, format: uuid }
        errorCode: { type: string, nullable: true }
        errorMsg: { type: string, nullable: true }

    CommunityPostRequest:
      type: object
      required: [postedUserId, username, postedBy, postDesc]
      properties:
        postedUserId:
          type: integer
          format: int64
          description: Admin user code (p_posted_user_id). Accepted in the body for this migration — no user-identity-token claim exists yet (see §1 out-of-scope).
        username:
          type: string
          maxLength: 200
          description: Admin user name (p_user_name).
        postedBy:
          type: string
          maxLength: 45
          description: Display name shown on the post (p_posted_by).
        postDesc:
          type: string
          description: Post body, HTML allowed, sanitised server-side before forwarding to Finoux (p_post_desc). 10000-char cap is enforced post-sanitisation (see §6 FNX004), not as a raw-input constraint here.
        tagSymbol:
          type: string
          minLength: 1
          maxLength: 50
          description: Company tag (p_tag_sc_comp_id), optional.

    CommunityPostResponse:
      type: object
      properties:
        post: { $ref: '#/components/schemas/CommunityPost' }

    CommunityPost:
      type: object
      properties:
        postId: { type: integer, format: int64 }
        postedUserId: { type: integer, format: int64 }
        postedBy: { type: string }
        status: { type: string, enum: [ACTIVE] }
        createdAt: { type: string, format: date-time }
        publishedAt: { type: string, format: date-time }
        postType: { type: string }
```

Note: `response` in the `201` example nests a `CommunityPostResponse` (`{post: {...}}`); the
generator produces that from the `$ref` chain above — `GenericResponse.response` stays untyped
`object` at the schema level (matching every other operation in this file) while the controller
populates it with a real `CommunityPostResponse` instance.

### 3.3 Java method signatures

```java
// com.alramz.controllers.CommunityPostController (new file)
@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class CommunityPostController implements CommunityApi {   // generated interface name from tag "Community"

    private final CommunityPostService communityPostService;

    @Override
    @JwtSecured(roles = "APP_UTILITY")
    @Loggable
    public ResponseEntity<GenericResponse> createCommunityPost(CommunityPostRequest communityPostRequest) {
        CommunityPost post = communityPostService.publish(communityPostRequest);
        GenericResponse body = new GenericResponse();
        body.setResponseCode("201");
        body.setResponseMessage("Created");
        body.setResponse(new CommunityPostResponse().post(post));
        return ResponseEntity.created(URI.create("/api/v1/community/posts/" + post.getPostId()))
                .body(body);
    }
}

// com.alramz.service.CommunityPostService (new file)
public interface CommunityPostService {
    CommunityPost publish(CommunityPostRequest request);
}

// com.alramz.service.impl.CommunityPostServiceImpl (new file) — mirrors IBANValidationServiceImpl's shape
@Service
public class CommunityPostServiceImpl extends AbstractRestClient implements CommunityPostService {
    public CommunityPostServiceImpl(
            @Qualifier("finouxService") WebClient webClient,
            @Qualifier("finouxCircuitBreaker") CircuitBreaker circuitBreaker,
            @Qualifier("finouxRetry") Retry retry,            // configured maxAttempts=1 — see §5, intentionally NOT the IBAN default
            @Qualifier("finouxTimeLimiter") TimeLimiter timeLimiter,
            FinouxProperties finouxProperties,
            Environment environment,
            ObjectMapper objectMapper) { ... }

    @Override
    @Loggable
    public CommunityPost publish(CommunityPostRequest request) { ... }  // sanitise -> build PARAM -> call -> map FinouxResult -> CommunityPost or throw
}
```

### 3.4 Downstream call (Finoux `InsertPostData`) — internal result type

Adopted directly from the source doc §2.4.3 (its own proposed design, not invented here):

```java
// com.alramz.service.impl.FinouxResult (new file)
sealed interface FinouxResult permits FinouxResult.Posted, FinouxResult.Rejected, FinouxResult.Unavailable {
    record Posted(long postId, long postedUserId, String postedBy, String status,
                  OffsetDateTime createdAt, OffsetDateTime publishedAt, String postType) implements FinouxResult {}
    record Rejected(int httpStatus, String finouxMessage) implements FinouxResult {}   // non-2xx, or 2xx with isSuccess=false / missing post_ID
    record Unavailable(Throwable cause) implements FinouxResult {}                      // timeout / connection
}
```

Wire DTOs (hand-written, placed in `com.alramz.model` alongside the generated schemas — same
precedent as `services/data-validation-service/src/main/java/com/alramz/model/ETradeResponse.java`,
a hand-written POJO coexisting with openapi-generator output in the same package):

```java
public record FinouxParam(@JsonProperty("Key") String key, @JsonProperty("Value") String value) {}

public record FinouxInsertPostDataRequest(
    @JsonProperty("METHOD") String method,     // "InsertPostData"
    @JsonProperty("Version") String version,   // "2.0"
    @JsonProperty("PARAM") List<FinouxParam> param) {}

@JsonIgnoreProperties(ignoreUnknown = true)
public record FinouxInsertPostDataResponse(
    Boolean isSuccess, String message, FinouxData data) {}

@JsonIgnoreProperties(ignoreUnknown = true)
public record FinouxData(List<Map<String, Object>> table) {}  // table[0] carries post_ID/posted_User_ID/posted_By/status/created_Dtm/publish_dtm/posttype
```

## 4. Data Model & Persistence Changes

**No new entity/table for post data.** Finoux remains the system of record (source doc Appendix C:
"no JDBC adapters, no database access"; `utility-service`'s own `middleware` datasource is used only
for JWT tables + DB audit logging per the source doc's own explicit decision, carried forward
unchanged here).

**One new Liquibase changeset is needed — not for this feature's data, but to make the
already-on `company.logging.database-logging` actually work (§2 grounding)**:

`utility-service` has **zero** existing changesets (`services/utility-service/src/main/resources/db/changelog/{dev,docker,preprod,prod}/` each contain only an empty `includeAll` pointing at a `sql/` subfolder that doesn't exist yet). The next sequential changeset is therefore `001`, not an amendment to anything already applied:

- `services/utility-service/src/main/resources/db/changelog/dev/sql/001-api-audit-log.sql`
- `services/utility-service/src/main/resources/db/changelog/docker/sql/001-api-audit-log.sql`
- `services/utility-service/src/main/resources/db/changelog/preprod/sql/001-api-audit-log.sql`
- `services/utility-service/src/main/resources/db/changelog/prod/sql/001-api-audit-log.sql`
- `services/utility-service/src/test/resources/db/changelog/test/sql/001-api-audit-log.sql` (separate test changelog root, `services/utility-service/src/test/resources/db/changelog/test/db.changelog-master.yaml`)

Content: copy the DDL from
`services/data-validation-service/src/main/resources/db/changelog/dev/sql/004-api-audit-log.sql`
verbatim (`api_audit_log` table + its four indexes + rollback) — same columns, same
`service_name` default column (the code always writes the real `spring.application.name` at
insert time regardless of the column default, per the howto).

## 5. Security & Config Impact

- **`company.jwt.permit-all-urls`**: **no change** — this endpoint is secured
  (`@JwtSecured(roles = "APP_UTILITY")`), not public. The existing single entry
  (`/api/v1/info`) in every `application-{dev,docker,preprod,prod}.yml` stays as-is.
- **New role**: `APP_UTILITY` — callers must present a JWT whose `roles` claim includes
  `ROLE_APP_UTILITY` (role prefix `ROLE_` per `company.jwt.role-prefix`, default, per
  `JwtProperties`). No YAML change needed for this — it's enforced purely by the
  `@JwtSecured` annotation + `JwtSecuredAspect`.
- **New config properties** (service-level adapter config, `com.alramz.config.FinouxProperties`,
  prefix `adapter.finoux`, matching the existing `adapter.external-iban-service`/`adapter.etrade`
  sibling pattern — but using the Lombok+`PREFIX`-constant shape the configuration-properties howto
  recommends, not the legacy bare-record shape those two use):
  ```yaml
  adapter:
    finoux:
      base-url: ${FINOUX_BASE_URL:}
      api-key: ${FINOUX_API_KEY:}
      request-timeout-seconds: 5
      post:
        posted-user-flag: ADMIN
        publish-flag: A
        post-type-id: "2"
  ```
  Added to `services/utility-service/src/main/resources/application-{dev,docker,preprod,prod}.yml`.
  `base-url` validated non-blank at startup (fail fast, matching the source doc's "validated at
  start-up" target note for `FINOUX_API_BASE_URL`) rather than failing per-request as the legacy
  flow did. `api-key` may be blank — sent as an outbound header only if configured (source doc's
  own explicit decision; vendor credential scheme unconfirmed, documented as an open item, not a
  blocking one — nothing in the interface contract or data model depends on knowing the exact
  scheme today).
- **Outbound call hardening (F-04/F-05)**: `ExternalFinouxServiceConfig` (new, mirrors
  `ExternalIbanServiceConfig`) wires a `finouxService` `WebClient` (base URL from
  `adapter.finoux.base-url`), a `finouxTimeLimiter` (timeout = `request-timeout-seconds`, default
  5s — no timeout existed in legacy), and a `finouxCircuitBreaker`. **Deliberate divergence from
  the `IbanServiceProperties`/`ExternalIbanServiceConfig` precedent**: `finouxRetry` is configured
  with `RetryConfig.custom().maxAttempts(1).build()` (i.e., no retry), not
  `registry.retry(id)`'s implicit resilience4j default (3 attempts) that `ibanServiceRetry` uses —
  the source doc explicitly says the Finoux POST must not be auto-retried (no idempotency-key
  infra backs it). `AbstractRestClient.call(...)` still requires a `Retry` bean positionally, so
  this is a 1-line config difference, not an architectural one.
- **Authentication forwarding caveat (residual, not blocking)**: `AbstractRestClient.execute()`
  (`services/alramz-api-starter/.../client/AbstractRestClient.java:57-66`) automatically attaches
  the **caller's own JWT bearer token** as `Authorization: Bearer ...` on every outbound call
  unless the active profile is `local` — this is exactly what happens today for the IBAN external
  call too (`IBANValidationServiceImpl` extends the same base class). Extending the same class for
  Finoux means the internal caller's bearer token is sent to Finoux alongside (or instead of) the
  `adapter.finoux.api-key` header, on every non-local profile. This matches existing repo behavior
  (not a new risk introduced by this feature) but is worth flagging explicitly — see Self-Critique.
- **Error leakage (F-07)**: `GlobalExceptionHandler`'s generic `Exception.class` handler never
  returns `ex.getMessage()`/stack trace to the caller for unexpected failures (fixed string
  `"Internal Server Error"` + `FNX013`); only validation-failure messages (client's own input) and
  Finoux's own `message` field (already client-facing data, not internal exception detail) are
  echoed back.
- **Masking**: none of this endpoint's fields are sensitive by this repo's existing definition —
  not in `SensitiveDataMasker`'s hardcoded key set (`services/alramz-api-starter/.../SensitiveDataMasker.java:23-28`)
  nor `company.logging.masking.sensitive-keys`. No masking-set change needed. (`postDesc` is public
  community content by design, not a secret — sanitisation, not masking, is the control for it.)
- **HTML sanitisation (F-02)**: new dependency, OWASP Java HTML Sanitizer
  (`com.googlecode.owasp-java-html-sanitizer:owasp-java-html-sanitizer`) — not present anywhere in
  this repo today (confirmed via repo-wide grep), so it needs an explicit `<version>` in
  `services/utility-service/pom.xml` (no BOM-managed version exists to inherit, unlike every other
  dependency in that `pom.xml`). This is the one genuinely new dependency this feature needs;
  justified per CLAUDE.md's "avoid speculative dependencies" since F-02 (stored-XSS via unsanitised
  HTML forwarded to a public feed) is a concrete, stated defect this migration must fix, not a
  speculative addition. Sanitisation policy: a basic formatting/links/blocks allow-list (OWASP's
  built-in `Sanitizers.FORMATTING.and(Sanitizers.LINKS).and(Sanitizers.BLOCKS)`), applied in
  `CommunityPostServiceImpl` before the 10000-char cap check and before building the Finoux PARAM
  list — residual assumption, not a blocking one (the exact allow-list is reversible/tunable later
  without touching the contract).
- **No new dependency needed for the outbound HTTP call itself**: `utility-service` already depends
  on `alramz-api-starter`, which transitively brings `spring-webflux` (for `WebClient`) and
  `spring-cloud-starter-circuitbreaker-reactor-resilience4j` (for `CircuitBreaker`/`Retry`/
  `TimeLimiter`) — confirmed in `services/alramz-api-starter/pom.xml:82-83,163-168`. `utility-service`'s
  `pom.xml` needs no new entry for this part.

## 6. Edge Cases & Error Behaviors

| # | Failure mode | Typed exception | HTTP status | `errorCode` |
|---|---|---|---|---|
| 1 | `postedUserId` missing, or present but not a JSON number | Jakarta Bean Validation (`@NotNull`) for "missing"; `HttpMessageNotReadableException` (Jackson number-coercion failure) for "non-numeric" — the latter can't carry a per-field code since Spring doesn't report which field failed JSON coercion, so it maps to the **malformed-request** fallback, `FNX090` (the doc's own "internal client errors" band, §2.4.2), not `FNX001` | 400 | `FNX001` (missing) / `FNX090` (malformed JSON) |
| 2 | `username` missing or > 200 chars | `MethodArgumentNotValidException` (`@NotBlank @Size(max=200)`) | 400 | `FNX002` |
| 3 | `postedBy` missing or > 45 chars | `MethodArgumentNotValidException` (`@NotBlank @Size(max=45)`) | 400 | `FNX003` |
| 4 | `postDesc` missing | `MethodArgumentNotValidException` (`@NotBlank`) | 400 | `FNX004` |
| 5 | `postDesc` empty after sanitising, or sanitised length > 10000 | `ApplicationException("postDesc", msg, "FNX004")` thrown explicitly from `CommunityPostServiceImpl` (Bean Validation can't see the post-sanitise length) | 400 | `FNX004` |
| 6 | `tagSymbol` present but blank or > 50 chars | `MethodArgumentNotValidException` (`@Size(min=1, max=50)`) | 400 | `FNX005` |
| 7 | Finoux responds non-2xx HTTP | `FinouxIntegrationException(500, "FNX010", msg)` from `CommunityPostServiceImpl` mapping `FinouxResult.Rejected` | 500 | `FNX010` |
| 8 | Finoux responds 2xx but `isSuccess=false` or `data.table[0].post_ID` missing | `FinouxIntegrationException(500, "FNX011", msg)` from the same mapping | 500 | `FNX011` |
| 9 | Finoux unreachable / connection refused / timed out (`finouxTimeLimiter` trips, or `WebClientRequestException`) | `FinouxUnavailableException("FNX012", msg)` mapping `FinouxResult.Unavailable` | 503 | `FNX012` |
| 10 | Unexpected error (response-mapping bug, missing `adapter.finoux.base-url` at call time despite startup validation, any uncaught `RuntimeException`) | Generic `Exception.class` handler in `GlobalExceptionHandler` | 500 | `FNX013` |
| 11 | Missing/invalid JWT | Starter's existing `JwtAuthFilter` + `anyRequest().authenticated()` (no new code) | 401 | — (no body customization requested; matches `401` precedent's bare `description` in every existing operation in this repo) |
| 12 | Valid JWT, missing `ROLE_APP_UTILITY` | `JwtSecuredAspect` (existing starter code, no new code) | 403 | — |

Every status code in §3's `responses` block (`201`/`400`/`401`/`403`/`500`/`503`) has at least one
row above producing it, and every row above produces one of those six statuses — no orphaned code
in either direction.

## 7. Open Questions & Decisions

No `AskUserQuestion` round-trip was needed. Every fact that would otherwise have been a blocking
gap (identity source, response envelope shape, outbound error codes, sanitiser choice, outbound
auth scheme, retry behavior) was already pre-resolved in the source doc's own "Explicit decisions
for this migration task" section, which this spec treats as equivalent to direct precedent per the
elicitation checklist's resolution order. The only things this spec itself decided (not
pre-resolved by the source doc) were cosmetic/reversible and are recorded as residual assumptions
in §9, not logged here as decisions requiring a user round-trip.

## 8. Explicit Acceptance Criteria

- [ ] `services/utility-service/specs/apiSpecs.yaml` has a `POST /community/posts` operation,
      `operationId: createCommunityPost`, tag `Community`, with `201`/`400`/`401`/`403`/`500`/`503`
      responses each carrying a realistic example body (where applicable) as specified in §3.2.
- [ ] `components.schemas.GenericResponse` in that file carries `correlationId`, `errorCode`,
      `errorMsg` in addition to the existing `responseCode`/`responseMessage`/`response`.
- [ ] `mvn -pl services/utility-service -am clean test-compile` regenerates a `CommunityApi`
      interface exposing `createCommunityPost(CommunityPostRequest)`.
- [ ] `CommunityPostController` implements that interface, is annotated
      `@JwtSecured(roles = "APP_UTILITY")` and `@Loggable`, and is not reachable without a valid
      JWT carrying `ROLE_APP_UTILITY` (401 without a token, 403 with a token lacking the role).
- [ ] A valid request with all four required fields + the Finoux call succeeding returns `201`,
      a `Location: /api/v1/community/posts/{postId}` header, and a `GenericResponse` whose
      `response.post.postId` matches Finoux's `data.table[0].post_ID`.
- [ ] Each of the 12 failure modes in §6 is independently reproducible and returns exactly the
      HTTP status + `errorCode` listed.
- [ ] `postDesc` HTML is run through the OWASP sanitiser before being placed in the outbound
      `p_post_desc` PARAM value — a request containing a `<script>` tag never reaches Finoux with
      that tag intact.
- [ ] The outbound Finoux call has a configured timeout (`adapter.finoux.request-timeout-seconds`,
      default 5s) and does **not** retry on failure (`finouxRetry` configured `maxAttempts=1`).
- [ ] `services/utility-service/src/main/resources/db/changelog/{dev,docker,preprod,prod}/sql/001-api-audit-log.sql`
      (+ the `src/test/resources` test-profile equivalent) exist and create the `api_audit_log`
      table; a real request to this endpoint produces a row in it (verifying F-06 is actually
      effective, not just configured).
- [ ] No exception stack trace, internal URL, or raw Finoux error payload beyond its own `message`
      field is ever present in a response body (F-07).
- [ ] `adapter.finoux.base-url` empty/blank at startup fails service startup (fail-fast), not a
      per-request 500 as in the legacy flow.
- [ ] `mvn -pl services/utility-service -am clean test` passes.

## 9. Self-Critique

**Confidence: medium-high.** The contract, data model, and security sections are grounded in real,
cited files throughout, and the source document pre-resolved nearly every decision that would
otherwise have required a user round-trip, which this spec carried forward rather than re-litigating.

Residual (non-blocking) assumptions made here, not stated verbatim in the source doc:
1. **`FNX090` for malformed-JSON/non-numeric `postedUserId`** — the source doc's own table only
   defines `FNX001` for "missing or not numeric" without distinguishing the two failure paths at
   the framework level; this spec splits them because Spring reports JSON-coercion failures via a
   different exception type than Bean Validation, and the field name isn't recoverable from a
   `HttpMessageNotReadableException` the way it is from `MethodArgumentNotValidException`.
2. **OWASP sanitiser policy** (`FORMATTING + LINKS + BLOCKS`) — a reasonable starting allow-list
   for "HTML supported" rich-text posts, not specified by the source doc beyond "sanitise it."
   Easy to tighten/loosen later without touching the contract.
3. **`adapter.finoux` config prefix / `APP_UTILITY` role name** — both follow stated repo
   conventions exactly, but are new names this spec mints rather than reuses, since
   `utility-service` had no prior adapter config or JWT role to match against.

**Weakest part of this spec**: the **outbound-auth-forwarding caveat in §5** — reusing
`AbstractRestClient` for the Finoux call (to match the `IBANValidationServiceImpl` precedent
exactly) means the caller's own internal JWT bearer token gets forwarded to an external third-party
vendor on every non-local-profile call, alongside whatever `adapter.finoux.api-key` header is
configured. This mirrors existing, shipped behavior (the IBAN external call does the same thing
today) so it isn't a regression this feature introduces, and no interface-contract or data-model
fact depends on resolving it — but it's a genuine security question (should an internal
service-to-service auth token ever leave the network to a vendor?) that this spec defers to
whoever owns `AbstractRestClient`/`alramz-api-starter` rather than solving by inventing a
bespoke non-forwarding HTTP client just for this one endpoint.
