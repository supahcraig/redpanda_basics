
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


