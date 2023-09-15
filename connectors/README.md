Ensure you have connectivity between the connector instance and the source/destination for your connector.


There are multiple ways to make the connection.
* They can setup peering and routing to the VPC where the particular data store is.
* In AWS, they can attach the Redpanda VPC to a Transit Gateway
* They can also setup Private Links and create PL attachments in the Redpanda VPC
* If the data store is public, connectors will connect through the NAT Gateway of the Redpanda VPC, the IP to allow list there is the NAT Gateway public IP.
* Cloud VPNs are also possible.
