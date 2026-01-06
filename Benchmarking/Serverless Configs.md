# Serverless benchmarking

This is based on inputs I got from the serverless team.


## OMB driver config

```yaml
name: Serverless Driver
driverClass: io.openmessaging.benchmark.driver.redpanda.RedpandaBenchmarkDriver
driverClass: io.openmessaging.benchmark.driver.kafka.KafkaBenchmarkDriver

# Kafka client-specific configuration
replicationFactor: 3
reset: true

# Configuration (flush.messages; flush.ms) enabled only for tests that fsync every message
topicConfig: |
commonConfig: |
  bootstrap.servers=d25sc344nva65l4a41tg.any.us-east-1.mpx.prd.cloud.redpanda.com:9092
  sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username='cnelson' password='cnelson';
  security.protocol=SASL_SSL
  sasl.mechanism=SCRAM-SHA-256
  request.timeout.ms=400000
producerConfig: |
  acks=all
  linger.ms=1
  #batch.size=32768
  #compression.type=lz4
  request.timeout.ms=400000
  #delivery.timeout.ms=120000
  #retries=2147483647
  #retry.backoff.ms=50
  #connections.max.idle.ms=300000
  max.in.flight.requests.per.connection=5
  enable.idempotence=true
consumerConfig: |
  group.id=benchGroup1001
  auto.offset.reset=earliest
  enable.auto.commit=false
  #auto.commit.interval.ms=1000
  #max.partition.fetch.bytes=1048576
  #fetch.min.bytes=1
  #fetch.max.wait.ms=1
  #max.poll.records=200
  #partition.assignment.strategy=org.apache.kafka.clients.consumer.CooperativeStickyAssignor
```

## Serverless Workload

```yaml
name: ServerlessTestWorkload

topics: 1
partitionsPerTopic: 30

messageSize: 1024
payloadFile: "payload/payload-1Kb.data"

subscriptionsPerTopic: 3
consumerPerSubscription: 4

producersPerTopic: 4
producerRate: 19531

consumerBacklogSizeGB: 0
warmupDurationMinutes: 1
testDurationMinutes: 1
```
