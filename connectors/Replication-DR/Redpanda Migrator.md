# Redpanda Migrator


## Migrator (not the bundle)

This is almost working.   Replication from A to B works, although it didn't pick up existing messages.   Replciation from B to A didn't seem to apply the filter to prevent the loop.

```yaml
input:
  redpanda_migrator:
    seed_brokers:
      - ${REDPANDA_BROKERS}
    topics:
      - .*   # Include all topics
    regexp_topics: true
    consumer_group: A2B
    start_from_oldest: true
    tls:
      enabled: true
    sasl:
      - mechanism: SCRAM-SHA-256
        username: cnelson
        password: test

pipeline:
  processors:
    - mapping: |
        root = if @kafka_topic.has_prefix("bar.") { deleted() }

output:
  redpanda_migrator:
    seed_brokers:
      - "d25sc344nva65l4a41tg.any.us-east-1.mpx.prd.cloud.redpanda.com:9092"
    topic_prefix: "foo."
    topic: ${! metadata("kafka_topic").or(throw("missing kafka_topic metadata")) }
    tls:
      enabled: true
    sasl:
      - mechanism: SCRAM-SHA-256
        username: cnelson
        password: test
```

And then the reverse direction replication:

```yaml
input:
  redpanda_migrator:
    seed_brokers:
      - ${REDPANDA_BROKERS}
    topics:
      - .*   # Include all topics
    regexp_topics: true
    consumer_group: A2B
    start_from_oldest: true
    tls:
      enabled: true
    sasl:
      - mechanism: SCRAM-SHA-256
        username: cnelson
        password: test

pipeline:
  processors:
    - mapping: |
        root = if @kafka_topic.has_prefix("foo.") { deleted() }

output:
  redpanda_migrator:
    seed_brokers:
      - "d03auajb92dfgde42s7g.any.us-east-1.mpx.prd.cloud.redpanda.com:9092"
    topic_prefix: "bar."
    topic: ${! metadata("kafka_topic").or(throw("missing kafka_topic metadata")) }
    tls:
      enabled: true
    sasl:
      - mechanism: SCRAM-SHA-256
        username: cnelson
        password: test
```
