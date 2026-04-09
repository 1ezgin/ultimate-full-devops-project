terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

provider "tls" {}

# VPC & Networking
resource "aws_vpc" "amir-project_vpc" {
  cidr_block = "10.0.0.0/16"
  tags       = { Name = "amir-project-vpc" }
}

resource "aws_subnet" "amir-project_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.amir-project_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.amir-project_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["eu-central-1a", "eu-central-1b"], count.index)
  map_public_ip_on_launch = true
  tags                    = { Name = "amir-project-subnet-${count.index}" }
}

resource "aws_internet_gateway" "amir-project_igw" {
  vpc_id = aws_vpc.amir-project_vpc.id
  tags   = { Name = "amir-project-igw" }
}

resource "aws_route_table" "amir-project_route_table" {
  vpc_id = aws_vpc.amir-project_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.amir-project_igw.id
  }
  tags = { Name = "amir-project-route-table" }
}

resource "aws_route_table_association" "amir-project_association" {
  count          = 2
  subnet_id      = aws_subnet.amir-project_subnet[count.index].id
  route_table_id = aws_route_table.amir-project_route_table.id
}

# Security Groups
resource "aws_security_group" "amir-project_cluster_sg" {
  vpc_id = aws_vpc.amir-project_vpc.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "amir-project-cluster-sg" }
}

resource "aws_security_group" "amir-project_node_sg" {
  vpc_id = aws_vpc.amir-project_vpc.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "amir-project-node-sg" }
}

# EKS Cluster
resource "aws_eks_cluster" "amir-project" {
  name     = "amir-project-cluster"
  role_arn = aws_iam_role.amir-project_cluster_role.arn
  vpc_config {
    subnet_ids         = aws_subnet.amir-project_subnet[*].id
    security_group_ids = [aws_security_group.amir-project_cluster_sg.id]
  }

  # Фикс ошибки StatusCode: 400 для EKS 1.35
  lifecycle {
    ignore_changes = [
      compute_config,
      storage_config,
    ]
  }
}

# OIDC Provider (Для прав доступа подов к AWS API)
data "tls_certificate" "eks" {
  url = aws_eks_cluster.amir-project.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.amir-project.identity[0].oidc[0].issuer
}

# EBS CSI Add-on (Драйвер для дисков)
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                = aws_eks_cluster.amir-project.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.amir-project_node_group_role.arn
  depends_on                  = [aws_eks_node_group.frankfurt, aws_iam_openid_connect_provider.eks]
}

# Node Group (Рабочие ноды)
resource "aws_eks_node_group" "frankfurt" {
  cluster_name    = aws_eks_cluster.amir-project.name
  node_group_name = "amir-project-node-group"
  node_role_arn   = aws_iam_role.amir-project_node_group_role.arn
  subnet_ids      = aws_subnet.amir-project_subnet[*].id
  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 3
  }
  instance_types = ["c7i-flex.large"]
  remote_access {
    ec2_ssh_key               = var.ssh_key_name
    source_security_group_ids = [aws_security_group.amir-project_node_sg.id]
  }
}

# IAM Roles & Policies
resource "aws_iam_role" "amir-project_cluster_role" {
  name = "amir-project-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "amir-project_cluster_role_policy" {
  role       = aws_iam_role.amir-project_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "amir-project_node_group_role" {
  name = "amir-project-node-group-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
      },
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.eks.arn }
        Condition = { StringEquals = { "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa" } }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "amir-project_node_group_role_policy" {
  role       = aws_iam_role.amir-project_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "amir-project_node_group_cni_policy" {
  role       = aws_iam_role.amir-project_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "amir-project_node_group_registry_policy" {
  role       = aws_iam_role.amir-project_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "amir-project_node_group_ebs_policy" {
  role       = aws_iam_role.amir-project_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
