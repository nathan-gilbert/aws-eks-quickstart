provider "aws" {
  region = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# Create a VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name                 = "eks-vpc"
  cidr                 = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  azs             = ["us-west-1b", "us-west-1c"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]
  enable_nat_gateway = true
}

# Create an EKS cluster
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "sonarqube-cluster"
  cluster_version = "1.31"
  subnet_ids      = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id

  # To add the current caller identity as an administrator
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    eks_nodes = {
      desired_size = 2
      max_size     = 3
      min_size     = 1

      instance_types = ["t3.medium"]
      disk_size      = 20
    }
  }

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
}

# Security Group for public access
resource "aws_security_group" "sonarqube_sg" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an RDS PostgreSQL instance for SonarQube
resource "aws_db_instance" "sonarqube_db" {
  identifier           = "sonarqube-db"
  engine              = "postgres"
  engine_version      = "15.10"
  instance_class      = "db.t3.medium"
  allocated_storage   = 20
  username           = "sonarqube"
  password           = "ChangeMe1234!"
  db_subnet_group_name = aws_db_subnet_group.sonarqube_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.sonarqube_sg.id]
  publicly_accessible = false
  skip_final_snapshot = true
}

resource "aws_db_subnet_group" "sonarqube_db_subnet_group" {
  name       = "sonarqube-db-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

# Outputs for SonarQube Helm configuration
output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "sonarqube_rds_endpoint" {
  value = aws_db_instance.sonarqube_db.endpoint
}

output "sonarqube_rds_username" {
  value = aws_db_instance.sonarqube_db.username
}

output "sonarqube_rds_password" {
  value = aws_db_instance.sonarqube_db.password
  sensitive = true
}
