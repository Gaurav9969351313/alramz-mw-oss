# Kubernetes Manifests

This folder contains the full Kubernetes deployment manifests for the Al Ramz Middleware platform, organized by **infrastructure** and **applications** with **Kustomize** overlays for environment-specific configuration. ArgoCD is used for GitOps-based delivery.

## Folder Structure

```
k8s/
├── apps/
│   ├── base/                    # Reusable base manifests for each microservice
│   │   ├── data-validation-service/
│   │   │   ├── configmap.yaml
│   │   │   ├── deployment.yaml
│   │   │   ├── pdb.yaml
│   │   │   ├── secret.yaml
│   │   │   ├── service.yaml
│   │   │   └── kustomization.yaml
│   │   └── alramz-notification-service/
│   │       ├── configmap.yaml
│   │       ├── deployment.yaml
│   │       ├── pdb.yaml
│   │       ├── secret.yaml
│   │       ├── service.yaml
│   │       └── kustomization.yaml
│   └── overlays/                # Environment-specific overlays (dev, test, preprod, prod)
│       ├── dev/
│       │   ├── kustomization.yaml
│       │   └── patches.yaml
│       ├── test/
│       │   ├── kustomization.yaml
│       │   └── patches.yaml
│       ├── preprod/
│       │   ├── kustomization.yaml
│       │   └── patches.yaml
│       └── prod/
│           ├── kustomization.yaml
│           └── patches.yaml
├── environments/                # Namespace definitions per environment
│   ├── dev/
│   │   └── namespace.yaml
│   ├── test/
│   │   └── namespace.yaml
│   ├── preprod/
│   │   └── namespace.yaml
│   └── prod/
│       └── namespace.yaml
├── infra/                       # Shared infrastructure services
│   ├── headlamp/                # Kubernetes Web UI
│   ├── postgres/                # PostgreSQL database
│   ├── redis/                   # Redis cache
│   └── seq/                     # Seq log aggregator
└── argocd/                      # ArgoCD Application definitions
    ├── project.yaml
    ├── dev.yaml
    ├── test.yaml
    ├── preprod.yaml
    └── prod.yaml
```

## Prerequisites

- `kubectl` configured for the target cluster
- `kustomize` (v4.5+) or `kubectl` with Kustomize support (`kubectl apply -k`)
- `argo` CLI (optional, for ArgoCD operations)

## What Is Deployed

### Infrastructure (`k8s/infra/`)

| Service      | Namespace    | Service Port | Container Port | Access Method                |
|--------------|--------------|--------------|----------------|------------------------------|
| Headlamp     | `headlamp`   | 80           | 4466           | `kubectl port-forward`       |
| PostgreSQL   | `<env>`      | 5432         | 5432           | ClusterIP / port-forward     |
| Redis        | `<env>`      | 6379         | 6379           | ClusterIP / port-forward     |
| Seq          | `<env>`      | 80           | 80             | `kubectl port-forward`       |

### Applications (`k8s/apps/`)

| Service                       | Namespace    | Service Port | Container Port |
|-------------------------------|--------------|--------------|----------------|
| data-validation-service       | `<env>`      | 8080         | 8080           |
| alramz-notification-service    | `<env>`      | 8082         | 8082           |

> Replace `<env>` with the target environment namespace: `alramz-dev`, `alramz-test`, `alramz-preprod`, or `alramz-prod`.

## How to Use

### 1. Create Namespaces

```bash
kubectl apply -f k8s/environments/
```

### 2. Deploy Infrastructure

```bash
kubectl apply -f k8s/infra/
```

Or use Kustomize:

```bash
kubectl apply -k k8s/infra/postgres/
kubectl apply -k k8s/infra/redis/
kubectl apply -k k8s/infra/seq/
kubectl apply -f k8s/infra/headlamp/
```

### 3. Deploy Applications (Base or Overlay)

Deploy a specific app base:

```bash
kubectl apply -k k8s/apps/base/data-validation-service/
kubectl apply -k k8s/apps/base/alramz-notification-service/
```

Deploy with environment overlay:

```bash
kubectl apply -k k8s/apps/overlays/dev
kubectl apply -k k8s/apps/overlays/test
kubectl apply -k k8s/apps/overlays/preprod
kubectl apply -k k8s/apps/overlays/prod
```

Build and preview the final rendered manifests:

```bash
kustomize build k8s/apps/overlays/dev
```

### 4. Verify Deployment

```bash
# Check pods
kubectl get pods -n alramz-dev

# Check services
kubectl get svc -n alramz-dev

# Check infrastructure
kubectl get pods -n headlamp
kubectl get pods -n alramz-dev
```

## Accessing Services

All services are `ClusterIP` by default. Use `kubectl port-forward` to expose them locally.

### Headlamp (Kubernetes Dashboard)

```bash
kubectl port-forward svc/headlamp -n headlamp 8000:80
```

Open `http://localhost:8000`

Authenticate using the service account token:

```bash
kubectl create token headlamp -n headlamp
```

### Seq (Log Aggregator)

```bash
kubectl port-forward svc/seq -n alramz-dev 5341:80
```

Open `http://localhost:5341`

Default admin password is stored in the `seq/secret.yaml` manifest.

### PostgreSQL

```bash
kubectl port-forward svc/postgres -n alramz-dev 5432:5432
```

Connect using any PostgreSQL client:

```bash
psql -h localhost -p 5432 -U <username> -d <database>
```

### Redis

```bash
kubectl port-forward svc/redis -n alramz-dev 6379:6379
```

Connect using Redis CLI:

```bash
redis-cli -h localhost -p 6379
```

### Microservices

```bash
# data-validation-service
kubectl port-forward svc/data-validation-service -n alramz-dev 8080:8080

# alramz-notification-service
kubectl port-forward svc/alramz-notification-service -n alramz-dev 8082:8082
```

## Common Commands

```bash
# Get all resources in a namespace
kubectl get all -n alramz-dev

# View logs
kubectl logs -l app=data-validation-service -n alramz-dev -f

# Describe a pod for debugging
kubectl describe pod -l app=data-validation-service -n alramz-dev

# Execute into a container
kubectl exec -it <pod-name> -n alramz-dev -- /bin/sh

# Delete all resources in an overlay
kubectl delete -k k8s/apps/overlays/dev

# Delete infrastructure
kubectl delete -f k8s/infra/
```

## ArgoCD GitOps

ArgoCD Application manifests are defined in `k8s/argocd/`. Each environment has its own Application pointing to the corresponding overlay path.

Sync via ArgoCD CLI:

```bash
# List apps
argo app list

# Sync dev environment
argo app sync alramz-dev

# Sync all apps
argo app sync alramz-dev alramz-test alramz-preprod alramz-prod
```

## Environment Variables & Secrets

Sensitive values are stored in Kubernetes Secrets. Never commit plaintext secrets to version control.

For local development, ensure you have the correct `kubeconfig` context set:

```bash
kubectl config use-context <your-cluster-context>
kubectl config current-context
```
=====================================================================================================================
kubectl port-forward svc/pgadmin -n alramz-dev 5555:80
Open http://localhost:5555

Login:

Email: admin@alramz.ae
Password: admin123
Then add the PostgreSQL server:

Host: postgres
Port: 5432
Database: alramzmwdb
Username: alramzmw
Password: changeme
=====================================================================================================================

export POD_NAME=$(kubectl get pods --namespace kube-system -l "app.kubernetes.io/name=headlamp,app.kubernetes.io/instance=alramz-headlamp" -o jsonpath="{.items[0].metadata.name}")

kubectl --namespace kube-system port-forward $POD_NAME 8084:4466

kubectl create token headlamp-admin -n kube-system
=====================================================================================================================

kubectl port-forward svc/argocd-server -n argocd 8083:443
KjK0bYZGO4WHIdef

=====================================================================================================================