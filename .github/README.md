# GitHub Actions Workflows

This folder contains the CI/CD and deployment automation for the alramz-mw-oss project, which builds, tests, and deploys microservices to Azure Container Apps across multiple environments.

- **CI/CD** (`cicd.yml`) detects changed services on push to `dev`, runs tests, builds Docker images, pushes to ACR, and deploys to the dev environment.
- **Deployments** (`deploy-*.yml`) deploy services from the deployment catalogue to preprod, QA, and production environments when their respective branches are updated.
- **Promotions** (`promote-*.yml`) automatically detect service changes in dev and create PRs to promote them to preprod, QA, and production.
- **Secrets Sync** (`sync-secrets-to-keyvault.yml`) synchronizes GitHub Secrets to Azure Key Vault for each environment on demand.