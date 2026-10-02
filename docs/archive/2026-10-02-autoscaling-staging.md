# Testing autoscaling in staging: HPA and cluster autoscaler

Commit: 1fdd623
Outcome: pass — every step in §2–§7 behaved as expected

Staging rather than production: the two scale the same way, and staging is one NAT gateway and a
single-AZ `db.t4g.micro` instead of three and a multi-AZ one. The HPA manifest lives in the
production overlay, so [§5 Apply the HPA](#5-apply-the-hpa) applies it to staging by hand.

## 1. What each half needs

| | Horizontal Pod Autoscaler | Cluster autoscaler |
| --- | --- | --- |
| Manifest or chart | `infra/k8s/eks/production/hpa.yaml` | `autoscaler/cluster-autoscaler` Helm chart |
| Needs to read | Pod CPU from metrics-server | The node group's Auto Scaling group |
| Denominator | `cpu: 100m` request in `infra/k8s/base/api/deployment.yaml` | The ASG's `min_size` / `max_size` |
| AWS side | none | IAM role plus the `k8s.io/cluster-autoscaler/<cluster>` discovery tag |
| Signal it responds to | CPU utilisation above 70% | A pod stuck `Pending` on `Insufficient cpu` |
| Range in staging | 2 to 6 pods | 1 to 2 nodes, 1 desired |

## 2. Apply the staging environment

```bash
cd infra/terraform/environments/staging
IP=$(curl -s https://checkip.amazonaws.com)
cat > terraform.tfvars <<VARS
cluster_public_access_cidrs = ["$IP/32"]
jenkins_allowed_cidrs       = ["$IP/32"]
enable_jenkins              = false
VARS
```

```bash
make tf_env_init  ENV=staging
make tf_env_apply ENV=staging          # VPC, EKS, RDS, ECR - 20-25 min
make tf_env_kubeconfig ENV=staging
kubectl get nodes                      # expect 1 Ready
```

The discovery tags and the autoscaler's IAM role come with the apply — `cluster_autoscaler_discovery_tags`
and `enable_cluster_autoscaler` both default to `true`. Confirm both before installing anything:

```bash
ASG=$(aws eks describe-nodegroup --cluster-name gaku-staging \
  --nodegroup-name $(aws eks list-nodegroups --cluster-name gaku-staging \
    --query 'nodegroups[0]' --output text) \
  --query 'nodegroup.resources.autoScalingGroups[0].name' --output text)
aws autoscaling describe-tags --filters Name=auto-scaling-group,Values=$ASG \
  --query 'Tags[?starts_with(Key, `k8s.io/cluster-autoscaler`)].[Key,Value]' --output table
make tf_env_output ENV=staging | grep -A5 controller_role_arns
```

| Expected | Meaning |
| --- | --- |
| `k8s.io/cluster-autoscaler/enabled = true` | The autoscaler will consider this ASG |
| `k8s.io/cluster-autoscaler/gaku-staging = owned` | The `Scale` statement's condition matches, so `SetDesiredCapacity` is allowed |
| `cluster_autoscaler` role ARN is non-null | The role and its Pod Identity association exist |

## 3. Check metrics-server

```bash
aws eks describe-addon --cluster-name gaku-staging --addon-name metrics-server \
  --query 'addon.status' --output text   # ACTIVE
kubectl top nodes                      # CPU and memory columns, not an error
```

`kubectl top nodes` failing with `Metrics API not available` means the add-on is not serving yet.

## 4. Install the controllers

Install the CA and check the log if it is installed correctly.
```bash
make ca_install ENV=staging
kubectl -n kube-system logs deploy/cluster-autoscaler | grep -i "node group\|AccessDenied"
```

Validate the CA's IAM role 
```bash
kubectl run aws-id -n kube-system --restart=Never \
  --image=public.ecr.aws/aws-cli/aws-cli \
  --overrides='{"spec":{"serviceAccountName":"cluster-autoscaler"}}' \
  -- sts get-caller-identity
kubectl -n kube-system wait --for=jsonpath='{.status.phase}'=Succeeded pod/aws-id --timeout=120s
kubectl -n kube-system logs aws-id
kubectl -n kube-system delete pod aws-id
```

| ARN | Meaning |
| --- | --- |
| `arn:aws:sts::100731996173:assumed-role/gaku-staging-cluster-autoscaler/<pod>` | Pod Identity worked |
| `arn:aws:sts::100731996173:assumed-role/gaku-staging-node/<instance-id>` | node credentials |

Install the External Secrets Operator. Without it the staging overlay's `ExternalSecret` has no CRD and HPA fails.
```bash
make eso_install ENV=staging
kubectl -n external-secrets get pods   # controller, webhook, cert-controller Running
```

## 5. Apply the HPA

`hpa` is not part of the `staging` overlay, `hpa` from production is used. 

The ECR repositories start empty, the images need to be built and push to ECR.
```bash
REG=100731996173.dkr.ecr.eu-central-1.amazonaws.com
TAG=$(git rev-parse --short HEAD)
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin $REG
for t in api web migrator; do
  docker build -f docker/Dockerfile --target $t -t $REG/gaku-$t:$TAG -t $REG/gaku-$t:latest .
  docker push $REG/gaku-$t:$TAG && docker push $REG/gaku-$t:latest
done
```

```bash
kubectl apply -k infra/k8s/eks/staging
kubectl -n gaku get externalsecret gaku-secret  
kubectl -n gaku wait --for=condition=complete job/db-migrate --timeout=300s
kubectl apply -f infra/k8s/eks/production/hpa.yaml
kubectl -n gaku get hpa -w
``` 

## 6. Test the HPA

Burn CPU inside the `gaku-api` pods. The HPA averages CPU over the pods of the Deployment it
targets, so a stress pod of its own would load the node and leave the HPA idle. The API image is
built on `dotnet/aspnet`, which is Debian and has `sh`, `yes` and `timeout`.

```bash
for p in $(kubectl -n gaku get pods -l app=gaku-api -o name); do
  kubectl -n gaku exec $p -- sh -c 'timeout 300 yes > /dev/null 2>&1 &'
done

kubectl -n gaku get hpa gaku-api -w          # TARGETS climbs, REPLICAS follows
kubectl -n gaku top pods
kubectl -n gaku describe hpa gaku-api | tail -20   # SuccessfulRescale events
```

## 7. Test the cluster autoscaler

The HPA alone will not trigger it: six pods at `100m` is `600m` against roughly `1930m` allocatable per `m7i-flex.large` node. 

```bash
kubectl -n gaku create deployment ballast --image=registry.k8s.io/pause:3.9 --replicas=2
kubectl -n gaku set resources deployment/ballast --requests=cpu=1500m
kubectl -n gaku get pods -l app=ballast -w     # some Pending
kubectl -n gaku describe pod -l app=ballast | grep -A3 Events   # Insufficient cpu
```

One `1500m` pod per node means two nodes for two replicas.

```bash
kubectl -n kube-system logs deploy/cluster-autoscaler -f | grep -i "scale.up\|setting.*size"
kubectl get nodes -w                            # a second node joins, 3-5 min
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG \
  --query 'AutoScalingGroups[0].{min:MinSize,desired:DesiredCapacity,max:MaxSize}'
```

`max_size` is 2, so a third replica would stay `Pending`.

```bash
kubectl -n gaku delete deployment ballast
kubectl get nodes -w                            # back to 1 after ~10 min
```

## 8. Teardown

```bash
kubectl -n gaku delete deployment ballast --ignore-not-found
kubectl delete -f infra/k8s/eks/production/hpa.yaml
make ca_uninstall ENV=staging
kubectl delete namespace gaku
make tf_env_destroy ENV=staging
```