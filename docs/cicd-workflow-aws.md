# AWS CI/CD Workflow

## 1. Overview

### 1.1 CI process - build, test, publish

CI is triggered by push of every branch.
CI works identically for staging and prod environment.

```mermaid
flowchart TD
    Dev["Developer pushes code"]
    GH["GitHub"]
    ECR["ECR"]

    subgraph Jenkins["Jenkins"]
        Restore["Restore"]
        Build["Build"]
        Test["Test"]
        Copy["Collect and publish\ntest results"]
        DB["Build\napi / web / migrator"]
        Scan["Security scan\nimages"]
    end

    Dev -->|push| GH
    Jenkins -->|polls every 2 min| GH
    Restore --> Build 
    Build --> Test
    Test --> Copy
    Copy --> DB
    DB --> Scan
    Jenkins --> |push images| ECR
```

The security scan fails the build on HIGH or CRITICAL findings that have a fix, before anything reaches ECR. Trivy checks the three images; its settings are in `trivy.yaml`. Pull requests run the same scan in `.github/workflows/security-scan.yml`, so findings block the merge and show in the repository's Security tab.

### 1.2 CD process - migrate, deploy, verify

CD is triggered by `master` branch.
`staging` environment.

```mermaid
flowchart TD
    ECR["ECR"]
    EKS-CP["EKS control plane"]
    Nodes["EKS Managed node group\n api / web / migrator"]

    Jenkins["Jenkins"]

    Jenkins -->|1. apply migration job<br/>2. rollout deployment| EKS-CP
    Jenkins -->|3. smoke test| Nodes  
    EKS-CP -->|schedules| Nodes
    ECR -->|image pull| Nodes
```

| Component | Provisioned by | Purpose |
| --- | --- | --- |
| `gaku-staging` EKS cluster | `modules/eks` | Runs the deployed workloads in namespace `gaku` |
| AWS Load Balancer Controller | Helm, in-cluster | Turns the overlay's Ingress objects into a shared ALB |
| External Secrets Operator | Helm, in-cluster | Materialises `gaku-secret` from Secrets Manager |

---

