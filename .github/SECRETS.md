# GitHub Actions Secrets & Environments Configuration

This document describes all secrets and environments required for the CI/CD pipelines.

---

## Configuration File

All Azure resource names are centralized in `.github/config/environments.json`. Update this file when resource names change — no workflow modifications needed.

```json
{
  "dev": {
    "resourceGroup": "alramz-dev-rg",
    "aksCluster": "alramz-dev-aks",
    "aksNamespace": "dev",
    "apimName": "alramz-dev-apim",
    "keyVault": "alramz-dev-key-vault",
    "keyVaultTenantId": "",
    "managedIdentityClientId": ""
  },
  ...
}
```

---

## GitHub Secrets

### Azure Authentication (OIDC)

| Secret | Description | Used By |
|--------|-------------|---------|
| `AZURE_CLIENT_ID` | Azure AD application client ID for OIDC authentication | All workflows |
| `AZURE_TENANT_ID` | Azure AD tenant ID | All workflows |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | All workflows |

### Container Registries

| Secret | Description | Used By |
|--------|-------------|---------|
| `GITHUB_TOKEN` | Auto-generated token for GHCR and PR operations | `cicd.yml`, `promote.yml`, `feature-deploy.yml` |
| `GH_TOKEN` | Custom GitHub token with `repo` and `packages:write` scope | `cicd.yml`, `promote.yml`, `feature-deploy.yml` |
| `DOCKERHUB_USERNAME` | Docker Hub username | `cicd.yml`, `feature-deploy.yml`, `feature-deploy-fast.yml` |
| `DOCKERHUB_PASSWORD` | Docker Hub access token | `cicd.yml`, `feature-deploy.yml`, `feature-deploy-fast.yml` |

### Managed Identity (Key Vault CSI Driver)

| Secret | Description | Used By |
|--------|-------------|---------|
| `MANAGED_IDENTITY_CLIENT_ID_DEV` | User-assigned managed identity client ID for dev | `cicd.yml` |
| `MANAGED_IDENTITY_CLIENT_ID_QA` | User-assigned managed identity client ID for QA | `promote.yml` |
| `MANAGED_IDENTITY_CLIENT_ID_PREPROD` | User-assigned managed identity client ID for preprod | `promote.yml` |
| `MANAGED_IDENTITY_CLIENT_ID_PROD` | User-assigned managed identity client ID for prod | `promote.yml` |

### Database Credentials (Liquibase)

| Secret | Description | Used By |
|--------|-------------|---------|
| `DB_URL_DEV` | JDBC URL for dev database | `promote.yml`, `feature-deploy.yml` |
| `DB_URL_QA` | JDBC URL for QA database | `promote.yml`, `feature-deploy.yml` |
| `DB_URL_PREPROD` | JDBC URL for preprod database | `promote.yml`, `feature-deploy.yml` |
| `DB_URL_PROD` | JDBC URL for prod database | `promote.yml`, `feature-deploy.yml` |
| `DB_USERNAME_DEV` | Database username for dev | `promote.yml`, `feature-deploy.yml` |
| `DB_USERNAME_QA` | database username for QA | `promote.yml`, `feature-deploy.yml` |
| `DB_USERNAME_PREPROD` | Database username for preprod | `promote.yml`, `feature-deploy.yml` |
| `DB_USERNAME_PROD` | Database username for prod | `promote.yml`, `feature-deploy.yml` |

---

## GitHub Environments

Environments provide deployment gates (approvals) and environment-specific secrets.

| Environment | Purpose | Approval Required |
|-------------|---------|-------------------|
| `dev` | Development environment | No |
| `test` | Testing/QA environment | No |
| `qa` | QA staging environment | Yes (1 approver) |
| `preprod` | Pre-production environment | Yes (1 approver) |
| `prod` | Production environment | Yes (2 approvers) |

### Environment Protection Rules

Configure in GitHub Settings > Environments:

| Environment | Required Reviewers | Wait Timer | Allowed Branches |
|-------------|-------------------|------------|------------------|
| `dev` | 0 | 0 | `dev` |
| `test` | 0 | 0 | `dev`, `feature/*` |
| `qa` | 1 | 0 | `qa` |
| `preprod` | 1 | 0 | `preprod` |
| `prod` | 2 | 5 min | `prod` |

---

## Azure Resources Mapping

Resource names are defined in `.github/config/environments.json`. The table below shows the default values:

| Environment | Resource Group | AKS Cluster | APIM Instance | Key Vault |
|-------------|---------------|-------------|---------------|-----------|
| dev | `alramz-dev-rg` | `alramz-dev-aks` | `alramz-dev-apim` | `alramz-dev-key-vault` |
| qa | `alramz-qa-rg` | `alramz-qa-aks` | `alramz-qa-apim` | `alramz-qa-key-vault` |
| preprod | `alramz-preprod-rg` | `alramz-preprod-aks` | `alramz-preprod-apim` | `alramz-preprod-key-vault` |
| prod | `alramz-prod-rg` | `alramz-prod-aks` | `alramz-prod-apim` | `alramz-prod-key-vault` |

---

## Azure Configuration

### Azure AD App Registration (OIDC)

1. Create an Azure AD application registration
2. Configure federated credentials for GitHub Actions:
   - **Issuer**: `https://token.actions.githubusercontent.com`
   - **Subject**: `repo:<org>/<repo>:ref:refs/heads/dev` (repeat for each branch)
3. Assign roles:
   - **ACR Push/Pull**: `AcrPush`, `AcrPull` on `alramzregistry`
   - **AKS Access**: `Azure Kubernetes Service Cluster User Role`
   - **APIM Contributor**: `API Management Service Contributor`
   - **Managed Identity Operator**: For Key Vault CSI driver

### Azure Container Registry

| Setting | Value |
|---------|-------|
| Name | `alramzregistry` |
| SKU | Standard or Premium |
| Admin enabled | No (use OIDC) |
| Trusted services | Enabled |

### Azure Key Vault Secrets

Each Key Vault must contain:

| Secret Name | Source | Description |
|-------------|--------|-------------|
| `DB_PASSWORD` | Manual/DBA | Database password for Liquibase migration |

### AKS Cluster Configuration

| Setting | Value |
|---------|-------|
| Identity | System-assigned or user-assigned |
| Network | Azure CNI |
| Ingress | NGINX Ingress Controller (internal) |
| Secret Store CSI Driver | Enabled |
| Workload Identity | Enabled |

### Azure API Management

| Setting | Value |
|---------|-------|
| SKU | Developer (dev), Standard (qa/prod) |
| Virtual network | Internal |
| Custom domains | `*.alramz.io` |
| Subscription required | Yes |

---

## Workflow Triggers Summary

| Workflow | Trigger | Environments |
|----------|---------|--------------|
| `cicd.yml` | Push to `dev`, `feature/*` | dev |
| `promote.yml` | Push to `qa`, `preprod`, `prod` | qa, preprod, prod |
| `feature-deploy.yml` | `workflow_dispatch` | dev, qa, preprod, prod |
| `feature-deploy-fast.yml` | `workflow_dispatch` | dev, test |
| `rollback.yml` | `workflow_dispatch` | dev, qa, preprod, prod |
| `restart-pods.yml` | `workflow_dispatch` | dev, qa, preprod, prod |
| `api-spec-sync.yml` | Push (spec changes), `workflow_dispatch` | dev, qa, preprod, prod |
| `sync-secrets-to-keyvault.yml` | `workflow_dispatch` | dev, qa, preprod, prod |
| `pr-validation.yml` | Pull request | N/A |

---

## Setting Up Secrets

### Via GitHub CLI

```bash
# Set repository secrets
gh secret set AZURE_CLIENT_ID --body "<client-id>"
gh secret set AZURE_TENANT_ID --body "<tenant-id>"
gh secret set AZURE_SUBSCRIPTION_ID --body "<subscription-id>"
gh secret set DOCKERHUB_USERNAME --body "<username>"
gh secret set DOCKERHUB_PASSWORD --body "<token>"
gh secret set GH_TOKEN --body "<personal-access-token>"

# Set managed identity client IDs
gh secret set MANAGED_IDENTITY_CLIENT_ID_DEV --body "<client-id>"
gh secret set MANAGED_IDENTITY_CLIENT_ID_QA --body "<client-id>"
gh secret set MANAGED_IDENTITY_CLIENT_ID_PREPROD --body "<client-id>"
gh secret set MANAGED_IDENTITY_CLIENT_ID_PROD --body "<client-id>"

# Set database credentials
gh secret set DB_URL_DEV --body "<jdbc-url>"
gh secret set DB_USERNAME_DEV --body "<username>"
gh secret set DB_URL_QA --body "<jdbc-url>"
gh secret set DB_USERNAME_QA --body "<username>"
gh secret set DB_URL_PREPROD --body "<jdbc-url>"
gh secret set DB_USERNAME_PREPROD --body "<username>"
gh secret set DB_URL_PROD --body "<jdbc-url>"
gh secret set DB_USERNAME_PROD --body "<username>"
```

### Via GitHub UI

1. Go to **Settings > Secrets and variables > Actions**
2. Click **New repository secret**
3. Enter name and value
4. Click **Add secret**

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| OIDC login fails | Verify federated credential subject matches branch |
| ACR push denied | Check `AcrPush` role assignment |
| AKS access denied | Check `Azure Kubernetes Service Cluster User Role` |
| Key Vault CSI fails | Verify managed identity client ID and Key Vault access policy |
| APIM sync fails | Check `API Management Service Contributor` role |
| DB migration fails | Verify DB_URL, DB_USERNAME secrets and Key Vault DB_PASSWORD |
