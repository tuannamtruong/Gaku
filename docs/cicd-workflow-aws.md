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
    end

    Dev -->|push| GH
    GH -->|webhook| Jenkins
    Restore --> Build 
    Build --> Test
    Test --> Copy
    Copy --> DB
    Jenkins --> |push images| ECR
```

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

