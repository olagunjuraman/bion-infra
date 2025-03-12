terraform {
  backend "s3" {
    bucket = "bion-terraform-state-715841369847"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}




# Store state in S3 (Optional)


# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "bion-vpc"
    Talent  = var.account_id
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "bion-igw"
    Talent  = var.account_id
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                        = "bion-public-${count.index + 1}"
    Talent                      = var.account_id
    "kubernetes.io/role/elb"    = "1"
    "kubernetes.io/cluster/bion-eks" = "shared"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name                              = "bion-private-${count.index + 1}"
    Talent                            = var.account_id
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/bion-eks"  = "shared"
  }
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count = 3
  domain = "vpc"

  tags = {
    Name    = "bion-nat-eip-${count.index + 1}"
    Talent  = var.account_id
  }
}

# NAT Gateways
resource "aws_nat_gateway" "nat" {
  count         = 3
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name    = "bion-nat-gw-${count.index + 1}"
    Talent  = var.account_id
  }

  depends_on = [aws_internet_gateway.igw]
}

# Route Tables for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name    = "bion-public-rt"
    Talent  = var.account_id
  }
}

# Route Tables for Private Subnets
resource "aws_route_table" "private" {
  count  = 3
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name    = "bion-private-rt-${count.index + 1}"
    Talent  = var.account_id
  }
}

# Route Table Association for Public Subnets
resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Table Association for Private Subnets
resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Data source for availability zones
data "aws_availability_zones" "available" {}

# Create AWS CLI profile configuration
resource "local_file" "aws_profile" {
  filename = pathexpand("~/.aws/config")
  content = <<-EOF
[profile bion-assessment]
region = ${var.region}
output = json

[profile bion-assessment-eks]
role_arn = ${aws_iam_role.eks_cluster.arn}
source_profile = bion-assessment
region = ${var.region}
output = json
EOF
}

# Create kubeconfig
resource "local_file" "kubeconfig" {
  filename = pathexpand("~/.kube/config")
  content = <<-EOF
apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.main.endpoint}
    certificate-authority-data: ${aws_eks_cluster.main.certificate_authority[0].data}
  name: ${aws_eks_cluster.main.name}
contexts:
- context:
    cluster: ${aws_eks_cluster.main.name}
    user: aws
  name: ${aws_eks_cluster.main.name}
current-context: ${aws_eks_cluster.main.name}
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: aws
      args:
        - --profile
        - bion-assessment-eks
        - eks
        - get-token
        - --cluster-name
        - ${aws_eks_cluster.main.name}
      env: []
EOF
}

output "configure_kubectl" {
  value = <<-EOT
    Run these commands to configure kubectl:
    
    aws eks update-kubeconfig --name ${aws_eks_cluster.main.name} --region ${var.region}
    kubectl get nodes
  EOT
}