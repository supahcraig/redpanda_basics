# GCP 

looks like you can do this through the UI

# AWS

https://docs.redpanda.com/redpanda-cloud/get-started/cluster-types/byoc/aws/vpc-byo-aws/

Clone the repo:  https://github.com/redpanda-data/cloud-examples.git


## Environment Variables.

```bash
export REDPANDA_COMMON_PREFIX=cnelson-byovpc
export AWS_ACCOUNT_ID=
export AWS_REGION=us-east-2
export AWS_VPC_ID=
export REDPANDA_CLIENT_ID=
export REDPANDA_CLIENT_SECRET=
export REDPANDA_RG_ID= #Retrieve the ID from the URL of the resource group when accessing within Redpanda Cloud
```

Client ID & secret are found by navigating to the cloud UI, under service accts
RG_ID is the resource group, thelast bit of the URL


## Terraform Setup

Generate a `byoc.auto.tfvars.json` to specify your VPC info.   This will create subnets, but if you already have subnets you want to use, I think you'll want to leave those as `[ ]`, since defaults are specified in `variables.tf`.   The CIDR ranges here are unique to my VPC, yours will be different.  Be certain your subnet CIDR's don't overlap existing subnets (i.e. a /20 needs to allow space for the /24 terraform wants to create.

* the public subnets are not strictly necessary.
* if I leave them in, all the routes seem to get created ok
* if I remove them, I needed to create a NAT Gateway (with a public address, new elastic IP, and gave it a private IP that fit into the public subnet CIDR, i.e. 10.100.1.1)
* At least TWO private subnets are required by the EKS control plane
* UNSURE:  to do a single AZ deployment, the terraform doesn't change
  * when you create the Redpanda Cluster, set the REDPANDA_ZONES env var to a single AZ rather than all 3.   Currently verifying this.

```json
cat > byoc.auto.tfvars.json <<EOF
{
  "aws_account_id": "${AWS_ACCOUNT_ID}",
  "region": "${AWS_REGION}",
  "common_prefix": "${REDPANDA_COMMON_PREFIX}",
  "condition_tags": {},
  "default_tags": {},
  "ignore_tags": [],
  "vpc_id": "${AWS_VPC_ID}",
  "vpc_cidr_block": "10.100.0.0/16",
  "zones": ["use2-az1", "use2-az2", "use2-az3"],
  "public_subnet_cidrs": [
     "10.100.50.0/24",
     "10.100.51.0/24",
     "10.100.52.0/24"
  ],
  "private_subnet_cidrs": [
     "10.100.100.0/24",
     "10.100.101.0/24",
     "10.100.102.0/24"
  ],
  "enable_private_link": false,
  "create_rpk_user": true,
  "force_destroy_cloud_storage": true
}
EOF
```

## Terraform Apply

```bash
terraform init
terraform plan
terraform apply
```

`terraform apply` will generate a number of terraform outputs that we will want to stick into environment variables:

```bash
eval $(terraform output -json | jq -r 'to_entries[] | "export " + (.key | ascii_upcase) + "=" + (.value.value|tostring)')
```

This is the same, but will quote the array elements

```bash
eval $(terraform output -json | jq -r '
  to_entries[] |
  "export \(.key | ascii_upcase)=" +
  (if (.value.value | type) == "array"
   then "[" + (.value.value | map("\"" + . + "\"") | join(",")) + "]"
   else (.value.value | @sh)
   end)')
```


__NOTE__: You may need to add a route from the public subnets to the internet gateway.




## Authenticate with Redpanda Cloud

```bash
export BEARER_TOKEN=$(curl --request POST \
--url 'https://auth.prd.cloud.redpanda.com/oauth/token' \
--header 'content-type: application/x-www-form-urlencoded' \
--data grant_type=client_credentials \
--data client_id=${REDPANDA_CLIENT_ID} \
--data client_secret=${REDPANDA_CLIENT_SECRET} \
--data audience=cloudv2-production.redpanda.cloud | jq -r '.access_token')
```


## Create the Redpanda Network

If you had your own subnets you wanted to use, you would paste the full arn's of those subnets as an array into the `private_subnets` field:  `["arn:subnet1", "arn:subnet2", etc]`

```json
cat > redpanda-network.json <<EOF
{
  "network": { 
    "name":"${REDPANDA_COMMON_PREFIX}-network",
    "resource_group_id": "${REDPANDA_RG_ID}",
    "cloud_provider":"CLOUD_PROVIDER_AWS",
    "region": "${AWS_REGION}",
    "cluster_type":"TYPE_BYOC",
    "customer_managed_resources": {
      "aws": {
        "management_bucket": {
          "arn": "${MANAGEMENT_BUCKET_ARN}"
        },
        "dynamodb_table": {
          "arn": "${DYNAMODB_TABLE_ARN}"
        },
        "private_subnets": {
          "arns": ${PRIVATE_SUBNET_IDS}
        },
        "vpc": {
          "arn": "${VPC_ARN}"
        }
      }
   }
  }
}
EOF
```

Cat the file to ensure all your environment variables were correctly substituted.

If you had existing subnets you wanted to deploy into, you would use the arn of your existing subnets.   >> I think
something like this: ` ["arn:aws:ec2:us-east-2:861276079005:subnet/subnet-0b79a7c3052ce4e82", "arn:aws:ec2:us-east-2:861276079005:subnet/subnet-0b79a7c3052ce4e82"]` and not the array itself wrapped in quotes.

>>>> API call in the docs is wrong, missing the "network" wrapper.   Also, the `private subnets` section needs to have the individual arns quoted.
>>>> also the jq is wrong

Run this to actually create the Redpanda Network

```bash
export REDPANDA_NETWORK_ID=$(curl -X POST "https://api.redpanda.com/v1/networks" \
 -H "accept: application/json" \
 -H "content-type: application/json" \
 -H "authorization: Bearer ${BEARER_TOKEN}" \
 --data-binary @redpanda-network.json | jq -r '.operation.metadata.network_id')
```

NOTE:  if the network already exists, it will put `null` into the env var.  Your network ID can be found after the fact from the Cloud UI.

>>> the docs should utilize the env vars created by terraform


## Create the Redpanda Cluster

__NOTE__: this step doesn't create the _actual_ cluster, just the logical cluster within Redpanda Cloud

### More Environment Variables

`export REDPANDA_ZONES='["use2-az1"]'`

The AZ's you export here are going to determine if you are single az or not.   A single AZ would look like:


then update to the latest version & tier
`export REDPANDA_VERSION=25.1`
`export REDPANDA_THROUGHPUT_TIER=tier-1-aws-v3-arm`


### Cluster Create

>>>> json doc is missing the `cluster` wrapper

```json
cat > redpanda-cluster.json <<EOF
{

  "cluster": {
    "cloud_provider":"CLOUD_PROVIDER_AWS",
    "connection_type":"CONNECTION_TYPE_PRIVATE",
    "name": "${REDPANDA_COMMON_PREFIX}-cluster",
    "resource_group_id": "${REDPANDA_RG_ID}",
    "network_id": "${REDPANDA_NETWORK_ID}",
    "region": "${AWS_REGION}",
    "throughput_tier": "${REDPANDA_THROUGHPUT_TIER}",
    "type": "TYPE_BYOC",
    "zones": ${REDPANDA_ZONES},
    "redpanda_version": "${REDPANDA_VERSION}",
    "customer_managed_resources": {
      "aws": {
        "agent_instance_profile": {
          "arn": "${AGENT_INSTANCE_PROFILE_ARN}"
        },
        "connectors_node_group_instance_profile": {
          "arn": "${CONNECTORS_NODE_GROUP_INSTANCE_PROFILE_ARN}"
        },
        "redpanda_connect_node_group_instance_profile": {
          "arn": "${REDPANDA_NODE_GROUP_INSTANCE_PROFILE_ARN}"
        },
        "redpanda_node_group_instance_profile": {
          "arn": "${REDPANDA_NODE_GROUP_INSTANCE_PROFILE_ARN}"
        },
        "utility_node_group_instance_profile": {
          "arn": "${UTILITY_NODE_GROUP_INSTANCE_PROFILE_ARN}"
        },
        "connectors_security_group": {
          "arn": "${CONNECTORS_SECURITY_GROUP_ARN}"
        },
        "redpanda_connect_security_group": {
          "arn": "${REDPANDA_CONNECT_SECURITY_GROUP_ARN}"
        },
        "node_security_group": {
          "arn": "${NODE_SECURITY_GROUP_ARN}"
        },
        "utility_security_group": {
          "arn": "${UTILITY_SECURITY_GROUP_ARN}"
        },
        "redpanda_agent_security_group": {
          "arn": "${REDPANDA_AGENT_SECURITY_GROUP_ARN}"
        },
        "redpanda_node_group_security_group": {
          "arn": "${REDPANDA_NODE_GROUP_SECURITY_GROUP_ARN}"
        },
        "cluster_security_group": {
          "arn": "${CLUSTER_SECURITY_GROUP_ARN}"
        },
        "k8s_cluster_role": {
          "arn": "${K8S_CLUSTER_ROLE_ARN}"
        },
        "cloud_storage_bucket": {
          "arn": "${CLOUD_STORAGE_BUCKET_ARN}"
        },
        "permissions_boundary_policy": {
          "arn": "${PERMISSIONS_BOUNDARY_POLICY_ARN}"
        }
      }
    }
  }
}
EOF
```

Then run this api to create the cluster based on the json spec.

```bash
export REDPANDA_ID=$(curl -X POST "https://api.redpanda.com/v1/clusters" \
 -H "accept: application/json" \
 -H "content-type: application/json" \
 -H "authorization: Bearer ${BEARER_TOKEN}" \
 --data-binary @redpanda-cluster.json | jq -r '.operation.resource_id')
```

## Create the Cluster Resources (aka deploy agent)

Redpanda Cloud login:

```bash
rpk cloud login \
  --save \
  --client-id=${REDPANDCA_CLIENT_ID} \
  --client-secret=${REDPANDA_CLIENT_SECRET} \
  --no-profile
```

and then actually kick it off:

```bash
rpk cloud byoc aws apply \
  --redpanda-id=${REDPANDA_ID}
```
  

