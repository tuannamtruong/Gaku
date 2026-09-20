# Jenkins on AWS, push to ECR

Commit: 82fcec69adb343a876fa212298e30e911a0dd957
Outcome: `Push to ECR` green.

## 1. Disable EKS
EKS stage is after ECR stage. It is not the test subject.

`infra/terraform/environments/staging/main.tf`, `module "jenkins"`:

```diff
-  eks_cluster_arn     = module.eks.cluster_arn
-  eks_cluster_name    = module.eks.cluster_name
+  enable_eks_access   = false
```

## 2. Apply ECR, VPC, Jenkins

```bash
GAKU=/home/nam/Gaku
cd "$GAKU"
cp infra/terraform/environments/staging/terraform.tfvars.example \
   infra/terraform/environments/staging/terraform.tfvars
# set jenkins_allowed_cidrs to your own address in terraform.tfvars
# the ip can be changed during the process, new terraform apply might needed
curl -s https://checkip.amazonaws.com

make tf_env_init ENV=staging
cd infra/terraform/environments/staging
terraform plan -target=module.ecr -target=module.vpc -target=module.jenkins
terraform apply -target=module.ecr -target=module.vpc -target=module.jenkins
terraform output
JENKINS=$(terraform -chdir=infra/terraform/environments/staging output -raw jenkins_url) # terraform output -> jenkins_url
```

## 3. Jenkins controller instance id

```bash
aws ec2 describe-instances --region eu-central-1 \
  --filters Name=tag:Name,Values=gaku-staging-jenkins \
            Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].InstanceId' --output text
```

## 4. Jenkins setup

```bash
aws ssm start-session --target "$(terraform output -raw jenkins_instance_id)"
sudo tail -30 /var/log/cloud-init-output.log
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
exit
```

## 5. Build

Open jenkins by `jenkins_url`
Requried plugins: Pipeline, Git, GitHub, JUnit, Timestamper
Start the build manually
Check if `Push to ECR` is green.

## 6. Teardown

```bash
terraform destroy -target=module.jenkins -target=module.vpc

for R in gaku-api gaku-web gaku-migrator; do
  aws ecr list-images --repository-name $R --region eu-central-1 --query 'imageIds[*]' --output json \
    > /tmp/$R-images.json
  aws ecr batch-delete-image --repository-name $R --region eu-central-1 \
    --image-ids file:///tmp/$R-images.json
done
terraform destroy -target=module.ecr
```

Revert the edit from [§1 Cut the EKS wire](#1-cut-the-eks-wire).