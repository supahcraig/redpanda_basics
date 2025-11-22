**NOTE** some of this may be outdated with the introcuction of Migrator V2

# Redpanda Migrator


## Migrator (not the bundle)

This is almost working.   Replication from A to B works, although it didn't pick up existing messages.   Replciation from B to A didn't seem to apply the filter to prevent the loop.   

> there may be an issue with regexp's and comments on the same line.  Or mabye just regexps in general.


```yaml
input:
  redpanda_migrator:
    seed_brokers:
      - ${REDPANDA_BROKERS}
    topics:
      - clusterA.*
    regexp_topics: true
    consumer_group: A2B
    start_from_oldest: true
    tls:
      enabled: true
    sasl:
      - mechanism: SCRAM-SHA-256
        username: cnelson
        password: test



output:
  redpanda_migrator:
    seed_brokers:
      - "d03auajb92dfgde42s7g.any.us-east-1.mpx.prd.cloud.redpanda.com:9092"
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
      - clusterB.*
    regexp_topics: true
    consumer_group: B2A
    start_from_oldest: true
    tls:
      enabled: true
    sasl:
      - mechanism: SCRAM-SHA-256
        username: cnelson
        password: test



output:
  redpanda_migrator:
    seed_brokers:
      - "d25sc344nva65l4a41tg.any.us-east-1.mpx.prd.cloud.redpanda.com:9092"
    topic: ${! metadata("kafka_topic").or(throw("missing kafka_topic metadata")) }
    tls:
      enabled: true
    sasl:
      - mechanism: SCRAM-SHA-256
        username: cnelson
        password: test
```
