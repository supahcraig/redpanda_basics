data "aws_caller_identity" "current" {}

#####################################
# Security groups
#####################################

resource "aws_security_group" "aurora" {
  name        = "${var.name_prefix}-aurora-sg"
  description = "Aurora Postgres SG"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name_prefix}-aurora-sg" }
}

resource "aws_security_group" "rpconnect_client" {
  name        = "${var.name_prefix}-rpconnect-client-sg"
  description = "EC2 client SG"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH (lock down in real life)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-rpconnect-client-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "aurora_from_client" {
  security_group_id            = aws_security_group.aurora.id
  referenced_security_group_id = aws_security_group.rpconnect_client.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "Postgres from rpconnect client SG"
}

resource "aws_vpc_security_group_egress_rule" "aurora_all_out" {
  security_group_id = aws_security_group.aurora.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Aurora outbound"
}

#####################################
# Subnet group + parameter group
#####################################

resource "aws_db_subnet_group" "aurora" {
  name       = "${var.name_prefix}-aurora-subnets"
  subnet_ids = var.db_subnet_ids

  tags = { Name = "${var.name_prefix}-aurora-subnets" }
}

resource "aws_rds_cluster_parameter_group" "aurora_pg" {
  name        = "${var.name_prefix}-aurora-pg"
  family      = "aurora-postgresql17"
  description = "Aurora PG params: force SSL + logical repl + IAM repl auth"

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "rds.iam_auth_for_replication"
    value        = "1"
    apply_method = "immediate"
  }

  tags = { Name = "${var.name_prefix}-aurora-pg" }
}

#####################################
# Aurora Serverless v2
#####################################

resource "aws_rds_cluster" "aurora" {
  cluster_identifier = "${var.name_prefix}-aurora"
  engine             = "aurora-postgresql"
  engine_version     = var.engine_version

  database_name   = var.db_name
  master_username = var.db_master_username
  master_password = var.db_master_password

  iam_database_authentication_enabled = true

  db_subnet_group_name            = aws_db_subnet_group.aurora.name
  vpc_security_group_ids          = [aws_security_group.aurora.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora_pg.name

  serverlessv2_scaling_configuration {
    min_capacity = var.serverlessv2_min_acu
    max_capacity = var.serverlessv2_max_acu
  }

  backup_retention_period = 1
  deletion_protection     = false
  skip_final_snapshot     = true

  tags = { Name = "${var.name_prefix}-aurora" }
}

resource "aws_rds_cluster_instance" "aurora" {
  identifier          = "${var.name_prefix}-aurora-1"
  cluster_identifier  = aws_rds_cluster.aurora.id
  engine              = aws_rds_cluster.aurora.engine
  engine_version      = aws_rds_cluster.aurora.engine_version
  instance_class      = "db.serverless"
  publicly_accessible = false

  tags = { Name = "${var.name_prefix}-aurora-1" }
}

#####################################
# IAM: rpconnect-app-role (EC2 role)
#####################################

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rpconnect_app_role" {
  name               = "${var.name_prefix}-rpconnect-app-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_instance_profile" "rpconnect" {
  name = "${var.name_prefix}-rpconnect-profile"
  role = aws_iam_role.rpconnect_app_role.name
}

#####################################
# IAM: cross-account-db-access-role
#####################################

data "aws_iam_policy_document" "db_access_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.rpconnect_app_role.arn]
    }
  }
}

resource "aws_iam_role" "cross_account_db_access_role" {
  name               = "${var.name_prefix}-cross-account-db-access-role"
  assume_role_policy = data.aws_iam_policy_document.db_access_trust.json
}

# rpconnect-app-role can assume cross-account-db-access-role
data "aws_iam_policy_document" "rpconnect_can_assume_db_access" {
  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.cross_account_db_access_role.arn]
  }
}

resource "aws_iam_policy" "rpconnect_can_assume_db_access" {
  name   = "${var.name_prefix}-rpconnect-assume-db-access"
  policy = data.aws_iam_policy_document.rpconnect_can_assume_db_access.json
}

resource "aws_iam_role_policy_attachment" "rpconnect_assume_attach" {
  role       = aws_iam_role.rpconnect_app_role.name
  policy_arn = aws_iam_policy.rpconnect_can_assume_db_access.arn
}

# cross-account-db-access-role can connect to DB user via IAM auth
data "aws_iam_policy_document" "rds_db_connect" {
  statement {
    effect  = "Allow"
    actions = ["rds-db:connect"]
    resources = [
      "arn:aws:rds-db:${var.aws_region}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_rds_cluster.aurora.cluster_resource_id}/${var.iam_db_user}"
    ]
  }
}

resource "aws_iam_policy" "rds_db_connect" {
  name   = "${var.name_prefix}-rds-db-connect"
  policy = data.aws_iam_policy_document.rds_db_connect.json
}

resource "aws_iam_role_policy_attachment" "db_access_connect_attach" {
  role       = aws_iam_role.cross_account_db_access_role.name
  policy_arn = aws_iam_policy.rds_db_connect.arn
}

#####################################
# EC2 instance (rpconnect client host)
#####################################

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "rpconnect_client" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.ec2_instance_type
  subnet_id              = var.ec2_subnet_id
  vpc_security_group_ids = [aws_security_group.rpconnect_client.id]
  key_name               = var.ec2_key_name

  iam_instance_profile = aws_iam_instance_profile.rpconnect.name

  user_data = templatefile("${path.module}/userdata.sh", {
    aws_region                     = var.aws_region
    aurora_cluster_endpoint        = aws_rds_cluster.aurora.endpoint
    aurora_port                    = aws_rds_cluster.aurora.port
    aurora_db                      = var.db_name
    aurora_master_user             = var.db_master_username
    aurora_master_password         = var.db_master_password
    rpconnect_app_role_name        = aws_iam_role.rpconnect_app_role.name
    cross_account_db_access_role_arn = aws_iam_role.cross_account_db_access_role.arn
    iam_db_user                    = var.iam_db_user
  })

  tags = { Name = "${var.name_prefix}-rpconnect-client" }
}
