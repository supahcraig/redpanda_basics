Here is how the IAM stuff works.   It's all laid out in the terraform below, but this is my attempt to explain that which is being built.

## RDS IAM authentication

First, set RDS to allow IAM authentication.    This basically tells the database that "I will be sending you IAM-signed tokens, please be prepared to validate them."   In order for this to work, we'll need a user (`iamuser`) that has `rds_iam` granted to it.


### Cross Account DB Access Role

Second, we need a role (`cross-account-db-access-role`), that has a policy that allows anyone who assumes this role to connect to the db via user `iamuser` using IAM auth.

This says "allow someone with the `rpconnect-app-role` to assume _this_ role.  You can find this in the trust relationship for the role.   

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::861276079005:role/rpconnect-app-role"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
```

#### Permissions policy

This says that this role is allowed to connect to the RDS instance (and db user) given by that ARN, which is specifically the ARN for the `iamuser` database user.    The wrinkle here is that RDS users have their own ARN.

```json
{
    "Statement": [
        {
            "Action": [
                "rds-db:connect"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:rds-db:us-east-2:861276079005:dbuser:cluster-5TTGRZ4AROUYJM2WZ6VKDJ535Q/iamuser"
            ]
        }
    ],
    "Version": "2012-10-17"
}
```

### RPConnect role

Lastly, the EC2 instance where connections will happen from needs a role (`rpconnect_app_role`).   This allows the EC2 instance to assume the cross-ccount-db-access-role.  

This role allows an EC2 instance to assume this role.

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
```

#### Permissions

```json
{
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Effect": "Allow",
            "Resource": "arn:aws:iam::861276079005:role/cross-account-db-access-role"
        }
    ],
    "Version": "2012-10-17"
}
```


### Overall permissions flow

```text
EC2 Instance
   |
   | (role assigned on instance)
   v
rpconnect-app-role
   |
   | sts:AssumeRole
   v
cross-account-db-access-role
   |
   | rds-db:connect
   v
aurora dbuser ARN  --->  IAM token  ---> PostgreSQL user 'iamuser'

Aurora validates token, maps to DB user `iamuser` (who has rds_iam, rds_replication)
```


---

This is just a regurgitation of what Joe Woodward sent me

Acct A with RPCN:  acct `927854233827`
Acct B with Aurora:  acct `082958828786`


## IAM Owned by Acct A

### x-account policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::082958828786:role/cross-account-db-access-role",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "my-secret-external-id-123"
        }
      }
    }
  ]
}
```

### Potentially unecessary

### my cross acct policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::082958828786:role/cross-account-db-access-role"
    }
  ]
}
```

### Trust policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::082958828786:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

### Administrator Access

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*"
    }
  ]
}
```


## IAM Owned by Acct B

###  cross-acct db access role
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "rds-db:connect"
      ],
      "Resource": [
        "arn:aws:rds-db:eu-west-2:082958828786:dbuser:db-XQI7DHAJQW3MY5CITYCAKNYPUQ/iamuser",
        "arn:aws:rds-db:eu-west-2:082958828786:dbuser:cluster-U7CPSIZSCX2MPYNHKRETJG0HGE/iamuser"
      ]
    }
  ]
}
```

### AssumeSecondRole (Customer inline)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::082958828786:role/cross-account-db-access-2"
    }
  ]
}
```

### RDS IAM Auth Policy (Customer inline)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "rds-db:connect"
      ],
      "Resource": [
        "arn:aws:rds-db:eu-west-2:082958828786:dbuser:cluster-VFTS67PYYPYLEBGOH3EXF2HKYA/iamuser",
        "arn:aws:rds-db:eu-west-2:082958828786:dbuser:cluster-U7CPSIZSCX2MPYNHKRETJG0HGE/iamuser"
      ]
    }
  ]
}
```

---


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

# Your existing VPC
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
  #db_cluster_parameter_group_name     = aws_rds_cluster_parameter_group.aurora_pg_iam.name

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

#locals {
#  aurora_db_user_arn = "arn:aws:rds-db:${var.region}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_rds_cluster.aurora_pg.db_cluster_resource_id}/iamuser"
#}

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

### DB setup

`brew install libpq`

Install postgres client
```bash
sudo apt-get update
sudo apt install postgresql-client -y
```


```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

Install AWS CLI, postgres, docker, etc.
```bash
sudo apt update

# AWS CLI v2 is usually already there on recent Ubuntu AMIs, but this is safe:
sudo apt install -y \
  awscli \
  jq \
  postgresql-client \
  docker.io
```

Install rpk
```bash
curl -LO https://github.com/redpanda-data/redpanda/releases/latest/download/rpk-linux-amd64.zip &&
  mkdir -p ~/.local/bin &&
  export PATH="~/.local/bin:$PATH" &&
  unzip rpk-linux-amd64.zip -d ~/.local/bin/
```


(this would all be easier had I run terraform from ec2)

AURORA_HOST=$(terraform output -raw aurora_endpoint)




Connect to the db

```bash
psql "host=$(terraform output -raw aurora_endpoint) \
      port=5432 \
      dbname=exampledb \
      user=postgres \
      password=postgres \
      sslmode=require"
```


```sql
-- Create the DB user that maps to your IAM identity
CREATE USER iamuser WITH LOGIN;

-- Allow this DB user to authenticate via IAM tokens
GRANT rds_iam TO iamuser;

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



sudo docker run --rm \
  -v /tmp/rpcn-postgres-iam.yaml:/rds.yaml \
  docker.redpanda.com/redpandadata/connect \
  run /rds.yaml


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

  
