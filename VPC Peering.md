# VPC Peering a Dedicated Cluster

## Prerequisites

* Private Dedicated cluster
* VPC
* Optional - if you want to test it, you'll want VM in your VPC
* Optional - if you want to test the Debezium connector, set up a Postgres instance on that VM
* 
The CIDR ranges for those must not overlap.   If you want to treat this as a lab, build out a VPC with CIDR 10.100.0.0/16 range, and then put your Redpanda cluster in 10.0.0.0/16


## The Steps

### Create Peering Connection

Follow the steps in the Redpanda documentation to create the peering connection.
https://docs.redpanda.com/docs/deploy/deployment-option/cloud/vpc-peering/

The final step is to select "Modify my route tables now" which opens up the route tables screen but doesn't actually modify your route tables, you get to do that yourself.


### Route Tables

This can get confusing, and I'm probably not even going to get all this right.    Your VPC will have one or more subnets.  IF those subnets already have route tables associated to them, you will need to add routes to those tables.  If any of your subnets do not have a route table associated to them you will need to add a route to the VPC route table.

The route you'll need to add is very simple:

The `Destination` is the CIDR of the Redpanda cluster, `10.0.0.0/16`
For the `Target`, select `Peering Connection` and then put the name of the peering connection that you just created. 


To test this from your VM, follow the instructions for installing rpk & creating a topic found in the Overview tab for your cluster.


### Security Groups

If you want to allow traffic from Redpanda to your postgres instance (i.e. you want to set up a Debezium connector) you will need to allow traffic on port 5432 from the CIDR range of the Redpanda VPC.   So the traffic source would be 10.0.0.0/16.


