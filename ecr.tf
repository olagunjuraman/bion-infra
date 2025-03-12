# Create ECR repositories for application images
resource "aws_ecr_repository" "app_repositories" {
  for_each = toset(var.ecr_repository_names)

  name                 = each.key
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name   = "bion-${each.key}-ecr"
    Talent = var.account_id
  }
}

# S3 bucket for storing scan reports
resource "aws_s3_bucket" "scan_reports" {
  bucket = "${var.scan_report_bucket_name}-${var.account_id}"

  tags = {
    Name   = "bion-scan-reports"
    Talent = var.account_id
  }
}

# S3 bucket policy
resource "aws_s3_bucket_policy" "scan_reports" {
  bucket = aws_s3_bucket.scan_reports.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          AWS = aws_iam_role.pipeline_role.arn
        }
        Action   = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.scan_reports.arn,
          "${aws_s3_bucket.scan_reports.arn}/*"
        ]
      }
    ]
  })
}

# IAM Role for CI/CD Pipeline
resource "aws_iam_role" "pipeline_role" {
  name = "bion-pipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "codebuild.amazonaws.com",
            "codepipeline.amazonaws.com"
          ]
        }
      }
    ]
  })

  tags = {
    Talent = var.account_id
  }
}

# Pipeline IAM Policy
resource "aws_iam_policy" "pipeline_policy" {
  name = "bion-pipeline-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.scan_reports.arn,
          "${aws_s3_bucket.scan_reports.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "pipeline_policy_attachment" {
  role       = aws_iam_role.pipeline_role.name
  policy_arn = aws_iam_policy.pipeline_policy.arn
}

# Create S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = "bion-terraform-state-${var.account_id}"
  force_destroy = true

  tags = {
    Name   = "bion-terraform-state"
    Talent = var.account_id
  }
}

# Enable versioning for state bucket
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Add server-side encryption for state bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}