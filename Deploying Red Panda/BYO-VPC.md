# GCP 

looks like you can do this through the UI

# AWS

https://docs.redpanda.com/redpanda-cloud/get-started/cluster-types/byoc/aws/vpc-byo-aws/

in `variables.tf` there are several references to the CIDR range, this needs to match your VPC

also you may want to tweak the public/private cidr & AZ sections

be certain your subnet cidr's don't overlap (i.e. a /20 needs to allow space for the /24 terraform wants to create

Client ID & secret are found by navigating to the cloud UI, under service accts
RG_ID is the resource group, thelast bit of the URL

API call in the docs is wrong, missing the "network" wrapper

```json
{
  "network": {
    "name":"cnelson-byovpc-redpanda-network",
    "resource_group_id": "7a87e349-e3d1-455c-910b-e07508a03cca",
    "cloud_provider":"CLOUD_PROVIDER_AWS",
    "region": "us-east-2",
    "cluster_type":"TYPE_BYOC",
    "customer_managed_resources": {
      "aws": {
        "management_bucket": {
          "arn": "arn:aws:s3:::rp-861276079005-us-east-2-mgmt-20250502201030255800000012"
        },
        "dynamodb_table": {
          "arn": "arn:aws:dynamodb:us-east-2:861276079005:table/rp-861276079005-us-east-2-mgmt-tflock-382d2ez0ds"
        },
        "private_subnets": {
          "arns": ["arn:aws:ec2:us-east-2:861276079005:subnet/subnet-0b79a7c3052ce4e82"]
        },
        "vpc": {
          "arn": "arn:aws:ec2:us-east-2:861276079005:vpc/vpc-0342476ccc1ef05f4"
        }
      }
   }
 }
}
```


Then the jq is wrong:

```bash
curl -X POST "https://api.redpanda.com/v1/networks" \
 -H "accept: application/json" \
 -H "content-type: application/json" \
 -H "authorization: Bearer ${BEARER_TOKEN}" \
 --data-binary @redpanda-network.json
```


Turn your `terraform output` into environment vars

```bash
eval $(terraform output -json | jq -r 'to_entries[] | "export " + (.key | ascii_upcase) + "=" + (.value.value|tostring)')
```

>>> the docs should utilize the env vars created by terraform

json doc is missing the `cluster` wrapper

```json
cat > redpanda-cluster.json <<EOF
{

  "cluster": {
    "cloud_provider":"CLOUD_PROVIDER_AWS",
    "connection_type":"CONNECTION_TYPE_PRIVATE",
    "name": "${REDPANDA_CLUSTER_NAME}",
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
