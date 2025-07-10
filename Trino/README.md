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
  -v ./trino-test.properties:/etc/trino/catalog/trino-test.properties \
  -e TRINO_CONFIG=/home/trino/.trino/trino.properties \
  trinodb/trino:latest
```



The two volmes configure the connector for connectivity to a BYOC cluster.

`kafka.properties`
```ini
connector.name=kafka
kafka.nodes=seed-6234e08e.curl3eo533clusterID.byoc.prd.cloud.redpanda.com:9092
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



# Iceberg

`trino-test.properties`
```ini
connector.name=iceberg
iceberg.catalog.type=rest
iceberg.rest-catalog.uri=https://dbc-XYZPDQ-2e36.cloud.databricks.com/api/2.1/unity-catalog/iceberg-rest
iceberg.rest-catalog.warehouse=trino-test
iceberg.security=read_only
iceberg.rest-catalog.security=OAUTH2
iceberg.rest-catalog.oauth2.server-uri=https://dbc-XYZPDQ-2e36.cloud.databricks.com/oidc/v1/token
iceberg.rest-catalog.oauth2.scope=all-apis
iceberg.rest-catalog.oauth2.token=<Your personal acces token (PAT)>
iceberg.rest-catalog.vended-credentials-enabled=true
fs.native-s3.enabled=true
s3.region=us-east-2
```

To generate the personal access token, go to the Databricks console:
Your User Icon (upper right) >> Settings >> Developer >> Access Tokens (Manage) >> Generate New Token

Copy that token, you'll need it for `iceberg.rest-catalog.oauth2.token`





Generating an access token using a client id & secret.  You don't necessarily need this.

```bash
curl -s -X POST https://dbc-XYZPDQ.cloud.databricks.com/oidc/v1/token \
  -d "grant_type=client_credentials" \
  -d "scope=all-apis" \
  -d "client_id=<YOUR-CLIENT-ID>" \
  -d "client_secret=<your client secret>" \
  | jq -r .access_token
```
