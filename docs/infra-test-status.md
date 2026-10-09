# Infrastructure test status

## 1. AWS

Two environments: `staging` and `production`.

### 1.1 Shared bootstrap

| Component | Pass criterion | Status | Last tested | Commit | Evidence |
| --- | --- | --- | --- | --- | --- |
| `aws_s3_bucket.state` | Bucket exists and accepts a state write | Pass | 2026-10-06 | 8d9e53d | `make tf_bootstrap_test` — `Bucket + write` |
| Versioning | Previous state versions are retrievable | Pass | 2026-10-06 | 8d9e53d | `make tf_bootstrap_test` — `Versioning` |
| Server-side encryption | Objects report SSE on `head-object` | Pass | 2026-10-06 | 8d9e53d | `make tf_bootstrap_test` — `Encryption` |
| Public access block | All four block settings are on | Pass | 2026-10-06 | 8d9e53d | `make tf_bootstrap_test` — `Public access` |
| Ownership controls | Bucket-owner-enforced, ACLs disabled | Pass | 2026-10-06 | 8d9e53d | `make tf_bootstrap_test` — `Ownership` |
| Lifecycle configuration | Noncurrent versions expire on the configured schedule | Pass | 2026-10-06 | 8d9e53d | `make tf_bootstrap_test` — `Lifecycle expiry`, `Lifecycle abort`; configuration only, the expiry itself is observable after 90 days |
| `state_tls_only` policy | A plain-HTTP request to the bucket is denied | Pass | 2026-10-06 | 8d9e53d | `make tf_bootstrap_test` — `TLS-only policy`, `Plain HTTP` |

### 1.2 Staging

`infra/terraform/environments/staging`, `infra/k8s/eks/staging`, and `Jenkinsfile.aws`.
EKS with RDS, images from ECR, traffic through an ALB.

#### 1.2.1 Terraform

| Component | Pass criterion | Status | Last tested | Commit | Evidence |
| --- | --- | --- | --- | --- | --- |
| `module.vpc` | Applies clean; subnets, routing and NAT reachable as designed | Pass | 2026-09-24 | 954a965 | [record](archive/2026-09-24-alb-controller-staging.md) — nodes ran in the private subnets and pulled images through NAT; the ALB came up in the public subnets |
| `module.eks` | Cluster reachable with `kubectl`, nodes `Ready` | Pass | 2026-10-02 | 1fdd623 | [record](archive/2026-10-02-autoscaling-staging.md) — 1 node `Ready` at the 1–2 node range |
| `module.eks` — `aws_autoscaling_group_tag.cluster_autoscaler` | Node group's ASG carries both `k8s.io/cluster-autoscaler` discovery tags | Pass | 2026-10-02 | 1fdd623 | [record](archive/2026-10-02-autoscaling-staging.md) — `enabled = true` and `gaku-staging = owned` on the ASG |
| `module.eks` — `aws_eks_addon.this["metrics-server"]` | Add-on `ACTIVE`, `kubectl top nodes` returns figures | Pass | 2026-10-02 | 1fdd623 | [record](archive/2026-10-02-autoscaling-staging.md) |
| `module.rds` | Instance available, reachable from a cluster pod | Pass | 2026-10-02 | 1fdd623 | [record](archive/2026-10-02-autoscaling-staging.md) — `db-migrate` job completed against it |
| `module.ecr` | Repositories exist and accept a push | Pass | 2026-09-20 | 82fcec6 | [record](archive/2026-09-20-jenkins-aws-ecr-push.md) — all three repositories accepted a push |
| `module.in_cluster_controller_identity` | Controller service account assumes its IAM role | Pass | 2026-09-24 | 954a965 | [record](archive/2026-09-24-alb-controller-staging.md) — throwaway pod on the service account resolved the controller role, not the node role |
| `module.in_cluster_controller_identity` — cluster autoscaler | `cluster-autoscaler` service account assumes `gaku-staging-cluster-autoscaler` | Pass | 2026-10-02 | 1fdd623 | [record](archive/2026-10-02-autoscaling-staging.md) — throwaway pod resolved the autoscaler role, not the node role |
| `module.jenkins` | Jenkins controller identity and access as designed | Pass | 2026-10-09 | cbd9e68 | [record](archive/2026-10-09-e2e-pipeline-staging.md) — instance profile, ECR push and EKS access all exercised |
| `aws_eks_access_entry.jenkins` + policy association | Jenkins can `kubectl` against the cluster | Pass | 2026-10-09 | cbd9e68 | [record](archive/2026-10-09-e2e-pipeline-staging.md) — `kubectl get nodes` and `auth can-i '*' '*' -A` as the `jenkins` user |
| `terraform plan` on a clean tree | No drift after a successful apply | Pass | 2026-10-09 | cbd9e68 | [record](archive/2026-10-09-e2e-pipeline-staging.md) — `make tf_env_plan ENV=staging` |

#### 1.2.2 Cluster add-ons and manifests

| Component | Pass criterion | Status | Last tested | Commit | Evidence |
| --- | --- | --- | --- | --- | --- |
| `eks/controllers/aws-load-balancer-controller.values.yaml` | Controller pods `Ready`, no IAM errors in the log | Pass | 2026-09-24 | 954a965 | [record](archive/2026-09-24-alb-controller-staging.md) |
| `eks/controllers/cluster-autoscaler.values.yaml` | Autoscaler running, discovers the node group, no `AccessDenied` in the log | Pass | 2026-10-02 | 1fdd623 | [record](archive/2026-10-02-autoscaling-staging.md) |
| External Secrets Operator | Controller, webhook and cert-controller pods `Running` | Pass | 2026-10-02 | 1fdd623 | [record](archive/2026-10-02-autoscaling-staging.md) |
| `eks/staging/external-secret.yaml` | `gaku-secret` is materialised from the external store | Pass | 2026-10-02 | 1fdd623 | [record](archive/2026-10-02-autoscaling-staging.md) |
| `components/alb-ingress/ingress-api.yaml` | ALB provisioned, API reachable through it | Pass | 2026-09-24 | 954a965 | [record](archive/2026-09-24-alb-controller-staging.md) — internet-facing ALB `active`, targets healthy, `/api/echo` answered from both pods |
| `components/alb-ingress/ingress-web.yaml` | Web reachable through the same ALB group | Pass | 2026-10-09 | cbd9e68 | [record](archive/2026-10-09-e2e-pipeline-staging.md) — `web-load-check.js` exit `0` |
| Image tag substitution | The overlay resolves to the ECR tag the build pushed | Pass | 2026-10-09 | cbd9e68 | [record](archive/2026-10-09-e2e-pipeline-staging.md) — deployments run `:TAG`, revision is the pushed commit |
| `migrate` | Migration job completes against RDS | Pass | 2026-10-02 | 1fdd623 | [record](archive/2026-10-02-autoscaling-staging.md) |
| `eks/production/hpa.yaml` (applied to staging by hand) | Under CPU load in the `gaku-api` pods, replicas scale out within 2–6 | Pass | 2026-10-02 | 1fdd623 | [record](archive/2026-10-02-autoscaling-staging.md) — `SuccessfulRescale` events |
| Cluster autoscaler scale-up | A pod `Pending` on `Insufficient cpu` brings a second node | Pass | 2026-10-02 | 1fdd623 | [record](archive/2026-10-02-autoscaling-staging.md) — `ballast` at `1500m` × 2 grew the ASG to 2 |
| Cluster autoscaler scale-down | Removing the load returns the ASG to 1 node | Pass | 2026-10-02 | 1fdd623 | [record](archive/2026-10-02-autoscaling-staging.md) |

#### 1.2.3 Pipeline (`Jenkinsfile.aws`)

| Component | Pass criterion | Status | Last tested | Commit | Evidence |
| --- | --- | --- | --- | --- | --- |
| Stage `Restore & Build` | Solution builds in the CI image | Pass | 2026-10-09 | cbd9e68 | [record](archive/2026-10-09-e2e-pipeline-staging.md) |
| Stages `Test — Domain/Application/Infrastructure/Web` | All four suites run and publish results | Pass | 2026-10-09 | cbd9e68 | [record](archive/2026-10-09-e2e-pipeline-staging.md) |
| Stage `Docker Build` | All three images build | Pass | 2026-10-09 | cbd9e68 | [record](archive/2026-10-09-e2e-pipeline-staging.md) |
| Stage `Push to ECR` | Images arrive in ECR under the build tag | Pass | 2026-10-09 | cbd9e68 | [record](archive/2026-10-09-e2e-pipeline-staging.md) |
| Stage `Migrate Staging Database` | Migration job completes against RDS | Pass | 2026-10-09 | cbd9e68 | [record](archive/2026-10-09-e2e-pipeline-staging.md) |
| Stage `Deploy to Staging` | Rollouts complete on the new tag | Pass | 2026-10-09 | cbd9e68 | [record](archive/2026-10-09-e2e-pipeline-staging.md) |
| Stage `Smoke Test` | `/api/health` and `/api/echo` answer through the ALB hostname | Pass | 2026-10-09 | cbd9e68 | [record](archive/2026-10-09-e2e-pipeline-staging.md) |
| End-to-end run | A push to `master` reaches a green smoke test | Pass | 2026-10-09 | cbd9e68 | [record](archive/2026-10-09-e2e-pipeline-staging.md) |

### 1.3 Production

`infra/terraform/environments/production`. Terraform only — there is no `eks/production`
kustomization and no pipeline targeting production yet, so deployment rows will be added when
those exist.

| Component | Pass criterion | Status | Last tested | Commit | Evidence |
| --- | --- | --- | --- | --- | --- |
| `module.vpc` | Applies clean; subnets, routing and NAT reachable as designed | Not tested | — | — | — |
| `module.eks` | Cluster reachable with `kubectl`, nodes `Ready` | Not tested | — | — | — |
| `module.rds` | Instance available, reachable from a cluster pod | Not tested | — | — | — |
| `module.ecr` | Repositories exist and accept a push | Not tested | — | — | — |
| `module.jenkins` | Jenkins controller identity and access as designed | Not tested | — | — | — |
| `aws_eks_access_entry.jenkins` + policy association | Jenkins can `kubectl` against the cluster | Pass | 2026-10-09 | cbd9e68 | [record](archive/2026-10-09-e2e-pipeline-staging.md) — `kubectl get nodes` and `auth can-i '*' '*' -A` as the `jenkins` user |
| `terraform plan` on a clean tree | No drift after a successful apply | Pass | 2026-10-09 | cbd9e68 | [record](archive/2026-10-09-e2e-pipeline-staging.md) — `make tf_env_plan ENV=staging` |
| Cluster add-ons | — (no production overlay yet) | Not tested | — | — | — |
| Deployment pipeline | — (no production pipeline yet) | Not tested | — | — | — |

## 2. Local

### 2.1 Docker Image

`docker-compose.yml` at the repo root, reading `.env`. Ports: PostgreSQL `5432`, API `8080`,
Web `8081`. 

| Component | Pass criterion | Status | Last tested | Commit |
| --- | --- | --- | --- | --- |
| `docker/Dockerfile` target `api` | Image builds from a clean context | Pass | 2026-09-20 | 4a2294e |
| `docker/Dockerfile` target `web` | Image builds from a clean context | Pass | 2026-09-20 | 4a2294e |
| `docker/Dockerfile` target `migrator` | Image builds from a clean context | Pass | 2026-09-20 | 4a2294e |
| `postgres` service | Container starts and `pg_isready` healthcheck goes healthy | Pass | 2026-09-20 | 4a2294e |
| `db-migrator` service | Migrations apply to an empty volume, container exits `0` | Pass | 2026-09-20 | 4a2294e |
| `gaku-api` service | `GET http://localhost:8080/api/health` returns `200` | Pass | 2026-09-20 | 4a2294e |
| `gaku-web` service | `http://localhost:8081` renders the map page, no console errors | Pass | 2026-09-20 | 4a2294e |
| Full stack | `docker compose up --build -d` reaches green state| Pass | 2026-09-20 | 4a2294e |


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