# CI/CD Pipeline for Gaku — Local First, then AWS

## Context

Gaku has two deployable ASP.NET Core 10 services (`Gaku.Api` on port 51020/51021 and `Gaku.Web` on port 51022/51023) backed by PostgreSQL+PostGIS.

The plan implements CI/CD in **two stages**:
- **Stage 1 (local):** Jenkins test automation → Docker → Kubernetes on the local machine
- **Stage 2 (cloud):** AWS + Terraform to mirror the same pipeline in production

**Current status:** Phase 0 (Jenkins CI via Docker) is **complete and running**. All subsequent phases are planned but not yet implemented.

---

## Stage 1 — Local CI/CD

### Phase 0: Jenkins — Automated Tests via Docker ✅ COMPLETE

**Goal:** On every push to `master`, Jenkins builds a Docker CI image from source and runs the three test suites (Domain, Application, Infrastructure) in isolated containers. GitHub pushes reach Jenkins via a Smee.io relay.

**Files (all created and in use):**
```
Jenkinsfile                    declarative pipeline at repo root
docker/
  Dockerfile.ci                multi-stage: stage build (restore + compile), stage test (unused by pipeline — build stage image is used directly)
jenkins/local/
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
2. `echo "SMEE_URL=https://smee.io/<your-id>" > jenkins/local/.env`
3. `cd jenkins/local && docker compose up -d`
4. Open `http://localhost:8090`, unlock with `docker exec gaku-jenkins cat /var/jenkins_home/secrets/initialAdminPassword`
5. Install plugins: **Pipeline**, **Git**, **GitHub**, **JUnit**, **Timestamper**
6. Create Pipeline job → SCM → Git → `https://github.com/tuannamtruong/Gaku` → branch `*/master` → script path `Jenkinsfile`
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

**`docker/Dockerfile.Gaku.Api`** — multi-stage build:
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
      dockerfile: docker/Dockerfile.Migrator
    environment:
      ConnectionStrings__DefaultConnection: "Host=postgres;Port=5432;Database=gaku;Username=gaku;Password=gaku_password"
    depends_on:
      postgres: { condition: service_healthy }
    restart: "no"

  gaku-api:
    build:
      context: .
      dockerfile: docker/Dockerfile.Gaku.Api
    ports: ["8080:8080"]
    environment:
      ConnectionStrings__DefaultConnection: "Host=postgres;Port=5432;Database=gaku;Username=gaku;Password=gaku_password"
    depends_on:
      postgres: { condition: service_healthy }

  gaku-web:
    build:
      context: .
      dockerfile: docker/Dockerfile.Gaku.Web
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

**Validation:** `docker compose up --build` → `curl http://localhost:8080/health` (api), open `http://localhost:8081` (web).

---

### Phase 2: Jenkins — Full CI Pipeline (Build + Docker) ✅ COMPLETE

Jenkins runs as a Docker container on the local machine with access to the Docker daemon.

**Files to create:**
```
jenkins/local/
  docker-compose.jenkins.yml   ← spin up Jenkins locally
Jenkinsfile                    ← pipeline definition at repo root
```

**`jenkins/local/docker-compose.jenkins.yml`:**
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

**`Jenkinsfile`** — declarative pipeline:
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
        sh "docker build -f docker/Dockerfile.Gaku.Api -t ${API_IMAGE}:${IMAGE_TAG} ."
        sh "docker build -f docker/Dockerfile.Gaku.Web -t ${WEB_IMAGE}:${IMAGE_TAG} ."
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
1. `docker compose -f jenkins/local/docker-compose.jenkins.yml up -d`
2. Open `http://localhost:8090`, unlock with initial admin password
3. Install plugins: Pipeline, Git, Docker Pipeline, JUnit, Kubernetes CLI
4. Create pipeline job pointing to repo `Jenkinsfile`

---

### Phase 3: Kubernetes — Local Cluster 

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
          httpGet: { path: /health, port: 8080 }
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

### Phase 5: Terraform Bootstrap
```
infra/terraform/bootstrap/main.tf
```
Creates S3 bucket (versioned) + DynamoDB table for remote state lock. Run once manually before any other Terraform.

### Phase 6: Terraform Modules (apply in this order)

| Order | Module | Creates |
|---|---|---|
| 1 | `modules/ecr` | ECR repos for `gaku-api` and `gaku-web` |
| 2 | `modules/vpc` | VPC, 3 public + 3 private subnets, NAT GW, IGW |
| 3 | `modules/rds` | RDS PostgreSQL 16 + PostGIS extension, in private subnets |
| 4 | `modules/eks` | EKS cluster + managed node group (t3.medium), OIDC provider |
| 5 | `modules/jenkins` | EC2 t3.medium, IAM role (ECR push + EKS access), Jenkins via user_data |

```
infra/terraform/
  bootstrap/
  modules/
    ecr/          ← aws_ecr_repository × 2
    vpc/          ← VPC + subnets + NAT gateway
    rds/          ← aws_db_instance postgres:16, PostGIS parameter group
    eks/          ← aws_eks_cluster + managed node group + OIDC
    jenkins/      ← EC2 + IAM role + security group (port 8080)
  environments/
    staging/      ← instantiates all modules, smaller instance sizes
    production/   ← instantiates all modules, production sizes
```

### Phase 7: K8s Cloud Overlays (Kustomize)
```
infra/k8s/
  base/              ← same manifests as local/, imagePullPolicy: Always
  overlays/
    staging/         ← kustomization.yaml: ECR image refs, replica=1
    production/      ← kustomization.yaml: ECR image refs, replica=2, HPA
```

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
        │   └── jenkins/
        └── environments/
            ├── staging/
            └── production/
```

---

## Verification Checkpoints

### Phase 0 (Jenkins test automation)
1. `docker compose -f jenkins/local/docker-compose.jenkins.yml up -d` → Jenkins at `http://localhost:8090`
2. Create pipeline job pointing to `Jenkinsfile`, branch `master`
3. Push a change to `src/Gaku.Core/` → Build + Test: Core stages run; Application and Infrastructure stages skipped
4. Push a change to `src/Gaku.Application/` → Build + Test: Application runs; others skipped
5. JUnit trend graph appears in the job dashboard after first test run

### Stage 1 (local Docker + K8s)
6. `docker compose up --build` → `curl http://localhost:8080/health` returns 200; web opens at `http://localhost:8081`
7. Jenkins pipeline on `master` → all stages green including Docker Build and K8s Deploy
8. `minikube start && eval $(minikube docker-env)` → builds go into minikube cache
9. `kubectl get pods -n gaku` → all pods Running
10. `curl http://gaku.local/health` → 200 via minikube ingress

### Stage 2 (cloud)
11. `terraform apply` in `bootstrap/` → S3 bucket + DynamoDB table created
12. `terraform apply` in `environments/staging/` → VPC, ECR, RDS, EKS, Jenkins EC2 created
13. `docker push <ecr-url>/gaku-api:latest` succeeds
14. `kubectl get nodes` (EKS context) → nodes Ready
15. Jenkins pipeline on `master` → all stages green, staging ALB responds
16. Production deploy after manual approval → `kubectl rollout status` confirms zero-downtime
