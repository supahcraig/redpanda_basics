# Repdanda Connect Replicator

Going from a BYOC cluster to another (different) BYOC cluster.

## build from the branch

This will check out the branch that has replicator in it, and then run the build (need to have golang installed)

```
git clone https://github.com/redpanda-data/connect.git
cd connect
git fetch origin pull/2789/head:mihaitodor-add-replicator-components`
git checkout mihaitodor-add-replicator-components
make
cd target/bin
```

The `redpanda-connect` binary is in the `target/bin` folder.


## Source Cluster

you'll need to create a handful of topics:

```bash
rpk topic create frosty-0
rpk topic create frosty-1
rpk topic create spot-0
rpk topic create spot-1
rpk topic create oodles-0
rpk topic create oodles-1
```


Then this pipeline configuration to generate data that will be replicated.

```yaml
input:
  generate:
    interval: 1s
    mapping: |
      root.ID = uuid_v4()
      root.Name = ["frosty", "spot", "oodles"].index(random_int() % 3)
      root.Gooeyness = (random_int() % 2)

output:
  kafka_franz:
    seed_brokers:
      -  "seed-a4c56bad.cqvdga17c9350kd7o9f0.byoc.prd.cloud.redpanda.com:9092"
    topic: '${! json("Name")}-${! json("Gooeyness")}'

    tls:
      enabled: true

    sasl:
      - mechanism: SCRAM-SHA-256
        username: test-user
        password: test-pass
```

Run the pipeline, and let it keep running to generate data in those topics.

`rpk connect run -w datagen.yaml`



## Target Cluster

This configuration will read off the source cluster and replicate topics & messages to the target cluster.

```yaml
input:
  redpanda_replicator:
    seed_brokers: [ "seed-a4c56bad.cqvdga17c9350kd7o9f0.byoc.prd.cloud.redpanda.com:9092" ]
    topics:
      - '^[^_]' # Skip internal topics which start with `_`
    regexp_topics: true
    consumer_group: ""
    start_from_oldest: true

    tls:
      enabled: true

    sasl:
      - mechanism: SCRAM-SHA-256
        username: test-user
        password: test-pass


output:
  redpanda_replicator:
    seed_brokers: [ "seed-c5e60d9e.cqvrp52ao90phrot6bag.byoc.prd.cloud.redpanda.com:9092" ]
    topic: ${! metadata("kafka_topic").or(throw("missing kafka_topic metadata")) }
    key: ${! metadata("kafka_key") }
    partitioner: manual
    partition: ${! metadata("kafka_partition").or(throw("missing kafka_partition metadata")) }
    timestamp: ${! metadata("kafka_timestamp_unix").or(timestamp_unix()) }
    max_in_flight: 1

    tls:
      enabled: true

    sasl:
      - mechanism: SCRAM-SHA-256
        username: test-user
        password: test-pass
```

Run this pipeline while the data generation pipeline is also running.

`redpanda-connect run replicator.yaml`


Profit.
