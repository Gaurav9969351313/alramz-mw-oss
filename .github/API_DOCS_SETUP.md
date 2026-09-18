# API Documentation Setup

This guide explains how to set up Redocly-based API documentation with basic authentication on GitHub Pages.

## Overview

The setup includes:
- **Redocly CLI**: Builds OpenAPI specs into beautiful HTML documentation
- **GitHub Actions Workflow**: Automatically builds and deploys docs on changes
- **Basic Authentication**: Simple username/password protection using JavaScript
- **GitHub Pages**: Hosting at `https://<org>.github.io/<repo>`

## Directory Structure

```
.
├── redocly.yaml                           # Redocly configuration
├── docs/
│   ├── API_DOCS_SETUP.md                 # This file
│   ├── create-auth-index.js              # Script to generate auth wrapper
│   ├── auth-wrapper.html                 # (Reference) auth template
│   └── dist/                             # Build output (generated)
│       ├── index.html                    # Entry point with auth
│       ├── redoc.html                    # Generated docs
│       └── .nojekyll                     # GitHub Pages config
├── services/
│   ├── alramz-notification-service/specs/openapi.yaml
│   └── data-validation-service/specs/apiSpecs.yaml
└── .github/workflows/
    └── api-docs-deploy.yml               # GitHub Actions workflow
```

## Configuration

### 1. GitHub Secrets

Set the following repository secrets in GitHub Settings → Secrets and variables → Actions:

- `DOCS_USERNAME`: Username for API documentation (e.g., `admin`)
- `DOCS_PASSWORD`: Password for API documentation (e.g., `SecurePassword123!`)

**Steps:**
1. Go to your GitHub repository
2. Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Add `DOCS_USERNAME` with your desired username
5. Add `DOCS_PASSWORD` with your desired password

### 2. Enable GitHub Pages

1. Go to repository Settings → Pages
2. Select "Deploy from a branch"
3. Choose branch: `gh-pages` (will be created by the workflow)
4. Save

### 3. OpenAPI Specs Location

Ensure your OpenAPI specs are in the correct locations:

- `services/alramz-notification-service/specs/openapi.yaml`
- `services/data-validation-service/specs/apiSpecs.yaml`

If you have additional services, update `redocly.yaml`:

```yaml
apis:
  service-name:
    root: ./services/service-name/specs/openapi.yaml
```

## Running the Workflow

### Automatic Deployment

The workflow triggers automatically when:
- Pushing to the `main` branch with changes to:
  - `services/*/specs/**`
  - `redocly.yaml`
  - `docs/**`
  - `.github/workflows/api-docs-deploy.yml`

### Manual Deployment

1. Go to Actions → "Deploy API Documentation"
2. Click "Run workflow"
3. Select branch and click "Run workflow"

## Accessing the Documentation

Once deployed:

1. Visit: `https://<username>.github.io/<repo-name>`
2. You'll see a login page
3. Enter the username and password from GitHub Secrets
4. You're authenticated for the session (credentials stored in sessionStorage)

**Note:** Authentication is per-session. Closing the browser tab/window clears the session.

## Local Development

### Prerequisites

```bash
npm install -g @redocly/cli@latest
```

### Build Documentation Locally

```bash
# Build docs
redocly build-docs redocly.yaml -o docs/dist/redoc.html

# Generate auth wrapper
DOCS_USERNAME=admin DOCS_PASSWORD=test node docs/create-auth-index.js

# Open docs/dist/index.html in a browser
```

### Serve Locally with Python

```bash
cd docs/dist
python3 -m http.server 8000
# Visit http://localhost:8000
```

## Customization

### Change Credentials

Update GitHub Secrets:
1. Settings → Secrets and variables → Actions
2. Click on `DOCS_USERNAME` or `DOCS_PASSWORD`
3. Update value
4. Next workflow run will use new credentials

### Update Redocly Theme/Config

Edit `redocly.yaml` to customize:

```yaml
output:
  html: ./docs/dist/index.html

theme:
  colors:
    primary:
      main: '#667eea'
  typography:
    fontFamily: 'Roboto, sans-serif'
```

See [Redocly documentation](https://docs.redocly.com/) for more options.

### Customize Authentication UI

Edit `docs/create-auth-index.js` to modify:
- Colors and styling
- Error messages
- Form layout

The generated `docs/dist/index.html` contains the compiled result.

## Troubleshooting

### Workflow fails to build

Check workflow logs: Actions → "Deploy API Documentation" → failed run

Common issues:
- **Invalid OpenAPI specs**: Run `redocly lint` locally to validate
- **Missing file paths**: Verify paths in `redocly.yaml` match your spec locations
- **Secret not found**: Ensure `DOCS_USERNAME` and `DOCS_PASSWORD` are set in GitHub Secrets

### Can't access documentation after deployment

1. Verify GitHub Pages is enabled (Settings → Pages)
2. Wait 1-2 minutes for deployment to complete
3. Clear browser cache and try again
4. Check workflow status in Actions tab

### Authentication not working

1. Verify credentials match what you set in GitHub Secrets
2. Try incognito/private browser window to clear sessionStorage
3. Check browser console for errors (F12 → Console)

## Security Considerations

### Credentials Management

- **GitHub Secrets**: Credentials are encrypted and not visible in logs
- **Session Storage**: Uses browser sessionStorage, not localStorage
- **HTTPS Only**: GitHub Pages uses HTTPS automatically
- **Per-Session**: Session clears when tab/browser closes

### Limitations

- **Not production-grade**: Basic Auth via JavaScript is suitable for non-sensitive docs
- **For sensitive content**: Consider:
  - Using GitHub's built-in branch protection
  - Deploying to a private server with proper authentication
  - Using OAuth/OIDC instead of basic auth

## Maintenance

### Regular Updates

```bash
# Update Redocly CLI
npm install -g @redocly/cli@latest

# Update Node.js version in workflow
# Edit .github/workflows/api-docs-deploy.yml
```

### OpenAPI Spec Updates

Simply push changes to your OpenAPI specs:

```bash
git add services/*/specs/*
git commit -m "Update API specifications"
git push origin main
```

The workflow will automatically rebuild and redeploy documentation.

## Support

For issues with:
- **Redocly**: See [docs.redocly.com](https://docs.redocly.com/)
- **GitHub Actions**: See [github.com/actions](https://github.com/actions)
- **GitHub Pages**: See [docs.github.com/pages](https://docs.github.com/en/pages)
