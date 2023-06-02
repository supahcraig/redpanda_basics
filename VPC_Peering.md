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
  --destination-cidr-block 10.51.0.0/16 \
  --vpc-peering-connection-id pcx-02efc8ef678823dfa

aws ec2 --region us-east-2 create-route \
  --route-table-id rtb-07d2ab45534ce527b \
  --destination-cidr-block 10.100.0.0/16 \
  --vpc-peering-connection-id pcx-02efc8ef678823dfa

```



