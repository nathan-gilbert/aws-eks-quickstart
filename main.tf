provider "aws" {
  region = "us-west-1"
}

# Create a VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name                 = "eks-vpc"
  cidr                 = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  azs             = ["us-west-1a", "us-west-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]
  enable_nat_gateway = true
}

# Create an EKS cluster
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "sonarqube-cluster"
  cluster_version = "1.27"
  subnet_ids      = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id

  node_groups = {
    eks_nodes = {
      desired_capacity = 2
      max_capacity     = 3
      min_capacity     = 1

      instance_types = ["t3.medium"]
      disk_size      = 20
    }
  }
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

# Install AWS Load Balancer Controller for ingress
resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }
}

# Create an RDS PostgreSQL instance for SonarQube
resource "aws_db_instance" "sonarqube_db" {
  identifier           = "sonarqube-db"
  engine              = "postgres"
  engine_version      = "14.3"
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

# Configure Ingress for SonarQube
resource "kubernetes_ingress_v1" "sonarqube_ingress" {
  metadata {
    name      = "sonarqube-ingress"
    namespace = "default"
    annotations = {
      "kubernetes.io/ingress.class" = "alb"
      "alb.ingress.kubernetes.io/scheme" = "internet-facing"
    }
  }

  spec {
    rule {
      host = "sonarqube.example.com"
      http {
        path {
          path = "/"
          backend {
            service {
              name = "sonarqube"
              port {
                number = 9000
              }
            }
          }
        }
      }
    }
  }
}
