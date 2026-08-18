#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$RELEASE_DIR")"
LOG_DIR="${RELEASE_DIR}/logs"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="${LOG_DIR}/release-${TIMESTAMP}.log"
MAX_LOG_SIZE=$((10 * 1024 * 1024))

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
GRAY='\033[0;90m'
NC='\033[0m'

DEBUG_MODE=false
CI_MODE=false
TEMP_DIR=""
MANIFEST_DIGESTS_FILE=""

log() {
    local level="$1"
    local function="$2"
    local message="$3"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    local log_line="[${ts}] [${level}] [${function}] ${message}"
    echo -e "${log_line}" | tee -a "$LOG_FILE"
}

log_debug() { [ "$DEBUG_MODE" = true ] && log "DEBUG" "${FUNCNAME[2]:-main}" "$1" || true; }
log_info()  { log "INFO"  "${FUNCNAME[2]:-main}" "$1"; }
log_warn()  { log "WARN"  "${FUNCNAME[2]:-main}" "$1"; }
log_error() { log "ERROR" "${FUNCNAME[2]:-main}" "$1"; }
log_fatal() { log "FATAL" "${FUNCNAME[2]:-main}" "$1"; }

redact() {
    local input="$1"
    echo "$input" | sed -E 's/(password|secret|token|key|credential|pass)[[:space:]]*[:=][[:space:]]*[^[:space:]]+/[REDACTED]/gi'
}

to_upper() {
    echo "$1" | tr 'a-z' 'A-Z'
}

rotate_log() {
    if [ -f "$LOG_FILE" ] && [ "$(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)" -ge "$MAX_LOG_SIZE" ]; then
        mv "$LOG_FILE" "${LOG_FILE}.${TIMESTAMP}"
        LOG_FILE="${LOG_DIR}/release-${TIMESTAMP}.log"
    fi
}

show_banner() {
    local mode_label="INTERACTIVE MODE"
    [ "$CI_MODE" = true ] && mode_label="CI/CD MODE (--no-prompt)"
    local registry_display="${REGISTRY_URL:-not set}"
    local version_display="${RELEASE_VERSION:-not set}"
    local started_at
    started_at=$(date '+%Y-%m-%d %H:%M:%S %Z')
    local host_display="$(hostname) | $(whoami)"

    cat <<EOF
${CYAN}################################################################################
#                                                                              #
#   █████╗ ██╗     ██╗██████╗ ██████╗ ██╗     ███████╗████████╗██████╗ ██╗    ██╗ #
#  ██╔══██╗██║     ██║██╔══██╗██╔══██╗██║     ██╔════╝╚══██╔══╝██╔══██╗██║    ██║ #
#  ███████║██║     ██║██████╔╝██████╔╝██║     █████╗     ██║   ██████╔╝██║ █╗ ██║ #
#  ██╔══██║██║     ██║██╔═══╝ ██╔═══╝ ██║     ██╔══╝     ██║   ██╔═══╝ ██║███╗██║ #
#  ██║  ██║███████╗██║██║     ██║     ███████╗███████╗   ██║   ██║     ╚███╔███╔╝ #
#  ╚═╝  ╚═╝╚══════╝╚═╝╚═╝     ╚═╝     ╚══════╝╚══════╝   ╚═╝   ╚═╝      ╚══╝╚══╝  #
#                                                                              #
#                      Al Ramz Release Manager v1.0.0                          #
#                           ${mode_label}                                        #
#                      Registry: ${registry_display}                          #
#                      Release: ${version_display}                                          #
#                      Started: ${started_at}                        #
#                      Host: ${host_display}#
################################################################################${NC}
EOF
}

cleanup() {
    log_info "Cleanup started"
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        log_info "Removed temp directory: ${TEMP_DIR}"
    fi
    if [ -n "$MANIFEST_DIGESTS_FILE" ] && [ -f "$MANIFEST_DIGESTS_FILE" ]; then
        rm -f "$MANIFEST_DIGESTS_FILE"
        log_info "Removed temp digests file"
    fi
    log_info "Cleanup completed"
}

trap cleanup EXIT
trap 'log_error "Script failed at line $LINENO with exit code $?"' ERR

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --debug    Enable debug mode (verbose output, command tracing)
  --no-prompt  CI/CD mode (skip interactive prompts, read from env vars)
  --help     Show this help message

Environment Variables:
  REGISTRY_URL            Docker registry URL
  RELEASE_VERSION         Semantic version (e.g., 1.0.0)
  DATA_VALIDATION_SERVICE_TAG   Image tag for data-validation-service
  NOTIFICATION_SERVICE_TAG      Image tag for alramz-notification-service
  POSTGRES_IMAGE          PostgreSQL image (e.g., postgres:15-alpine)
  REDIS_IMAGE             Redis image (e.g., redis:7-alpine)
EOF
    exit 0
}

cmd_validate_prerequisites() {
    log_info "[STEP 1/14] Validate Prerequisites"
    local all_pass=true

    check() {
        local name="$1"
        local cmd="$2"
        log_info "Checking ${name}..."
        if eval "$cmd" >/dev/null 2>&1; then
            log_info "  [PASS] ${name}"
        else
            log_error "  [FAIL] ${name}"
            all_pass=false
        fi
    }

    check "docker" "docker --version"
    check "docker compose" "docker compose version || docker-compose version"
    check "maven" "mvn --version"
    check "service directories" "test -d ${PROJECT_DIR}/services/data-validation-service && test -d ${PROJECT_DIR}/services/alramz-notification-service"
    check "dockerfiles" "test -f ${PROJECT_DIR}/services/data-validation-service/Dockerfile && test -f ${PROJECT_DIR}/services/alramz-notification-service/Dockerfile"

    if [ -z "$REGISTRY_URL" ]; then
        log_warn "REGISTRY_URL is not set"
    fi
    if [ -z "$RELEASE_VERSION" ]; then
        log_warn "RELEASE_VERSION is not set"
    fi

    if [ "$all_pass" = true ]; then
        log_info "All prerequisite checks passed"
    else
        log_error "Some prerequisite checks failed"
    fi
}

cmd_build_all() {
    log_info "[STEP 2/14] Build All Services"
    build_all_services_locally
    build_service "data-validation-service"
    build_service "alramz-notification-service"
    log_info "All services built"
}

cmd_build_selected() {
    log_info "[STEP 3/14] Build Selected Service"
    echo "Select service:"
    echo " 1) data-validation-service"
    echo " 2) alramz-notification-service"
    read -rp "Enter choice [1-2]: " svc_choice
    case "$svc_choice" in
        1) build_all_services_locally; build_service "data-validation-service" ;;
        2) build_all_services_locally; build_service "alramz-notification-service" ;;
        *) log_error "Invalid selection"; return 1 ;;
    esac
}

build_all_services_locally() {
    local maven_log="${LOG_DIR}/maven-all-${TIMESTAMP}.log"
    log_info "Building all services locally with Maven..."
    if ! (cd "${PROJECT_DIR}" && mvn clean package -DskipTests > "$maven_log" 2>&1); then
        log_error "Maven build failed for all services"
        log_error "Last 20 lines of Maven log:"
        tail -n 20 "$maven_log" | while IFS= read -r line; do log_error "  $line"; done
        return 1
    fi
    log_info "Maven build completed for all services"
}

build_service() {
    local service="$1"
    local docker_log="${LOG_DIR}/docker-build-${service}-${TIMESTAMP}.log"
    local tag_var="$(to_upper "$service")_TAG"
    local tag="${!tag_var:-${RELEASE_VERSION:-latest}}"
    local image="${REGISTRY_URL:-localhost}/${REGISTRY_NAMESPACE}/${service}:${tag}"

    log_info "Docker build for ${service} started"
    if ! docker build -t "$image" -f "${PROJECT_DIR}/services/${service}/Dockerfile" "${PROJECT_DIR}/services/${service}" > "$docker_log" 2>&1; then
        log_error "Docker build failed for ${service}"
        log_error "Last 20 lines of Docker log:"
        tail -n 20 "$docker_log" | while IFS= read -r line; do log_error "  $line"; done
        return 1
    fi
    log_info "Docker build completed for ${service}: ${image}"
}

cmd_login_registry() {
    log_info "[STEP 4/14] Login to Registry"
    if [ -z "$REGISTRY_URL" ]; then
        log_error "REGISTRY_URL is not set"
        return 1
    fi

    local username="$REGISTRY_USERNAME"
    local password="$REGISTRY_PASSWORD"

    if [ -z "$username" ] || [ -z "$password" ]; then
        if [ "$CI_MODE" = false ]; then
            read -rp "Registry username: " username
            read -rsp "Registry password: " password
            echo
        else
            log_error "REGISTRY_USERNAME and REGISTRY_PASSWORD must be set in CI mode"
            return 1
        fi
    fi

    log_info "Logging in to ${REGISTRY_URL}"
    echo "$password" | docker login "$REGISTRY_URL" -u "$username" --password-stdin >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        log_info "Login successful to ${REGISTRY_URL}"
    else
        log_error "Login failed to ${REGISTRY_URL}"
        return 1
    fi
}

cmd_tag_images() {
    log_info "[STEP 5/14] Tag Images"
    for service in data-validation-service alramz-notification-service; do
        local tag_var="$(to_upper "$service")_TAG"
        local tag="${!tag_var:-${RELEASE_VERSION:-latest}}"
        local local_tag="${REGISTRY_NAMESPACE}/${service}:${tag}"
        local remote_tag="${REGISTRY_URL:-localhost}/${REGISTRY_NAMESPACE}/${service}:${tag}"

        log_info "Tagging ${local_tag} -> ${remote_tag}"
        docker tag "$local_tag" "$remote_tag" || {
            log_error "Failed to tag ${service}"
            return 1
        }
        log_info "Tagged: ${remote_tag}"
    done
}

cmd_push_all() {
    log_info "[STEP 6/14] Push All Images"
    for service in data-validation-service alramz-notification-service; do
        cmd_push_selected "$service"
    done
}

cmd_push_selected() {
    local service="${1:-}"
    if [ -z "$service" ]; then
        echo "Select service:"
        echo " 1) data-validation-service"
        echo " 2) alramz-notification-service"
        read -rp "Enter choice [1-2]: " svc_choice
        case "$svc_choice" in
            1) service="data-validation-service" ;;
            2) service="alramz-notification-service" ;;
            *) log_error "Invalid selection"; return 1 ;;
        esac
    fi

    log_info "[STEP 7/14] Push Selected Image: ${service}"
    local tag_var="$(to_upper "$service")_TAG"
    local tag="${!tag_var:-${RELEASE_VERSION:-latest}}"
    local image="${REGISTRY_URL:-localhost}/${REGISTRY_NAMESPACE}/${service}:${tag}"
    local push_log="${LOG_DIR}/push-${service}-${TIMESTAMP}.log"

    log_info "Pushing ${image}"
    if ! docker push "$image" > "$push_log" 2>&1; then
        log_error "Push failed for ${service}"
        log_error "Last 20 lines of push log:"
        tail -n 20 "$push_log" | while IFS= read -r line; do log_error "  $line"; done
        return 1
    fi
    log_info "Push completed for ${service}"

    local digest
    digest=$(docker inspect --format='{{index .RepoDigests 0}}' "$image" 2>/dev/null || echo "unknown")
    log_info "Digest for ${service}: ${digest}"

    echo "${service}=${digest}" >> "$MANIFEST_DIGESTS_FILE"
}

cmd_generate_manifest() {
    log_info "[STEP 8/14] Generate Image Manifest"
    if [ ! -f "$MANIFEST_DIGESTS_FILE" ]; then
        log_error "No digests file found. Push images first."
        return 1
    fi

    local manifest_file="${RELEASE_DIR}/RELEASE-MANIFEST.yaml"
    cp "${RELEASE_DIR}/RELEASE-MANIFEST.yaml.template" "$manifest_file"

    local dvs_digest=""
    local notif_digest=""
    while IFS= read -r line; do
        local svc="${line%%=*}"
        local dgst="${line#*=}"
        case "$svc" in
            data-validation-service) dvs_digest="$dgst" ;;
            alramz-notification-service) notif_digest="$dgst" ;;
        esac
    done < "$MANIFEST_DIGESTS_FILE"

    sed -i.bak \
        -e "s|\${RELEASE_VERSION}|${RELEASE_VERSION}|g" \
        -e "s|\${GENERATED_AT}|${GENERATED_AT}|g" \
        -e "s|\${GENERATED_BY}|${GENERATED_BY}|g" \
        -e "s|\${REGISTRY_URL}|${REGISTRY_URL}|g" \
        -e "s|\${DATA_VALIDATION_SERVICE_TAG}|${DATA_VALIDATION_SERVICE_TAG}|g" \
        -e "s|\${NOTIFICATION_SERVICE_TAG}|${NOTIFICATION_SERVICE_TAG}|g" \
        -e "s|\${DATA_VALIDATION_SERVICE_DIGEST}|${dvs_digest}|g" \
        -e "s|\${NOTIFICATION_SERVICE_DIGEST}|${notif_digest}|g" \
        -e "s|\${POSTGRES_IMAGE}|${POSTGRES_IMAGE}|g" \
        -e "s|\${REDIS_IMAGE}|${REDIS_IMAGE}|g" \
        -e "s|\${CHECKSUMS_SHA256}|pending|g" \
        "$manifest_file"

    rm -f "${manifest_file}.bak"
    log_info "Manifest generated: ${manifest_file}"
}

cmd_verify_registry() {
    log_info "[STEP 9/14] Verify Registry Images"
    for service in data-validation-service alramz-notification-service; do
        local tag_var="$(to_upper "$service")_TAG"
        local tag="${!tag_var:-${RELEASE_VERSION:-latest}}"
        local image="${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${service}:${tag}"

        log_info "Verifying ${image}"
        if docker manifest inspect "$image" >/dev/null 2>&1; then
            log_info "  [OK] ${image}"
        else
            log_error "  [MISSING] ${image}"
        fi
    done
}

cmd_validate_compose() {
    log_info "[STEP 10/14] Validate Docker Compose"
    local compose_log="${LOG_DIR}/compose-config-${TIMESTAMP}.log"
    if docker compose -f "${RELEASE_DIR}/docker-compose.yml" --env-file "${RELEASE_DIR}/.env" config > "$compose_log" 2>&1; then
        log_info "Docker Compose configuration is valid"
    else
        log_error "Docker Compose configuration has errors"
        log_error "Last 30 lines of log:"
        tail -n 30 "$compose_log" | while IFS= read -r line; do log_error "  $line"; done
        return 1
    fi
}

cmd_generate_checksums() {
    log_info "[STEP 11/14] Generate Release Checksums"
    local checksum_file="${RELEASE_DIR}/checksums.txt"
    find "$RELEASE_DIR" -type f ! -name "checksums.txt" ! -path "*/logs/*" ! -path "*/.git/*" | sort | while IFS= read -r f; do
        shasum -a 256 "$f" | awk '{print $1 "  " $2}'
    done > "$checksum_file"
    local count
    count=$(wc -l < "$checksum_file" | tr -d ' ')
    log_info "Checksums generated: ${checksum_file} (${count} files)"
}

cmd_generate_package() {
    log_info "[STEP 12/14] Generate Release Package"
    if [ -z "$RELEASE_VERSION" ]; then
        log_error "RELEASE_VERSION is not set"
        return 1
    fi

    local package_name="alramz-platform-${RELEASE_VERSION}"
    local package_dir="${RELEASE_DIR}/${package_name}"
    local archive="${RELEASE_DIR}/${package_name}.tar.gz"

    if [ -d "$package_dir" ]; then
        if [ "$CI_MODE" = true ]; then
            log_error "Release directory ${package_dir} already exists. Aborting in CI mode."
            return 1
        fi
        log_warn "Release directory already exists: ${package_dir}"
        read -rp "Overwrite? (y/N): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            log_info "Package generation cancelled"
            return 0
        fi
        rm -rf "$package_dir"
    fi

    mkdir -p "$package_dir"
    cp "${RELEASE_DIR}/docker-compose.yml" "$package_dir/"
    if [ -f "${RELEASE_DIR}/RELEASE-MANIFEST.yaml" ]; then
        cp "${RELEASE_DIR}/RELEASE-MANIFEST.yaml" "$package_dir/"
    fi
    cp "${RELEASE_DIR}/.env.example" "$package_dir/"
    cp -r "${RELEASE_DIR}/scripts" "$package_dir/"
    cp -r "${RELEASE_DIR}/dockerfiles" "$package_dir/"
    if [ -f "${RELEASE_DIR}/checksums.txt" ]; then
        cp "${RELEASE_DIR}/checksums.txt" "$package_dir/"
    fi
    if [ -f "${RELEASE_DIR}/README.md" ]; then
        cp "${RELEASE_DIR}/README.md" "$package_dir/"
    fi

    tar -czf "$archive" -C "$RELEASE_DIR" "$package_name"
    local size
    size=$(du -h "$archive" | cut -f1)
    log_info "Package generated: ${archive} (${size})"
}

cmd_show_info() {
    log_info "[STEP 13/14] Show Release Information"
    log_info "Release Version: ${RELEASE_VERSION:-not set}"
    log_info "Registry URL: ${REGISTRY_URL:-not set}"
    log_info "Data Validation Service Tag: ${DATA_VALIDATION_SERVICE_TAG:-not set}"
    log_info "Notification Service Tag: ${NOTIFICATION_SERVICE_TAG:-not set}"
    log_info "Postgres Image: ${POSTGRES_IMAGE:-not set}"
    log_info "Redis Image: ${REDIS_IMAGE:-not set}"

    if [ -f "${RELEASE_DIR}/RELEASE-MANIFEST.yaml" ]; then
        log_info "=== RELEASE-MANIFEST.yaml ==="
        cat "${RELEASE_DIR}/RELEASE-MANIFEST.yaml" | while IFS= read -r line; do
            log_info "  $line"
        done
    fi

    if [ -f "${RELEASE_DIR}/checksums.txt" ]; then
        log_info "=== checksums.txt (first 5 lines) ==="
        head -n 5 "${RELEASE_DIR}/checksums.txt" | while IFS= read -r line; do
            log_info "  $line"
        done
    fi
}

run_ci_pipeline() {
    log_info "Running CI/CD pipeline"

    if [ -z "$REGISTRY_URL" ] || [ -z "$RELEASE_VERSION" ] || [ -z "$DATA_VALIDATION_SERVICE_TAG" ] || [ -z "$NOTIFICATION_SERVICE_TAG" ]; then
        log_fatal "Required environment variables are not set"
        exit 1
    fi

    if ! [[ "$RELEASE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_fatal "RELEASE_VERSION must match semantic versioning pattern (e.g., 1.0.0)"
        exit 1
    fi

    cmd_validate_prerequisites || exit 1
    cmd_build_all || exit 1
    cmd_login_registry || exit 1
    cmd_tag_images || exit 1
    cmd_push_all || exit 1
    cmd_generate_manifest || exit 1
    cmd_verify_registry || exit 1
    cmd_validate_compose || exit 1
    cmd_generate_checksums || exit 1
    cmd_generate_package || exit 1

    log_info "CI/CD pipeline completed successfully"
}

main() {
    if [ "$CI_MODE" = false ]; then
        if [ -z "$REGISTRY_URL" ]; then
            read -rp "Registry URL: " REGISTRY_URL
        fi
        if [ -z "$RELEASE_VERSION" ]; then
            read -rp "Release Version: " RELEASE_VERSION
        fi
        if [ -z "$DATA_VALIDATION_SERVICE_TAG" ]; then
            read -rp "Data Validation Service Tag [${RELEASE_VERSION}]: " DATA_VALIDATION_SERVICE_TAG
            DATA_VALIDATION_SERVICE_TAG="${DATA_VALIDATION_SERVICE_TAG:-$RELEASE_VERSION}"
        fi
        if [ -z "$NOTIFICATION_SERVICE_TAG" ]; then
            read -rp "Notification Service Tag [${RELEASE_VERSION}]: " NOTIFICATION_SERVICE_TAG
            NOTIFICATION_SERVICE_TAG="${NOTIFICATION_SERVICE_TAG:-$RELEASE_VERSION}"
        fi
        if [ -z "$POSTGRES_IMAGE" ]; then
            read -rp "Postgres Image [postgres:15-alpine]: " POSTGRES_IMAGE
            POSTGRES_IMAGE="${POSTGRES_IMAGE:-postgres:15-alpine}"
        fi
        if [ -z "$REDIS_IMAGE" ]; then
            read -rp "Redis Image [redis:7-alpine]: " REDIS_IMAGE
            REDIS_IMAGE="${REDIS_IMAGE:-redis:7-alpine}"
        fi
    fi

    show_banner

    while true; do
        cat <<EOF

${CYAN}[STEP MENU]${NC} Select an option:
 1. Validate Prerequisites
 2. Build All Services
 3. Build Selected Service
 4. Login to Registry
 5. Tag Images
 6. Push All Images
 7. Push Selected Image
 8. Generate Image Manifest
 9. Verify Registry Images
10. Validate Docker Compose
11. Generate Release Checksums
12. Generate Release Package
13. Show Release Information
14. Exit

EOF
        read -rp "Enter choice [1-14]: " choice
        case "$choice" in
            1) cmd_validate_prerequisites ;;
            2) cmd_build_all ;;
            3) cmd_build_selected ;;
            4) cmd_login_registry ;;
            5) cmd_tag_images ;;
            6) cmd_push_all ;;
            7) cmd_push_selected ;;
            8) cmd_generate_manifest ;;
            9) cmd_verify_registry ;;
            10) cmd_validate_compose ;;
            11) cmd_generate_checksums ;;
            12) cmd_generate_package ;;
            13) cmd_show_info ;;
            14) log_info "Exit requested"; exit 0 ;;
            *) log_warn "Invalid choice: $choice" ;;
        esac
    done
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --debug)
            DEBUG_MODE=true
            set -x
            shift
            ;;
        --no-prompt)
            CI_MODE=true
            shift
            ;;
        --help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

mkdir -p "$LOG_DIR"
rotate_log

log_info "Script started with args: $*"

REGISTRY_URL="${REGISTRY_URL:-}"
REGISTRY_NAMESPACE="${REGISTRY_NAMESPACE:-alramz}"
RELEASE_VERSION="${RELEASE_VERSION:-}"
DATA_VALIDATION_SERVICE_TAG="${DATA_VALIDATION_SERVICE_TAG:-}"
NOTIFICATION_SERVICE_TAG="${NOTIFICATION_SERVICE_TAG:-}"
POSTGRES_IMAGE="${POSTGRES_IMAGE:-}"
REDIS_IMAGE="${REDIS_IMAGE:-}"
REGISTRY_USERNAME="${REGISTRY_USERNAME:-}"
REGISTRY_PASSWORD="${REGISTRY_PASSWORD:-}"
GENERATED_BY="${GENERATED_BY:-$(whoami)}"
GENERATED_AT="${GENERATED_AT:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

TEMP_DIR=$(mktemp -d)
MANIFEST_DIGESTS_FILE="${TEMP_DIR}/digests.txt"
touch "$MANIFEST_DIGESTS_FILE"

if [ "$CI_MODE" = true ]; then
    show_banner
    run_ci_pipeline
    exit 0
fi

main
