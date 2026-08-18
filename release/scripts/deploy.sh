#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="${RELEASE_DIR}/logs"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="${LOG_DIR}/deploy-${TIMESTAMP}.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
GRAY='\033[0;90m'
NC='\033[0m'

DEBUG_MODE=false
CI_MODE=false

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

to_upper() {
    echo "$1" | tr 'a-z' 'A-Z'
}

show_banner() {
    local mode_label="INTERACTIVE MODE"
    [ "$CI_MODE" = true ] && mode_label="AUTOMATION MODE (--no-prompt)"
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
#  ██╔══██╗██║     ██║██╔═══╝ ██╔═══╝ ██║     ██╔══╝     ██║   ██╔═══╝ ██║███╗██║ #
#  ██║  ██║███████╗██║██║     ██║     ███████╗███████╗   ██║   ██║     ╚███╔███╔╝ #
#  ╚═╝  ╚═╝╚══════╝╚═╝╚═╝     ╚═╝     ╚══════╝╚══════╝   ╚═╝   ╚═╝      ╚══╝╚══╝  #
#                                                                              #
#                 Al Ramz Deployment Manager v1.0.0                            #
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
    log_info "Cleanup completed"
}

trap cleanup EXIT
trap 'log_error "Script failed at line $LINENO with exit code $?"' ERR

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --debug       Enable debug mode (verbose output, command tracing)
  --no-prompt   Automation mode (skip interactive prompts)
  --help        Show this help message
EOF
    exit 0
}

cmd_validate_prerequisites() {
    log_info "[STEP 1/15] Validate Prerequisites"
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
    check "docker daemon" "docker info"
    check "registry reachable" "[ -n \"${REGISTRY_URL}\" ] && docker manifest inspect ${REGISTRY_URL}/${REGISTRY_NAMESPACE}/data-validation-service:latest >/dev/null 2>&1 || echo 'skip'"
    check "host port 8080" "lsof -i :8080 >/dev/null 2>&1 || ss -i listening '( dport = 8080 )' >/dev/null 2>&1 || echo 'skip'"
    check "host port 8082" "lsof -i :8082 >/dev/null 2>&1 || ss -i listening '( dport = 8082 )' >/dev/null 2>&1 || echo 'skip'"
    check "compose file" "test -f ${RELEASE_DIR}/docker-compose.yml"
    check ".env file" "test -f ${RELEASE_DIR}/.env"

    if [ "$all_pass" = true ]; then
        log_info "All prerequisite checks passed"
    else
        log_error "Some prerequisite checks failed"
    fi
}

cmd_configure_environment() {
    log_info "[STEP 2/15] Configure Environment"
    if [ -f "${RELEASE_DIR}/.env" ]; then
        log_info ".env already exists"
        read -rp "Overwrite existing .env? (y/N): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            log_info "Configuration cancelled"
            return 0
        fi
    fi
    cp "${RELEASE_DIR}/.env.example" "${RELEASE_DIR}/.env"
    log_info ".env created from .env.example"
    log_info "Please edit ${RELEASE_DIR}/.env with your actual values"
}

cmd_login_registry() {
    log_info "[STEP 3/15] Login to Registry"
    if [ -z "$REGISTRY_URL" ]; then
        log_error "REGISTRY_URL is not set"
        return 1
    fi

    local username="$REGISTRY_USERNAME"
    local password="$REGISTRY_PASSWORD"

    if [ -z "$username" ] || [ -z "$password" ]; then
        read -rp "Registry username: " username
        read -rsp "Registry password: " password
        echo
    fi

    log_info "Logging in to ${REGISTRY_URL}"
    echo "$password" | docker login "$REGISTRY_URL" -u "$username" --password-stdin >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        log_info "Login successful"
    else
        log_error "Login failed"
        return 1
    fi
}

cmd_pull_images() {
    log_info "[STEP 4/15] Pull Images"
    source "${RELEASE_DIR}/.env"

    for service in data-validation-service alramz-notification-service; do
        local tag_var="$(to_upper "$service")_TAG"
        local tag="${!tag_var:-${RELEASE_VERSION:-latest}}"
        local image="${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${service}:${tag}"
        log_info "Pulling ${image}"
        if ! docker pull "$image" >/dev/null 2>&1; then
            log_error "Failed to pull ${image}"
            return 1
        fi
        log_info "Pulled: ${image}"
    done

    log_info "Pulling ${POSTGRES_IMAGE}"
    docker pull "$POSTGRES_IMAGE" >/dev/null 2>&1 || { log_error "Failed to pull ${POSTGRES_IMAGE}"; return 1; }
    log_info "Pulled: ${POSTGRES_IMAGE}"

    log_info "Pulling ${REDIS_IMAGE}"
    docker pull "$REDIS_IMAGE" >/dev/null 2>&1 || { log_error "Failed to pull ${REDIS_IMAGE}"; return 1; }
    log_info "Pulled: ${REDIS_IMAGE}"
}

cmd_verify_images() {
    log_info "[STEP 5/15] Verify Images"
    source "${RELEASE_DIR}/.env"

    for service in data-validation-service alramz-notification-service; do
        local tag_var="$(to_upper "$service")_TAG"
        local tag="${!tag_var:-${RELEASE_VERSION:-latest}}"
        local image="${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${service}:${tag}"
        local id
        id=$(docker inspect --format='{{.Id}}' "$image" 2>/dev/null || echo "not found")
        log_info "${service}: ${id}"
    done
}

cmd_validate_compose() {
    log_info "[STEP 6/15] Validate Compose"
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

cmd_start_platform() {
    log_info "[STEP 7/15] Start Platform"
    docker compose -f "${RELEASE_DIR}/docker-compose.yml" --env-file "${RELEASE_DIR}/.env" up -d
    log_info "Waiting for healthchecks..."
    sleep 10
    log_info "Platform started"
}

cmd_stop_platform() {
    log_info "[STEP 8/15] Stop Platform"
    read -rp "Remove volumes? (y/N): " confirm
    local remove_volumes=""
    [[ "$confirm" == "y" || "$confirm" == "Y" ]] && remove_volumes="-v"
    docker compose -f "${RELEASE_DIR}/docker-compose.yml" --env-file "${RELEASE_DIR}/.env" down $remove_volumes
    log_info "Platform stopped"
}

cmd_restart_platform() {
    log_info "[STEP 9/15] Restart Platform"
    docker compose -f "${RELEASE_DIR}/docker-compose.yml" --env-file "${RELEASE_DIR}/.env" restart
    log_info "Platform restarted"
}

cmd_platform_status() {
    log_info "[STEP 10/15] Platform Status"
    docker compose -f "${RELEASE_DIR}/docker-compose.yml" --env-file "${RELEASE_DIR}/.env" ps
    docker stats --no-stream
}

cmd_health_check() {
    log_info "[STEP 11/15] Health Check"
    local services=("data-validation-service:8080:/actuator/health" "alramz-notification-service:8082:/api/v1/info")
    for entry in "${services[@]}"; do
        local svc="${entry%%:*}"
        local port="${entry##*:}"
        local path="${entry#*:}"
        path="${path%:*}"
        local url="http://localhost:${port}${path}"
        log_info "Checking ${svc} at ${url}"
        if curl -sf "$url" >/dev/null 2>&1; then
            log_info "  [HEALTHY] ${svc}"
        else
            log_error "  [UNHEALTHY] ${svc} (${url})"
        fi
    done
}

cmd_view_logs() {
    log_info "[STEP 12/15] View Logs"
    echo "Select service:"
    echo " 1) data-validation-service"
    echo " 2) alramz-notification-service"
    echo " 3) postgres"
    echo " 4) redis"
    echo " 5) all"
    read -rp "Enter choice [1-5]: " log_choice
    local service=""
    case "$log_choice" in
        1) service="data-validation-service" ;;
        2) service="alramz-notification-service" ;;
        3) service="postgres" ;;
        4) service="redis" ;;
        5) service="" ;;
        *) log_error "Invalid selection"; return 1 ;;
    esac
    log_info "Viewing logs for ${service:-all}"
    docker compose -f "${RELEASE_DIR}/docker-compose.yml" --env-file "${RELEASE_DIR}/.env" logs -f --tail=100 ${service}
}

cmd_upgrade_release() {
    log_info "[STEP 13/15] Upgrade Release"
    local upgrade_log="${LOG_DIR}/upgrade-${TIMESTAMP}.log"
    local old_version="${RELEASE_VERSION}"

    log_info "Upgrade started from ${old_version}"

    read -rp "Enter new RELEASE_VERSION: " RELEASE_VERSION
    read -rp "Enter new DATA_VALIDATION_SERVICE_TAG: " DATA_VALIDATION_SERVICE_TAG
    read -rp "Enter new NOTIFICATION_SERVICE_TAG: " NOTIFICATION_SERVICE_TAG

    log_info "Backing up configuration..."
    cp "${RELEASE_DIR}/.env" "${LOG_DIR}/env-backup-${TIMESTAMP}.env"
    cp "${RELEASE_DIR}/docker-compose.yml" "${LOG_DIR}/compose-backup-${TIMESTAMP}.yml"

    cmd_stop_platform
    cmd_pull_images
    cmd_start_platform
    cmd_health_check

    log_info "Upgrade completed"
}

cmd_rollback_release() {
    log_info "[STEP 14/15] Rollback Release"
    local backups=()
    local i=1
    for f in "${LOG_DIR}"/env-backup-*.env; do
        [ -f "$f" ] && backups+=("$f") && echo "  ${i}) $f" && ((i++))
    done

    if [ ${#backups[@]} -eq 0 ]; then
        log_error "No backups found"
        return 1
    fi

    read -rp "Select backup to restore [1-${#backups[@]}]: " backup_choice
    local selected="${backups[$((backup_choice-1))]}"

    cmd_stop_platform
    cp "$selected" "${RELEASE_DIR}/.env"
    log_info "Restored .env from ${selected}"
    cmd_start_platform
    cmd_health_check
    log_info "Rollback completed"
}

run_ci_pipeline() {
    log_info "Running automation pipeline"

    if [ -z "$REGISTRY_URL" ] || [ -z "$RELEASE_VERSION" ]; then
        log_fatal "REGISTRY_URL and RELEASE_VERSION must be set in automation mode"
        exit 1
    fi

    cmd_validate_prerequisites || exit 1
    cmd_configure_environment || exit 1
    cmd_login_registry || exit 1
    cmd_pull_images || exit 1
    cmd_verify_images || exit 1
    cmd_validate_compose || exit 1
    cmd_start_platform || exit 1
    cmd_health_check || exit 1

    log_info "Automation pipeline completed successfully"
}

main() {
    show_banner

    if [ "$CI_MODE" = true ]; then
        run_ci_pipeline
        exit 0
    fi

    while true; do
        cat <<EOF

${CYAN}[STEP MENU]${NC} Select an option:
 1. Validate Prerequisites
 2. Configure Environment
 3. Login to Registry
 4. Pull Images
 5. Verify Images
 6. Validate Compose
 7. Start Platform
 8. Stop Platform
 9. Restart Platform
10. Platform Status
11. Health Check
12. View Logs
13. Upgrade Release
14. Rollback Release
15. Exit

EOF
        read -rp "Enter choice [1-15]: " choice
        case "$choice" in
            1) cmd_validate_prerequisites ;;
            2) cmd_configure_environment ;;
            3) cmd_login_registry ;;
            4) cmd_pull_images ;;
            5) cmd_verify_images ;;
            6) cmd_validate_compose ;;
            7) cmd_start_platform ;;
            8) cmd_stop_platform ;;
            9) cmd_restart_platform ;;
            10) cmd_platform_status ;;
            11) cmd_health_check ;;
            12) cmd_view_logs ;;
            13) cmd_upgrade_release ;;
            14) cmd_rollback_release ;;
            15) log_info "Exit requested"; exit 0 ;;
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

REGISTRY_URL="${REGISTRY_URL:-}"
REGISTRY_NAMESPACE="${REGISTRY_NAMESPACE:-alramz}"
RELEASE_VERSION="${RELEASE_VERSION:-}"
REGISTRY_USERNAME="${REGISTRY_USERNAME:-}"
REGISTRY_PASSWORD="${REGISTRY_PASSWORD:-}"

main
