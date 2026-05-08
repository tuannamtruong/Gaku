# Infrastructure

## Local Kubernetes (Minikube)

### First-time setup

```bash
minikube start
minikube addons enable ingress
eval $(minikube docker-env)              # point Docker CLI at minikube's daemon

# Build images inside minikube so imagePullPolicy: Never works
docker build -f docker/Dockerfile.Gaku.Api -t gaku-api:latest .
docker build -f docker/Dockerfile.Gaku.Web -t gaku-web:latest .
docker build -f docker/Dockerfile.Migrator -t gaku-migrator:latest .

# Apply all manifests and generate gaku-secret from root .env
kubectl apply -k infra/k8s/local/ --load-restrictor LoadRestrictionsNone

# Add minikube IP to hosts so gaku.local resolves
echo "$(minikube ip) gaku.local" | sudo tee -a /etc/hosts
```

### Re-applying infrastructure

```bash
kubectl apply -k infra/k8s/local/ --load-restrictor LoadRestrictionsNone
```

### Verification

```bash
kubectl get pods -n gaku                 # all pods should reach Running/Completed
curl http://gaku.local/api/health        # API health check via ingress
```
