# Trino & Redpanda


Running locally with a docker container:

Minimal Trino instance with the Kafka connector working against a BYOC cluster.

```bash
docker run -d \
  --name trino \
  -p 8080:8080 \
  -v ./kafka.properties:/etc/trino/catalog/kafka.properties:ro \
  -v ./kafka-client.properties:/etc/trino/kafka-client.properties:ro \
  -v ./trino.properties:/home/trino/.trino/trino.properties:ro \
  -e TRINO_CONFIG=/home/trino/.trino/trino.properties \
  trinodb/trino:latest
```



The two volmes configure the connector for connectivity to a BYOC cluster.

`kafka.properties`
```ini
connector.name=kafka
kafka.nodes=seed-6234e08e.curl3eo533cmsnt23dv0.byoc.prd.cloud.redpanda.com:9092
kafka.table-names=my_topic
kafka.config.resources=/etc/trino/kafka-client.properties
kafka.hide-internal-columns=false
```

`kafka-client.properties`
```ini
security.protocol = SASL_SSL
sasl.mechanism  = SCRAM-SHA-256
sasl.jaas.config = org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="trino" \
  password="trino";
```

`trino.properties`
```ini
catalog=kafka
schema=default
```



* `kafka.nodes` is the bootstrap URL of your cluster
* `kafka.table-name` is a comma separated list of the topics you want Trino to query
* `username`/`password` are your SASL creds from your BYOC cluster




Paul Wilkinson created a patch that resolves a performance bottleneck on large numbers of partitions, esp when using tiered storage.

```bash
docker run -d \
  --name pw-trino \
  -p 8081:8080 \
  -v ./kafka.properties:/etc/trino/catalog/kafka.properties:ro \
  -v ./kafka-client.properties:/etc/trino/kafka-client.properties:ro \
  docker.io/paulmw/trino:477-SNAPSHOT-arm64
```
