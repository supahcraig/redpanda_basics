# GCP 

looks like you can do this through the UI

# AWS

https://docs.redpanda.com/redpanda-cloud/get-started/cluster-types/byoc/aws/vpc-byo-aws/

in `variables.tf` there are several references to the CIDR range, this needs to match your VPC.  You need at least 2 subnets in both public & private sections, and all 3 AZ in the AZ section.

You may also want to set `enable_private_link` to false in the `byoc.auto.tfvars.json` file.

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




be certain your subnet cidr's don't overlap (i.e. a /20 needs to allow space for the /24 terraform wants to create

Client ID & secret are found by navigating to the cloud UI, under service accts
RG_ID is the resource group, thelast bit of the URL


Turn your `terraform output` into environment vars

```bash
eval $(terraform output -json | jq -r 'to_entries[] | "export " + (.key | ascii_upcase) + "=" + (.value.value|tostring)')
```

Also export this:

```bash
export REDPANDA_COMMON_PREFIX=cnelson-byovpc
```



API call in the docs is wrong, missing the "network" wrapper.   Also, the `private subnets` section needs to have the individual arns quoted.

something like this: ` ["arn:aws:ec2:us-east-2:861276079005:subnet/subnet-0b79a7c3052ce4e82"]` and not the array itself wrapped in quotes.

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



Then the jq is wrong:

```bash
export REDPANDA_NETWORK_ID=$(curl -X POST "https://api.redpanda.com/v1/networks" \
 -H "accept: application/json" \
 -H "content-type: application/json" \
 -H "authorization: Bearer ${BEARER_TOKEN}" \
 --data-binary @redpanda-network.json | jq -r '.operation.metadata.network_id')
```

>>> the docs should utilize the env vars created by terraform


The AZ's you export here are going to determine if you are single az or not.

`export AWS_ZONES='["use-az1"]'`  for a single AZ

then update to the latest version
`export REDPANDA_VERSION=25.1`

you don't need to export the cluster name if you did my "CLUSTER_NAME" env var above.

json doc is missing the `cluster` wrapper

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
    "zones": ${AWS_ZONES},
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


Then you may need to add a route from the public subnets to the internet gateway.
