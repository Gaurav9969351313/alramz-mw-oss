#!/bin/bash

# API Documentation Generator - Simple Version
# Generates interactive API documentation using Scalar

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${1:-api-docs-build}"
DOCS_USERNAME="${DOCS_USERNAME:-}"
DOCS_PASSWORD="${DOCS_PASSWORD:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

main() {
    log_info "API Documentation Generator"
    log_info "================================"

    # Check jq
    if ! command -v jq &> /dev/null; then
        log_error "jq is required. Install: brew install jq"
        exit 1
    fi

    # Cleanup
    log_info "Cleaning up..."
    rm -rf "$OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR/specs"

    # Find specs
    log_info "Discovering OpenAPI specs..."
    local spec_count=0
    declare -a specs_array

    while IFS= read -r spec_file; do
        [ -z "$spec_file" ] && continue

        local service=$(basename "$(dirname "$spec_file")")
        local parent=$(basename "$(dirname "$(dirname "$spec_file")")")

        log_success "Found: $spec_file"

        # Copy spec
        mkdir -p "$OUTPUT_DIR/specs/$parent"
        cp "$spec_file" "$OUTPUT_DIR/specs/$parent/$(basename "$spec_file")"

        specs_array+=("$parent:$(basename "$spec_file")")
        ((spec_count++))
    done < <(find "$PROJECT_ROOT/services" -path "*/specs/*.yaml" -o -path "*/specs/*.yml" 2>/dev/null | sort)

    if [ $spec_count -eq 0 ]; then
        log_error "No OpenAPI specs found!"
        exit 1
    fi

    log_success "Discovered $spec_count API specifications"

    # Generate manifest
    log_info "Generating manifest..."
    cat > "$OUTPUT_DIR/specs/manifest.json" << 'EOF'
[
EOF

    first=true
    for spec in "${specs_array[@]}"; do
        IFS=':' read -r parent filename <<< "$spec"
        service_name=$(echo "$parent" | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')

        if [ "$first" = false ]; then
            echo "," >> "$OUTPUT_DIR/specs/manifest.json"
        fi
        first=false

        cat >> "$OUTPUT_DIR/specs/manifest.json" << EOF
  {
    "service": "$parent",
    "service_name": "$service_name",
    "spec_file": "$parent/$filename"
  }
EOF
    done

    cat >> "$OUTPUT_DIR/specs/manifest.json" << 'EOF'

]
EOF

    log_success "Manifest created"

    # Generate HTML
    log_info "Generating HTML..."

    # Read manifest
    local manifest=$(cat "$OUTPUT_DIR/specs/manifest.json")

    cat > "$OUTPUT_DIR/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>API Documentation</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    :root {
      --color-primary: #1e293b;
      --color-secondary: #0f172a;
      --color-accent: #3b82f6;
      --color-accent-light: #60a5fa;
      --color-success: #10b981;
      --color-error: #ef4444;
      --color-text: #1f2937;
      --color-text-light: #6b7280;
      --color-border: #e5e7eb;
      --color-bg: #ffffff;
      --color-bg-light: #f9fafb;
    }

    html, body {
      height: 100%;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
      background: var(--color-bg);
      color: var(--color-text);
    }

    .container {
      max-width: 1200px;
      margin: 0 auto;
      height: 100%;
      display: flex;
      flex-direction: column;
    }

    header {
      background: linear-gradient(135deg, var(--color-primary) 0%, var(--color-secondary) 100%);
      color: white;
      padding: 2rem;
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
    }

    header h1 {
      font-size: 2rem;
      margin-bottom: 0.5rem;
    }

    header p {
      opacity: 0.9;
    }

    .auth-section {
      background: var(--color-bg-light);
      border: 1px solid var(--color-border);
      border-radius: 8px;
      padding: 2rem;
      margin: 2rem;
      max-width: 500px;
    }

    .auth-section h2 {
      font-size: 1.5rem;
      margin-bottom: 1.5rem;
      color: var(--color-primary);
    }

    .auth-tabs {
      display: flex;
      gap: 1rem;
      margin-bottom: 1.5rem;
      border-bottom: 2px solid var(--color-border);
    }

    .auth-tab {
      padding: 0.75rem 1rem;
      border: none;
      background: transparent;
      cursor: pointer;
      font-size: 0.95rem;
      font-weight: 500;
      color: var(--color-text-light);
      border-bottom: 3px solid transparent;
      transition: all 0.2s ease;
    }

    .auth-tab.active {
      color: var(--color-accent);
      border-bottom-color: var(--color-accent);
    }

    .auth-tab:hover {
      color: var(--color-text);
    }

    .auth-form {
      display: none;
    }

    .auth-form.active {
      display: block;
    }

    .form-group {
      margin-bottom: 1rem;
    }

    .form-group label {
      display: block;
      margin-bottom: 0.5rem;
      font-weight: 500;
      color: var(--color-primary);
    }

    .form-group input, .form-group select {
      width: 100%;
      padding: 0.75rem;
      border: 1px solid var(--color-border);
      border-radius: 4px;
      font-size: 0.95rem;
      background: white;
    }

    .form-group input:focus, .form-group select:focus {
      outline: none;
      border-color: var(--color-accent);
      box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
    }

    .button-group {
      display: flex;
      gap: 1rem;
      margin-top: 1.5rem;
    }

    button {
      flex: 1;
      padding: 0.75rem 1.5rem;
      border: none;
      border-radius: 4px;
      font-size: 0.95rem;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s ease;
    }

    .btn-primary {
      background: var(--color-accent);
      color: white;
    }

    .btn-primary:hover {
      background: var(--color-accent-light);
      transform: translateY(-2px);
      box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
    }

    .btn-secondary {
      background: var(--color-bg-light);
      color: var(--color-text);
      border: 1px solid var(--color-border);
    }

    .btn-secondary:hover {
      background: var(--color-border);
    }

    .alert {
      padding: 1rem;
      border-radius: 4px;
      margin-bottom: 1rem;
      font-size: 0.9rem;
    }

    .alert-success {
      background: rgba(16, 185, 129, 0.1);
      color: var(--color-success);
      border: 1px solid rgba(16, 185, 129, 0.3);
    }

    .alert-error {
      background: rgba(239, 68, 68, 0.1);
      color: var(--color-error);
      border: 1px solid rgba(239, 68, 68, 0.3);
    }

    .docs-container {
      flex: 1;
      overflow: hidden;
      display: none;
    }

    .docs-container.show {
      display: block;
    }

    iframe {
      width: 100%;
      height: 100%;
      border: none;
    }

    .helper-text {
      color: var(--color-text-light);
      font-size: 0.85rem;
      margin-top: 0.25rem;
    }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>🚀 API Documentation</h1>
      <p>Interactive API explorer with authentication</p>
    </header>

    <div class="auth-section">
      <h2>Authentication</h2>

      <div class="auth-tabs">
        <button class="auth-tab active" data-tab="basic">Basic Auth</button>
        <button class="auth-tab" data-tab="jwt">JWT Token</button>
      </div>

      <div id="basicAuthForm" class="auth-form active">
        <div class="form-group">
          <label for="username">Username</label>
          <input type="text" id="username" placeholder="Enter username" />
        </div>
        <div class="form-group">
          <label for="password">Password</label>
          <input type="password" id="password" placeholder="Enter password" />
        </div>
        <p class="helper-text">Credentials are used locally only to generate Authorization header.</p>
        <div class="button-group">
          <button class="btn-primary" onclick="authenticateBasic()">Authenticate</button>
          <button class="btn-secondary" onclick="clearAuth()">Clear</button>
        </div>
        <div id="basicAlert"></div>
      </div>

      <div id="jwtAuthForm" class="auth-form">
        <div class="form-group">
          <label for="jwtToken">JWT Token</label>
          <input type="text" id="jwtToken" placeholder="Paste your JWT token" />
        </div>
        <p class="helper-text">Token stored securely in browser session.</p>
        <div class="button-group">
          <button class="btn-primary" onclick="authenticateJWT()">Authenticate</button>
          <button class="btn-secondary" onclick="clearAuth()">Clear</button>
        </div>
        <div id="jwtAlert"></div>
      </div>

      <div class="form-group">
        <label for="apiSelect">Select API</label>
        <select id="apiSelect" onchange="loadAPI()">
          <option value="">-- Choose an API --</option>
        </select>
      </div>
    </div>

    <div class="docs-container" id="docsContainer">
      <iframe id="scalarFrame" src="about:blank"></iframe>
    </div>
  </div>

  <script>
    const apiSpecs = %%API_MANIFEST%%;
    let currentAuth = { type: null, token: null };

    document.querySelectorAll('.auth-tab').forEach(tab => {
      tab.addEventListener('click', function() {
        document.querySelectorAll('.auth-tab').forEach(t => t.classList.remove('active'));
        document.querySelectorAll('.auth-form').forEach(f => f.classList.remove('active'));
        this.classList.add('active');
        const formId = this.dataset.tab === 'basic' ? 'basicAuthForm' : 'jwtAuthForm';
        document.getElementById(formId).classList.add('active');
      });
    });

    function authenticateBasic() {
      const username = document.getElementById('username').value;
      const password = document.getElementById('password').value;
      if (!username || !password) {
        showAlert('basicAlert', 'Username and password required', 'error');
        return;
      }
      currentAuth = { type: 'basic', token: btoa(username + ':' + password) };
      showAlert('basicAlert', 'Authenticated! Select an API.', 'success');
    }

    function authenticateJWT() {
      const token = document.getElementById('jwtToken').value;
      if (!token) {
        showAlert('jwtAlert', 'JWT token required', 'error');
        return;
      }
      currentAuth = { type: 'jwt', token: token };
      showAlert('jwtAlert', 'Authenticated! Select an API.', 'success');
    }

    function clearAuth() {
      document.getElementById('username').value = '';
      document.getElementById('password').value = '';
      document.getElementById('jwtToken').value = '';
      document.getElementById('apiSelect').value = '';
      currentAuth = { type: null, token: null };
      document.getElementById('docsContainer').classList.remove('show');
      showAlert('basicAlert', '');
      showAlert('jwtAlert', '');
    }

    function showAlert(id, msg, type) {
      const div = document.getElementById(id);
      div.innerHTML = msg ? `<div class="alert alert-${type}">${msg}</div>` : '';
    }

    function loadAPI() {
      if (!currentAuth.type) {
        alert('Please authenticate first');
        document.getElementById('apiSelect').value = '';
        return;
      }

      const apiName = document.getElementById('apiSelect').value;
      if (!apiName) return;

      const spec = apiSpecs.find(s => s.service === apiName);
      if (!spec) return;

      const specPath = `./specs/${spec.spec_file}`;

      let htmlContent = `
        <!DOCTYPE html>
        <html>
        <head>
          <title>${spec.service_name}</title>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <style>body { margin: 0; font-family: sans-serif; }</style>
        </head>
        <body>
          <script id="api-reference" data-url="${specPath}"></script>
          <script src="https://cdn.jsdelivr.net/npm/@scalar/api-reference"></script>
          <script>
            const specUrl = document.getElementById('api-reference').getAttribute('data-url');
            const authType = '${currentAuth.type}';
            const authToken = '${currentAuth.token}';

            fetch(specUrl)
              .then(res => res.text())
              .then(spec => {
                const config = {
                  spec: { content: spec },
                  theme: 'light',
                  customHeaders: {}
                };
                if (authType === 'basic') {
                  config.customHeaders['Authorization'] = 'Basic ' + authToken;
                } else if (authType === 'jwt') {
                  config.customHeaders['Authorization'] = 'Bearer ' + authToken;
                }
                window.ScalarApiReference(config);
              })
              .catch(err => {
                document.body.innerHTML = '<p style="padding: 2rem;">Error: ' + err.message + '</p>';
              });
          </script>
        </body>
        </html>
      `;

      document.getElementById('scalarFrame').srcdoc = htmlContent;
      document.getElementById('docsContainer').classList.add('show');
    }

    function initAPIs() {
      const select = document.getElementById('apiSelect');
      apiSpecs.forEach(spec => {
        const opt = document.createElement('option');
        opt.value = spec.service;
        opt.textContent = spec.service_name;
        select.appendChild(opt);
      });
    }

    document.addEventListener('DOMContentLoaded', initAPIs);
  </script>
</body>
</html>
HTMLEOF

    # Replace manifest using Python to handle JSON properly
    python3 << PYTHON_EOF
import json
import sys

# Read the manifest JSON
manifest_data = json.loads('''$manifest''')
manifest_str = json.dumps(manifest_data)

# Read HTML file
with open('$OUTPUT_DIR/index.html', 'r') as f:
    html_content = f.read()

# Replace placeholder
html_content = html_content.replace('%%API_MANIFEST%%', manifest_str)

# Write back
with open('$OUTPUT_DIR/index.html', 'w') as f:
    f.write(html_content)
PYTHON_EOF

    log_success "================================"
    log_success "Documentation generated!"
    log_info "Output: $OUTPUT_DIR/"
    log_info "Specs: $OUTPUT_DIR/specs/"
    log_info ""
    log_info "To serve locally:"
    log_info "  cd $OUTPUT_DIR"
    log_info "  python -m http.server 8000"
    log_info "  # Open: http://localhost:8000"
}

main "$@"
