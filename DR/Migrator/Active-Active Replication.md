**NOTE** much of this has been handled in Migrator V2, including loop detection via provenance headers

# Active-Active DR with Loop Detection

We don't actully do active-active replication.  Instead we do a pair of one-way replications, where we filter out things that have already been replicated.   There are 2 basic ways to do this:

* Same topic names on both clusters with loop detection to prevent infinite replication.
* Namespaced topic names where each cluster has its topic names prefixed.

In either case, the general idea is that only self-sourced topics are replicated.   Messages are either tagged with their provenance in the message header or "provenanced" by virtue of the topic prefix.


## Loop Detection with Provenance Headers

Messages are consumed from cluster A and in the pipeline processor the metadata is inspected.  If the metadata has a key named `origin` then it will be deleted from the pipeline, since the existence of that key indicates that it was published to this cluster via replication.  If that header key is missing, that indicates it was sourced through a traditional producer.   On the other cluster, a similar pipeline would exist that does the same check.  The net result is that Each cluster will be _near_-copies of one another.   The only difference being that messages on one side will consist of a set of messages witout any provenance header (that is, sourced on this cluster) and then some with a provenance header (that is, sourced via replication pipeline).   Then on the other cluster, the messages will be exactly inverted in terms of provenance/no provenance.

Here we are checking for existence of the metadata key, but another option would be to tag the messages with the actual cluster ID, and then check for that key/value pair specifically.    

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
        password: REDACTED
    topics:
      - provenance
    consumer_group: cg_A2B
    start_from_oldest: true

pipeline:
  processors:
    - mapping: |
        root = if metadata("origin") != null { deleted() }        
    - mapping: |
        meta origin = "cluster-a"

output:
  redpanda_migrator:
    seed_brokers:
      - d25sc344nva65l4a41tg.any.us-east-1.mpx.prd.cloud.redpanda.com:9092
    tls:
      enabled: true
    sasl:
      - mechanism: SCRAM-SHA-256
        username: cnelson
        password: REDACTED
    topic: provenance
    metadata:
      include_prefixes: [ "origin" ]
```


### Known Gotchas

#### Metadata <-> Headers

Redpanda Migrator uses the kafka_franz input/output under the covers, and its default behavior is to push ALL metadata as headers when the message is produced.   It seems that migrator does not carry this behavior forward, so we need to explcitly include the `origin` metadata on the output to write it as part of the header.   However, this likely means that any other metadata is not carried through to the headers.   This is most likely a bug.


#### Failing Back/Forward

* Failing backward is hard.
  * (why?)
* Failing forward involves creating a new empty cluster and then re-replicating from the remaining cluster to seed the new cluster.   This would require an additional pipeline that only runs while seeding, and stops once the recovery is complete.   The pipeline would need to copy ALL messages, and would need to strip the provenance header from messages that originated on the failed cluster, and then add the provenance header to the messages that originated on the remaining cluster.  This will result in both clusters looking exactly as they did prior to the outage.
  * Care needs to be taken here, because if you start producing to the recovered cluster before it is fully caught back up, messages will be out of order on the recoverd cluster.

#### Message timestamps are not preserved

Since migrator is simply re-publishing the messages, they will get a new timestamp when they are re-seeded on the replacement cluster.    Maybe this is expected?   The timestamps aren't preserved on migration in the first place, but in the steady state they will be very close.   On re-seed they will be wildly different, although order should still be preserved.


### Re-Seeding/Fail Forward

This hasn't been _completely_ thought through yet, but the general idea is thee treat the remaining cluster as the source of truth & use it to re-create the lost cluster as it was.   We do this by looking at the provenance header on the remaining cluster and "inverting" it-- if the provenance header is null, that means it originated on this cluster so we need to replicate to the replacement cluster with a provenance header indicating it came from the remaining cluster.  If the provenance header is not null, that means it came from the failed cluster, so we need to remove the provenance header when we write it to the replacement cluster.   This will push all messages back to the other cluster with the provenance headers as they were prior to the failure.

Prior to bringing up the new cluster, the existing replication pipeline should be halted (it will most likely need to be updated to point to the new cluster bootstrap URL).   Producers & consumers should still work off the remaining cluster until the re-seed is complete.   Then the clients that need to move back to the new cluster should be halted, then the re-seed pipeline should be restarted, then the normal replication pipeline should be restarted, then the clients can be restarted.

TODO:   think about what needs to happen to the migrator consumer groups in this scenario, since traffic will continue to be written to the remaining cluster but the messages will be replicated via a different consumer group.   Might need to set it to `latest` but this requires more thought and testing.

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
        password: REDACTED
    topics:
      - provenance
    consumer_group: cg_B2A_reseed
    start_from_oldest: true

pipeline:
  processors:
    - mapping: |
        meta origin = if metadata("origin") != null {
          deleted()
        } else {
          "cluster-b"
        }

output:
  redpanda_migrator:
    seed_brokers:
      - d03auajb92dfgde42s7g.any.us-east-1.mpx.prd.cloud.redpanda.com:9092
    tls:
      enabled: true
    sasl:
      - mechanism: SCRAM-SHA-256
        username: cnelson
        password: REDACTED
    topic: provenance
    metadata:
      include_prefixes: [ "origin" ]




