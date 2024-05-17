# Redpanda to Redpanda via Benthos

## Documentation

https://www.benthos.dev/docs/components/outputs/kafka_franz#tls


---

I used the quickstart docker to spin up Redpanda & Console, which puts everything into a Docker network called `redpanda-quickstart-one-broker_redpanda_network`


```
docker pull ghcr.io/benthosdev/benthos
```

```
docker run --rm -v ${PWD}/config.yaml:/benthos.yaml  --net=redpanda-quickstart-one-broker_redpanda_network ghcr.io/benthosdev/benthos
```




`config.yaml`

```
input:
  label: ""
  kafka:
    addresses: [redpanda-0:9092]
    topics: ["test_topic"]
    consumer_group: "benthos_cg_1"
    checkpoint_limit: 1024


output:
  label: ""
  kafka:
    addresses: [redpanda-0:9092]
    topic: "benthos_dest_prime"
    key: "bb"
```

Benthos will attempt to create the topics if they don't already exist.   Test it by publishing to the topic specified in the input section, and consume from the topic in tout output section.  It's that easy.

----

## How to configure for TLS

Minimal TLS setup for publishing/consuming from BYOC (or any TLS-enabled/SASL-SCRAM cluster).  Note that BYOC has auto-topic creation disabled so you'll have to create the topics up front.

Also used the `kafka_franz` output which has a slightly different construct for the brokers.


```
input:
  label: ""
  kafka:
    addresses: [redpanda-0:9092]
    topics: ["test_topic"]
    consumer_group: "benthos_cg_1"
    checkpoint_limit: 1024


output:
  label: ""
  kafka_franz:
    seed_brokers:
      - seed-c47ff96d.cnthrbjiuvqvkcfi4acg.byoc.prd.cloud.redpanda.com:9092
    topic: "benthos_dest_byoc"

    tls:
      enabled: true

    sasl:
      - mechanism: SCRAM-SHA-256
        username: benthos
        password: benthos
```

