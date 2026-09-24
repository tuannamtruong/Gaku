# Testing the AWS Load Balancer Controller in staging

Commit: 954a965
Outcome: controller installed with Pod Identity credentials, `gaku-api` Ingress provisioned an internet-facing ALB, and traffic reached the pods.

## 1. Apply the staging environment

Set values in `terraform.tfvars`

```bash
cd infra/terraform/environments/staging
IP=$(curl -s https://checkip.amazonaws.com)
cat > terraform.tfvars <<VARS
cluster_public_access_cidrs = ["$IP/32"]
jenkins_allowed_cidrs       = ["$IP/32"]
enable_jenkins              = true
VARS
```

```bash
make tf_env_init  ENV=staging
make tf_env_apply ENV=staging          # VPC, EKS, RDS, ECR - 20-25 min
make tf_env_kubeconfig ENV=staging
kubectl get nodes                      # expect 2 Ready
make tf_env_output ENV=staging         # note controller_service_accounts, controller_role_arns
```

The apply creates the Pod Identity association before the controller exists. That is fine — an
association pointing at a service account that is not there yet does nothing and is not an error.

## 2. Install the controller

```bash
make lbc_install ENV=staging
make lbc_preingress_check    ENV=staging
```

## 3. Check the IAM setup

```bash
make lbc_preingress_check ENV=staging
```

Test if a pod in aws-load-balancer-controller service account get the controller's or the node's IAM role?

It can't be checked from inside the controller because its image is distroless, so no shell to get-caller-identity. Use a throwaway pod on the same service account and read the ARN it resolves to.
- Controller role ARN → credentials are wired.
- Node role ARN → wiring is wrong. 

```bash
kubectl run aws-id -n kube-system --restart=Never \
  --image=public.ecr.aws/aws-cli/aws-cli \
  --overrides='{"spec":{"serviceAccountName":"aws-load-balancer-controller"}}' \
  -- sts get-caller-identity
kubectl -n kube-system wait --for=jsonpath='{.status.phase}'=Succeeded pod/aws-id --timeout=120s
kubectl -n kube-system logs aws-id
kubectl -n kube-system delete pod aws-id
```
Expected ARN role name:

| ARN | Meaning |
| --- | --- |
| `arn:aws:sts::100731996173:assumed-role/gaku-staging-aws-load-balancer-controller/<pod>` | Pod Identity worked |
| `arn:aws:sts::100731996173:assumed-role/gaku-staging-node/<instance-id>` | node credentials  |

## 4. Build and push images to ECR

```bash
make docker_build_api IMAGE_TAG=lbcheck
aws ecr get-login-password --region eu-central-1 \
  | docker login --username AWS --password-stdin 100731996173.dkr.ecr.eu-central-1.amazonaws.com
docker tag  gaku-api:lbcheck 100731996173.dkr.ecr.eu-central-1.amazonaws.com/gaku-api:lbcheck
docker push 100731996173.dkr.ecr.eu-central-1.amazonaws.com/gaku-api:lbcheck
```

## 5. Check the ALB is created

ESO is not installed yet, so manual apply of secret is needed.
```bash
kubectl apply -f infra/k8s/base/namespace.yaml -f infra/k8s/base/configmap.yaml

CONN=$(aws secretsmanager get-secret-value --secret-id gaku-staging/database \
  --region eu-central-1 --query SecretString --output text \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["ConnectionStrings__DefaultConnection"])')
kubectl -n gaku create secret generic gaku-secret \
  --from-literal=ConnectionStrings__DefaultConnection="$CONN"
```

Apply gaku-api deploy.
```bash
kubectl apply -f infra/k8s/base/api/deployment.yaml -f infra/k8s/base/api/service.yaml
kubectl -n gaku set image deployment/gaku-api \
  gaku-api=100731996173.dkr.ecr.eu-central-1.amazonaws.com/gaku-api:lbcheck
kubectl -n gaku scale deployment/gaku-api --replicas=2
kubectl -n gaku rollout status deployment/gaku-api

```

Trigger the test
```bash
kubectl apply -f infra/k8s/components/alb-ingress/ingress-api.yaml
```

`lbcheck` is the tag section 4 pushes by hand. `:latest` is the pipeline's tag and does not exist until `Jenkinsfile.aws` has run.
 
```bash
# The controller reconciles the desired state in Ingress.
kubectl -n kube-system logs deploy/aws-load-balancer-controller -f   # no AccessDenied
kubectl -n gaku get ingress gaku-api -w                              # Address is filled
# # Should show: `internet-facing`, `active`, and public subnets
aws elbv2 describe-load-balancers --region eu-central-1 \
  --query 'LoadBalancers[].{name:LoadBalancerName,scheme:Scheme,state:State.Code,subnets:AvailabilityZones[].SubnetId}'
```

## 6. Check traffic reaches the pods

Target group health check
```bash
TG=$(aws elbv2 describe-target-groups --region eu-central-1 \
  --query 'TargetGroups[?contains(TargetGroupName,`gaku`)].TargetGroupArn' --output text)
aws elbv2 describe-target-health --target-group-arn $TG \
  --query 'TargetHealthDescriptions[].{ip:Target.Id,port:Target.Port,state:TargetHealth.State}' --output table
kubectl -n gaku get pods -o wide  # should have multiple pods
```

`echo` x times to see if the request distributed between the pods
```bash
ADDR=$(kubectl -n gaku get ingress gaku-api -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
for i in $(seq 20); do curl -s http://$ADDR/api/echo; echo; done | python3 -c '
import sys, json, collections
print(collections.Counter(json.loads(l)["pod"] for l in sys.stdin if l.strip()))'
```

## 7. Common failures

| Symptom | Cause to check |
| --- | --- |
| Ingress `ADDRESS` stays empty | `kubectl -n gaku describe ingress gaku-api` events, then the controller log |
| `AccessDenied` in the controller log | the named action against the controller role |
| Controller log shows the node role | Pod Identity not applied — service account name mismatch, or the pod started before the association existed (restart it) |
| `couldn't auto-discover subnets` | `kubernetes.io/role/elb` tags on the public subnets |
| Pod in `CreateContainerConfigError` | `gaku-secret` missing |
| `ImagePullBackOff`, `NotFound` | tag is not or not correct in ECR. auth and egress are fine, the registry answered; list the repo and use a tag that exists |
| `ImagePullBackOff`, 401 | node role missing `AmazonEC2ContainerRegistryReadOnly` |
| `ImagePullBackOff`, timeout | NAT egress from the private subnets |
| Targets `unhealthy` | `/api/health` against the pod directly, then the cluster security group rule for the ALB security group |
| `terraform destroy` hangs on the VPC | an ALB still holds an ENI — delete the Ingress first and wait |

## 8. Teardown

```bash
kubectl delete -f infra/k8s/components/alb-ingress/ingress-api.yaml
aws elbv2 describe-load-balancers --region eu-central-1 --query 'LoadBalancers[].LoadBalancerName'
kubectl delete namespace gaku
make tf_env_destroy ENV=staging
```