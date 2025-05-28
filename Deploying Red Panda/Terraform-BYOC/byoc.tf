terraform {
  required_providers {
    redpanda = {
      source  = "redpanda-data/redpanda"
      version = "~> 0.10.1"
    }
  }
}

# Variables to parameterize the configuration
variable "resource_group_name" {
  description = "Name of the Redpanda resource group"
  default     = "testname"
}

variable "network_name" {
  description = "Name of the Redpanda network"
  default     = "testname"
}

variable "cluster_name" {
  description = "Name of the Redpanda BYOC cluster"
  default     = "test-cluster"
}

variable "region" {
  description = "Region for the Redpanda network and cluster"
  default     = "us-east-2"
}

variable "cloud_provider" {
  description = "Cloud provider for the Redpanda network"
  default     = "aws"
}

variable "zones" {
  description = "List of availability zones for the cluster"
  type        = list(string)
  default     = ["use2-az1", "use2-az2", "use2-az3"]
}

variable "cidr_block" {
  description = "CIDR block for the Redpanda network"
  default     = "10.0.0.0/20"
}

variable "throughput_tier" {
  description = "Throughput tier for the cluster"
  default     = "tier-1-aws-v2-x86"
}

# Redpanda provider configuration
provider "redpanda" {}

# Create a Redpanda resource group
resource "redpanda_resource_group" "test" {
  name = var.resource_group_name
}

# Create a Redpanda network
resource "redpanda_network" "test" {
  name              = var.network_name
  resource_group_id = redpanda_resource_group.test.id
  cloud_provider    = var.cloud_provider
  region            = var.region
  cluster_type      = "byoc"  # Specify BYOC cluster type
  cidr_block        = var.cidr_block
}

# Create a Redpanda BYOC cluster
resource "redpanda_cluster" "test" {
  name              = var.cluster_name
  resource_group_id = redpanda_resource_group.test.id
  network_id        = redpanda_network.test.id
  cloud_provider    = var.cloud_provider
  region            = var.region
  cluster_type      = "byoc"
  connection_type   = "public"  # Publicly accessible cluster
  throughput_tier   = var.throughput_tier
  zones             = var.zones
  allow_deletion    = true      # Allow the cluster to be deleted
  tags = {                      # Add metadata tags
    "environment" = "dev"
  }
