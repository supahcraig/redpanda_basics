# GCP 

looks like you can do this through the UI

# AWS

https://docs.redpanda.com/redpanda-cloud/get-started/cluster-types/byoc/aws/vpc-byo-aws/

Clone the repo:  https://github.com/redpanda-data/cloud-examples.git


There are 3 main phases to this that are not quite as intertwined as you might expect.

### PHASE 1:  
We have terraform build out the subnets within your VPC, and a few other minor things.  No EKS or EC2 is deployed at this time.   If possible, it will create the NAT gateway & add the necessary routes to make your network usable.   You will specify the AZ's you want to work in, but it's important to understand that you need at least TWO AZ's in this phase because the EKS Control Plane requires two availability zones.   So you will want to create as many private subnets as you have AZ's, with the minimum being 2.  This is set in the `"zones": [ ]` field in `byoc.auto.tfvars.json`.  These zones will reflect your choice of region (i.e. 'use' being us-east-1 and 'use2' being us-east-2).   _This is unrelated to your cluster being single- or multi-az._

No public subnets are _necessary_ but if you don't create any public subnets, then you will need to profide your own routes from the private subnet to the internet via NAT gateway.   This could mean you need to create your own NAT Gateway in a public subnet, with a public address & elastic IP.  Creating a single public subnet avoids this hassle.  Multiple public subnets does not appear to add any value.

#### Using pre-existing subnets
TBD:  I think the proper course of action is to remove the subnet cidr sections from the terraform, and then put the private subnets into `redpanda-cluster.json`, although it is not clear how it will know what the public subnets are.


### PHASE 2: 
We build out some json that will be passed to the Redpanda control plane API to create the Redpanda Network and Redpand Cluster (which are really just logical "things" within Redpanda Cloud, not the actual network/resources in AWS).  The cluster create step is where you specify single- or multi-az, by setting the REDPANDA_ZONES env var.  The output from these API calls is essentially to just return the ID's of the network & cluster.  You can see the network in the cloud UI, but the cluster won't be there until into phase 3.   

NOTE:  if you find yourself spinning up & tearing down clusters (during testing, for example), you should know that deleting a cluster does not delete the network.  Furthermore, the create network api isn't completely idempotent; if the network already exists it won't return the ID, it will return `"null"`.  So it's a good idea to verify the outputs as you go.


### PHASE 3: 
We actually deploy the agent into the cloud infra and start creating EKS & EC2 instances.   You will see in the Cloud UI that the screen will change to "Step 3 of 3" after a few minutes while it is working.   If that screen does not come up, the most likely culprit is that your agent does not have access to the public internet; you are missing a route or similar.  Use the AWS Rechability Analyzer for help here, with the agent instance as the source and your internet gateway as your destination.  The Redpanda Cloud Admin panel has a link to the Agents Log, which will bring up Grafana for your cluster.   Logs should begin writing very shorly thereafter.


---


## Environment Variables.

```bash
export REDPANDA_COMMON_PREFIX=cnelson-byovpc
export AWS_REGION=us-east-2
export AWS_ZONES='["use2-az1", "use2-az2", "use2-az3"]'

export AWS_ACCOUNT_ID=
export AWS_VPC_ID=
export REDPANDA_CLIENT_ID=
export REDPANDA_CLIENT_SECRET=
export REDPANDA_RG_ID= #Retrieve the ID from the URL of the resource group when accessing within Redpanda Cloud
```

Client ID & secret are found by navigating to the cloud UI, under service accts
RG_ID is the resource group, thelast bit of the URL

The zones here are not related to your cluster being multi-az or not.   The EKS Control Plane requires subnets in at least 2 zones.

TODO:  what happens if your region has many AZ's but the az's selected here don't align with the AZ's where your existing subnets are deployed?

## Terraform Setup

Generate a `byoc.auto.tfvars.json` to specify your VPC info.   This will create subnets, but if you already have subnets you want to use, I think you'll want to leave those as `[ ]`, since defaults are specified in `variables.tf`.   The CIDR ranges here are unique to my VPC, yours will be different.  Be certain your subnet CIDR's don't overlap existing subnets (i.e. a /20 needs to allow space for the /24 terraform wants to create.

<details>
<summary> Creating NEW subnets in an Existing VPC</summary>
  
### Creating NEW subnets in an Existing VPC

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
  "zones": ${AWS_ZONES},
  "public_subnet_cidrs": [
     "10.100.50.0/24"
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
</details>

<details>
  <summary>Using EXISTING Subnets in an Existing VPC</summary>

### Using EXISTING Subnets in an Existing VPC

If you have a set of private subnets which already exist that you want to deploy into, you will need to supply the subnet ID's (i.e. `subnet-xxxxxxxxxxxxx`) to terraform in the form of an array.   Put them into an environment variable.

```bash
export PRIVATE_SUBNET_IDS='["subnet1", "subnet2", "subnet3"]'
```


**NOTE:**  it is undocumented, but the subnets you deploy into require a specifc tag or else it will fail during the `rpk cloud byoc aws apply` step.

|key | value|
|---|---|
|`kubernetes.io/role/internal-elb` | 1 |

You can automate this by terateingover all of them to apply the tag:

```bash
aws ec2 create-tags \
  --resources $(echo "$PRIVATE_SUBNET_IDS" | jq -r '.[]') \
  --tags Key=kubernetes.io/role/internal-elb,Value=1
```


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
  "zones": ${AWS_ZONES},
  "private_subnet_ids": ${PRIVATE_SUBNET_IDS},
  "enable_private_link": false,
  "create_rpk_user": false,
  "force_destroy_cloud_storage": true
}
EOF
```

It is recommended you cat the file to ensure your variables were interpolated correctly.

</details>

---


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


The AZ's you export here are going to determine if you are single az or not.   A single AZ would look like:

```bash
export REDPANDA_ZONES='["use2-az1"]'
```

Multi-AZ would look like 

```bash
export REDPANDA_ZONES='["use2-az1", "use2-az2", "use2-az3"]'
```


then update to the latest version & tier
```bash
export REDPANDA_VERSION=25.1
export REDPANDA_THROUGHPUT_TIER=tier-1-aws-v3-arm
```


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
  

