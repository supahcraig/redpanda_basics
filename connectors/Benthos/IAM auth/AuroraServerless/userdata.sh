#!/bin/bash
set -euo pipefail

dnf -y update
dnf -y install jq awscli curl

cat >/home/ec2-user/aurora_env.sh <<EOF
export AWS_REGION="${aws_region}"
export AURORA_HOST="${aurora_cluster_endpoint}"
export AURORA_PORT="${aurora_port}"
export AURORA_DB="${aurora_db}"

# Password bootstrap creds (testing only)
export AURORA_MASTER_USER="${aurora_master_user}"
export AURORA_MASTER_PASSWORD="${aurora_master_password}"

# IAM chain:
# rpconnect-app-role (this instance role) -> AssumeRole -> cross-account-db-access-role
export RPCONNECT_APP_ROLE_NAME="${rpconnect_app_role_name}"
export CROSS_ACCOUNT_DB_ACCESS_ROLE_ARN="${cross_account_db_access_role_arn}"

# DB user intended for IAM auth
export AURORA_IAM_USER="${iam_db_user}"
EOF

chown ec2-user:ec2-user /home/ec2-user/aurora_env.sh
chmod 0755 /home/ec2-user/aurora_env.sh

cat >/home/ec2-user/README.txt <<'EOF'
1) Source env:
   source ~/aurora_env.sh

2) Bootstrap the IAM DB user in Postgres (run once using password auth):
   psql "host=$AURORA_HOST port=$AURORA_PORT dbname=$AURORA_DB user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" <<SQL
   DO $$
   BEGIN
     IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$AURORA_IAM_USER') THEN
       EXECUTE format('CREATE ROLE %I LOGIN', '$AURORA_IAM_USER');
     END IF;
   END$$;
   GRANT rds_iam TO $AURORA_IAM_USER;
   ALTER ROLE $AURORA_IAM_USER WITH REPLICATION;
SQL

3) Redpanda Connect will generate/refresh IAM tokens automatically when aws.enabled=true.
   It can also assume CROSS_ACCOUNT_DB_ACCESS_ROLE_ARN automatically (no manual "aws sts assume-role" loop).
EOF

chown ec2-user:ec2-user /home/ec2-user/README.txt
chmod 0644 /home/ec2-user/README.txt
