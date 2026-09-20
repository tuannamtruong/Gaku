# Infrastructure test status

## 1. AWS

Two Terraform environments, `staging` and `production`, over the one shared state backend they
both write to.

### 1.1 Shared bootstrap

`infra/terraform/bootstrap` — the S3 remote state backend both AWS environments write to. Applied
once, before anything in [§1.2 Staging](#12-staging) or
[§1.3 Production](#13-production).

| Component | Pass criterion | Status | Last tested | Commit | Evidence |
| --- | --- | --- | --- | --- | --- |
| `aws_s3_bucket.state` | Bucket exists and accepts a state write | Not tested | — | — | — |
| Versioning | Previous state versions are retrievable | Not tested | — | — | — |
| Server-side encryption | Objects report SSE on `head-object` | Not tested | — | — | — |
| Public access block | All four block settings are on | Not tested | — | — | — |
| Ownership controls | Bucket-owner-enforced, ACLs disabled | Not tested | — | — | — |
| Lifecycle configuration | Noncurrent versions expire on the configured schedule | Not tested | — | — | — |
| `state_tls_only` policy | A plain-HTTP request to the bucket is denied | Not tested | — | — | — |

### 1.2 Staging

`infra/terraform/environments/staging`, `infra/k8s/overlays/staging`, and `Jenkinsfile.aws`.
EKS with RDS, images from ECR, traffic through an ALB.

#### 1.2.1 Terraform

| Component | Pass criterion | Status | Last tested | Commit | Evidence |
| --- | --- | --- | --- | --- | --- |
| `module.vpc` | Applies clean; subnets, routing and NAT reachable as designed | Partial | 2026-09-20 | 82fcec6 | [record](archive/2026-09-20-jenkins-aws-ecr-push.md) — public subnets, route table and IGW carried the controller; private subnets and NAT unexercised |
| `module.eks` | Cluster reachable with `kubectl`, nodes `Ready` | Not tested | — | — | — |
| `module.rds` | Instance available, reachable from a cluster pod | Not tested | — | — | — |
| `module.ecr` | Repositories exist and accept a push | Pass | 2026-09-20 | 82fcec6 | [record](archive/2026-09-20-jenkins-aws-ecr-push.md) — all three repositories accepted a push |
| `module.in_cluster_controller_identity` | Controller service account assumes its IAM role | Not tested | — | — | — |
| `module.jenkins` | Jenkins controller identity and access as designed | Partial | 2026-09-20 | 82fcec6 | [record](archive/2026-09-20-jenkins-aws-ecr-push.md) — instance profile and ECR policy proven; applied with `enable_eks_access = false`, so the EKS half is unexercised |
| `aws_eks_access_entry.jenkins` + policy association | Jenkins can `kubectl` against the cluster | Not tested | — | — | — |
| `terraform plan` on a clean tree | No drift after a successful apply | Not tested | — | — | — |

#### 1.2.2 Cluster add-ons and manifests

| Component | Pass criterion | Status | Last tested | Commit | Evidence |
| --- | --- | --- | --- | --- | --- |
| `controllers/aws-load-balancer-controller.values.yaml` | Controller pods `Ready`, no IAM errors in the log | Not tested | — | — | — |
| `overlays/staging/external-secret.yaml` | `gaku-secret` is materialised from the external store | Not tested | — | — | — |
| `components/alb-ingress/ingress-api.yaml` | ALB provisioned, API reachable through it | Not tested | — | — | — |
| `components/alb-ingress/ingress-web.yaml` | Web reachable through the same ALB group | Not tested | — | — | — |
| Image tag substitution | The overlay resolves to the ECR tag the build pushed | Not tested | — | — | — |
| `overlays/staging/migrate` | Migration job completes against RDS | Not tested | — | — | — |

#### 1.2.3 Pipeline (`Jenkinsfile.aws`)

| Component | Pass criterion | Status | Last tested | Commit | Evidence |
| --- | --- | --- | --- | --- | --- |
| Stage `Restore & Build` | Solution builds in the CI image | Pass | 2026-09-20 | 82fcec6 | [record](archive/2026-09-20-jenkins-aws-ecr-push.md) |
| Stages `Test — Domain/Application/Infrastructure/Web` | All four suites run and publish results | Pass | 2026-09-20 | 82fcec6 | [record](archive/2026-09-20-jenkins-aws-ecr-push.md) |
| Stage `Docker Build` | All three images build | Pass | 2026-09-20 | 82fcec6 | [record](archive/2026-09-20-jenkins-aws-ecr-push.md) |
| Stage `Push to ECR` | Images arrive in ECR under the build tag | Pass | 2026-09-20 | 82fcec6 | [record](archive/2026-09-20-jenkins-aws-ecr-push.md) |
| Stage `Migrate Staging Database` | Migration job completes against RDS | Not tested | — | — | — |
| Stage `Deploy to Staging` | Rollouts complete on the new tag | Not tested | — | — | — |
| Stage `Smoke Test` | `/api/health` and `/api/echo` answer through the ALB hostname | Not tested | — | — | — |
| End-to-end run | A push to `master` reaches a green smoke test | Not tested | — | — | — |

### 1.3 Production

`infra/terraform/environments/production`. Terraform only — there is no `overlays/production`
kustomization and no pipeline targeting production yet, so deployment rows will be added when
those exist.

| Component | Pass criterion | Status | Last tested | Commit | Evidence |
| --- | --- | --- | --- | --- | --- |
| `module.vpc` | Applies clean; subnets, routing and NAT reachable as designed | Not tested | — | — | — |
| `module.eks` | Cluster reachable with `kubectl`, nodes `Ready` | Not tested | — | — | — |
| `module.rds` | Instance available, reachable from a cluster pod | Not tested | — | — | — |
| `module.ecr` | Repositories exist and accept a push | Not tested | — | — | — |
| `module.jenkins` | Jenkins controller identity and access as designed | Not tested | — | — | — |
| `aws_eks_access_entry.jenkins` + policy association | Jenkins can `kubectl` against the cluster | Not tested | — | — | — |
| `terraform plan` on a clean tree | No drift after a successful apply | Not tested | — | — | — |
| Cluster add-ons | — (no production overlay yet) | Not tested | — | — | — |
| Deployment pipeline | — (no production pipeline yet) | Not tested | — | — | — |

## 2. Local

### 2.1 Docker Image

`docker-compose.yml` at the repo root, reading `.env`. Ports: PostgreSQL `5432`, API `8080`,
Web `8081`. 

| Component | Pass criterion | Status | Last tested | Commit |
| --- | --- | --- | --- | --- |
| `docker/Dockerfile` target `api` | Image builds from a clean context | Not tested | — | — |
| `docker/Dockerfile` target `web` | Image builds from a clean context | Not tested | — | — |
| `docker/Dockerfile` target `migrator` | Image builds from a clean context | Not tested | — | — |
| `postgres` service | Container starts and `pg_isready` healthcheck goes healthy | Not tested | — | — |
| `db-migrator` service | Migrations apply to an empty volume, container exits `0` | Not tested | — | — |
| `gaku-api` service | `GET http://localhost:8080/api/health` returns `200` | Not tested | — | — |
| `gaku-web` service | `http://localhost:8081` renders the map page, no console errors | Not tested | — | — |
| Full stack | `docker compose up --build -d` reaches all-healthy from a clean `docker compose down -v` | Not tested | — | — |

### 2.2 Kubernetes

Applying [§3 Deploy](infra-local.md#3-deploy), [§4 Verification](infra-local.md#4-verification) and [§5 Redeploy](infra-local.md#5-redeploy) from [Infrastructure - Local](infra-local.md).

| Stage | Status | Last tested | Commit |
| --- | --- | --- | --- |
| [§3 Deploy](infra-local.md#3-deploy) | Not tested | 2026-09-20 | 7ec0c45 |
| [§4 Verification](infra-local.md#4-verification) — `k8s_test_layer1` | Not tested | 2026-09-20 | 7ec0c45 |
| [§4 Verification](infra-local.md#4-verification) — `k8s_test_layer2` | Not tested | 2026-09-20 | 7ec0c45 |
| [§4 Verification](infra-local.md#4-verification) — `k8s_test_layer3` | Not tested | 2026-09-20 | 7ec0c45 |
| [§4 Verification](infra-local.md#4-verification) — `k8s_test_layer4` | Not tested | 2026-09-20 | 7ec0c45 |
| [§4 Verification](infra-local.md#4-verification) — `k8s_test_layer5` | Not tested | 2026-09-20 | 7ec0c45 |
| [§5 Redeploy](infra-local.md#5-redeploy) | Not tested | 2026-09-20 | 7ec0c45 |
| Gaku-Web E2E testing. `kubectl port-forward -n gaku svc/gaku-web 8081:8080` <br/> Open http://localhost:8081. | Not tested | 2026-09-20 | 7ec0c45 |

### 2.3 Jenkins

`infra/jenkins/local` (controller image, compose file, Smee relay, seed job).

| Component | Pass criterion | Status | Last tested | Evidence |
| --- | --- | --- | --- | --- |
| `smee-relay.js` | A GitHub push webhook arrives at the local controller | Not tested | — | — |
| `job-config.xml` | Seeded job appears and points at this repo | Not tested | — | — |
| Stage `Restore & Build` | Solution restores and builds inside the agent | Not tested | — | — |
| Stages `Test — Domain/Application/Infrastructure/Web` | All four suites run and publish results | Not tested | — | — |
| Stage `Docker Build` | All three images build inside the agent | Not tested | — | — |
| Stage `Load Images into Minikube` | Images land in the node daemon | Not tested | — | — |
| Stage `Deploy to Local K8s` | Overlay applies and rollouts complete | Not tested | — | — |
| End-to-end run | A push to `master` produces a green build with the app redeployed | Not tested | — | — |