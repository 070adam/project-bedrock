variable "region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "student_id" {
  description = "Your student ID — appended to the S3 assets bucket name (bedrock-assets-<student_id>)"
  type        = string
  # Set via TF_VAR_student_id env var or -var flag. Never commit a real value.
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "project-bedrock-cluster"
}

variable "cluster_version" {
  description = "EKS Kubernetes version (must be >= 1.34)"
  type        = string
  default     = "1.34"
}

variable "vpc_name" {
  description = "Name tag for the VPC"
  type        = string
  default     = "project-bedrock-vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "azs" {
  description = "Availability zones to deploy into"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

variable "app_namespace" {
  description = "Kubernetes namespace for the retail application"
  type        = string
  default     = "retail-app"
}

variable "mysql_db_name" {
  description = "Database name for the MySQL RDS instance"
  type        = string
  default     = "retailcatalog"
}

variable "mysql_username" {
  description = "Master username for MySQL RDS"
  type        = string
  default     = "catalogadmin"
}

variable "postgres_db_name" {
  description = "Database name for the PostgreSQL RDS instance"
  type        = string
  default     = "retailorders"
}

variable "postgres_username" {
  description = "Master username for PostgreSQL RDS"
  type        = string
  default     = "ordersadmin"
}

variable "rds_instance_class" {
  description = "Instance class for RDS instances"
  type        = string
  default     = "db.t3.micro"
}

variable "dynamodb_cart_table" {
  description = "DynamoDB table name for the cart service"
  type        = string
  default     = "retail-store-cart"
}

variable "common_tags" {
  description = "Tags applied to every resource"
  type        = map(string)
  default = {
    Project = "karatu-2025-capstone"
  }
}
