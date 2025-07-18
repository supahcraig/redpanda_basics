# GCP 

looks like you can do this through the UI

# AWS

https://docs.redpanda.com/redpanda-cloud/get-started/cluster-types/byoc/aws/vpc-byo-aws/

Clone the repo:  https://github.com/redpanda-data/cloud-examples.git


There are 3 main phases to this that are not quite as intertwined as you might expect.

### PHASE 1:  
We have terraform build out the subnets within your VPC, and a few other minor things.  No EKS or EC2 is deployed at this time.   If possible, it will create the NAT gateway & add the necessary routes to make your network usable.   You will specify the AZ's you want to work in, but it's important to understand that you need at least TWO AZ's in this phase because the EKS Control Plane requires two availability zones.   So you will want to create as many private subnets as you have AZ's, with the minimum being 2.  This is set in the `"zones": [ ]` field in `byoc.auto.tfvars.json`.  These zones will reflect your choice of region (i.e. 'use' being us-east-1 and 'use2' being us-east-2).   _This is unrelated to your cluster being single- or multi-az._

No public subnets are _necessary_ but if you don't create any public subnets, then you will need to profide your own routes from the private subnet to the internet via NAT gateway.   This could mean you need to create your own NAT Gateway in a public subnet, with a public address & elastic IP.  ~~Creating a single public subnet avoids this hassle.~~  Multiple public subnets does not appear to add any value.

The general expectation is that the terraform will either build all the subnets, igw, natgw, routes, etc to make it work OR you will supply all that.  Depending on your specific VPC, you may need to add routes to natgw, igw, etc.   In general, the private subnets need routes to the NAT gateway in the public subnet(s).   The public subnet needs a route from `0.0.0.0/0` to the VPC's internet gateway.   Whether or not that gets built as part of this terraform depends on your specific setup.

#### Using pre-existing subnets
Instead of supplying the CIDR ranges of for subnets terraform will create, you will instead supply the subnet ID's of the existing subnets.   Then later on you will need to supply the ARNs of those subnets.   Proper natgw & igw routing is left to the user to complete, if not already in place.   Ultimatly the requirements are the same:  the private subnets need routes to the NAT gateway in the public subnet(s) and the public subnet needs a route to the igw.


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
RG_ID is the resource group, the last bit of the URL

The zones here are not related to your cluster being multi-az or not.   The EKS Control Plane requires subnets in at least 2 zones.

TODO:  what happens if your region has many AZ's but the az's selected here don't align with the AZ's where your existing subnets are deployed?

## Terraform Setup

First cd into `customer-managed/aws/terraform`

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
  "create_internet_gateway": true,
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

You can automate this by iterating over all of them to apply the tag:

```bash
aws ec2 create-tags \
  --resources $(echo "$PRIVATE_SUBNET_IDS" | jq -r '.[]') \
  --tags Key=kubernetes.io/role/internal-elb,Value=1
```

Similarly for the public subnets:

```bash
aws ec2 create-tags \
  --resources $(echo "$PUBLIC_SUBNET_IDS" | jq -r '.[]') \
  --tags Key=kubernetes.io/role/elb,Value=1
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

The terraform output will look like this:

```bash
Outputs:

agent_instance_profile_arn = "arn:aws:iam::<aws-acct-id>:instance-profile/cnelson-byovpc-agent-2025061018353677340000001b"
byovpc_rpk_user_policy_arns = "[\"arn:aws:iam::<aws-acct-id>:policy/cnelson-byovpc-rpk-user-1_20250610183550095200000039\",\"arn:aws:iam::<aws-acct-id>:policy/cnelson-byovpc-rpk-user-2_2025061018355009530000003a\"]"
cloud_storage_bucket_arn = "arn:aws:s3:::redpanda-cloud-storage-20250610183534306300000009"
cluster_security_group_arn = "arn:aws:ec2:us-east-2:<aws-acct-id>:security-group/sg-07635cd1fa8860e85"
connectors_node_group_instance_profile_arn = "arn:aws:iam::<aws-acct-id>:instance-profile/cnelson-byovpc-connect-20250610183537005000000020"
connectors_security_group_arn = "arn:aws:ec2:us-east-2:<aws-acct-id>:security-group/sg-011fcb991a10426b8"
dynamodb_table_arn = "arn:aws:dynamodb:us-east-2:<aws-acct-id>:table/rp-<aws-acct-id>-us-east-2-mgmt-tflock-ntu28lfz5q"
k8s_cluster_role_arn = "arn:aws:iam::<aws-acct-id>:role/cnelson-byovpc-cluster-20250610183534301800000005"
management_bucket_arn = "arn:aws:s3:::rp-<aws-acct-id>-us-east-2-mgmt-20250610183536156300000012"
node_security_group_arn = "arn:aws:ec2:us-east-2:<aws-acct-id>:security-group/sg-069c47f39907c787c"
permissions_boundary_policy_arn = "arn:aws:iam::<aws-acct-id>:policy/cnelson-byovpc-agent-boundary-2025061018354092140000002c"
private_subnet_ids = "[\"arn:aws:ec2:us-east-2:<aws-acct-id>:subnet/subnet-02d30e8cfb39af740\",\"arn:aws:ec2:us-east-2:<aws-acct-id>:subnet/subnet-0f9768fa35bfac9c3\",\"arn:aws:ec2:us-east-2:<aws-acct-id>:subnet/subnet-03aa9d2b29324686c\"]"
redpanda_agent_role_arn = "arn:aws:iam::<aws-acct-id>:role/cnelson-byovpc-agent-20250610183534302400000006"
redpanda_agent_security_group_arn = "arn:aws:ec2:us-east-2:<aws-acct-id>:security-group/sg-076ee7182e85582ee"
redpanda_connect_node_group_instance_profile_arn = "arn:aws:iam::<aws-acct-id>:instance-profile/cnelson-byovpc-rpcn-20250610183536448800000017"
redpanda_connect_security_group_arn = "arn:aws:ec2:us-east-2:<aws-acct-id>:security-group/sg-0bacf4b193d108ec4"
redpanda_node_group_instance_profile_arn = "arn:aws:iam::<aws-acct-id>:instance-profile/cnelson-byovpc-rp-2025061018353689690000001d"
redpanda_node_group_security_group_arn = "arn:aws:ec2:us-east-2:<aws-acct-id>:security-group/sg-0123bceed90f1974c"
utility_node_group_instance_profile_arn = "arn:aws:iam::<aws-acct-id>:instance-profile/cnelson-byovpc-util-20250610183536503200000018"
utility_security_group_arn = "arn:aws:ec2:us-east-2:<aws-acct-id>:security-group/sg-07aa320e92512431b"
vpc_arn = "arn:aws:ec2:us-east-2:<aws-acct-id>:vpc/vpc-0342476ccc1ef05f4"
```

And we can turn that output into environment variables by running this eval block.

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

<details>
    <summary> Using your newly-created subnets</summary>

No additional steps are necessary.

</details>


<details>
    <summary> Using existing subnets</summary>

If you had your own subnets you wanted to use, you would paste the full arn's of those subnets as an array into the `private_subnets` field: 

Example environment variable:

```bash
export PRIVATE_SUBNET_ARNS='["arn:subnet1", "arn:subnet2", etc]'
```

This one-liner will genrate the subnet ARN's from the previously supplied list of subnet ID's:

```bash
export PRIVATE_SUBNET_ARNS=$(echo $PRIVATE_SUBNET_IDS | jq -r --arg region "$AWS_REGION" --arg account_id "$AWS_ACCOUNT_ID" '[.[] | "arn:aws:ec2:" + $region + ":" + $account_id + ":subnet/" + .] | @csv' | sed 's/^/[/;s/$/]/')
```

</details>

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
          "arns": ${PRIVATE_SUBNET_ARNS}
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

If you had existing subnets you wanted to deploy into, you would use the arn of your existing subnets.   

>> I think something like this: `["arn:aws:ec2:us-east-2:<aws-acct-id>:subnet/subnet-0b79a7c3052ce4e82", "arn:aws:ec2:us-east-2:<aws-acct-id>:subnet/subnet-0b79a7c3052ce4e82"]` and not the array itself wrapped in quotes.

>>>> API call in the docs is wrong, missing the "network" wrapper.   Also, the `private subnets` section needs to have the individual arns quoted.
>>>> 
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
  
You should see output similar to this:

```bash
2025-06-10T20:04:42.907Z	INFO	.rpk.managed-byoc	validation/validate.go:75	Checking RPK User... PASSED
2025-06-10T20:04:50.597Z	INFO	.rpk.managed-byoc	validation/validate.go:75	Checking IAM Instance Profiles... PASSED
2025-06-10T20:04:51.227Z	INFO	.rpk.managed-byoc	validation/validate.go:75	Checking Storage... PASSED
2025-06-10T20:04:52.825Z	INFO	.rpk.managed-byoc	validation/validate.go:75	Checking Network... PASSED
2025-06-10T20:04:55.028Z	INFO	.rpk.managed-byoc	aws/apply.go:115	Reconciling agent infrastructure...
2025-06-10T20:04:55.217Z	INFO	.rpk.managed-byoc	cli/cli.go:195	Running apply	{"provisioner": "redpanda-bootstrap"}
2025-06-10T20:05:09.340Z	INFO	.rpk.managed-byoc	cli/cli.go:208	Finished apply	{"provisioner": "redpanda-bootstrap"}
2025-06-10T20:05:09.340Z	INFO	.rpk.managed-byoc	cli/cli.go:195	Running apply	{"provisioner": "redpanda-network"}
2025-06-10T20:05:09.343Z	INFO	.rpk.managed-byoc.network	aws/network.go:135	subnet IDs were provided by customer. Setting network as unmanaged
2025-06-10T20:05:28.478Z	INFO	.rpk.managed-byoc	cli/cli.go:208	Finished apply	{"provisioner": "redpanda-network"}
2025-06-10T20:05:28.478Z	INFO	.rpk.managed-byoc	cli/cli.go:195	Running apply	{"provisioner": "redpanda-agent"}
2025-06-10T20:06:02.229Z	INFO	.rpk.managed-byoc	cli/cli.go:208	Finished apply	{"provisioner": "redpanda-agent"}
2025-06-10T20:06:02.229Z	INFO	.rpk.managed-byoc	aws/apply.go:161	The Redpanda cluster is deploying. This can take up to 45 minutes. View status at https://cloud.redpanda.com/clusters/d148sdfafwvci89vpbdg/overview.
```

It will take about 45 minutes from this point.   About 10 minutes in, the Redpanda Cloud UI should switch to this screen.   If it doesn't, the #1 cause is that your private subnets don't have a route to the internet.

![step3of3](https://github.com/user-attachments/assets/2e7adfd1-85a8-49f2-9761-194765c436fd)


---

# Teardown


```bash
export REDPANDA_ID=$(curl -X DELETE "https://api.redpanda.com/v1/clusters/${REDPANDA_ID}" \
 -H "accept: application/json"\
 -H "content-type: application/json" \
 -H "authorization: Bearer ${BEARER_TOKEN}" | jq -r '.operation.resource_id')
```

```bash
rpk cloud byoc aws destroy --redpanda-id ${REDPANDA_ID}
```

You may find that the Redpanda Network doesn't get removed...

```bash
curl -X DELETE "https://api.redpanda.com/v1/networks/${REDPANDA_NETWORK_ID}" \
 -H "accept: application/json"\
 -H "content-type: application/json" \
 -H "authorization: Bearer ${BEARER_TOKEN}"
```

Then teardown everything that we created in terraform:

```bash
terraform destroy --auto-approve
```


