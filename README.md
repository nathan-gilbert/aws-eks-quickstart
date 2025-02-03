# EKS Quickstart

Terraform to standup EKS system quickly.

Set up a `terraform.tfvars` file with your AWS credentials.

`tofu init`
`tofu apply -auto-approve`

Connect to context: `aws eks update-kubeconfig --region us-west-1 --name sonarqube-cluster`
