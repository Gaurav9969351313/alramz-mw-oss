# Al Ramz Platform Release

Self-contained release package for the Al Ramz microservices platform. This package includes everything needed to build, package, and deploy the platform using Docker Compose.

## Overview

The release folder provides:
- `docker-compose.yml` — Platform definition with app services, PostgreSQL, and Redis
- `scripts/release.sh` — Vendor script to build, tag, push, and package images
- `scripts/deploy.sh` — Customer script to pull, deploy, and manage the platform
- `RELEASE-MANIFEST.yaml.template` — Manifest template for image digests and metadata
- `.env.example` — Template documenting all required environment variables

**Note:** Each service owns its own `Dockerfile` inside its service directory (e.g., `services/data-validation-service/Dockerfile`). There are no duplicate Dockerfiles in the release folder.

## Which Script Do I Need?

| Role | Script | Purpose |
|------|--------|---------|
| **Vendor / Release Engineer** | `scripts/release.sh` | Build services, create Docker images, push to registry, package the release |
| **Customer / Ops** | `scripts/deploy.sh` | Pull images, start/stop the platform, view logs, upgrade/rollback |

### Decision Flow

```
Are you building and publishing images?
├── YES → Use release.sh
│         ├── Interactive: ./scripts/release.sh
│         └── CI/CD:     ./scripts/release.sh --no-prompt
└── NO  → Use deploy.sh
          ├── Interactive: ./scripts/deploy.sh
          └── CI/CD:     ./scripts/deploy.sh --no-prompt
```

**Use `release.sh` when:**
- You have the source code and need to build JARs and Docker images
- You need to push images to a Docker registry
- You are creating a versioned release package (`alramz-platform-X.Y.Z.tar.gz`)
- You are running in CI/CD and need a fully automated pipeline

**Use `deploy.sh` when:**
- You have the release archive or registry access
- You need to start, stop, or restart the platform
- You need to check health, view logs, or manage running containers
- You are upgrading or rolling back a deployment

## Architecture

Services:
- **data-validation-service** (port 8080) — Validates user data against external APIs and internal DB
- **alramz-notification-service** (port 8082) — Sends notifications via Microsoft Graph
- **postgres** (port 5432) — Persistent database (Liquibase migrations)
- **redis** (port 6379) — Cache layer

Dependencies:
- data-validation-service depends on postgres and redis
- alramz-notification-service depends on postgres

Network: All services communicate via a dedicated `alramz-platform_alramz-network` bridge network.

## Prerequisites

- Docker Engine >= 20.10
- Docker Compose >= 2.0
- Maven >= 3.8
- Access to a Docker registry (for `release.sh`)

## Quick Start (Customer)

1. Unpack the release archive:
   ```bash
   tar -xzf alramz-platform-1.0.0.tar.gz
   cd alramz-platform-1.0.0
   ```

2. Configure environment:
   ```bash
   cp .env.example .env
   # Edit .env with your registry URL, tags, and secrets
   ```

3. Run the deployment manager:
   ```bash
   ./scripts/deploy.sh
   ```

4. Select **Login to Registry**, **Pull Images**, **Validate Compose**, **Start Platform**.

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `REGISTRY_URL` | Docker registry URL | `your-registry.example.com` |
| `REGISTRY_NAMESPACE` | Docker registry namespace/org | `alramz` |
| `RELEASE_VERSION` | Semantic version (e.g., `1.0.0`) | `1.0.0` |
| `DATA_VALIDATION_SERVICE_TAG` | Image tag for data-validation-service | `1.0.0` |
| `NOTIFICATION_SERVICE_TAG` | Image tag for alramz-notification-service | `1.0.0` |
| `POSTGRES_IMAGE` | PostgreSQL Docker image | `postgres:15-alpine` |
| `REDIS_IMAGE` | Redis Docker image | `redis:7-alpine` |
| `POSTGRES_DB` | Database name | `alramzmwdb` |
| `POSTGRES_USER` | Database user | `alramzmw` |
| `POSTGRES_PASSWORD` | Database password | `changeme` |
| `REDIS_PASSWORD` | Redis password (empty = no auth) | *(empty)* |
| `IBAN_API_KEY` | IBAN validation API key | *(empty)* |
| `VERIPHONE_API_KEY` | Phone validation API key | *(empty)* |
| `ETRADE_BASE_URL` | eTrade base URL | *(empty)* |
| `ETRADE_CLIENT_ID` | eTrade client ID | *(empty)* |
| `ETRADE_CLIENT_SECRET` | eTrade client secret | *(empty)* |
| `JWT_SECRET` | JWT signing secret | *(empty)* |
| `AZURE_TENANT_ID` | Azure tenant ID | *(empty)* |
| `AZURE_CLIENT_ID` | Azure client ID | *(empty)* |
| `AZURE_CLIENT_SECRET` | Azure client secret | *(empty)* |
| `CIPHER_PASSWORD` | AES cipher password for datasource encryption | *(empty)* |

## Vendor Workflow

Use `scripts/release.sh` to build and package the release.

### Build Process

The release script follows a **local-first, multi-module** build:

1. **Build all services locally with Maven** — runs `mvn clean package -DskipTests` from the repo root, building all modules in the correct order (including `alramz-common-bom` and `alramz-api-starter`)
2. **Docker build per service** — each service's Dockerfile simply copies the pre-built JAR from `target/` into a JDK runtime image
3. **No Maven inside Docker** — Docker images contain only the JRE and the application JAR

### Interactive Mode

```bash
./scripts/release.sh
```

Menu options:
1. **Validate Prerequisites** — Check docker, maven, dockerfiles
2. **Build All Services** — Maven build + Docker build for both services
3. **Build Selected Service** — Build a single service
4. **Login to Registry** — Authenticate to the Docker registry
5. **Tag Images** — Tag local images with registry path
6. **Push All Images** — Push all images to registry
7. **Push Selected Image** — Push a single image
8. **Generate Image Manifest** — Create `RELEASE-MANIFEST.yaml` with digests
9. **Verify Registry Images** — Confirm images exist in registry
10. **Validate Docker Compose** — Verify compose YAML is valid
11. **Generate Release Checksums** — SHA256 checksums for all release files
12. **Generate Release Package** — Create versioned tar.gz archive
13. **Show Release Information** — Display current release details
14. **Exit**

### CI/CD Mode

```bash
export REGISTRY_URL=registry.example.com
export REGISTRY_NAMESPACE=alramz
export RELEASE_VERSION=1.0.0
export DATA_VALIDATION_SERVICE_TAG=1.0.0
export NOTIFICATION_SERVICE_TAG=1.0.0
export REGISTRY_USERNAME=ci-user
export REGISTRY_PASSWORD=ci-password

./scripts/release.sh --no-prompt
```

This executes the full pipeline: validate → build → login → tag → push → manifest → checksums → package.

## Customer Workflow

Use `scripts/deploy.sh` to deploy and manage the platform.

### Interactive Mode

```bash
./scripts/deploy.sh
```

Menu options:
1. **Validate Prerequisites** — Check docker, compose, ports, registry
2. **Configure Environment** — Copy `.env.example` to `.env`
3. **Login to Registry** — Authenticate to the Docker registry
4. **Pull Images** — Pull all images from registry
5. **Verify Images** — Inspect pulled image digests
6. **Validate Compose** — Verify compose configuration
7. **Start Platform** — Start all services
8. **Stop Platform** — Stop all services
9. **Restart Platform** — Restart all services
10. **Platform Status** — Show container status and resource usage
11. **Health Check** — Check application health endpoints
12. **View Logs** — Tail container logs
13. **Upgrade Release** — Pull and deploy new images with rollback
14. **Rollback Release** — Restore from previous backup
15. **Exit**

### Automation Mode

```bash
export REGISTRY_URL=registry.example.com
export REGISTRY_NAMESPACE=alramz
export RELEASE_VERSION=1.0.0
export DATA_VALIDATION_SERVICE_TAG=1.0.0
export NOTIFICATION_SERVICE_TAG=1.0.0

./scripts/deploy.sh --no-prompt
```

## How to Add a New Service

To add a new microservice to the platform, follow these steps:

### 1. Create the service module

Create your service under `services/`:
```
services/
  my-new-service/
    pom.xml
    src/
    Dockerfile
```

The service must be added to the root `pom.xml` modules list:
```xml
<modules>
    <module>services/alramz-common-bom</module>
    <module>services/alramz-api-starter</module>
    <module>services/data-validation-service</module>
    <module>services/alramz-notification-service</module>
    <module>services/my-new-service</module>  <!-- add this -->
</modules>
```

### 2. Create a minimal Dockerfile

Each service must have a `Dockerfile` in its root that copies the pre-built JAR:
```dockerfile
FROM eclipse-temurin:21-jdk

WORKDIR /app
COPY target/my-new-service-*.jar app.jar
EXPOSE 8083
ENTRYPOINT ["java", "-jar", "app.jar"]
```

**Important:** The Dockerfile must use `COPY target/<artifact-name>-*.jar` — the release script builds all services locally first via Maven, then runs `docker build` with the service directory as context.

### 3. Add service to docker-compose

Edit `release/docker-compose.yml` and add the new service:

```yaml
  my-new-service:
    image: ${REGISTRY_URL}/${REGISTRY_NAMESPACE}/my-new-service:${MY_NEW_SERVICE_TAG}
    container_name: alramz-my-new-service
    restart: unless-stopped
    env_file:
      - .env
    environment:
      SPRING_PROFILES_ACTIVE: docker
      # add service-specific env vars here
    depends_on:
      postgres:
        condition: service_healthy
    ports:
      - "8083:8083"
    networks:
      - alramz-network
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:8083/actuator/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
```

### 4. Add environment variables

Add any service-specific environment variables to `release/.env` and `release/.env.example`:
```
MY_NEW_SERVICE_TAG=1.0.0
MY_API_KEY=
```

### 5. Update release.sh service list

Edit `release/scripts/release.sh` and add the service to the build loops:

- `cmd_build_all()` — add `build_service "my-new-service"`
- `cmd_push_all()` — the loop already iterates over both services; update if needed
- `cmd_verify_registry()` — same, update the loop if needed
- `cmd_generate_package()` — update if you want to include additional files

Also add the tag variable in the `main()` function:
```bash
if [ -z "$MY_NEW_SERVICE_TAG" ]; then
    read -rp "My New Service Tag [${RELEASE_VERSION}]: " MY_NEW_SERVICE_TAG
    MY_NEW_SERVICE_TAG="${MY_NEW_SERVICE_TAG:-$RELEASE_VERSION}"
fi
```

### 6. Create application-docker.yml profile

Create `services/my-new-service/src/main/resources/application-docker.yml` for container-specific configuration:
```yaml
server:
  address: 0.0.0.0
  port: 8083

spring:
  datasource:
    url: jdbc:postgresql://postgres:5432/${POSTGRES_DB}
    driver-class-name: org.postgresql.Driver
    username: ${POSTGRES_USER}
    password: ${POSTGRES_PASSWORD}
```

The base `application.yml` should set `spring.profiles.active: dev` for local development. Docker Compose overrides this via `SPRING_PROFILES_ACTIVE=docker`.

### 7. Test locally

```bash
cd release
./scripts/release.sh --no-prompt
```

## Menu Options Reference

### release.sh Options

| # | Option | Description |
|---|--------|-------------|
| 1 | Validate Prerequisites | Check docker, maven, dockerfiles |
| 2 | Build All Services | Maven + Docker build for both services |
| 3 | Build Selected Service | Build a single service |
| 4 | Login to Registry | Authenticate to Docker registry |
| 5 | Tag Images | Tag images with registry path |
| 6 | Push All Images | Push all images to registry |
| 7 | Push Selected Image | Push a single image |
| 8 | Generate Image Manifest | Create RELEASE-MANIFEST.yaml |
| 9 | Verify Registry Images | Confirm images in registry |
| 10 | Validate Docker Compose | Verify compose YAML |
| 11 | Generate Release Checksums | SHA256 checksums |
| 12 | Generate Release Package | Create versioned archive |
| 13 | Show Release Information | Display release details |
| 14 | Exit | Quit |

### deploy.sh Options

| # | Option | Description |
|---|--------|-------------|
| 1 | Validate Prerequisites | Check docker, compose, ports, registry |
| 2 | Configure Environment | Copy .env.example to .env |
| 3 | Login to Registry | Authenticate to Docker registry |
| 4 | Pull Images | Pull all images from registry |
| 5 | Verify Images | Inspect pulled image digests |
| 6 | Validate Compose | Verify compose configuration |
| 7 | Start Platform | Start all services |
| 8 | Stop Platform | Stop all services |
| 9 | Restart Platform | Restart all services |
| 10 | Platform Status | Show container status |
| 11 | Health Check | Check health endpoints |
| 12 | View Logs | Tail container logs |
| 13 | Upgrade Release | Deploy new images with rollback |
| 14 | Rollback Release | Restore from backup |
| 15 | Exit | Quit |

## Upgrade and Rollback

### Upgrade Procedure

1. Backup configuration (automatic during upgrade)
2. Pull new images
3. Verify image digests against manifest
4. Stop current platform
5. Start new platform
6. Run health checks
7. Rollback automatically if health checks fail

### Rollback Procedure

1. Stop current platform
2. Restore `.env` from backup
3. Start platform from backup
4. Run health checks

## Logging and Debugging

- All scripts log to `logs/` directory with timestamped filenames
- Log format: `[YYYY-MM-DD HH:MM:SS] [LEVEL] [FUNCTION] message`
- Use `--debug` flag for verbose output and command tracing
- Sensitive values are redacted as `[REDACTED]` in logs

## docker-compose Reference

Services, networks, and volumes are defined in `docker-compose.yml`. Key details:

- **Network**: `alramz-platform_alramz-network` (bridge driver)
- **Volumes**: `postgres_data`, `redis_data`
- **Restart policy**: `unless-stopped` for all services
- **Image naming**: `${REGISTRY_URL}/${REGISTRY_NAMESPACE}/<service-name>:<tag>`

## Troubleshooting

### Port Already in Use
If ports 8080 or 8082 are already in use, stop the conflicting process or modify the port mapping in `docker-compose.yml`.

### Registry Authentication Failed
Ensure `REGISTRY_URL` is correct and credentials are valid. Try logging in manually:
```bash
docker login docker.io -u gauravtalele1994 --password-stdin
```

### Dockerfile Not Found
Ensure the service has a `Dockerfile` at `services/<service-name>/Dockerfile`. The release script validates this in the prerequisite check.

### Maven Build Fails
Run locally first to identify issues:
```bash
mvn clean package -DskipTests
```

### Image Not Found
Verify the image tag and registry URL are correct. Use `docker manifest inspect` to check availability:
```bash
docker manifest inspect docker.io/gauravtalele1994/data-validation-service:1.0.0
```
