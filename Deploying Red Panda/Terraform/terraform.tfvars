resource_group_name = "cnelson-tf-rg"
network_name        = "cnelson-tf-network"
cluster_name        = "cnelson-tf-cluster"

cloud_provider       = "aws"
#region              = "us-east-2"
#zones               = # default:  ["use2-az1", "use2-az2", "use2-az3"]

cidr_block           = "10.20.0.0/16"
throughput_tier      = "tier-1-aws-v3-arm"
