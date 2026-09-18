# API Documentation Deployment Guide

## Quick Start

This repository automatically deploys interactive API documentation to GitHub Pages using the Scalar library with built-in authentication support.

## Files Created

```
.github/workflows/
  └── api-docs-deploy.yml          # Main deployment workflow

scripts/
  └── generate-api-docs.sh         # Local development helper

docs/
  └── API-DOCS.md                  # Comprehensive documentation
```

## Setup Instructions

### 1. Enable GitHub Pages

1. Go to repository **Settings** → **Pages**
2. Under "Build and deployment":
   - Source: **Deploy from a branch**
   - Branch: **gh-pages** (will be created by workflow)
   - Folder: **/ (root)**
3. Enable **Enforce HTTPS**

### 2. Verify Workflow Permissions

1. Go to **Settings** → **Actions** → **General**
2. Under "Workflow permissions":
   - Select **Read and write permissions**
   - Check **Allow GitHub Actions to create and approve pull requests**

### 3. Your First Deployment

Push changes to `main` branch that include OpenAPI specs:

```bash
git push origin main
```

The workflow will automatically:
1. Detect OpenAPI specs in `services/*/specs/*.yaml`
2. Build interactive documentation
3. Deploy to GitHub Pages
4. Post deployment summary

## Workflow Triggers

The workflow runs automatically when:

- **Push to main/feature-cicd-rewrite**: Any changes to:
  - OpenAPI spec files (`services/**/specs/*.yaml`)
  - Workflow file itself
  - Helper scripts
  - Docs configuration

- **Manual Trigger**: Go to **Actions** → **Deploy API Docs** → **Run workflow**

## Using the Documentation

### Access the Docs

1. Navigate to your GitHub Pages URL (find in **Settings** → **Pages**)
2. You'll see the authentication interface

### Authenticate

**Option 1: Basic Auth**
- Username: your username
- Password: your password
- Click "Authenticate"

**Option 2: JWT Token**
- Paste your JWT token
- Click "Authenticate"

### Explore APIs

1. Select an API from the dropdown
2. Browse endpoints and schemas
3. Click "Try it out" to test endpoints
4. Auth headers are automatically included

## Adding New APIs

### 1. Create OpenAPI Spec

```bash
mkdir -p services/my-service/specs
cat > services/my-service/specs/openapi.yaml << 'EOF'
openapi: 3.0.3

info:
  title: My Service API
  version: 1.0.0
  description: API description

servers:
  - url: http://localhost:8080

paths:
  /api/v1/endpoint:
    get:
      summary: Get something
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                type: object

components:
  schemas:
    MySchema:
      type: object
      properties:
        id:
          type: string
EOF
```

### 2. Commit and Push

```bash
git add services/my-service/specs/openapi.yaml
git commit -m "Add OpenAPI spec for my-service"
git push
```

### 3. Wait for Deployment

Check **Actions** tab to see deployment progress. Docs update automatically.

## Local Development

### Generate Docs Locally

```bash
# Requires: jq (brew install jq)
./scripts/generate-api-docs.sh

# Output: api-docs-build/
```

### Serve Locally

```bash
# Using Python
cd api-docs-build
python -m http.server 8000

# Using Node
npx http-server api-docs-build -p 8000

# Then open: http://localhost:8000
```

## Troubleshooting

### Workflow Doesn't Run

**Problem**: Changes to specs don't trigger workflow

**Check**:
1. File path: Must be `services/<name>/specs/*.yaml`
2. Branch: Workflow triggers on `main` and `feature/cicd-rewrite`
3. Permissions: Review **Settings** → **Actions** → **General**

**Fix**:
- Manually trigger: **Actions** → **Deploy API Docs** → **Run workflow**

### Documentation Not Updating

**Problem**: Website shows old API docs

**Solutions**:
1. Clear browser cache (Ctrl+Shift+Delete or Cmd+Shift+Delete)
2. Check workflow completion in **Actions** tab
3. Verify specs in `api-docs-build/specs/` on `gh-pages` branch

### CORS Errors

**Problem**: API requests fail with CORS error

**Solution**: Configure CORS in your backend

```java
@Configuration
public class CorsConfig {
    @Bean
    public WebMvcConfigurer corsConfigurer() {
        return new WebMvcConfigurer() {
            @Override
            public void addCorsMappings(CorsRegistry registry) {
                registry.addMapping("/api/**")
                    .allowedOrigins("https://<your-pages-domain>")
                    .allowedMethods("*")
                    .allowedHeaders("*")
                    .allowCredentials(true);
            }
        };
    }
}
```

### Missing APIs in Dropdown

**Problem**: New API doesn't appear

**Solutions**:
1. Verify file in correct location: `services/<name>/specs/<file>.yaml`
2. Manually trigger workflow
3. Hard refresh page (Ctrl+F5)

## Architecture

```
Monorepo Structure:
services/
  ├── notification-service/
  │   └── specs/openapi.yaml
  └── validation-service/
      └── specs/apiSpecs.yaml

Workflow Process:
1. Push specs to GitHub
2. Workflow detects changes
3. Collects all OpenAPI specs
4. Generates HTML with Scalar
5. Deploys to gh-pages branch
6. Available at GitHub Pages URL

Documentation Site:
index.html
├── Auth Layer (Basic + JWT)
├── API Selector
└── Scalar Viewer (embedded)
    ├── Try it out
    ├── Request/Response
    └── Schema browser
```

## Security

### Token Handling

- ✅ Tokens stored in **browser session only** (not persisted)
- ✅ Not logged or stored in workflow logs
- ✅ Transmitted via **HTTPS only**
- ✅ Cleared on browser close

### Best Practices

1. **Use Test Credentials**: Don't use production passwords
2. **Rotate Keys**: Regularly update JWT signing keys
3. **Enforce HTTPS**: GitHub Pages enforces it automatically
4. **Rate Limit APIs**: Protect backend from doc-based spam
5. **Configure CORS**: Only allow your Pages domain

## Features

### Authentication
- ✅ Basic Auth (username/password)
- ✅ JWT Bearer tokens
- ✅ Custom headers in requests
- ✅ Secure local storage

### API Explorer
- ✅ Interactive endpoint browser
- ✅ Request/response visualization
- ✅ Schema documentation
- ✅ Try it out functionality
- ✅ Example payloads
- ✅ Error codes documentation

### Deployment
- ✅ Automatic on spec changes
- ✅ Manual trigger support
- ✅ GitHub Pages hosting
- ✅ HTTPS enabled
- ✅ Custom domain support

## Next Steps

1. ✅ Workflow is ready - just commit specs
2. Enable GitHub Pages (see setup)
3. Add your OpenAPI specs to `services/*/specs/`
4. Push and watch it deploy
5. Share documentation URL with your team

## References

- [API Documentation Guide](../docs/API-DOCS.md)
- [Scalar Documentation](https://github.com/scalar/scalar)
- [OpenAPI 3.0 Spec](https://spec.openapis.org/oas/v3.0.3)
- [GitHub Pages Docs](https://docs.github.com/pages)

---

**Questions?** Check the comprehensive guide at `docs/API-DOCS.md`
