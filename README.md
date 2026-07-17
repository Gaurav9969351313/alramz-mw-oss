# Al Ramz Middleware & Infrastructure Ecosystem

Welcome to the **Al Ramz Middleware and Infrastructure** repository. This repository implements a modern, secure, and highly scalable cloud-native middleware ecosystem on Microsoft Azure. It combines containerized Java microservices with fully modular Infrastructure as Code (IaC) using Terraform, backed by an automated CI/CD pipeline.

---

## 🏛️ System Architecture

The infrastructure strategy is designed for enterprise grade isolation, security, and scalability. It leverages Azure Container Apps (ACA) for serverless container execution and Azure API Management (APIM) as the gateway.

Detailed architectural assets are located in the [docs/](file:///c:/Users/User/Desktop/alramz-mw-oss/docs) directory:
* **Infrastructure Components**: The component-level blueprint of the Azure setup is detailed in [finalComponentDiagram.drawio](file:///c:/Users/User/Desktop/alramz-mw-oss/docs/finalComponentDiagram.drawio) and [finalCloudFlocusedComponentDiagram-v-0-0-1.svg](file:///c:/Users/User/Desktop/alramz-mw-oss/docs/finalCloudFlocusedComponentDiagram-v-0-0-1.svg).
* **Virtual Network (VNet) Strategy**: Detailed plan for private networking, subnets, internal/external load balancing, and Hub-Spoke topology in [virtual-network-strategy.drawio](file:///c:/Users/User/Desktop/alramz-mw-oss/docs/virtual-network-strategy.drawio) and [virtual-network-strategy.svg](file:///c:/Users/User/Desktop/alramz-mw-oss/docs/virtual-network-strategy.svg).
* **CI/CD Lifecycle**: The path-filtered continuous integration pipeline flow in [cicd.drawio](file:///c:/Users/User/Desktop/alramz-mw-oss/docs/cicd.drawio) and [cicd.svg](file:///c:/Users/User/Desktop/alramz-mw-oss/docs/cicd.svg).

---

## 📂 Repository Directory Layout

Below is a detailed map of the files and directories in the repository:

```text
alramz-mw-oss/
├── .github/                                  # CI/CD Workflows & Custom Actions
│   ├── actions/
│   │   ├── build-service/
│   │   │   └── action.yaml                   # Docker Build & Push composite action
│   │   └── maven-test/
│   │       └── action.yml                    # Java Setup & Maven Test runner
│   └── workflows/
│       └── cicd.yml                          # Master GitHub Actions workflow
├── docs/                                     # Architecture diagrams and drawings
│   ├── cicd.drawio
│   ├── cicd.svg
│   ├── finalCloudFlocusedComponentDiagram-v-0-0-1.svg
│   ├── finalComponentDiagram.drawio
│   ├── virtual-network-strategy.drawio
│   └── virtual-network-strategy.svg
├── infra/                                    # Terraform Infrastructure as Code
│   ├── environments/                         # Environment-specific configuration files
│   │   ├── dev.tfvars                        # Development env variables
│   │   ├── preprod.tfvars                    # Pre-production env variables
│   │   ├── prod.tfvars                       # Production env variables
│   │   ├── qa.tfvars                         # QA env variables
│   │   └── shared-platform.tfvars            # Shared platform variables (ACR, etc)
│   ├── modules/                              # Reusable Terraform Modules
│   │   ├── acr/                              # Azure Container Registry setup
│   │   ├── apim/                             # Azure API Management gateway
│   │   ├── container-app-environment/        # Azure Container App Environment
│   │   ├── key-vault/                        # Azure Key Vault with RBAC
│   │   ├── monitoring/                       # Log Analytics & App Insights
│   │   ├── resource-group/                   # Resource Group provisioning
│   │   └── service-principal/                # Azure AD Application & Service Principal
│   └── stacks/                               # Root Terraform deployments
│       ├── dev/                              # Dev Environment Stack
│       ├── preprod/                          # Preprod Environment Stack (Placeholder)
│       ├── prod/                             # Prod Environment Stack (Placeholder)
│       ├── qa/                               # QA Environment Stack (Placeholder)
│       └── shared-platform/                  # Shared Platform Stack (ACR & Service Principals)
├── services/                                 # Microservice applications
│   └── data-validation-service/              # Java Spring Boot validation service
│       ├── .mvn/
│       ├── src/                              # Source code directory
│       ├── Dockerfile                        # Multi-stage containerization build file
│       ├── HELP.md                           # Spring Boot starter helper info
│       ├── apiCollection.http                # REST API Client collection endpoints
│       ├── mvnw                              # Maven wrapper (UNIX)
│       ├── mvnw.cmd                          # Maven wrapper (Windows)
│       └── pom.xml                           # Maven dependencies build configuration
├── notes.md                                  # Setup commands, state backend, and credentials
└── README.md                                 # This file
```

---

## ☕ Services

### 📊 Data Validation Service

The [data-validation-service](file:///c:/Users/User/Desktop/alramz-mw-oss/services/data-validation-service) is a Java-based microservice designed for validating middleware payloads.

#### Key Features:
* **Tech Stack**: Built with **Java 21** and **Spring Boot 4.1.0**.
* **Database**: Embedded in-memory **H2 database** with an active H2 Console for local diagnostics.
* **ORM & Data**: Spring Data JPA for persistence.
* **Boilerplate Reduction**: Project Lombok for automatic getters, setters, and builders.
* **Observability**: Spring Boot Actuator endpoints enabled to monitor service health.
* **Testing**: JUnit 5 tests inside [DataValidationServiceApplicationTests.java](file:///c:/Users/User/Desktop/alramz-mw-oss/services/data-validation-service/src/test/java/com/alramz/DataValidationServiceApplicationTests.java).

#### Local Development:
1. Make sure you have Java 21 JDK and Maven installed.
2. Run the application from the microservice folder:
   ```bash
   cd services/data-validation-service
   ./mvnw spring-boot:run
   ```
3. The service starts on port `5001`. You can test the main endpoint using `curl` or the provided HTTP request helper in [apiCollection.http](file:///c:/Users/User/Desktop/alramz-mw-oss/services/data-validation-service/apiCollection.http):
   ```bash
   curl http://localhost:5001/api/v1/info
   ```
   **Response Format:**
   ```json
   {
     "applicationName": "data-validation-service",
     "host": "<your-hostname>",
     "timestamp": "2026-07-17T12:00:00Z"
   }
   ```
4. Access the **H2 Console** at: `http://localhost:5001/h2-console`
   * **JDBC URL**: `jdbc:h2:mem:testdb`
   * **Username**: `sa`
   * **Password**: *(leave blank)*

#### Docker Build:
The service provides a optimized multi-stage build in its [Dockerfile](file:///c:/Users/User/Desktop/alramz-mw-oss/services/data-validation-service/Dockerfile):
```dockerfile
# Stage 1: Build the artifact
FROM maven AS build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -B
COPY src ./src
RUN mvn clean package -DskipTests

# Stage 2: Final lightweight JRE layer
FROM eclipse-temurin:21-jdk AS final
WORKDIR /app
COPY --from=build /app/target/data-validation-service-*.jar app.jar
EXPOSE 5001
ENTRYPOINT ["java", "-jar", "app.jar"]
```
To build it manually:
```bash
docker build -t alramz/data-validation-service:latest ./services/data-validation-service
```

---

## 🛠️ Infrastructure as Code (IaC)

All Azure resources are managed declaratively inside the [infra/](file:///c:/Users/User/Desktop/alramz-mw-oss/infra) directory.

### Backend State Configuration
Terraform uses an Azure Storage Account backend to share state files remotely. The backend configurations are located inside the stack folders:
* Shared Platform state config: [shared-platform/backend.tf](file:///c:/Users/User/Desktop/alramz-mw-oss/infra/stacks/shared-platform/backend.tf)
* Dev environment state config: [dev/backend.tf](file:///c:/Users/User/Desktop/alramz-mw-oss/infra/stacks/dev/backend.tf)

The state resources reside under:
* **Resource Group**: `alramz-tf-assets-rg`
* **Storage Account**: `alramztfstatefiles98`
* **Containers**: `devtfstate`, `qatfstate`, `preprodtfstate`, `prodtfstate`, `sharedplatformtfstate`

Refer to [notes.md](file:///c:/Users/User/Desktop/alramz-mw-oss/notes.md) for the exact Azure CLI commands used to spin up this remote backend.

### 🏢 Stacks & Deployments

#### 1. Shared Platform Stack
Located in [infra/stacks/shared-platform](file:///c:/Users/User/Desktop/alramz-mw-oss/infra/stacks/shared-platform). It provisions:
* **Azure Container Registry (ACR)** (`alramzregistry`): Stores docker images for all microservices.
* **GitHub Actions Service Principal**: Service Principal assigned with `AcrPush`, `Contributor`, and `AcrPull` roles to push docker images securely during builds.
* **ACA Pull Service Principal**: Used by Azure Container Apps to pull docker images from the registry.

#### 2. Environment Stacks (e.g. Dev Stack)
Located in [infra/stacks/dev](file:///c:/Users/User/Desktop/alramz-mw-oss/infra/stacks/dev). It provisions:
* **Resource Group**: Isolated RG (`alramz-dev-rg`).
* **Key Vault**: Standard SKU Key Vault with Azure RBAC authentication enabled. Public network access is disabled for enhanced security.
* **Azure API Management (APIM)**: Exposes endpoints publicly and routes them safely. SKU is set to `Developer_1` (customizable).
* **Container App Environment**: The hosting cluster environment for running Azure Container Apps.
* **Azure Monitor**: Provisions a Log Analytics Workspace and an Application Insights instance with a 30-day retention policy.

### 🚀 Deploying Infrastructure
Ensure you are authenticated in Azure CLI:
```powershell
az login
az account set --subscription "<subscription-id>"
```
Register the required Resource Providers using the helper script [registerProviders.ps1](file:///c:/Users/User/Desktop/alramz-mw-oss/infra/utils/registerProviders.ps1):
```powershell
./infra/utils/registerProviders.ps1
```
Run Terraform for a specific stack (e.g., `dev`):
```bash
cd infra/stacks/dev
terraform init
terraform plan -var-file="../../environments/dev.tfvars"
terraform apply -var-file="../../environments/dev.tfvars"
```

---

## 🔄 CI/CD Pipeline

The continuous integration and deployment flow is configured via GitHub Actions in [.github/workflows/cicd.yml](file:///c:/Users/User/Desktop/alramz-mw-oss/.github/workflows/cicd.yml).

### Workflow Mechanism:
1. **Trigger**: Executes on `workflow_dispatch` or on a `push` to the `dev` branch.
2. **Detect Changes (Monorepo Optimization)**: Uses `dorny/paths-filter@v3` to scan the `services/` directory and build a dynamic matrix containing only the modified microservices. This avoids wasting runner execution hours.
3. **Automated Testing**: Runs Java 21 Maven tests for each modified microservice via the composite action [maven-test/action.yml](file:///c:/Users/User/Desktop/alramz-mw-oss/.github/actions/maven-test/action.yml).
4. **Docker Build & Push**: Logs into the Azure Container Registry and executes the composite action [build-service/action.yaml](file:///c:/Users/User/Desktop/alramz-mw-oss/.github/actions/build-service/action.yaml). It builds the multi-stage Docker image, tags it with the first 5 characters of the git commit SHA, and pushes it to the registry.

---

## 🔒 Security & Best Practices

1. **Least Privilege**: Deployment is governed by separate Service Principals (`GitHub Actions` SP and `ACA Pull` SP) with scoped RBAC roles.
2. **Key Vault Isolation**: Key Vault restricts access to the public network (`public_network_access_enabled = false`) and uses Role-Based Access Control (RBAC) with the `Key Vault Secrets User` role for services instead of old-style Access Policies.
3. **State File Protection**: Remote state is stored in encrypted Azure blob storage with locked access keys.
