# Peering a BYOC Cluster

* create a private BYOC cluster
* pick a cidr range that doesn't overlap (10.50.0.0/16 is good)
* Have another VPC ready (I keep a VPC with cidr 10.100.0.0/16 to reduce the liklihood of an overlap since everybody loves 10.0.0.0/16
  * An EC2 instance in this VPC for testing
* Then go to AWS and find the VPC for your BYOC cluster.  You'll need to know the `vpc-XXXXXXXXXXXXXXXX` name to peer it.

## Initate Peering Request

I'm not 100% sure it matters yet, but the requester VPC will be the VPC that Redpanda is living in, and the accepter VPC will be the "non-Redpanda" VPC.  The easy way to remember this is to consider how peering works in Redpanda Dedicated.   You push the peering button in the UI, and the peering request shows up in the customer's VPC awaiting acceptance.

From the VPC UI, click `Create Peering Connection`

* give it a unique name
* For "Local VPC to Peer with (requester)" find the Redpanda VPC in the drop down
* For "VPC ID (accepter)" you will find your other (non-Redpanda) VPC in the drop down
* Then click `Create Peering Connection`

## Accept Peering Request

Once you click to create the peering connection it will take you to the screen showing the (pending) peering request details.  You can accept directly from here under the Actions menu....

Or you can navigate to VPC --> Peering Connections to find the new peering connection which is in the Pending Acceptance state.   

Either way, accept the pending request.



## Modify Route Tables

--- still sorting this out ---
### General Concepts

Once you've peered the networks, you will need to add routes from both VPCs to the peering connection.  The Redpanda network is well-understood so the setting up of the routes can be scripted.  The network for the non-Redpanda VPC will be unique to the customer, so it could be more challenging.  Every resource in that VPC will be in a subnet....it is likely that those subnets will have their own route table.   If they do, you will need to add a route to the Redpanda VPC to that route table.  If they don't already have a route table, you will need to add a route to the main route table (the main route table is only used if the subnet does not have a route table association).


When creating the routes from the non-Redpanda VPC, you'll navigate to the route table for each subnet that will expect to communicate to Redpanda and add a route:

* destination is the CIDR range of the Redpanda VPC
* target is "Peering Connection" which will then give you a list of available peering connections

In plain English, this is telling AWS that whenever you see traffic directed to the IP range of Redpanda, it needs to realize that is part of a peered network so it should route that traffic to the peering connection.  

_(Routes set up from Redpanda to the peering connection would likewise use the IP range of the non-Redpanda VPC)_


 
### Brute Force

1.  Get your Redpanda VPC ID
  * Find the cluster ID from the Redpanda UI
  * Find the networkd ID from the Redpanda UI 
3.  Find the subnets attached to the load balancer (or brokers?)
4.  Find the route tables attached to those subnets


### Find your Redpanda VPC ID:

`aws ec2 describe-vpcs | jq '.Vpcs[] | select(.Tags[].Value | endswith("[YOUR_REDPANDA_NETWORK_ID]")) | .VpcId'`

`aws ec2 describe-vpcs | jq '.Vpcs[] | select(.Tags[].Value | endswith("network-cl1ajkkmfckfjaoo4pt0")) | .VpcId'`


cl1ajkkmfckfjaoo4pt0
cl1ajkkmfckfjaoo4pt0


### List the subnets attached to the load balancer

it will return a list of subnets, using the VPC ID found in the prior step.

`aws elbv2 describe-load-balancers | jq '.LoadBalancers[] | select(.VpcId == "[YOUR_VPC_ID]") | .AvailabilityZones[].SubnetId'`

`aws elbv2 describe-load-balancers | jq '.LoadBalancers[] | select(.VpcId == "vpc-0c22f7cf13c3fd55a") | .AvailabilityZones[].SubnetId'`
NOTE:  this returns only 3 subnets, but I know we add routes to at least 6 route tables...


### Find the Route Table for the Subnets 

For each subnet returned, run this to identify the route table associated to the subnet:

`aws ec2 describe-route-tables | jq '.RouteTables[] | select(.Associations[].SubnetId == "[YOUR_SUBNET_ID]") | .Associations[].RouteTableId'`

`aws ec2 describe-route-tables | jq '.RouteTables[] | select(.Associations[].SubnetId == "subnet-00809a69d682bdc19") | .Associations[].RouteTableId'`
`aws ec2 describe-route-tables | jq '.RouteTables[] | select(.Associations[].SubnetId == "subnet-01a496c9729a4a5ed") | .Associations[].RouteTableId'`
`aws ec2 describe-route-tables | jq '.RouteTables[] | select(.Associations[].SubnetId == "subnet-03d0cb1519f3e6c07") | .Associations[].RouteTableId'`


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
export REDPANDA_CLUSTER_ID=cl1ajksmfckfjaoo4pu0
export REDPANDA_NETWORK_ID=cl1ajkkmfckfjaoo4pt0
export CIDR_BLOCK=172.31.0.0/16
export PEERING_CONNECTION_ID=pcx-00000204e9a0d5702
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
 
