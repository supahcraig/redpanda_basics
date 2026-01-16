region       = "us-east-2"
name_prefix  = "demo"

# Put YOUR home public IP here:
home_ip_cidr = "0.0.0.0/32" # change this!

vpc_cidr = "10.201.0.0/16"  # VPC where Aurora will deploy

db_name      = "demo_db"
db_username  = "postgres"
db_password  = "postgres"

engine_version       = "17.4"
serverlessv2_min_acu = 0.5
serverlessv2_max_acu = 2
az_count             = 2

trusted_principal_role_arn = "arn:aws:iam::861276079005:role/redpanda-curl3eo533cmsnt23dv0-redpanda-connect-pipeline"
