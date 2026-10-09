---
name: alramz-postman-e2e-validation
description: >
  Turns one endpoint that already exists in a Postman collection under e2e/ into a folder of
  end-to-end test cases, each with a pre-request validation script (fresh ids, token, and a
  check that the request fixture really sets up the case under test) and post-response
  validation tests (status, envelope schema, field rules, correlation echo). Modeled on the
  `dfm-onboarding` folder in e2e/alramz-onbaording-apis.postman_collection.json. Use when asked
  to "write e2e test cases for <endpoint> in the collection", "add pre/post validation to the
  Postman tests", "harden the Postman request for X", or to add negative cases to an existing
  Postman item. For generating brand-new items straight from an OpenAPI spec (endpoint not yet
  in any collection), use alramz-e2e-api-tests-generator instead.
---

# Postman e2e cases with pre- and post-validation

Input: a collection file under `e2e/` and the name of one item in it (the "referral" request).
Output: that item replaced in place by a same-named **folder** of cases, verified with newman.

Scope: only write under `e2e/`. Read service code for facts; never edit it from this skill.

**Worked example — read it first:** the `dfm-onboarding` folder in
`e2e/alramz-onbaording-apis.postman_collection.json` (5 cases, 41 assertions, all passing
against a local onboarding-service). The original single-request version is preserved in
`e2e/alramz-onbaording-apis-uie.postman_collection.json`. Copy its scripts by analogy.

## 1. Ground every expectation in the service, not the spec alone

For the endpoint's URL, find and read:

| Fact | Where |
|---|---|
| Real path | controller class `@RequestMapping` + the generated `*Api` interface (`target/generated-sources`) |
| Required fields and constraints | generated model in `target/generated-sources` (`@NotNull`, `@Size`, `@Email`); this is what bean validation actually enforces |
| Business rules and their error codes | service impl (`throw new ApplicationException(field, msg, code)`) |
| What the client actually receives for each error | the service's `GlobalExceptionHandler`. It often rewrites codes per path (for example, dfm-onboarding maps every `ApplicationException` to `ONB011`, and only bean-validation errors keep `ONB001..005`) |
| Auth | `@JwtSecured(roles=...)` on the method; `company.jwt.permit-all-urls` in `application-dev.yml` |

When the spec and the code disagree, assert what the code does and tell the user about the drift.

## 2. Pick the cases (one per distinct code path, not one per field)

1. **Happy path**: the referral request's body, with `request_id`-style ids replaced by `{{v_request_id}}`.
2. **No bearer token** (secured endpoints only).
3. **One bean-validation failure**: drop one `required` field.
4. **One case per service business rule** that produces a distinct client-visible error.

Don't add a case per required field unless asked; they all go through the same handler.
Negative cases use a **minimal body** (just the required fields plus whatever the rule needs).
That keeps them short, and it reaches validation before any external call, so they pass even
when downstream systems are down.

## 3. Folder-level scripts (shared by every case)

- **Pre-request**: set `v_request_id` and `v_correlation_id` with `pm.variables.set(name, pm.variables.replaceIn("{{$guid}}"))`.
  Then log in, but only if no token is cached or the cached token is more than 5 minutes old.
  Assert the login inside the callback as `[pre] login returns an accessToken`.
  Running at folder level means every case still works when run alone or in any order.
- **Test**: shared post-validation for every response that has a body (skip 401/403):
  - `Content-Type` is JSON.
  - `pm.response.to.have.jsonSchema(<envelope schema>)` with the envelope's `required` fields, and UUID `pattern`s where the format is `uuid`.
  - The envelope's status code field mirrors the HTTP status.

## 4. Item pre-request = pre-validation of the fixture

Every case checks that its own request really sets up what the case claims, so a failed
post-test means the API is wrong, not the fixture. Pattern:

```js
const body = JSON.parse(pm.variables.replaceIn(pm.request.body.raw));
const blank = (v) => v === undefined || v === null || String(v).trim() === "";
const problems = [];
// ...push a message for each violated precondition...
pm.test("[pre] <what this fixture must be>", function () {
    pm.expect(problems, problems.join("; ")).to.be.empty;
});
if (problems.length) pm.execution.skipRequest();
```

- **Happy path**: all required fields are non-blank, and the body satisfies every business rule
  from step 1 (so expecting a 200 is legitimate). Also check that a token is present.
- **Negative case**: the rule under test is broken, and every *other* required field is non-blank.
  Otherwise the case could pass for the wrong reason.
- **No-token case**: assert `pm.request.headers.has("Authorization")` is false.

## 5. Item test = post-validation of the response

- Exact HTTP status.
- **Success**: the endpoint's own fields: UUID regexes, cross-field equalities (for example,
  `member_reference_number == member_client_id`), error fields null, and `.to.have.all.keys(...)`
  if the referral asserted a closed body.
- **Failure**: the error code the handler really returns, and `response_message` *includes the
  field name*. Never match the full message text; message wording drifts. Also assert that the
  correlation id echoes the `X-Correlation-Id` request header, and that success-only fields are null.
- Keep the referral's existing assertions; extend them, don't rewrite them.

## 6. Assemble, merge, verify

1. Write `{"item": [<folder>]}` to a scratchpad file. For more than ~3 cases, a small Python
   generator in the scratchpad that builds the folder beats hand-escaping JS inside JSON.
2. Merge into the collection, replacing the referral item by name:
   `python3 .claude/skills/alramz-e2e-api-tests-generator/scripts/merge_postman_json.py --target e2e/<file> --add <scratch>.json`
3. Check that the file is valid JSON: `python3 -m json.tool e2e/<file> >/dev/null`.
4. Syntax-check every script. Wrap each `exec` block in `(async function(){ ... });`, write them all to one `.js` file, and run `node --check` on it.
5. If the service is up (`curl -s -o /dev/null -w '%{http_code}' localhost:<port>/api/auth/login`),
   run `newman run e2e/<file> -e e2e/local.postman_environment.json --folder <name>` and report
   the pass count. If any assertion fails, decide whether the test or the service is wrong
   before changing an assertion to match.

## Known gotchas in this repo

- `baseurl`, `v_consumer` and `v_consumerPassword` live in the **environment**. Read them with
  `pm.variables.get`, which resolves any scope. `pm.collectionVariables.get("baseurl")` returns undefined.
- A missing or invalid token returns **403 with an empty body**, not the 401 the specs document,
  because the starter's `SecurityFilterChain` sets no `AuthenticationEntryPoint`.
  Assert `oneOf([401, 403])`.
- Two `/api/auth/login` calls in the same second return 500 (duplicate refresh token). That's
  why the folder script reuses the token instead of logging in for every case.
- `X-Correlation-Id` must be a valid UUID. The handlers call `UUID.fromString` on it.
- Never copy key- or credential-looking values (`securitykey`, API keys, passwords) from the
  referral into new cases. Use `{{$guid}}` when the service only checks for non-blank (true of
  dfm-onboarding's `securitykey`); otherwise use an environment variable.
- `pm.execution.skipRequest()` needs Postman 10.x or newman 6.1+.
