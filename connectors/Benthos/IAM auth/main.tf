terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
  profile = var.aws_profile
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Two /24 public subnets carved from the /16
  public_subnet_cidrs = [
    cidrsubnet(var.vpc_cidr, 8, 0),
    cidrsubnet(var.vpc_cidr, 8, 1),
  ]
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

resource "aws_subnet" "public" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.this.id
  availability_zone       = local.azs[count.index]
  cidr_block              = local.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-public-${local.azs[count.index]}"
  }
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

data "http" "home_ip" {
  url = "https://api.ipify.org"
}

locals {
  home_ip_cidr = "${chomp(data.http.home_ip.response_body)}/32"
}


resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-db-sg"
  description = "Allow Postgres from home IP"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Allow traffic to Postgres from home/Redpanda"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [local.home_ip_cidr, var.redpanda_cidr]
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-db-sg"
  }
}

resource "aws_db_subnet_group" "db" {
  name       = "${var.name_prefix}-db-subnets"
  subnet_ids = aws_subnet.public[*].id

  tags = {
    Name = "${var.name_prefix}-db-subnets"
  }
}

resource "aws_rds_cluster_parameter_group" "aurora_pg17" {
  name   = "${var.name_prefix}-aurora-pg17-cluster-pg"
  family = "aurora-postgresql17"

  # Require SSL
  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  # Enable logical replication
  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }

  # Enable IAM auth for replication connections
  parameter {
    name         = "rds.iam_auth_for_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }

  # Reasonable starting values; tune for your workload
  parameter {
    name         = "max_replication_slots"
    value        = "10"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "max_wal_senders"
    value        = "10"
    apply_method = "pending-reboot"
  }

  tags = {
    Name = "${var.name_prefix}-aurora-pg17-cluster-pg"
  }
}

resource "aws_rds_cluster" "aurora" {
  cluster_identifier = "${var.name_prefix}-aurora-pg"

  engine         = "aurora-postgresql"
  engine_version = var.engine_version

  # Serverless v2 uses engine_mode = "provisioned" + serverlessv2_scaling_configuration
  engine_mode = "provisioned" # :contentReference[oaicite:4]{index=4}

  serverlessv2_scaling_configuration {
    min_capacity = var.serverlessv2_min_acu
    max_capacity = var.serverlessv2_max_acu
  }

  database_name   = var.db_name
  master_username = var.db_username
  master_password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db.id]

  storage_encrypted = true

  # IAM DB authentication (tokens) enabled at the cluster level :contentReference[oaicite:5]{index=5}
  iam_database_authentication_enabled = true

  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora_pg17.name

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "${var.name_prefix}-aurora-pg"
  }
}

resource "aws_rds_cluster_instance" "aurora_instance" {
  identifier         = "${var.name_prefix}-aurora-pg-1"
  cluster_identifier = aws_rds_cluster.aurora.id

  engine         = aws_rds_cluster.aurora.engine
  engine_version = aws_rds_cluster.aurora.engine_version

  instance_class = "db.serverless"
  publicly_accessible = true

  tags = {
    Name = "${var.name_prefix}-aurora-pg-1"
  }
}


############
# IAM role
############

data "aws_caller_identity" "current" {}

#data "aws_region" "current" {}

# Role that will be assumed by the principal you pass in via tfvars
resource "aws_iam_role" "aurora_iam_demo_user" {
  name = "${var.name_prefix}-aurora-iam-demo-user"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAssumeFromTrustedPrincipal"
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          AWS = var.trusted_principal_role_arn
        }
      }
    ]
  })

  tags = {
    redpanda_scope_redpanda_connect = "true"
  }
}

# Permission to connect as database user given by var.iam_auth_user
# IMPORTANT: rds-db:connect uses the *cluster* resource_id: aws_rds_cluster_instance.<...>.resource_id
resource "aws_iam_role_policy" "aurora_iam_demo_user_connect" {
  name = "${var.name_prefix}-aurora-iam-demo-user-connect"
  role = aws_iam_role.aurora_iam_demo_user.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowIamAuthToAuroraAsIamDemoUser"
        Effect = "Allow"
        Action = [
          "rds-db:connect"
        ]
        Resource = [
          "arn:aws:rds-db:${var.region}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_rds_cluster.aurora.cluster_resource_id}/${var.iam_auth_user}"
        ]
      }
    ]
  })
}


output "db_cluster_endpoint" {
  value = aws_rds_cluster.aurora.endpoint
}

output "db_reader_endpoint" {
  value = aws_rds_cluster.aurora.reader_endpoint
}

output "db_name" {
  value = var.db_name
}

output "aurora_instance_resource_id" {
  value = aws_rds_cluster.aurora.cluster_resource_id
}

output "iam_db_auth_role_arn" {
  value = aws_iam_role.aurora_iam_demo_user.arn
}
