# Migrator V2 Demo

## Basic components

* Serverless cluster
  * RPCN pipeline genrating data
* BYOC cluster
  * migrator pipeline pulling from serverless

## Data Generator RPCN config


## (minimal) Migrator V2 pipeline config


```yaml
input:
  redpanda_migrator:
    seed_brokers:
       - ${REDPANDA_BROKERS}
    tls: 
      enabled: true
    sasl:
      - mechanism: SCRAM-SHA-256
        username: cnelson
        password: cnelson
    topics: 
      - topicA
      - topicB
    consumer_group: migrator_consumer_group
    start_offset: earliest
    schema_registry:
      url: "https://schema-registry-2eb3ee18.d41p9tuc4cape6v42hgg.byoc.prd.cloud.redpanda.com:30081"
      basic_auth:
        enabled: true
        username: cnelson
        password: cnelson

output:
  redpanda_migrator:
    seed_brokers:
      - seed-1f06b5ea.d41p9tuc4cape6v42hgg.byoc.prd.cloud.redpanda.com:9092
    tls:
      enabled: true
    sasl:
      - mechanism: SCRAM-SHA-256
        username: cnelson
        password: cnelson
    allow_auto_topic_creation: true
    topic: migrator.${! @kafka_topic }
    consumer_groups:
      enabled: true
      fetch_timeout: 10s
      include:
        - migrator_consumer_group
      interval: 5s
      only_empty: false
    metadata_max_age: 5s
    schema_registry:
      enabled: true
      url: https://schema-registry-2eb3ee18.d41p9tuc4cape6v42hgg.byoc.prd.cloud.redpanda.com:30081
      basic_auth:
        enabled: true
        username: cnelson
        password: cnelson

#logger:
#  level: DEBUG
