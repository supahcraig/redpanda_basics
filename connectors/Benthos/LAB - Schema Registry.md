# Using the Schema Registry with Redpanda Connect (aka Benthos)

This is more or less taken from Ash Jeffs' video on the topic.   He spun up a whole set of containers, but I'm going to assume you already have Redpanda running somewhere.

## Flow description

This will take randomized input json messages, convert them to avro using the schema registry, and then publish them to Redpanda.   They will then be consumed & decoded and printed to stdout.   Once that is running, we will modify the input json & schema in various ways to see how it all works.


## Inbound Pipeline

```yaml



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
    addresses: [redpanda-0:9092]
    topic: rp_connect_topic

```
