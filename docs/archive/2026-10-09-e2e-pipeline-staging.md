# Full e2e staging pipeline test

Commit: cbd9e68
Outcome: pass — every check in §1.1–§1.4 behaved as expected

## 1. Pipeline test

### 1.1 Apply infra

```bash
make tf_env_init ENV=staging && make tf_env_apply ENV=staging
make tf_env_plan ENV=staging         
make tf_bootstrap_test               
make tf_env_kubeconfig ENV=staging
make controllers_install ENV=staging
make lbc_preingress_check ENV=staging
```

### 1.2 Set up Jenkins

```bash
make tf_env_output ENV=staging | grep jenkins_url
make jenkins_aws_password
# Open `jenkins_url` and setup.
make jenkins_aws_job # execute `infra/jenkins/aws/job-config.xml`
```

### 1.3 Check if Jenkins reaches the cluster

```bash
aws ssm start-session --target $(cd infra/terraform/environments/staging && terraform output -raw jenkins_instance_id)
sudo -u jenkins aws eks update-kubeconfig --name gaku-staging --region eu-central-1
sudo -u jenkins kubectl get nodes
sudo -u jenkins kubectl auth can-i '*' '*' -A
```

### 1.4 Checks per stage

`ADDR=$(kubectl -n gaku get ingress gaku-web -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')`.

| Row | Check | Pass |
| --- | --- | --- |
| Stage `Migrate Staging Database` | `kubectl -n gaku get job db-migrate -o jsonpath='{.status.succeeded}'` | `1`, job created; Job gone after 10 minutes, then the stage being green is the check |
| Stage `Deploy to Staging` | `kubectl -n gaku get deploy -o jsonpath='{range .items[*]}{.metadata.name} {.spec.template.spec.containers[0].image} {.metadata.annotations.org\.opencontainers\.image\.revision}{"\n"}{end}'` | images + `:TAG`; revision is the pushed commit |
| Smoke: Health check| `for TG in $(aws elbv2 describe-target-groups --region eu-central-1 --query "TargetGroups[?contains(TargetGroupName,'gaku')].TargetGroupArn" --output text); do aws elbv2 describe-target-health --target-group-arn $TG --query 'TargetHealthDescriptions[].TargetHealth.State' --output text; done` | every target `healthy` |
| Smoke: echo API | `for i in $(seq 20); do curl -sf --max-time 10 http://${ADDR:?set ADDR first}/api/echo; echo; done \| grep -o '"pod":"[^"]*"' \| sort \| uniq -c` | 20 replies |
| `ingress-web.yaml` | `NODE_PATH=<playwright node_modules> node scripts/infra/test/web-load-check.js http://$ADDR/` | exit `0`: status `200`, `AWSALB` in cookies, map tile loaded, no browser errors |
| web pod in browser interaction | URL `kubectl -n gaku get ingress gaku-web -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'` | interaction|

## 2. Teardown
`kubectl delete namespace gaku` -> the controllers remove the ALB
`make tf_env_destroy ENV=staging`