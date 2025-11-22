# Shadow Linking for DR

This writeup is barebones for now, ideally could be a 1-click deployment with some ansible work.   

## High level steps

1.  Create 2 clusters
2.  Peer them
3.  Configure shadowing
4.  (optional) Configure shadowing in the other direction for "bi-directional" replication

---

## Create Your Clusters

Perhaps the easiest thing to do is use OMB to spin up a cluster, and then create another OMB environment to be used as the shadow cluster.  The advantage of doing it this way is that you can immediately run load tests & benchmarks against either cluster.

When you create the first cluster, leaving the peering components disabled in `terraform.tfvars`, which is the default behavior anyway.  When you create the 2nd cluster, you _should_ be able to configure the peering based on the VPC ID & CIDR of the first cluster, but I spun it up without peering as well.  Then I modified the first clusters tfvars to allow for peering to the 2nd cluster and then re-applied the terraform on that side.

## Configure Shadowing

On the _source_ cluster, you need to enable shadowing, and this must be done via rpk.  This command is given to you in the Console under Shadow Links.   

```bash
rpk cluster config set enable_shadow_linking true
```

Once you run it, this page will turn into a button allowing you to further configure shadowing. 

**NOTE:**  At the time of this writing, you cannot configure schema registry replication from the console, you must do it via rpk.

The console is easy to follow, although I have not set it up for TLS yet, as this doesn't yet work in BYOC and I have not bothered to set up TLS on a SH cluster.   

### Configuring your Shadow Link without using the Console

You'll need to create a configuration file that rpk will use to upload, call it `shadow-link.yaml`

This is a somewhat barebones config that will bring over topics, consumer groups, and schema registry.   I have prefix filters for topics & consumers to only include things that begin with `clusterA`.  Anything not meeting that condition will not replicate.

The docs have much more detail around shadowing options:  https://docs.redpanda.com/current/manage/disaster-recovery/shadowing/setup/

Obviously you'll need to change the bootstrap servers to point to the target cluster.

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




### rpk shadow commands (that aren't documented)

* `rpk shadow list`
* `rpk shadow describe shadow_clusterA -a`   (more options are available for sub-sections)
