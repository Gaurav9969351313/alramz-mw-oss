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

capitalize_words() {
    echo "$1" | awk '{for(i=1;i<=NF;i++)$i=toupper(substr($i,1,1))substr($i,2)}1'
}

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
        service_name=$(capitalize_words "$(echo "$parent" | sed 's/-/ /g')")

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

    # Generate docs.html from template
    log_info "Generating documentation HTML..."

    # Copy template to docs.html
    if [ -f "$PROJECT_ROOT/docs/templates/docs.html" ]; then
        cp "$PROJECT_ROOT/docs/templates/docs.html" "$OUTPUT_DIR/docs.html"
        log_success "Copied template to docs.html"
    else
        log_error "Template not found: docs/templates/docs.html"
        exit 1
    fi

    # Replace manifest placeholder in docs.html
    python3 << PYTHON_EOF
import json

# Read the manifest JSON
with open('$OUTPUT_DIR/specs/manifest.json', 'r') as f:
    manifest_data = json.load(f)
    manifest_str = json.dumps(manifest_data)

# Read HTML file
with open('$OUTPUT_DIR/docs.html', 'r') as f:
    html_content = f.read()

# Replace placeholder
html_content = html_content.replace('%%API_MANIFEST%%', manifest_str)

# Write back
with open('$OUTPUT_DIR/docs.html', 'w') as f:
    f.write(html_content)
PYTHON_EOF

    # Create login gate (index.html)
    log_info "Creating login gate..."
    DOCS_USERNAME="${DOCS_USERNAME:-admin}" \
    DOCS_PASSWORD="${DOCS_PASSWORD:-SecurePass123!}" \
    node "$PROJECT_ROOT/scripts/create-auth-wrapper.js" "$OUTPUT_DIR"

    # Rename auth wrapper to be the index
    if [ -f "$OUTPUT_DIR/auth-index.html" ]; then
        mv "$OUTPUT_DIR/auth-index.html" "$OUTPUT_DIR/index.html"
        log_success "✓ Login gate created as index.html"
    else
        log_error "Auth wrapper not created"
        exit 1
    fi

    log_success "================================"
    log_success "Documentation generated!"
    log_info "Output: $OUTPUT_DIR/"
    log_info "Specs: $OUTPUT_DIR/specs/"
    log_info ""
    log_info "Login credentials:"
    log_info "  Username: ${DOCS_USERNAME:-admin}"
    log_info "  Password: ${DOCS_PASSWORD:-SecurePass123!}"
    log_info ""
    log_info "To serve locally:"
    log_info "  cd $OUTPUT_DIR"
    log_info "  python3 -m http.server 8000"
    log_info "  # Open: http://localhost:8000"
}

main "$@"
