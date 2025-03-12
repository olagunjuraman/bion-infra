# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster" {
  name = "bion-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Talent = var.account_id
  }
}

# Attach policies to cluster role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# IAM Role for Node Group
resource "aws_iam_role" "eks_nodes" {
  name = "bion-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Talent = var.account_id
  }
}

# Attach policies to node role
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }

  tags = {
    Name   = var.cluster_name
    Talent = var.account_id
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# Security Group for EKS Cluster
resource "aws_security_group" "eks_cluster" {
  name        = "bion-eks-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name   = "bion-eks-cluster-sg"
    Talent = var.account_id
  }
}

# Security Group for EKS Nodes
resource "aws_security_group" "eks_nodes" {
  name        = "bion-eks-nodes-sg"
  description = "Security group for EKS nodes"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Limit this to your IP in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name   = "bion-eks-nodes-sg"
    Talent = var.account_id
  }
}

# Security Group Rules
resource "aws_security_group_rule" "cluster_nodes" {
  type                     = "ingress"
  from_port               = 443
  to_port                 = 443
  protocol                = "tcp"
  source_security_group_id = aws_security_group.eks_nodes.id
  security_group_id       = aws_security_group.eks_cluster.id
}

resource "aws_security_group_rule" "nodes_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  security_group_id = aws_security_group.eks_nodes.id
}

resource "aws_security_group_rule" "nodes_cluster" {
  type                     = "ingress"
  from_port               = 0
  to_port                 = 0
  protocol                = "-1"
  source_security_group_id = aws_security_group.eks_cluster.id
  security_group_id       = aws_security_group.eks_nodes.id
}

# EKS Node Group
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "bion-eks-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = aws_subnet.private[*].id
  instance_types  = [var.instance_type]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  # Use spot instances if needed
  capacity_type = "ON_DEMAND"  # Change to "SPOT" for spot instances

  # Remote access to nodes (Optional)
  remote_access {
    ec2_ssh_key               = aws_key_pair.eks_nodes.key_name
    source_security_group_ids = [aws_security_group.eks_nodes.id]
  }

  tags = {
    Name   = "bion-eks-nodes"
    Talent = var.account_id
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry
  ]
}

# Generate SSH key for node access
resource "tls_private_key" "eks_nodes" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Store SSH key
resource "aws_key_pair" "eks_nodes" {
  key_name   = "bion-eks-nodes-key"
  public_key = tls_private_key.eks_nodes.public_key_openssh

  tags = {
    Talent = var.account_id
  }
}

# Store SSH private key securely in SSM
resource "aws_ssm_parameter" "eks_nodes_private_key" {
  name  = "/bion/eks/nodes/ssh_key"
  type  = "SecureString"
  value = tls_private_key.eks_nodes.private_key_pem

  tags = {
    Talent = var.account_id
  }
}

# Add permissions to view nodes in AWS console
resource "aws_iam_role_policy" "eks_console_viewer" {
  name = "eks-console-viewer"
  role = aws_iam_role.eks_cluster.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:ListNodegroups",
          "eks:DescribeNodegroup",
          "eks:ListClusters",
          "eks:DescribeCluster",
          "eks:AccessKubernetesApi",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVolumes",
          "ec2:DescribeVpcs",
          "iam:ListRoles"
        ]
        Resource = "*"
      }
    ]
  })
}