# Trino & Redpanda


## Catalog creation/setup

### 1.  Create a new Catalog

From the databricks console, under Catlog (1), then under the (+) click "Create a catalog"

![databricks-catalog-create-1](https://github.com/user-attachments/assets/fb4d41c4-7a01-424e-8925-dbc23eb3c757)

In the dialog, give it a nice catalog name, and then uncheck the box for using the default storage location; we're going to create a new external storage location.  

>> why are other cloud providers not an option here?  Is this because our Databricks acct is set up on AWS?

![databricks-catalog-create-2](https://github.com/user-attachments/assets/010dc6c5-21b5-4fce-aef1-51286474c933)

### 2. Create a new External Location

Clicking on the Create a new external location link will bring up another screen, where you will choose the AWS Quickstart option.  

![databricks-catalog-create-3](https://github.com/user-attachments/assets/4d7f8170-ff6f-4c23-8ec8-7b27d531d33f)



### 3. Configure the New External Location

Databricks needs to know some info about the bucket we're using so that it can create the necessary permissions & other stuff in AWS to allow it all to work. 

![databricks-catalog-create-4](https://github.com/user-attachments/assets/f69a313c-2302-4407-b0b7-57198c0c90d3)


#### Finding your Redpanda S3 bucket

Databricks needs to know the name of our bucket, which is the bucket that Redpanda has already created.  From the Redpanda BYOC console, you'll need to find your cluster ID.  The bucket name will be `redpanda-cloud-storage-<Redpanda Cluster ID>`  Paste that into the box back in Databricks.  Note that the box has the `s3://bucket_name` prompt but you actually only want the bucket name, not the s3 prefix.  Then you'll click the Generate new token, which will create a token you will need to copy for the next step.   

Finally, click Launch in Quickstart.  This will bring up the AWS Console.

![databricks-catalog-create-5](https://github.com/user-attachments/assets/2222a969-43d0-4412-a54d-789098890229)


### 4. 


## Spin up Trino with some connectors

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

This properties file is only nessary if you want to set your default catalog/schema when the trino repl opens up.  It seems to be challenging to change this from within trino once it is set, so you may not want to actually do this.  YMMV.

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

The name of this file defines the name of the catalog within Trino.   You can call it whatever you want, but it probably makes sense to align it with your actual catalog name, unless you hate your sanity.  On the other hand, if you have special characters in the catalog name, you'll hae to wrap it in quotes in all your Trino queries.  Note that it seems to force everything to lower case, so a mixed case filename will cause you real problems.

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
iceberg.rest-catalog.oauth2.token=<Your personal access token (PAT)>
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
