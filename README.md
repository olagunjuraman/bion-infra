Bion Consulting Technical Assignment - Infrastructure
This repository contains the Terraform code for provisioning the AWS infrastructure required for the Bion Consulting technical assignment.

Infrastructure Overview
The Terraform code creates the following AWS resources:

VPC with public and private subnets across 3 availability zones
Internet Gateway and NAT Gateways for network connectivity
EKS cluster with node groups using t3.large instances
ECR repositories for container images
S3 bucket for Grype security scan reports
IAM roles and policies


Prerequisites
AWS CLI installed and configured
Terraform installed (v1.0.0+)
kubectl installed
Access to AWS account with proper permissions
Setup Instructions

Configure AWS Credentials
Configure your AWS CLI with your credentials
aws configure
OR set environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"

Initialize Terraform
terraform init

Set Your Account ID for Tagging

Set your account ID as a variable
export TF_VAR_account_id=$(aws sts get-caller-identity --query Account --output text)

Review and Apply Infrastructure
terraform plan
Apply the changes
terraform apply -auto-approve

Configure kubectl to Access Your EKS Cluster
eks update-kubeconfig --region us-east-1 --name bion-eks
kubectl get nodes # Verify connectivity