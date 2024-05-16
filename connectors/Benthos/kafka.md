# Redpanda to Redpanda via Benthos

I used the quickstart docker to spin up Redpanda & Console, which puts everything into a Docker network called `edpanda-quickstart-one-broker_redpanda_network`


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

This will create the topics if they don't already exist.   Test it by publishing to the topic specified in the input section, and consume from the topic in tout output section.  It's that easy.

----

## How to configure for TLS

??
