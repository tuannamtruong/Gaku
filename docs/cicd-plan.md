# CI/CD Pipeline for Gaku — Local First, then AWS

## Context

Gaku has two deployable ASP.NET Core 10 services (`Gaku.Api` on port 51020/51021 and `Gaku.Web` on port 51022/51023) backed by PostgreSQL+PostGIS.

The plan implements CI/CD in **two stages**:
- **Stage 1 (local):** Jenkins test automation → Docker → Kubernetes on the local machine
- **Stage 2 (cloud):** AWS + Terraform to mirror the same pipeline in production

**Current status:** Phases 0–7 are **written**: the Stage 1 local pipeline (Jenkins CI, Docker images, full pipeline, local Kubernetes), the Stage 2 Terraform (bootstrap, six modules, two environments) and the Kustomize base and cloud overlays. Phase 8 (log forwarding) is not written. Phase 9 (Jenkins cloud stages) is written as
`Jenkinsfile.aws` up to the smoke test, but has never been run against a real controller.

Phase status here tracks whether the code exists, not whether it has been applied to an account — apply state lives in the state files, not in this document.

---

## Stage 1 — Local CI/CD

### Phase 0: Jenkins — Automated Tests via Docker ✅ COMPLETE

**Goal:** On every push to `master`, Jenkins builds a Docker CI image from source and runs the three test suites (Domain, Application, Infrastructure) in isolated containers. GitHub pushes reach Jenkins via a Smee.io relay.

**Files (all created and in use):**
```
Jenkinsfile.local              declarative pipeline at repo root, run by the local controller
Jenkinsfile.aws                the cloud pipeline, run by the EC2 controller
docker/
  Dockerfile                   
infra/jenkins/local/
  Dockerfile                   extends jenkins/jenkins:lts-jdk21 — installs Docker CLI
  docker-compose.yml           two services: gaku-jenkins + smee relay sidecar
  smee-relay.js                pure Node.js SSE→HTTP relay; no npm packages required
  .env                         SMEE_URL=https://smee.io/<channel-id>  (not committed)
.dockerignore                  excludes bin/, obj/, .git/, .vs/ from build context
```

**Key design decisions:**
- Jenkins runs inside Docker with the host Docker socket mounted — no Docker-in-Docker daemon needed
- The CI image is built once per build number (`gaku-ci:<build>`) then removed in `post.always`
- Each test suite runs in its own named container so results can be `docker cp`'d to the Jenkins workspace before the container is removed
- Smee relay is a custom zero-dependency Node.js script — avoids the `smee-client` npm package and handles the `content-type: application/json` header that Jenkins' GitHub plugin requires
- `group_add: ["1001"]` grants the Jenkins container access to `/var/run/docker.sock` without running as root (GID matches the Docker socket group on this host)

**Setup steps (manual, once):**
1. Get a Smee channel: visit `https://smee.io/new`, copy the URL
2. `echo "SMEE_URL=https://smee.io/<your-id>" > infra/jenkins/local/.env`
3. `cd infra/jenkins/local && docker compose up -d`
4. Open `http://localhost:8090`, unlock with `docker exec gaku-jenkins cat /var/jenkins_home/secrets/initialAdminPassword`
5. Install plugins: **Pipeline**, **Git**, **GitHub**, **JUnit**, **Timestamper**
6. Create Pipeline job → SCM → Git → `https://github.com/tuannamtruong/Gaku` → branch `*/master` → script path `Jenkinsfile.local`
7. Add Smee URL as a GitHub webhook: Settings → Webhooks → Content-Type `application/json` → push events only

**Verification:**
- Push any commit to `master` → Jenkins job triggers within seconds via Smee relay
- All three test stages run; JUnit trend graph appears in the job dashboard after the first run
- `docker ps` shows `gaku-jenkins` and `smee` containers running; no test containers remain after build completes

---

### Phase 1: Docker — Containerize the Applications  ✅ COMPLETE

**What gets Dockerized:**
| Service | Image name | Base image |
|---|---|---|
| `Gaku.Api` | `gaku-api` | `mcr.microsoft.com/dotnet/aspnet:10.0` |
| `Gaku.Web` | `gaku-web` | `mcr.microsoft.com/dotnet/aspnet:10.0` |
| PostgreSQL+PostGIS | not custom — use `postgis/postgis:16-3.4-alpine` | — |

**Files to create:**
```
docker/
  Dockerfile.Gaku.Api
  Dockerfile.Gaku.Web
  Dockerfile.Migrator
.dockerignore
docker-compose.yml   ← extend existing (add gaku-api + gaku-web + db-migrator)
```

**`docker/Dockerfile.Gaku.Api`** — multi-stage build, as sketched during planning. The three
files below were later merged into one `docker/Dockerfile` so the shared libraries compile once
for all images; read that file for the current shape.
```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY . .
RUN dotnet publish src/Gaku.Api/Gaku.Api.csproj -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production
EXPOSE 8080
ENTRYPOINT ["dotnet", "Gaku.Api.dll"]
```

**`docker/Dockerfile.Gaku.Web`** — identical pattern, different project path:
```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY . .
RUN dotnet publish src/Gaku.Web/Gaku.Web.csproj -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production
EXPOSE 8080
ENTRYPOINT ["dotnet", "Gaku.Web.dll"]
```

**`docker/Dockerfile.Migrator`** — runs EF Core migrations:
```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:10.0
WORKDIR /src
COPY . .
RUN dotnet tool install --global dotnet-ef
ENV PATH="$PATH:/root/.dotnet/tools"
ENTRYPOINT ["dotnet", "ef", "database", "update", "--project", "src/Gaku.Infrastructure", "--startup-project", "src/Gaku.Api"]
```

**`docker-compose.yml`** — extend with api + web + db-migrator:
```yaml
services:
  postgres:     # existing, unchanged
    ...

  db-migrator:
    build:
      context: .
      dockerfile: docker/Dockerfile
      target: migrator
    environment:
      ConnectionStrings__DefaultConnection: "Host=postgres;Port=5432;Database=gaku;Username=gaku;Password=gaku_password"
    depends_on:
      postgres: { condition: service_healthy }
    restart: "no"

  gaku-api:
    build:
      context: .
      dockerfile: docker/Dockerfile
      target: api
    ports: ["8080:8080"]
    environment:
      ConnectionStrings__DefaultConnection: "Host=postgres;Port=5432;Database=gaku;Username=gaku;Password=gaku_password"
    depends_on:
      postgres: { condition: service_healthy }

  gaku-web:
    build:
      context: .
      dockerfile: docker/Dockerfile
      target: web
    ports: ["8081:8080"]
    environment:
      ConnectionStrings__DefaultConnection: "Host=postgres;Port=5432;Database=gaku;Username=gaku;Password=gaku_password"
    depends_on:
      postgres: { condition: service_healthy }
      gaku-api: { condition: service_started }
```

**`.dockerignore`:**
```
**/bin/
**/obj/
**/.git/
**/*.user
**/TestResults/
```

**Validation:** `docker compose up --build` → `curl http://localhost:8080/api/health` (api), open `http://localhost:8081` (web).

---

### Phase 2: Jenkins — Full CI Pipeline (Build + Docker) ✅ COMPLETE

Jenkins runs as a Docker container on the local machine with access to the Docker daemon.

**Files to create:**
```
infra/jenkins/local/
  docker-compose.yml           ← spin up Jenkins locally
Jenkinsfile.local              ← pipeline definition at repo root
```

**`infra/jenkins/local/docker-compose.yml`** (as planned — the committed file adds the Smee
sidecar, kubectl/minikube binaries and the kubeconfig mount):
```yaml
services:
  jenkins:
    image: jenkins/jenkins:lts-jdk21
    ports: ["8090:8080", "50000:50000"]
    volumes:
      - jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
    group_add: ["docker"]
volumes:
  jenkins_home:
```

**`Jenkinsfile.local`** — declarative pipeline, as sketched during planning. The committed file
builds and tests inside the CI image rather than on the agent; read it for the current shape:
```groovy
pipeline {
  agent any

  environment {
    API_IMAGE  = "gaku-api"
    WEB_IMAGE  = "gaku-web"
    IMAGE_TAG  = "${env.BUILD_NUMBER}"
  }

  stages {
    stage('Build') {
      steps { sh 'dotnet build Gaku.sln -c Release' }
    }
    stage('Test') {
      steps { sh 'dotnet test Gaku.sln --no-build -c Release --logger trx' }
      post { always { junit '**/TestResults/*.trx' } }
    }
    stage('Docker Build') {
      steps {
        sh "docker build -f docker/Dockerfile --target api -t ${API_IMAGE}:${IMAGE_TAG} ."
        sh "docker build -f docker/Dockerfile --target web -t ${WEB_IMAGE}:${IMAGE_TAG} ."
      }
    }
    stage('Deploy to Local K8s') {
      when { branch 'master' }
      steps {
        sh "kubectl set image deployment/gaku-api gaku-api=${API_IMAGE}:${IMAGE_TAG} -n gaku"
        sh "kubectl set image deployment/gaku-web gaku-web=${WEB_IMAGE}:${IMAGE_TAG} -n gaku"
        sh "kubectl rollout status deployment/gaku-api -n gaku"
        sh "kubectl rollout status deployment/gaku-web -n gaku"
      }
    }
  }
}
```

**Branch strategy:**
- `master` → runs all stages including K8s deploy
- Feature branches → Build + Test only

**Setup steps (manual, once):**
1. `docker compose -f infra/jenkins/local/docker-compose.yml up -d`
2. Open `http://localhost:8090`, unlock with initial admin password
3. Install plugins: Pipeline, Git, Docker Pipeline, JUnit, Kubernetes CLI
4. Create pipeline job pointing to repo `Jenkinsfile.local`

---

### Phase 3: Kubernetes — Local Cluster ✅ COMPLETE

**Local K8s tool:** minikube (recommended) or Docker Desktop Kubernetes.

**Files to create:**
```
infra/k8s/local/
  kustomization.yaml
  namespace.yaml
  configmap.yaml
  postgres/
    statefulset.yaml
    service.yaml
    pvc.yaml
  api/
    deployment.yaml
    service.yaml
  web/
    deployment.yaml
    service.yaml
  db-migration/
    job.yaml
  ingress.yaml
```

**`namespace.yaml`:**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: gaku
```

**`configmap.yaml`:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: gaku-config
  namespace: gaku
data:
  ASPNETCORE_ENVIRONMENT: "Production"
```

**`kustomization.yaml`** — `gaku-secret` is generated from the root `.env` file via Kustomize `secretGenerator` (no credentials in source control):
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- namespace.yaml
- configmap.yaml
- ingress.yaml
- postgres/pvc.yaml
- postgres/statefulset.yaml
- postgres/service.yaml
- api/deployment.yaml
- api/service.yaml
- web/deployment.yaml
- web/service.yaml
- db-migration/job.yaml

generatorOptions:
  disableNameSuffixHash: true

secretGenerator:
- name: gaku-secret
  namespace: gaku
  envs:
  - ../../../.env
```

**`api/deployment.yaml`:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gaku-api
  namespace: gaku
spec:
  replicas: 1
  selector:
    matchLabels: { app: gaku-api }
  template:
    metadata:
      labels: { app: gaku-api }
    spec:
      containers:
      - name: gaku-api
        image: gaku-api:latest
        imagePullPolicy: Never
        ports: [{ containerPort: 8080 }]
        envFrom:
        - configMapRef: { name: gaku-config }
        - secretRef:    { name: gaku-secret }
        readinessProbe:
          httpGet: { path: /api/health, port: 8080 }
          initialDelaySeconds: 10
```

**`web/deployment.yaml`** — same structure, `image: gaku-web:latest`.

**`ingress.yaml`:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: gaku-ingress
  namespace: gaku
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: gaku.local
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend: { service: { name: gaku-api, port: { number: 8080 } } }
      - path: /
        pathType: Prefix
        backend: { service: { name: gaku-web, port: { number: 8080 } } }
```

**`db-migration/job.yaml`:**
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migrate
  namespace: gaku
spec:
  template:
    spec:
      containers:
      - name: migrator
        image: gaku-migrator:latest
        imagePullPolicy: Never
        envFrom:
        - secretRef: { name: gaku-secret }
      restartPolicy: OnFailure
```

**Minikube setup steps (manual, once):**
```bash
minikube start
minikube addons enable ingress
eval $(minikube docker-env)          # point Docker CLI to minikube's daemon

# Applies all k8s infrastructure + generates secret from root .env
kubectl apply -k infra/k8s/local/ --load-restrictor LoadRestrictionsNone

echo "$(minikube ip) gaku.local" | sudo tee -a /etc/hosts
```

---

## Stage 2 — AWS Cloud (Future Phase)

Once Stage 1 is working locally, mirror it to AWS using Terraform. The local K8s manifests reuse as-is — only image sources and secret backends change.

### Phase 5: Terraform Bootstrap ✅

Creates the remote state backend every later module writes to. Run once manually before any other Terraform.

**Files created:**
```
infra/terraform/
  terraform.mk                 make targets, included from the root Makefile
  bootstrap/
    versions.tf                required_version >= 1.10, aws ~> 6.0, no backend block
    variables.tf               
    main.tf                    S3 state bucket
    outputs.tf                 bucket, ARN, region, ready-to-paste backend block
    README.md                  
    .terraform.lock.hcl        
```

**What it provisions:** seven resources, all of them the one bucket and its settings — a globally unique, versioned, AES256-encrypted S3 bucket named `gaku-tfstate-<account-id>-<region>`, with public access blocked, ACLs disabled (`BucketOwnerEnforced`), a TLS-only bucket policy, and lifecycle rules that expire noncurrent versions after 90 days and abort incomplete multipart uploads after 7. Locking is S3-native, so there is no DynamoDB table.

**Key design decisions:**
- **Local state** — the bucket holding remote state cannot hold the state describing itself, so this module has no `backend` block. The root `.gitignore` keeps `*.tfstate` out of git; the README documents `terraform import` for recovery
- **S3 native locking, no lock table** — Terraform 1.11 deprecated the backend's `dynamodb_table` parameter in favour of `use_lockfile`, and 1.14 warns on every `init` when it is used. Nothing here creates a DynamoDB table, and the emitted `backend_config` output sets `use_lockfile = true`, which both environments consume verbatim
- **`prevent_destroy` is present but commented out** in `main.tf` — losing the state bucket strands every resource Terraform built, so the block belongs there, but while the bucket is still being torn down and rebuilt the guard is more obstacle than protection. Uncomment it once the bucket holds state worth keeping; until then a stray `terraform destroy` in this directory is not blocked. `bootstrap/README.md` documents the delete-the-block-then-destroy sequence

**Commands:**
```bash
make tf_bootstrap_init      # download the AWS provider
make tf_bootstrap_plan      # read-only; 7 resources to add on a fresh account
make tf_bootstrap_apply     # creates real, billable resources
make tf_bootstrap_test      # [OK]/[FAIL] checklist over the live bucket
make tf_backend_config      # prints the backend block for Phase 6 modules
```

**State of the code:** `fmt`, `init` and `validate` are clean, and a `plan` against a real account in `eu-central-1` reports 7 to add with no deprecation warnings. See [infra/terraform/bootstrap/README.md](../infra/terraform/bootstrap/README.md).

### Phase 6: Terraform Modules ✅

| Order | Module | Creates |
|---|---|---|
| 1 | `modules/ecr` | ECR repos for `gaku-api`, `gaku-web`, `gaku-migrator` + lifecycle policies |
| 2 | `modules/vpc` | VPC, 3 public + 3 private subnets, NAT GW, IGW, S3 gateway endpoint |
| 3 | `modules/rds` | RDS PostgreSQL 16 in private subnets, parameter group, Secrets Manager entry |
| 4 | `modules/eks` | EKS cluster + managed node group (t3.medium), core addons + `eks-pod-identity-agent` |
| 5 | `modules/jenkins-controller` | EC2 t3.medium, IAM role (ECR push + EKS access), Jenkins via user_data |

```
infra/terraform/
  bootstrap/                   Phase 5
  modules/
    ecr/                 create-or-lookup toggle, so one registry is shared across environments
    vpc/                 VPC + subnets + NAT (single or per-AZ) + S3 endpoint + optional flow logs
    rds/                 aws_db_instance postgres:16, random_password → Secrets Manager
    eks/                 aws_eks_cluster (authentication_mode = API) + node group + addons
    jenkins-controller/  EC2 + instance profile + security group (8080) + EIP + user_data template
  environments/
    staging/             all five modules, small sizes, owns the ECR repositories
    production/          all five modules, HA sizes, reads staging's repositories
```

**Key design decisions:**
- **The registry is shared, not duplicated** — staging creates the ECR repositories and production looks them up, so an image tested in staging is promoted by digest rather than rebuilt. The cost is ordering: production cannot plan until staging exists
- **Access entries, not `aws-auth`** — the cluster runs `authentication_mode = "API"`. The Jenkins role is granted cluster-admin by an `aws_eks_access_entry` declared in the *environment root* rather than inside the EKS module, because the Jenkins role ARN is unknown at plan time and the module keys its access entries with `for_each`. There is no dependency cycle to avoid here — Jenkins depends on EKS and not the reverse; the constraint is purely that `for_each` keys must be known at plan time
- **Partial backend config** — each environment declares only the state `key`; bucket and region are injected at `init` from the Phase 5 outputs, keeping the account ID out of source control
- **One Jenkins controller** — `enable_jenkins` is true in staging, false in production. Phase 8's approval gate implies a single controller deploying to both, so production takes the staging role ARN via `external_deploy_role_arns`
- **Pod Identity, not IRSA** — workloads that need AWS permissions will get them from an `aws_eks_pod_identity_association` binding a service account to an IAM role, so the role stays cluster-agnostic and staging and production can share one instead of each needing a trust policy naming its own OIDC issuer. Phase 6 ships only the half that belongs to the cluster: the `eks-pod-identity-agent` addon that vends the credentials on the node. The associations themselves land in Phase 7, with the controllers that need them. No `aws_iam_openid_connect_provider` is registered anywhere — nothing came to depend on it, so it was removed rather than left as a second path to the same thing
- **PostGIS needs no Terraform** — the `InitialCreate` migration already carries the extension annotation and the RDS master user has `rds_superuser`. The parameter group forces TLS and logs slow queries instead
- **`for_each` keys must be plan-time known** — the same constraint that moves the access entry to the environment root shapes two more places: `allowed_security_group_ids` is a map keyed by label rather than a list of ids, and the Jenkins EKS policy is gated on a static bool rather than a null check against an unknown ARN

**Commands** (every `tf_env_*` target takes `ENV=staging` or `ENV=production`):
```bash
make tf_validate_all              # every module + environment, no AWS calls — safe anytime
make tf_env_init  ENV=staging     # backend wired from the bootstrap outputs
make tf_env_plan  ENV=staging
make tf_env_apply ENV=staging     # creates real, billable resources
make tf_env_kubeconfig ENV=staging
make tf_env_destroy ENV=staging
```

**State of the code:** `make tf_validate_all` reports `[OK]` for all five modules, the bootstrap, and both environments, and `terraform fmt -recursive -check` is clean. `make tf_env_plan ENV=staging` against a real account produces 59 resources to add, no errors.

Production cannot be planned until staging exists. `modules/ecr` looks the repositories up instead of creating them there, and the data source is a hard error while they are absent:

```
Error: reading ECR Repository (gaku-api): couldn't find resource
  with module.ecr.data.aws_ecr_repository.existing["gaku-api"]
```

See [docs/infra-aws.md](infra-aws.md) for apply order (§3), the environment split (§5), and cost (§8).

> **Cost warning:** these environments bill on existence, not traffic — roughly $230/month for staging and $350/month for production at list prices, dominated by the EKS control plane and NAT gateways. Neither scales down when idle.

### Phase 7: K8s Cloud Overlays (Kustomize)
```
infra/k8s/
  base/              ← same manifests as local/, imagePullPolicy: Always
  overlays/
    staging/         ← kustomization.yaml: ECR image refs, replica=1
    production/      ← kustomization.yaml: ECR image refs, replica=2, HPA
```

Terraform work that lands with this phase: an IAM role plus an `aws_eks_pod_identity_association`
for each controller that needs AWS permissions — the AWS Load Balancer Controller, the external
secrets operator reading `gaku-<env>/database`, and the cluster autoscaler. The
`eks-pod-identity-agent` addon that serves them is already in `modules/eks`. The Gaku deployments
themselves need no association; their only AWS dependency is RDS, reached over the VPC.

### Phase 8: Jenkinsfile Extended Cloud Stages
Add to the existing `Jenkinsfile` behind `when { branch 'master' }`:
```
Stage 5: Push to ECR      ← aws ecr get-login-password | docker push <ecr>/gaku-api:${BUILD_NUMBER}
Stage 6: DB Migration     ← kubectl apply db-migration/job.yaml, wait for completion
Stage 7: Deploy Staging   ← kustomize build overlays/staging | kubectl apply
Stage 8: Smoke Test       ← curl staging ALB /health
Stage 9: Manual Approval  ← Jenkins input() step
Stage 10: Deploy Prod     ← kustomize build overlays/production | kubectl apply
```

---

## Complete File Tree

```
Gaku/
├── docker/
│   ├── api/Dockerfile
│   ├── web/Dockerfile
│   └── migrator/Dockerfile
├── .dockerignore
├── docker-compose.yml               ← extended: postgres + migrator + api + web
├── Jenkinsfile
├── jenkins/
│   └── local/
│       └── docker-compose.jenkins.yml
└── infra/
    ├── k8s/
    │   ├── local/
    │   │   ├── kustomization.yaml
    │   │   ├── namespace.yaml
    │   │   ├── configmap.yaml
    │   │   ├── postgres/
    │   │   ├── api/
    │   │   ├── web/
    │   │   ├── db-migration/
    │   │   └── ingress.yaml
    │   ├── base/
    │   └── overlays/
    │       ├── staging/
    │       └── production/
    └── terraform/
        ├── bootstrap/
        ├── modules/
        │   ├── ecr/
        │   ├── vpc/
        │   ├── rds/
        │   ├── eks/
        │   └── jenkins-controller/
        └── environments/
            ├── staging/
            └── production/
```

---

## Verification Checkpoints

### Phase 0 (Jenkins test automation)
1. `docker compose -f jenkins/local/docker-compose.jenkins.yml up -d` → Jenkins at `http://localhost:8090`
2. Create pipeline job pointing to `Jenkinsfile`, branch `master`
3. Push a change to `src/Gaku.Domain/` → Build + Test: Domain stages run; Application and Infrastructure stages skipped
4. Push a change to `src/Gaku.Application/` → Build + Test: Application runs; others skipped
5. JUnit trend graph appears in the job dashboard after first test run

### Stage 1 (local Docker + K8s)
6. `docker compose up --build` → `curl http://localhost:8080/api/health` returns 200; web opens at `http://localhost:8081`
7. Jenkins pipeline on `master` → all stages green including Docker Build and K8s Deploy
8. `minikube start && eval $(minikube docker-env)` → builds go into minikube cache
9. `kubectl get pods -n gaku` → all pods Running
10. `curl http://gaku.local/health` → 200 via minikube ingress

### Stage 2 (cloud)
11. `make tf_bootstrap_apply` → S3 bucket + DynamoDB table created; `make tf_bootstrap_test` reports all `[OK]`
12. `make tf_env_apply ENV=staging` → VPC, ECR, RDS, EKS, Jenkins EC2 created; then `ENV=production` (staging must come first — it owns the ECR repositories)
13. `docker push <ecr-url>/gaku-api:latest` succeeds
14. `kubectl get nodes` (EKS context) → nodes Ready
15. Jenkins pipeline on `master` → all stages green, staging ALB responds
16. Production deploy after manual approval → `kubectl rollout status` confirms zero-downtime
