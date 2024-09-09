terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = ">= 4.33.0"
        }

        helm = {
            source = "hashicorp/helm"
            version = "2.12.1"
        }

        kubernetes = {
            source = "hashicorp/kubernetes"
            version = "2.26.0"
        }
    }

    required_version = ">= 1.2.0"
}

provider "aws" {
    region = "eu-west-2"
}

resource "aws_iam_role" "eks_access_user_role" {
  name = "EKSAccessRole"

  assume_role_policy = jsonencode({
    # Version of the policy language used by AWS
    Version = "2012-10-17"
    # Contains rules about who can assume the role and what they are allowed to do
    # Controls which principals can act as the role and use perms
    Statement = [
      {
      # What action is allowed
      Action = "sts:AssumeRole"
      # Allow or disallow
      Effect = "Allow"
      # Who can assume the role
      Principal = {
        AWS = "arn:aws:iam::187065639894:user/terraform-user"
      }
      },
    ]
  })

  # tags = {
  #   tag-key = "tag-value"
  # }
}

# EKS Access
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role = aws_iam_role.eks_access_user_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# EKS service permissions
resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  role = aws_iam_role.eks_access_user_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

variable "vpc_id" {
  description = "vpc-02b742c0be91aaca2"
  type = string
}

data "aws_subnets" "eks_subnets" {
  filter {
    name = "vpc-02b742c0be91aaca2"
    values = [ var.vpc_id ]
  }
}

resource "aws_eks_cluster" "initial_cluster" {
  name = "initial_cluster"
  role_arn = aws_iam_role.eks_access_user_role.arn
  vpc_config {
    endpoint_private_access = true
    endpoint_public_access = true
    subnet_ids = data.aws_subnets.eks_subnets
  }
}

locals {
    host = aws_eks_cluster.initial_cluster.endpoint
    # certificate = base64decode(aws_eks_cluster.initial_cluster.)
    certificate = base64decode(aws_eks_cluster.initial_cluster.certificate_authority.data)
}

provider "helm" {
    kubernetes {
      host = local.host
      cluster_ca_certificate = local.certificate

      exec {
        api_version = "client.authentication.k8s.io/v1beta1"
        args = ["eks", "get-token", "--cluster-name", aws_eks_cluster.initial_cluster.name]
        command = "aws"
      }
    }
}

provider "kubernetes" {
  host = local.host
  cluster_ca_certificate = local.certificate
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args = ["eks", "get-token", "--cluster-name", aws_eks_cluster.initial_cluster.name]
    command = "aws"
  }
}