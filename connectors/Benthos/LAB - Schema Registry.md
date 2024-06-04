# Using the Schema Registry with Redpanda Connect (aka Benthos)

This is more or less taken from Ash Jeffs' video on the topic.   He spun up a whole set of containers, but I'm going to assume you already have Redpanda running somewhere.

## Flow description

This will take randomized input json messages, convert them to avro using the schema registry, and then publish them to Redpanda.   They will then be consumed & decoded and printed to stdout.   Once that is running, we will modify the input json & schema in various ways to see how it all works.

1.  Create inbound pipeline (see errors)
2.  Create avro schema
3.  Add a field to the generated data (see errors)
4.  Update schema
5.  Remove field from generated data (see errors)
6.  Update schema



## Inbound Pipeline


### Configuration

This will generate random json input, encode it into avro using the schema registry, and will trash any messages that have a conversion error.  Finally it will produce the avro-encoded messages to Redpanda.

```yaml
input:
  generate:
    interval: 1s
    mapping: |
      root.ID = uuid_v4()
      root.Name = ["frosty", "spot", "oodles"].index(random_int() % 3)
      root.Gooeyness = (random_int() % 100) / 100

pipeline:
  processors:
    - schema_registry_encode:
        url: http://redpanda-0:8081
        subject: redpanda_connect_example
        refresh_period: 15s

    - catch:
      - log:
          level: ERROR
          message: ${! error() }
      - bloblang: root = deleted()

output:
  kafka:
    addresses: [localhost:19092]
    topic: rp_connect_topic

```

### Spin up Redpanda Connect for the inbound pipeline

```console
rpk connect run -w inbound.yaml
```


This will throw errors because the schema registry does not yet exist.

```logtalk
ERRO schema subject 'redpanda_connect_example' not found by registry  @service=benthos label="" path=root.pipeline.processors.1.catch.0
ERRO schema subject 'redpanda_connect_example' not found by registry  @service=benthos label="" path=root.pipeline.processors.0
ERRO schema subject 'redpanda_connect_example' not found by registry  @service=benthos label="" path=root.pipeline.processors.1.catch.0
ERRO schema subject 'redpanda_connect_example' not found by registry  @service=benthos label="" path=root.pipeline.processors.0
ERRO schema subject 'redpanda_connect_example' not found by registry  @service=benthos label="" path=root.pipeline.processors.1.catch.0
ERRO schema subject 'redpanda_connect_example' not found by registry  @service=benthos label="" path=root.pipeline.processors.0
ERRO schema subject 'redpanda_connect_example' not found by registry  @service=benthos label="" path=root.pipeline.processors.1.catch.0
```

---

## Outbound Pipeline


```yaml
input:
  kafka:
    addresses: [redpanda-0:9092]
    consumer_group: rp_connect_cg
    topics: [rp_connect_topic]

pipeline:
  processors:
    - schema_registry_decode:
        url: http://redpanda-0:8081

    - catch:
      - log:
          level: ERROR
          message: ${! error()}
      - bloblang: root = deleted()

output:
  stdout: {}
```

### Spin up Redpanda Connect for the outbound pipeline

```console
rpk connect run -w outbound.yaml
```

This will throw errors because the schema registry does not yet exist.



---

## Avro schema

### Schema Definition

```json
{
  "type": "record",
  "name": "redpanda_connect_example",
  "fields": [
    {"name": "ID", "type": "string"},
    {"name": "Name", "type": "string"},
    {"name": "Gooeyness", "type": "double"}
  ]
}
```

### Deploy Schema

```console
#!/bin/bash
curl -s \
  -X POST "http://localhost:18081/subjects/redpanda_connect_example/versions" \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  -d "$(cat blob_schema.json | jq '{schema: . | tostring}')" \
  | jq
```

Output:

```json
% ./insert_schema.sh
{
  "id": 1
}
```

The pair of Redpanda Connect processes should pick up the new schema quickly and cease throwing errors.  You can also see messages being written by either consuming the topic or using the Redpanda Console.



---


# Make it break! 

## Add a field to inbound data

Modify the inbound.yaml to include this additional field which isn't part of our schema.  Because we invoked redpanda connect using the `-w` flag, it will _watch_ for changes to the config and restart the pipeline whenever it sees a new config.

`root.Bouncing = random_int() % 2 == 0`


should throw errors again

```logtalk
ERRO cannot decode textual record "redpanda_connect_example": cannot decode textual map: cannot determine codec: "Bouncing"  @service=benthos label="" path=root.pipeline.processors.1.catch.0
ERRO cannot decode textual record "redpanda_connect_example": cannot decode textual map: cannot determine codec: "Bouncing"  @service=benthos label="" path=root.pipeline.processors.1.catch.0
ERRO cannot decode textual record "redpanda_connect_example": cannot decode textual map: cannot determine codec: "Bouncing"  @service=benthos label="" path=root.pipeline.processors.1.catch.0
ERRO cannot decode textual record "redpanda_connect_example": cannot decode textual map: cannot determine codec: "Bouncing"  @service=benthos label="" path=root.pipeline.processors.1.catch.0
```

## Modify the schema

Adding this line to our schema will allow our generated json to adhere to the latest version of the schema, which will allow our pipeline to once again work.

`{"name": "Bouncing", "type": "boolean", "default": true}` 

```json
{
  "type": "record",
  "name": "redpanda_connect_example",
  "fields": [
    {"name": "ID", "type": "string"},
    {"name": "Name", "type": "string"},
    {"name": "Gooeyness", "type": "double"},
    {"name": "Bouncing", "type": "boolean", "default": true}
  ]
}
```

```console
./insert_schema.sh
```

Output:

```json
% ./insert_schema.sh
{
  "id": 2
}
```

And you should start to see new records in Console with the new `Bouncing` field added.


## Remove a field

Comment out the `root.Gooeyness` line from `inbound.yaml` to exclude it from the generated json.   This will no longer adhere to the schema since `Gooeyness` is a required field, so the pipeline will immediately start throwing errors.

```logtalk
ERRO cannot decode textual record "redpanda_connect_example": only found 3 of 4 fields  @service=benthos label="" path=root.pipeline.processors.1.catch.0
ERRO cannot decode textual record "redpanda_connect_example": only found 3 of 4 fields  @service=benthos label="" path=root.pipeline.processors.1.catch.0
ERRO cannot decode textual record "redpanda_connect_example": only found 3 of 4 fields  @service=benthos label="" path=root.pipeline.processors.1.catch.0
ERRO cannot decode textual record "redpanda_connect_example": only found 3 of 4 fields  @service=benthos label="" path=root.pipeline.processors.1.catch.0
```

## Modify the schema again

Adding a default value to the `Gooeyness` field will allow the inbound data to conform to the newest schema and data can beging flowing once again.

`{"name": "Gooeyness", "type": "double", "default": -1}`

```json
{
  "type": "record",
  "name": "redpanda_connect_example",
  "fields": [
    {"name": "ID", "type": "string"},
    {"name": "Name", "type": "string"},
    {"name": "Gooeyness", "type": "double", "default": -1},
    {"name": "Bouncing", "type": "boolean", "default": true}
  ]
}
```

```console
./insert_schema.sh
```

Output:

```json
% ./insert_schema.sh
{
  "id": 3
}
```

And you should start to see new records in Console with the new `Bouncing` field added.



