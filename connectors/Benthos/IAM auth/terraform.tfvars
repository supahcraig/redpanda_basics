region       = "us-east-2"
name_prefix  = "demo"
aws_profile  = "se_demo"

vpc_cidr = "10.201.0.0/16"  # CIDR range of the new VPC where RDS will deploy

# Allowing access to RDS
# if your database is private (most likely) you would first peer the networks, and then add a SG rule to allow traffic from the Redpanda CIDR
# if your database is public (i.e. this terraform example), you will add an SG rule to allow traffic from the Redpanda NAT Gateway
redpanda_cidr = "3.139.175.89/32"

trusted_principal_role_arn = "arn:aws:iam::861276079005:role/redpanda-curl3eo533cmsnt23dv0-redpanda-connect-pipeline"

db_name       = "demo_db"
db_username   = "postgres"
db_password   = "postgres"
iam_auth_user = "iam_demo_user"

engine_version       = "17.4"
serverlessv2_min_acu = 0.5
serverlessv2_max_acu = 2
az_count             = 2
