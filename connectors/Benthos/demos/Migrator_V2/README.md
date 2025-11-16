# Migrator V2 Demo

## Basic components

* Serverless cluster
  * RPCN pipeline genrating data
* BYOC cluster
  * migrator pipeline pulling from serverless

## Data Generator RPCN config

You'll need a SASL user/pass with ACLs, and you'll need to pre-create the topics the generator will write into.

```yaml
input:
  generate:
    interval: 1s
    mapping: |
      root.ID = uuid_v4()
      root.Name = ["frosty", "spot", "oodles"].index(random_int() % 3)
      root.Gooeyness = (random_int() % 5)


output:
  kafka_franz:
    seed_brokers:
        - ${REDPANDA_BROKERS}
    topic: '${! json("Name")}'
    key: ${! this.ID }
    partitioner: murmur2_hash

    tls:
      enabled: true

    sasl:
      - mechanism: SCRAM-SHA-256
        username: serverless_user
        password: ${secrets.SERVERLESS_USER_PASS}

```

## (minimal) Migrator V2 pipeline config


```yaml
input:
  redpanda_migrator:
    seed_brokers:
       - cu38sb80u72l8kq21rf0.any.us-east-1.mpx.prd.cloud.redpanda.com:9092
    tls: 
      enabled: true
    sasl:
      - mechanism: SCRAM-SHA-256
        username: serverless_user
        password: serverless_user
    topics: 
      - frosty
      - oodles
      - spot
    consumer_group: migrator_consumer_group
    start_offset: earliest


output:
  redpanda_migrator:
    seed_brokers:
      - ${REDPANDA_BROKERS}
    tls:
      enabled: true
    sasl:
      - mechanism: SCRAM-SHA-256
        username: migrator_user
        password: migrator_user
    allow_auto_topic_creation: true
    # topic: migrator.${! @kafka_topic }. #requires 4.69.0
    consumer_groups:
      enabled: true
      fetch_timeout: 10s
      include:
        - migrator_consumer_group
      interval: 5s
      only_empty: false
    metadata_max_age: 5s

#logger:
#  level: DEBUG
```
