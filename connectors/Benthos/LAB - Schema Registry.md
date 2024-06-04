# Using the Schema Registry with Redpanda Connect (aka Benthos)

This is more or less taken from Ash Jeffs' video on the topic.   He spun up a whole set of containers, but I'm going to assume you already have Redpanda running somewhere.

## Flow description

This will take randomized input json messages, convert them to avro using the schema registry, and then publish them to Redpanda.   They will then be consumed & decoded and printed to stdout.   Once that is running, we will modify the input json & schema in various ways to see how it all works.


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
benthos -w -c inbound.yaml
```

TODO:  change `benthos` to corresponding `rpk` CLI syntax

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
benthos -w -c outbound.yaml
```

TODO:  change `benthos` to corresponding `rpk` CLI syntax

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

The pair of Redpanda Connect processes should pick up the new schema quickly and cease throwing errors.




