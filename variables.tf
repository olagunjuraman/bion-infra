variable "account_id" {
  description = "Your AWS account ID for tagging resources"
  type        = string

}

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1" 
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "bion-eks"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}


variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.large"  # As specified in requirements
}


variable "scan_report_bucket_name" {
  description = "S3 bucket name for scan reports"
  type        = string
  default     = "bion-scan-reports"
}


variable "ecr_repository_names" {
  description = "Names of ECR repositories to create"
  type        = list(string)
  default     = ["voting-app", "result-app", "worker", "vote", "db"]
}