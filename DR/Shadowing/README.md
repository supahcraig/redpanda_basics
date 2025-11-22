# Shadow Linking for DR on Self-Hosted

This writeup is barebones for now, ideally could be a 1-click deployment with some automation work.   

**NOTE:** this is not yet available for BYOC (as of Nov 21, 2025)

## High level steps

1.  Create 2 clusters
2.  Peer them
3.  Configure shadowing
4.  (optional) Configure shadowing in the other direction for "bi-directional" replication
5.  Prove it works

---

## Create Your Clusters

Perhaps the easiest thing to do is use OMB to spin up a cluster, and then create another OMB environment to be used as the shadow cluster.  The advantage of doing it this way is that you can immediately run load tests & benchmarks against either cluster.  If you don't want the workers, just set client=0.   

OMB repository:
https://github.com/redpanda-data/openmessaging-benchmark/tree/main/driver-redpanda

When you create the first cluster, leaving the peering components disabled in `terraform.tfvars`, which is the default behavior anyway.  When you create the 2nd cluster, you should be able to configure the peering based on the VPC ID & CIDR of the first cluster, but I spun it up without peering on either side.  Then I modified the first cluster's tfvars to allow for peering to the 2nd cluster and then re-applied the terraform on that side.  The peering automation does not modify the SG's to actually allow traffic between the VPCs.

### Security Group Rules

I added firewall rules to the security group attached to the brokers.  To side 1, I allowed all traffic from the CIDR range of the cluster on side 2.  On side 2, I added a similar rule allowing all traffic from the CIDR range of the cluster on side 1.   We could be much more secure with this, but I don't (yet) know what ports are required for shadowing to work.   Most likely it is 9092 & 9644.

---

## Configure Shadowing

On the _target_ cluster, you'll need to enable shadowing, which must be done via rpk.  This command is given to you in the Console under Shadow Links.  Shadow Linking runs as a PULL operation.  In other words you are setting up a cluster as a shadow _of some other cluster_.   It's easy to forget and think it is a push and that you are telling a cluster where it should shadow to, but this is wrongthink.

```bash
rpk cluster config set enable_shadow_linking true
```

Once you run it, the console page will turn into a button allowing you to further configure shadowing.  You can do a lot from the console "wizard," but not everything.   At the time of this writing, you cannot configure schema registry replication from the console, you must do it via rpk.

**NOTE:**  I have not set it up for TLS yet, as this doesn't yet work in BYOC and I have not taken the time to set up TLS on a SH cluster.   

---

### Configuring your Shadow Link without using the Console

You'll need to create a configuration file that rpk will use to upload, call it `shadow-link.yaml`

This is a somewhat barebones config that will bring over topics, consumer groups, and schema registry.   I have prefix filters for topics & consumers to only include things that begin with `clusterA`.  Anything not meeting that condition will not replicate.

The docs have much more detail around shadowing options:  https://docs.redpanda.com/current/manage/disaster-recovery/shadowing/setup/

Obviously you'll need to change the bootstrap servers to point to the _source_ cluster, since shadow linking runs on the target cluster and pulls from the source.   If you enable sasl, you would similarly use a sasl user on the _source_ cluster.

```bash
rpk shadow create --config-file shadow-link.yaml
```

```yaml
name: shadow_clusterA
client_options:
    bootstrap_servers:
        - 10.200.0.38:9092
        - 10.200.0.40:9092
        - 10.200.0.20:9092
    metadata_max_age_ms: 10000
    connection_timeout_ms: 1000
    retry_backoff_ms: 100
    fetch_wait_max_ms: 500
    fetch_min_bytes: 5242880
    fetch_max_bytes: 20971520
    fetch_partition_max_bytes: 1048576
topic_metadata_sync_options:
    auto_create_shadow_topic_filters:
        - pattern_type: PREFIX
          filter_type: INCLUDE
          name: clusterA
    synced_shadow_topic_properties:
        - max.compaction.lag.ms
        - message.timestamp.type
        - compression.type
        - retention.bytes
        - delete.retention.ms
        - cleanup.policy
        - replication.factor
        - max.message.bytes
        - min.compaction.lag.ms
        - retention.ms
consumer_offset_sync_options:
    group_filters:
        - pattern_type: PREFIX
          filter_type: INCLUDE
          name: clusterA
security_sync_options:
    acl_filters:
        - resource_filter:
            resource_type: ANY
            pattern_type: ANY
          access_filter:
            operation: ANY
            permission_type: ANY
schema_registry_sync_options:
    shadow_schema_registry_topic: {}
```

---

## Testing

Testing will be dependent on your topic filters, but it is quite simple.   Using the topic filters in the above config, try this:

### Create topics on Cluster A (the source)

```bash
rpk topic create clusterA.topic_to_replicate
rpk topic create do_not_replicate
```

If shadowing is working, you should see 2 topics on the source side (you should see this regardless!), and on the target side you should see ONE topic, `clusterA.topic_to_replicate`   No messages need to be produced to the topic for the topic itself to replicate.

### Produce messages to Cluster A (the source)

```bash
seq 1 5 | jq -R -c '{msg: .}' | rpk topic produce clusterA.topic_to_replicate
```

Produces this output, paying particular attention to the offset number.

```bash
Produced to partition 0 at offset 15 with timestamp 1763785802134.
Produced to partition 0 at offset 16 with timestamp 1763785802134.
Produced to partition 0 at offset 17 with timestamp 1763785802134.
Produced to partition 0 at offset 18 with timestamp 1763785802134.
Produced to partition 0 at offset 19 with timestamp 1763785802134.
```



### Consume messages from Cluster B (the target)

```bash
rpk topic consume clusterA.topic_to_replicate -g clusterB_cg
```

And you should see the same messages that were produced at the source, and the offsets should be identical.

```json
{
  "topic": "clusterA.topic_to_replicate",
  "value": "{\"msg\":\"1\"}",
  "timestamp": 1763785802134,
  "partition": 0,
  "offset": 15
}
{
  "topic": "clusterA.topic_to_replicate",
  "value": "{\"msg\":\"2\"}",
  "timestamp": 1763785802134,
  "partition": 0,
  "offset": 16
}
{
  "topic": "clusterA.topic_to_replicate",
  "value": "{\"msg\":\"3\"}",
  "timestamp": 1763785802134,
  "partition": 0,
  "offset": 17
}
{
  "topic": "clusterA.topic_to_replicate",
  "value": "{\"msg\":\"4\"}",
  "timestamp": 1763785802134,
  "partition": 0,
  "offset": 18
}
{
  "topic": "clusterA.topic_to_replicate",
  "value": "{\"msg\":\"5\"}",
  "timestamp": 1763785802134,
  "partition": 0,
  "offset": 19
}
```

### Consumer Group Replication

When we consumed the messages, we specified a consumer group with the `-g` flag.   Because that consumer group began with `clusterB` it was replicated to Cluster A.  You can verify this with rpk:

```bash
rpk consumer group list
```

Shows:

```bash
BROKER  GROUP              STATE
1       clusterB_cg        Empty
```

If you consume with a differently prefixed group, you'll find that it does not replicate over.


### rpk shadow commands (that aren't documented)

* `rpk shadow list`
* `rpk shadow describe shadow_clusterA -a`   (more options are available for sub-sections)
