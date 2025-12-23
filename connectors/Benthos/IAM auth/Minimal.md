This is the bare minimum to make it work.

1.  Create the IAM roles
2.  Create an EC2 instance
3.  attach the role to the EC2 instance
4.  install rpk, connect
5.  run the pipeline




### Terraform for Aurora RDS w/IAM

This will build an Aurora RDS instance with IAM & user/pass auth into an existing VPC, and create the necessary roles for an EC2 instance to assume the role & allow for IAM auth into the database. 

NOTE:  currently blocked by an AWS limitation that logical replication doesn't work with IAM.   Allegedly this can be gotten around but I have no idea how.

`main.tf`

```terraform
########################
# Variables
########################

variable "region" {
  type    = string
  default = "us-east-2"
}

provider "aws" {
  region = var.region
}

########################
# Existing VPC & Subnets
########################

# Your existing VPC where you want to deploy Aurora Postgres
variable "vpc_id" {
  type    = string
  default = "vpc-0342476ccc1ef05f4"
}

# Your two subnets for Aurora (these can be public or private)
variable "db_subnet_ids" {
  type = list(string)
  default = [
    "subnet-043c307ad7cec520a",
    "subnet-04848c8e444a48139"
  ]
}

# For quick testing you can open to a CIDR; for real use,
# you'd usually restrict this to app/security-group sources.
variable "allowed_cidr_blocks" {
  type    = list(string)
  default = ["0.0.0.0/0"] # <-- for dev only; tighten this later
}

variable "db_master_username" {
  type    = string
  default = "postgres"
}

variable "db_master_password" {
  type      = string
  default   = "postgres" # <-- change for anything real
  sensitive = true
}

########################
# Networking for Aurora
########################

resource "aws_db_subnet_group" "aurora_subnets" {
  name       = "aurora-postgres-subnets"
  subnet_ids = var.db_subnet_ids

  tags = {
    Name = "aurora-postgres-subnet-group"
  }
}

resource "aws_security_group" "aurora_sg" {
  name        = "aurora-postgres-sg"
  description = "Security group for Aurora PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "aurora-postgres-sg"
  }
}


########################
# Aurora PostgreSQL cluster
########################

resource "aws_rds_cluster" "aurora_pg" {
  cluster_identifier                  = "aurora-pg-iam-demo"
  engine                              = "aurora-postgresql"
  #engine_version                      = "15.3" # adjust if needed
  master_username                     = var.db_master_username
  master_password                     = var.db_master_password
  database_name                       = "exampledb"
  db_subnet_group_name                = aws_db_subnet_group.aurora_subnets.name
  vpc_security_group_ids              = [aws_security_group.aurora_sg.id]
  storage_encrypted                   = true
  backup_retention_period             = 1
  preferred_backup_window             = "03:00-04:00"
  skip_final_snapshot                 = true
  iam_database_authentication_enabled = true
  db_cluster_parameter_group_name     = aws_rds_cluster_parameter_group.aurora_pg_iam.name

  tags = {
    Name = "aurora-pg-iam-demo"
  }
}

########################
# Aurora instance (small)
########################

resource "aws_rds_cluster_instance" "aurora_pg_instance" {
  identifier           = "aurora-pg-iam-demo-1"
  cluster_identifier   = aws_rds_cluster.aurora_pg.id
  instance_class       = "db.t4g.medium" # small-ish dev size
  engine               = aws_rds_cluster.aurora_pg.engine
  #engine_version       = aws_rds_cluster.aurora_pg.engine_version
  publicly_accessible  = true            # since your subnets are public
  db_subnet_group_name = aws_db_subnet_group.aurora_subnets.name

  tags = {
    Name = "aurora-pg-iam-demo-instance"
  }
}

########################
# Aurora parameter group
########################

resource "aws_rds_cluster_parameter_group" "aurora_pg_iam" {
  name   = "aurora-pg-iam-parameter-group"
  family = "aurora-postgresql17"   # or whatever matches your engine
  #parameter {
  #  name  = "rds.iam_authentication"
  #  value = "1"
  #  apply_method = "pending-reboot"
  #}
  parameter {
    name  = "rds.logical_replication"
    value = "1"
    apply_method = "pending-reboot"
  }
  # **This is the key one**
  parameter {
    name  = "rds.iam_auth_for_replication"
    value = "1"
    apply_method = "pending-reboot"
  }
}


########################
# Outputs
########################

output "aurora_endpoint" {
  value = aws_rds_cluster.aurora_pg.endpoint
}

output "aurora_reader_endpoint" {
  value = aws_rds_cluster.aurora_pg.reader_endpoint
}



########################
# IAM for simulated cross-account IAM DB auth
########################

# Who am I? (for account ID)
data "aws_caller_identity" "current" {}

# Local: RDS DB user ARN for iamuser on this cluster
locals {
  aurora_db_user_arn = "arn:aws:rds-db:${var.region}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_rds_cluster.aurora_pg.cluster_resource_id}/iamuser"
}


########################
# Role A: "Redpanda Connect app" role
########################

resource "aws_iam_role" "rpconnect_app_role" {
  name = "rpconnect-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          # Adjust depending on where RPCN runs:
          # EC2: "ec2.amazonaws.com"
          # ECS tasks: "ecs-tasks.amazonaws.com"
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "rpconnect-app-role"
  }
}

########################
# Role B: "DB access" role
########################

# Role B: can be assumed by Role A
resource "aws_iam_role" "db_access_role" {
  name = "cross-account-db-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = aws_iam_role.rpconnect_app_role.arn
        },
        Action = "sts:AssumeRole"
        # In real cross-account, you'd often add an ExternalId condition
      }
    ]
  })

  tags = {
    Name = "cross-account-db-access-role"
  }
}

# Policy for Role B: rds-db:connect on the Aurora cluster as iamuser
resource "aws_iam_policy" "db_connect_policy" {
  name = "RDSIAMAuthPolicy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "rds-db:connect"
        ],
        Resource = [
          local.aurora_db_user_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "db_access_attach" {
  role       = aws_iam_role.db_access_role.name
  policy_arn = aws_iam_policy.db_connect_policy.arn
}

########################
# Role A permissions: can assume Role B
########################

resource "aws_iam_policy" "assume_db_access_policy" {
  name = "AssumeDbAccessRolePolicy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "sts:AssumeRole",
        Resource = aws_iam_role.db_access_role.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "assume_db_access_attach" {
  role       = aws_iam_role.rpconnect_app_role.name
  policy_arn = aws_iam_policy.assume_db_access_policy.arn
}

output "rpconnect_app_role_arn" {
  value = aws_iam_role.rpconnect_app_role.arn
}

output "db_access_role_arn" {
  value = aws_iam_role.db_access_role.arn
}

output "aurora_db_user_arn" {
  value = local.aurora_db_user_arn
}


##########
# Creates the instance profile
##########

resource "aws_iam_instance_profile" "rpconnect_app_profile" {
  name = "rpconnect-app-instance-profile"
  role = aws_iam_role.rpconnect_app_role.name
}
```

### Testing

You'll need an EC2 instance.  What you install on it will depend on what you want to test.  At a bare minimum it will need the `rpconnect` role attached to the instance, and network connectivity to the RDS instance.   You may still need to connect into the db in order to run all the necessary grants.



#### Postgres connectivity test

If you want to prove out that you can connect to postgres with an IAM role, first install postgres client
```bash
sudo apt-get update
sudo apt install postgresql-client -y
```

You'll also need the AWS CLI:
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

Connect to the db, if successful it should drop you into the postgres command prompt.

```bash
psql "host=$(terraform output -raw aurora_endpoint) \
      port=5432 \
      dbname=exampledb \
      user=postgres \
      password=postgres \
      sslmode=require"
```

### Make the connector work

On an EC2 instance that will be used to run RPCN, install rpk:
```bash
curl -LO https://github.com/redpanda-data/redpanda/releases/latest/download/rpk-linux-amd64.zip &&
  mkdir -p ~/.local/bin &&
  export PATH="~/.local/bin:$PATH" &&
  unzip rpk-linux-amd64.zip -d ~/.local/bin/
```



### Database Permissions

#### Create the user + enable IAM auth

The user here must match the database user in the arn of the cross-account role.

```sql
CREATE ROLE iam_user LOGIN;
GRANT rds_iam TO iam_user;
```

#### Give replication capability

```sql
GRANT rds_replication TO iam_user;
```

#### Minimal DB/schema privs

```sql
GRANT CONNECT ON DATABASE app TO iam_user;
GRANT USAGE  ON SCHEMA public TO iam_user;
```

####  Sample table/insert

```sql
CREATE TABLE IF NOT EXISTS public.iamuser_test (
  id bigserial primary key,
  msg text not null,
  created_at timestamptz not null default now()
);

-- give SELECT so publication can include it
GRANT SELECT ON TABLE public.iamuser_test TO iam_user;

-- (optional) if you want the pipeline to be able to snapshot/see inserts etc.
GRANT INSERT, UPDATE, DELETE ON TABLE public.iamuser_test TO iam_user;

INSERT INTO public.iamuser_test (msg)
VALUES
  ('first event'),
  ('second event'),
  ('third event');
```





This also works, but is probalby heavy-handed

```sql
-- Give it some privileges (for now, make it simple)
GRANT ALL PRIVILEGES ON DATABASE exampledb TO iamuser;
```


## IAM stuff

Even though you’re in one AWS account, we’ll simulate:

Role A – “App role” (Redpanda Connect side)
Think: account B role that Redpanda runs as → can call sts:AssumeRole on the DB role.

Role B – “DB access role” (Aurora side)
Think: account A role that owns Aurora → can call rds-db:connect on the Aurora cluster as iamuser.

Flow will be:

Role A (rpconnect-app-role)
→ sts:AssumeRole into
Role B (cross-account-db-access-role)
→ uses that role’s rds-db:connect permissions to generate IAM auth tokens for iamuser.

All the IAM stuff is baked into the terraform, including the last bit which allows the role to be attached to an EC2 instance for testing.




### RPCN pipeline

```yaml
logger:
  level: DEBUG

input:
  label: "postgres_cdc"
  postgres_cdc:
    dsn: "postgres://iamuser@aurora-pg-iam-demo.cluster-c3uaqo244uj7.us-east-2.rds.amazonaws.com:5432/exampledb?sslmode=require"
    include_transaction_markers: false
    slot_name: "rpcn_iam_test"
    snapshot_batch_size: 1
    checkpoint_limit: 1
    stream_snapshot: false
    temporary_slot: true
    unchanged_toast_value: null
    schema: public
    tables:
      - "iamuser_test"

    tls:
      # for a quick dev test – *don’t* leave this in production:
      skip_cert_verify: true

    aws:
      enabled: true
      region: "us-east-2" # No default (optional)

      endpoint: "aurora-pg-iam-demo.cluster-c3uaqo244uj7.us-east-2.rds.amazonaws.com:5432"
      roles:
        - role: "arn:aws:iam::861276079005:role/cross-account-db-access-role"
          role_external_id: ""

output:
  stdout: {}
```

```yaml
output:
  kafka_franz:
    seed_brokers:
      - ${REDPANDA_BROKERS}

    topic: iam_test

    tls:
      enabled: true

    sasl:
      - mechanism: SCRAM-SHA-256
        username: cnelson
        password: cnelson
```


## Troubleshooting

If you see "Waiting to ping..." very likely you have a networking problem where Redpanda can't get to Aurora.  Double check your peering, routes, and make sure that Aurora's security group allows ingress on 5432.
  
