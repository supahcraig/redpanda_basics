This is a work in progress.

# Replicating BYOC to BYOC using MM2


You first need to have MM2 enabled for your cluster.  This is most easily handled by a request to #help-cloud.



## Target Cluster Setup


## Mirror Source Connector

Create a new connector on the Target cluster using mirror-source-connector (`Import from Kafka cluster topics`)

| Setting | Likely Value | Description |
|---|---|---|
| Regexes of topics to import | `.*` | This will pull all topics from the source cluster |
| Security | SASL_SSL | This is how you'll auth against BYOC |
| SASL user/pass | user/pass | Your sasl user/pass from the source cluster |
| SSL certs | _leave blank_ | you won't need these for BYOC replication |
| Topics to exclude | `clusterA\.*,` + the pre-populated list | more explanation below |
| Source cluster alias | "source" or "clusterA" | this will be what is used as a namespace prefix to all the replicated topic names |
| Replication policy class | `DefaultReplicationPolicy` | Default will use the source cluster alias; Identity will leave the topic names as-is |
| Auto offset reset | earliest | |

Most everythign else can be left with the default options.

### Topics to Exclude

Much to unwrap here, but excluding topics that get the source cluster alias will prevent a recursive thing happening where replicated topics themselves get replicated.  Unclear to what extent this is an issue on one-way replication, but the heartbeat connector plays a role here somehow.  The pre-populate list includes all the "underscore" system topics.


Here is a working configuration.  Note that the SASL password is needed when you create the config, but is removed from the json configuration view.  Also note that the replication policy class isn't present in the config (at least not if DefaultReplicationPolicy is what is in use).

```json
{
    "connector.class": "org.apache.kafka.connect.mirror.MirrorSourceConnector",
    "consumer.auto.offset.reset": "earliest",
    "name": "mirror-source-connector-9anh",
    "offset-syncs.topic.replication.factor": "-1",
    "replication.factor": "-1",
    "replication.policy.class": "org.apache.kafka.connect.mirror.DefaultReplicationPolicy",
    "source.cluster.alias": "clusterA",
    "source.cluster.bootstrap.servers": "seed-6234e08e.curl3eo533cmsnt23dv0.byoc.prd.cloud.redpanda.com:9092",
    "source.cluster.sasl.jaas.config": "org.apache.kafka.common.security.scram.ScramLoginModule required username='cnelson' password='${secretsManager:mirror-source-connector-9anh-a3hu:source.cluster.sasl.password}';",
    "source.cluster.sasl.mechanism": "SCRAM-SHA-256",
    "source.cluster.sasl.password": "${secretsManager:mirror-source-connector-9anh-a3hu:source.cluster.sasl.password}",
    "source.cluster.sasl.username": "cnelson",
    "source.cluster.security.protocol": "SASL_SSL",
    "sync.topic.acls.enabled": "true",
    "sync.topic.configs.enabled": "true",
    "topics.exclude": "clusterA\\.*,.*[\\-\\.]internal,.*\\.replica,__consumer_offsets,_redpanda.audit_log,_redpanda_e2e_probe,__redpanda.*,_internal_connectors.*,_schemas"
}
```

### Troubleshooting

If you have iceberg topics on the source but the target is not configured for iceberg, MM2 will not be able to re-create the topic and _no replication will happen_.   You can either enable iceberg on the target, or you can manually create the topic (with the source cluster alias prefix).   In my case, manually createing the topic immediately allowed the replication to start.




## Mirror Checkpoint Connector


```json
{
    "checkpoints.topic.replication.factor": "-1",
    "connector.class": "org.apache.kafka.connect.mirror.MirrorCheckpointConnector",
    "name": "mirror-checkpoint-connector-4vgk",
    "refresh.groups.interval.seconds": "60",
    "replication.policy.class": "org.apache.kafka.connect.mirror.IdentityReplicationPolicy",
    "source.cluster.alias": "source",
    "source.cluster.bootstrap.servers": "seed-6234e08e.curl3eo533cmsnt23dv0.byoc.prd.cloud.redpanda.com:9092",
    "source.cluster.sasl.jaas.config": "org.apache.kafka.common.security.scram.ScramLoginModule required username='cnelson' password='${secretsManager:mirror-checkpoint-connector-4vgk-vdsw:source.cluster.sasl.password}';",
    "source.cluster.sasl.mechanism": "SCRAM-SHA-256",
    "source.cluster.sasl.password": "${secretsManager:mirror-checkpoint-connector-4vgk-vdsw:source.cluster.sasl.password}",
    "source.cluster.sasl.username": "cnelson",
    "source.cluster.security.protocol": "SASL_SSL",
    "sync.group.offsets.enabled": "true"
}
```


## Mirror Heartbeat Connector

This one is a bit of an enigma, since it doesn't mention the source OR the target cluster.   Since it's running in BYOC I guess it can probably infer the target cluster, which is consistent with how the other 2 connectors are configured.  But it is not at all clear how this connector knows what the source is, unless Mirror Maker is somehow inspecting the other connectors.

```json
{
    "connector.class": "org.apache.kafka.connect.mirror.MirrorHeartbeatConnector",
    "heartbeats.topic.replication.factor": "-1",
    "name": "mirror-heartbeat-connector-fwne",
    "source.cluster.alias": "source"
}
```
