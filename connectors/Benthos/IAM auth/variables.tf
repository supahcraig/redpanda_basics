variable "region" {
  type        = string
  description = "AWS region"
}

variable "name_prefix" {
  type        = string
  description = "Prefix used for naming resources"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR for the VPC"
  default     = "10.200.0.0/16"
}

variable "home_ip_cidr" {
  type        = string
  description = "Your home public IP in CIDR form, e.g. 1.2.3.4/32"
}

variable "db_name" {
  type        = string
  description = "Initial database name"
  default     = "demo_db"
}

variable "db_username" {
  type        = string
  description = "Master username"
  default     = "postgres"
}

variable "db_password" {
  type        = string
  description = "Master password"
  sensitive   = true
  default     = "postgres"
}

variable "serverlessv2_min_acu" {
  type        = number
  description = "Serverless v2 minimum ACUs"
  default     = 0.5
}

variable "serverlessv2_max_acu" {
  type        = number
  description = "Serverless v2 maximum ACUs"
  default     = 2
}

variable "engine_version" {
  type        = string
  description = "Aurora PostgreSQL engine version"
  default     = "17.4"
}

variable "az_count" {
  type        = number
  description = "How many AZs/subnets to use (Aurora requires >= 2)"
  default     = 2
}

variable "trusted_principal_role_arn" {
  type        = string
  description = "ARN of the Redpanda IAM role that will be assuming the db auth role"
}
