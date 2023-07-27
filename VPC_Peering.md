# Peering a BYOC Cluster

* create a private BYOC cluster
* pick a cidr range that doesn't overlap (10.50.0.0/16 is good)
* Have another VPC ready (I keep a VPC with cidr 10.100.0.0/16 to reduce the liklihood of an overlap since everybody loves 10.0.0.0/16
  * An EC2 instance in this VPC for testing
* Then go to AWS and find the VPC for your BYOC cluster.  You'll need to know the `vpc-XXXXXXXXXXXXXXXX` name to peer it.

## Initate Peering Request

From the VPC UI, click `Create Peering Connection`

* give it a unique name
* For "Local VPC to Peer with (requester)" find the BYOC VPC in the drop down
* For "VPC ID (accepter)" you will find your other VPC in the drop down
* Then click `Create Peering Connection`

## Accept Peering Request

Once you click to create the peering connection it will take you to the screen showing the (pending) peering request details.  You can accept directly from here under the Actions menu....

Or you can navigate to VPC --> Peering Connections to find the new peering connection which is in the Pending Acceptance state.   

Either way, accept the pending request



## Modify Route Tables

--- still sorting this out ---

Anything that needs to talk to Redpanda will need to be in the VPC that you just peered.   Every resource in that VPC will be in a subnet....it is likely that those subnets will have their own route table.   If they do, you will need to add a route to the Redpanda VPC to that route table.  If they don't already have a route table, you will need to add a route to the main route table (the main route table is only used if the subnet does not have a route table association).

* destination is the CIDR range of the Redpanda VPC
* target is "Peering Connection" which will then give you a list of available peering connections




 

## Troubleshooting / minimal subnet route table requirements

REMOVED PEERING ROUTE >>> ??? subnet-058ffbda69edbbef5 // rtb-0824c64ee02a047db
>>> ??? subnet-089031bd1f94575d1 // rtb-04fb798e924360dc7 , load balancer on this subnet
REMOVED PEERING ROUTE >>> ???subnet-0118d62d0bc968f01 // rtb-0824c64ee02a047db
REMOVED PEERING ROUTE >>> t3.micro? subnet-0ad0dfca492450769 // rtb-0824c64ee02a047db
>>> brokers: subnet-0e7a36e44b4c53c8c // rtb-0de87b21dd0815162 , load balancer on this subnet
>>> load balancer: subnet-03b9bd0ddf40f2cdb // rtb-00bc8fbdb038a320f , load balancer on this subnet
>>> postgres: subnet-0d2967ab2b198b362

* brokers
subnet-0e7a36e44b4c53c8c

* admin


* connect


1.  Get your Redpanda VPC ID
  * Find the cluster ID from the Redpanda UI   
3.  Find the subnets attached to the load balancer
4.  Find the route tables attached to those subnets


### Find your Redpanda VPC ID:

`aws ec2 describe-vpcs | jq '.Vpcs[] | select(.Tags[].Value | endswith("[YOUR_CLUSTER_ID]")) | .VpcId'`

or this, same thing only different:

`aws ec2 describe-vpcs --filters "Name=tag:Name,Values=network-[YOUR CLUSTER ID]"`

### List the subnets attached to the load balancer

it will return a list of subnets:

`aws elbv2 describe-load-balancers | jq '.LoadBalancers[] | select(.VpcId == "[YOUR_VPC_ID]") | .AvailabilityZones[].SubnetId'`


### Find the Route Table for the Subnets 

For each subnet returned, run this to identify the route table associated to the subnet:

`aws ec2 describe-route-tables | jq '.RouteTables[] | select(.Associations[].SubnetId == "[YOUR_SUBNET_ID]") | .Associations[].RouteTableId'`


### Create the Routes

You'll need to run this for each route table that needs a route....could be multiples depending on your topology.

```
aws ec2 --region [YOUR REGION HERE] create-route
  --route-table-id [YOUR REDPANDA ROUTE TABLE ID HERE]
  --destination-cidr-block [YOUR REDPANDA CIDR RANGE]
  --vpc-peering-connection-id [YOUR PEERING CONNECTION ID HERE]

aws ec2 --region [YOUR REGION HERE] create-route
  --route-table-id [YOUR AWS ROUTE TABLE ID HERE]
  --destination-cidr-block [YOUR AWS CIDR BLOCK HERE]
  --vpc-peering-connection-id [YOUR PEERING CONNECTION ID HERE]
```

This way will take your through the VPC to the load balancer, to the subnets, to the route tables.

```
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=network-[YOUR CLUSTER ID]" | \
jq -r '.Vpcs[].VpcId' | \
while read -r vpc_id; do \
  aws elbv2 describe-load-balancers | \
  jq -r --arg vpc_id "$vpc_id" '.LoadBalancers[] | select(.VpcId == $vpc_id) | .AvailabilityZones[].SubnetId' | \
  while read -r subnet_id; do \
    aws ec2 describe-route-tables --filters Name=association.subnet-id,Values=$subnet_id | \
    jq -r '.RouteTables[].RouteTableId' | \
    xargs -I {} aws ec2 create-route --route-table-id {} --destination-cidr-block [YOUR CIDR BLOCK] --vpc-peering-connection-id [YOUR PEERING CONNECTION ID]; \
  done; \
done
```

This way leverages the tags "purpose=private" which exist on the minimal set of route tables, which is a much more direct approach to finding the correct route tables.


_change these as per your specifics_

```
export REDPANDA_CLUSTER_ID=civuvvn09u988pmsfpc0
export REDPANDA_NETWORK_ID=civuvvf09u988pmsfpag
export CIDR_BLOCK=10.100.0.0/16
export PEERING_CONNECTION_ID=pcx-014337d1f083602d0
```

```
aws ec2 describe-route-tables --filter "Name=tag:Name,Values=network-${REDPANDA_NETWORK_ID}" "Name=tag:purpose,Values=private" | jq -r '.RouteTables[].RouteTableId' | \
while read -r route_table_id; do \
  aws ec2 create-route --route-table-id $route_table_id --destination-cidr-block ${CIDR_BLOCK} --vpc-peering-connection-id ${PEERING_CONNECTION_ID}; \
done;
```

## Removing Peered Routes

```
aws ec2 describe-route-tables --filter "Name=tag:Name,Values=network-${REDPANDA_NETWORK_ID}" "Name=tag:purpose,Values=private" | jq -r '.RouteTables[].RouteTableId' | \
while read -r route_table_id; do \
  aws ec2 delete-route --route-table-id $route_table_id --destination-cidr-block ${CIDR_BLOCK};\
done;
```




aws ec2 --region us-east-2 create-route \
--route-table-id rtb-07d2ab45534ce527b \
--destination-cidr-block 10.49.0.0/16 \
--vpc-peering-connection-id pcx-07fe9eb5f580b7626 
 
