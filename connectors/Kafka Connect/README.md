Ensure you have connectivity between the connector instance and the source/destination for your connector.


There are multiple ways to make the connection.
* They can setup peering and routing to the VPC where the particular data store is.
* In AWS, they can attach the Redpanda VPC to a Transit Gateway
* They can also setup Private Links and create PL attachments in the Redpanda VPC
* If the data store is public, connectors will connect through the NAT Gateway of the Redpanda VPC, the IP to allow list there is the NAT Gateway public IP.
* Cloud VPNs are also possible.



## Grafana

https://vectorizedio.grafana.net/d/redpanda-prod-v2/redpanda-clusters-v2?orgId=1&var-datasource=metrics-prod-cloudv2&var-redpanda_id=clt2h8gip70h3qnjuq00

https://vectorizedio.grafana.net/d/aCb4GOW4z/dp-connectors?orgId=1&refresh=1m&var-datasource=VtFd5GIVz&var-redpanda_id=clt2h8gip70h3qnjuq00&var-container=All&var-instance=All&var-node_ip=10.160.0.19&var-node_ip=10.160.0.25&var-node_ip=10.160.0.32&var-node_ip=10.160.0.33&var-node_ip=10.160.0.34&var-node_ip=10.160.0.35&var-node_ip=10.160.0.36&var-node_ip=10.160.0.37&var-node_ip=10.160.0.38&var-node_ip=10.160.0.39&var-node_ip=10.160.0.40&var-connector=All&var-task=All&var-search=&var-query0=prd&from=now-2d&to=now



## Example Queries

https://vectorizedio.grafana.net/explore?schemaVersion=1&panes=%7B%22oa6%22:%7B%22datasource%22:%22zsAoBWS4z%22,%22queries%22:%5B%7B%22refId%22:%22A%22,%22expr%22:%22%7Bredpanda_id%3D%5C%22clt2h8gip70h3qnjuq00%5C%22,%20namespace%3D%5C%22redpanda-connectors%5C%22%7D%7C~%20%5C%22ERROR%5C%22%20%22,%22queryType%22:%22range%22,%22datasource%22:%7B%22type%22:%22loki%22,%22uid%22:%22zsAoBWS4z%22%7D,%22editorMode%22:%22code%22%7D%5D,%22range%22:%7B%22from%22:%221704947164016%22,%22to%22:%221704990364016%22%7D%7D%7D&orgId=1

To find any error on a specific connector in a cluster:
{redpanda_id="clt2h8gip70h3qnjuq00", namespace="redpanda-connectors"}|~ "ERROR" |~ "v16-source-production-main-v2-mongod-32" 

