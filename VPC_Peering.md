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




Boilerplate:
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

```
aws ec2 --region us-east-2 create-route \
  --route-table-id rtb-0824c64ee02a047db \
  --destination-cidr-block 10.100.0.0/16 \
  --vpc-peering-connection-id pcx-0cbb3094774216d5c

aws ec2 --region us-east-2 create-route \
  --route-table-id rtb-07d2ab45534ce527b \
  --destination-cidr-block 10.51.0.0/16 \
  --vpc-peering-connection-id pcx-0cbb3094774216d5c
```


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
2.  Find the subnets attached to the load balancer
3.  Find the route tables attached to those subnets



To list the subnets attached to the load balancer:

`aws elbv2 describe-load-balancers | jq '.LoadBalancers[] | select(.VpcId == "vpc-0f5280796c8593a07") | .AvailabilityZones[].SubnetId'`


