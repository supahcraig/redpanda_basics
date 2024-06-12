
## install postgres

Install instructions for Postgres on AL2023: https://linux.how2shout.com/how-to-install-postgresql-15-amazon-linux-2023/

A synopsis of the above if you don't have time for all that reading.

```
sudo dnf update
sudo dnf install postgresql15.x86_64 postgresql15-server
sudo postgresql-setup --initdb
sudo systemctl start postgresql
sudo systemctl enable postgresql
sudo systemctl status postgresql.service
sudo passwd postgres
```

## Configure the Connector

The options are pretty straightforward to configure.

I tend to like to use the advanced options to specify which schema/table I'm interested in CDC'ing, but that doesn't actually show up in the config presented back when you view your config.  That's probably a bug.

```
{
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "topic.prefix": "crn",
    "database.hostname": "13.59.23.149",
    "database.user": "postgres",
    "database.password": "postgres",
    "database.dbname": "postgres",
    "database.sslmode": "disable",
    "plugin.name": "pgoutput",
    "key.converter": "org.apache.kafka.connect.json.JsonConverter",
    "key.converter.schemas.enable": true,
    "key.converter.json.schemas.enable": true,
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": true,
    "value.converter.json.schemas.enable": true,
    "header.converter": "org.apache.kafka.connect.storage.SimpleHeaderConverter",
    "table.include.list": "test",
    "topic.creation.enable": true,
    "topic.creation.default.partitions": "5",
    "topic.creation.default.replication.factor": "3",
    "name": "debezium-postgresql-connector-dowc"
}
```


There is a refresh button at the top of most of the console screens...it WILL NOT refresh the messages in the topic viewer.  Instead there is another refresh button in the messages block that you should use.   

## Connectivity

You'll need to allow the connector instance and the database to talk to each other.   Odds are they will be in different VPC's so you either need to communicate over the internet or do some sort of VPN/Peering:

There are multiple ways to make the connection.
* They can setup peering and routing to the VPC where the particular data store is.
* In AWS, they can attach the Redpanda VPC to a Transit Gateway
* They can also setup Private Links and create PL attachments in the Redpanda VPC
* If the data store is public, connectors will connect through the NAT Gateway of the Redpanda VPC, the IP to allow list there is the NAT Gateway public IP.
* Cloud VPNs are also possible.

  
