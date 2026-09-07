#!/usr/bin/env bash

# ============================================================
# Ubuntu Developer Environment Bootstrap
#
# Installs:
#   - Java 21
#   - Maven
#   - PostgreSQL
#   - Docker Engine + Docker Compose
#   - kubectl
#   - Kind
#   - Local Kubernetes cluster
#
# Tested conceptually for Ubuntu 22.04 / 24.04
# ============================================================

set -euo pipefail

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

KIND_CLUSTER_NAME="dev-cluster"
POSTGRES_VERSION="16"

# ------------------------------------------------------------
# Colors / Logging
# ------------------------------------------------------------

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ------------------------------------------------------------
# Check Ubuntu
# ------------------------------------------------------------

if [ ! -f /etc/os-release ]; then
    error "Cannot determine operating system."
    exit 1
fi

source /etc/os-release

if [ "${ID}" != "ubuntu" ]; then
    error "This script is designed for Ubuntu."
    exit 1
fi

log "Detected Ubuntu ${VERSION_ID}"

# ------------------------------------------------------------
# Check sudo
# ------------------------------------------------------------

if ! command -v sudo >/dev/null 2>&1; then
    error "sudo is required."
    exit 1
fi

# ------------------------------------------------------------
# Update system
# ------------------------------------------------------------

log "Updating Ubuntu packages..."

sudo apt-get update
sudo apt-get upgrade -y

# ------------------------------------------------------------
# Install basic utilities
# ------------------------------------------------------------

log "Installing required utilities..."

sudo apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    zip \
    gnupg \
    ca-certificates \
    lsb-release \
    apt-transport-https \
    software-properties-common \
    jq \
    net-tools \
    vim \
    htop

# ============================================================
# JAVA 21
# ============================================================

log "Installing Java 21..."

if command -v java >/dev/null 2>&1; then
    JAVA_VERSION=$(java -version 2>&1 | head -n 1)
    log "Java already installed: ${JAVA_VERSION}"
else
    sudo apt-get install -y openjdk-21-jdk
fi

# Set JAVA_HOME
JAVA_HOME_PATH=$(dirname "$(dirname "$(readlink -f "$(which java)")")")

if ! grep -q "JAVA_HOME" /etc/profile.d/java.sh 2>/dev/null; then
    sudo tee /etc/profile.d/java.sh >/dev/null <<EOF
export JAVA_HOME=${JAVA_HOME_PATH}
export PATH=\$JAVA_HOME/bin:\$PATH
EOF
fi

export JAVA_HOME="${JAVA_HOME_PATH}"
export PATH="${JAVA_HOME}/bin:${PATH}"

log "JAVA_HOME=${JAVA_HOME}"

# ============================================================
# MAVEN
# ============================================================

log "Installing Maven..."

if command -v mvn >/dev/null 2>&1; then
    log "Maven already installed."
else
    sudo apt-get install -y maven
fi

# ============================================================
# POSTGRESQL
# ============================================================

log "Installing PostgreSQL ${POSTGRES_VERSION}..."

if command -v psql >/dev/null 2>&1; then
    log "PostgreSQL already installed."
else

    # Add official PostgreSQL repository
    sudo install -d /usr/share/postgresql-common/pgdg

    curl -fsSL \
        https://www.postgresql.org/media/keys/ACCC4CF8.asc \
        | sudo gpg --dearmor \
        -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.gpg

    echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
        | sudo tee /etc/apt/sources.list.d/pgdg.list >/dev/null

    sudo apt-get update

    sudo apt-get install -y "postgresql-${POSTGRES_VERSION}" \
        "postgresql-client-${POSTGRES_VERSION}"
fi

# Start PostgreSQL
sudo systemctl enable postgresql
sudo systemctl start postgresql

log "PostgreSQL service started."

# ============================================================
# DOCKER
# ============================================================

log "Installing Docker Engine..."

if command -v docker >/dev/null 2>&1; then
    log "Docker already installed."
else

    # Remove old/conflicting packages
    sudo apt-get remove -y \
        docker.io \
        docker-doc \
        docker-compose \
        podman-docker \
        containerd \
        runc 2>/dev/null || true

    # Docker GPG key
    sudo install -m 0755 -d /etc/apt/keyrings

    sudo curl -fsSL \
        https://download.docker.com/linux/ubuntu/gpg \
        -o /etc/apt/keyrings/docker.asc

    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update

    # Install Docker
    sudo apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
fi

# Enable Docker
sudo systemctl enable docker
sudo systemctl start docker

# ============================================================
# ADD CURRENT USER TO DOCKER GROUP
# ============================================================

log "Configuring Docker for current user..."

if ! getent group docker >/dev/null 2>&1; then
    sudo groupadd docker
fi

sudo usermod -aG docker "$USER"

log "User ${USER} added to docker group."

# ============================================================
# KUBECTL
# ============================================================

log "Installing kubectl..."

if command -v kubectl >/dev/null 2>&1; then
    log "kubectl already installed."
else

    KUBECTL_VERSION=$(curl -L -s \
        https://dl.k8s.io/release/stable.txt)

    curl -LO \
        "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"

    curl -LO \
        "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256"

    echo "$(cat kubectl.sha256)  kubectl" \
        | sha256sum --check

    sudo install -o root -g root -m 0755 kubectl \
        /usr/local/bin/kubectl

    rm -f kubectl kubectl.sha256
fi

# ============================================================
# KIND
# ============================================================

log "Installing Kind..."

if command -v kind >/dev/null 2>&1; then
    log "Kind already installed."
else

    KIND_VERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest \
        | jq -r '.tag_name')

    curl -Lo ./kind \
        "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64"

    chmod +x ./kind

    sudo mv ./kind /usr/local/bin/kind
fi

# ============================================================
# DOCKER COMPOSE
# ============================================================

log "Checking Docker Compose..."

docker compose version || true

# ============================================================
# KUBERNETES CLUSTER
# ============================================================

log "Checking Kubernetes cluster..."

if kind get clusters 2>/dev/null | grep -qx "${KIND_CLUSTER_NAME}"; then

    log "Kind cluster '${KIND_CLUSTER_NAME}' already exists."

else

    log "Creating Kubernetes cluster '${KIND_CLUSTER_NAME}'..."

    kind create cluster \
        --name "${KIND_CLUSTER_NAME}"

fi

# ============================================================
# KUBECTL CONTEXT
# ============================================================

kubectl cluster-info \
    --context "kind-${KIND_CLUSTER_NAME}"

# ============================================================
# VERIFICATION
# ============================================================

echo ""
echo "============================================================"
echo " INSTALLATION VERIFICATION"
echo "============================================================"

echo ""
echo "Java:"
java -version

echo ""
echo "JAVA_HOME:"
echo "${JAVA_HOME}"

echo ""
echo "Maven:"
mvn -version

echo ""
echo "PostgreSQL:"
psql --version

echo ""
echo "PostgreSQL Service:"
sudo systemctl is-active postgresql

echo ""
echo "Docker:"
sudo docker --version

echo ""
echo "Docker Compose:"
sudo docker compose version

echo ""
echo "kubectl:"
kubectl version --client

echo ""
echo "Kind:"
kind version

echo ""
echo "Kubernetes Nodes:"
kubectl get nodes

echo ""
echo "Kubernetes Pods:"
kubectl get pods -A

echo ""
echo "============================================================"
echo " SETUP COMPLETED"
echo "============================================================"

echo ""
warn "IMPORTANT:"
echo "Log out and log back in (or reboot) for Docker group"
echo "permissions to take effect."
echo ""
echo "After logging back in, test:"
echo ""
echo "    docker ps"
echo "    kubectl get nodes"
echo "    kubectl get pods -A"
echo ""
echo "Kubernetes cluster:"
echo "    ${KIND_CLUSTER_NAME}"
echo ""
echo "============================================================"
