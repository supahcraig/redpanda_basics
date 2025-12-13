# Setting up a Shadow Link via RPK

You will need a recent version of rpk, this rev or later:

`rpk version (Redpanda CLI): v25.3.2 (rev 5126a59180)`


## Generate a shadow config

Use this if your source cluster is a SH redpanda or some other flavor of Kafka (OSS Kafka, MSK, Confluent, etc).

```bash
rpk shadow config generate -o shadow-config.yaml
```

which will generate a boilerplate shadow config you can edit. 

* `bootstrap_servers` will be the boostrap urls of your source cluster, which are optional (but not mutually exclusive)
* `source_cluster_id` will be the Redpanda ID if you have a cloud cluster.   You can use this in conjuction with bootstrap servers, if they don't match it will fail on create
* `tls_setting` for BYOC you just need it to be enabled; you don't need the tls file setting sectin.
* 

```yaml
name: sample-shadow-link
client_options:
  bootstrap_servers:
  - localhost:9092
  - localhost:19092
  source_cluster_id: optional-source-cluster-id
  tls_settings:
    enabled: true
    tls_file_settings:
      ca_path: /path/to/ca.crt
      key_path: /path/to/optional/client.key
      cert_path: /path/to/optional/client.crt
  authentication_configuration:
    scram_configuration:
      username: username
      password: password
      scram_mechanism: SCRAM-SHA-256
  metadata_max_age_ms: 10000
  connection_timeout_ms: 1000
  retry_backoff_ms: 100
  fetch_wait_max_ms: 100
  fetch_min_bytes: 100
  fetch_max_bytes: 1048576
  fetch_partition_max_bytes: 1048576
topic_metadata_sync_options:
  interval: 30s
  auto_create_shadow_topic_filters:
  - pattern_type: LITERAL
    filter_type: INCLUDE
    name: '*'
  - pattern_type: PREFIX
    filter_type: EXCLUDE
    name: foo-
  synced_shadow_topic_properties:
  - retention.ms
  - segment.ms
  exclude_default: true
  start_at_earliest: {}
consumer_offset_sync_options:
  interval: 30s
  group_filters:
  - pattern_type: LITERAL
    filter_type: INCLUDE
    name: '*'
security_sync_options:
  interval: 30s
  acl_filters:
  - resource_filter:
      resource_type: TOPIC
      pattern_type: PREFIXED
      name: test-
    access_filter:
      principal: User:admin
      operation: ANY
      permission_type: ALLOW
      host: '*'
schema_registry_sync_options:
  shadow_schema_registry_topic: {}
```

### Common config settings




## BYOC Shadow

You can use the `--for-cloud` flag to gnerate a BYOC-based config with your info injected into the config

```bash
rpk shadow config generate --for-cloud -o shadow-config-cloud.yaml
```

And then inject the relevant values:

* `name` - must use lowercase letters, numbers, and dashes.  No underscores.
* `source_redpanda_id` - this is the cluster ID of your SOURCE cluster
* `shadow_cluster_id` - this is the cluster ID of your SHADOW cluster (aka the target)
* remove the tls pem settings unless you happen to need them
* `scram_configuration`
  * `username` is the username of your sasl user _on the source cluster_
  * `password` is slightly confusing.   It actually needs a secret name, not an actual scram password.   The secret must exist on the SHADOW cluster, and the value of the secret is the password of your sasl user _on the source cluster_
* Then set whichever filters you would like for topics & consumer groups
* The existence of the 

```yaml
name: sample-shadow-link
cloud_options:
  source_redpanda_id: 
  shadow_redpanda_id: 
client_options:
  tls_settings:
    enabled: true
    tls_pem_settings:
      ca: |-
        -----BEGIN CERTIFICATE-----
        ...
        -----END CERTIFICATE-----
      key: ${secrets.KEY_FROM_SHADOW_CLUSTER_SECRET_STORE}
      cert: |-
        -----BEGIN CERTIFICATE-----
        ...
        -----END CERTIFICATE-----
  authentication_configuration:
    scram_configuration:
      username: username
      password: ${secrets.PASSWORD_FROM_SHADOW_CLUSTER_SECRET_STORE}
      scram_mechanism: SCRAM-SHA-256
  metadata_max_age_ms: 10000
  connection_timeout_ms: 1000
  retry_backoff_ms: 100
  fetch_wait_max_ms: 100
  fetch_min_bytes: 100
  fetch_max_bytes: 1048576
  fetch_partition_max_bytes: 1048576
topic_metadata_sync_options:
  interval: 30s
  auto_create_shadow_topic_filters:
  - pattern_type: LITERAL
    filter_type: INCLUDE
    name: '*'
  - pattern_type: PREFIX
    filter_type: EXCLUDE
    name: foo-
  synced_shadow_topic_properties:
  - retention.ms
  - segment.ms
  exclude_default: true
  start_at_earliest: {}
consumer_offset_sync_options:
  interval: 30s
  group_filters:
  - pattern_type: LITERAL
    filter_type: INCLUDE
    name: '*'
security_sync_options:
  interval: 30s
  acl_filters:
  - resource_filter:
      resource_type: TOPIC
      pattern_type: PREFIXED
      name: test-
    access_filter:
      principal: User:admin
      operation: ANY
      permission_type: ALLOW
      host: '*'
schema_registry_sync_options:
  shadow_schema_registry_topic: {}
```

So the net result is something like this:

```yaml
name: test-shadow-link-via-rpk
cloud_options:
  source_redpanda_id: curl3eo533cmsnt23dv0
  shadow_redpanda_id: d41p9tuc4cape6v42hgg
client_options:
  tls_settings:
    enabled: true
  authentication_configuration:
    scram_configuration:
      username: cnelson
      password: ${secrets.CNELSON_SASL_PASSWORD}
      scram_mechanism: SCRAM-SHA-256
  metadata_max_age_ms: 10000
  connection_timeout_ms: 1000
  retry_backoff_ms: 100
  fetch_wait_max_ms: 100
  fetch_min_bytes: 100
  fetch_max_bytes: 1048576
  fetch_partition_max_bytes: 1048576
topic_metadata_sync_options:
  interval: 30s
  auto_create_shadow_topic_filters:
  - pattern_type: PREFIX
    filter_type: EXCLUDE
    name: shadow_test.
  synced_shadow_topic_properties:
  - retention.ms
  - segment.ms
  exclude_default: true
  start_at_earliest: {}
consumer_offset_sync_options:
  interval: 30s
  group_filters:
  - pattern_type: PREFIX
    filter_type: INCLUDE
    name: shadow_test_cg.
security_sync_options:
  interval: 30s
  acl_filters:
  - resource_filter:
      resource_type: TOPIC
      pattern_type: PREFIXED
      name: test-
    access_filter:
      principal: User:admin
      operation: ANY
      permission_type: ALLOW
      host: '*'
schema_registry_sync_options:
  shadow_schema_registry_topic: {}
```

### Create the Shadow Link

```bash
rpk shadow create --config-file shadow-config.yaml
```
Which will then prompt you to confirm creation of the shadow link:

```text
Link Name:           test-shadow-link-via-rpk
Shadow Redpanda ID:  d41p9tuc4cape6v42hgg
Source Redpanda ID:  curl3eo533cmsnt23dv0
? Do you want to create this shadow link? (Y/n) Y
```

Hitting Y will create the link.  If successful, it will report back this:

```text
Successfully created shadow link "test-shadow-link-via-rpk" with ID "d4u8cf8tubdl9u8op4fg". To query the status, run:
  'rpk shadow status test-shadow-link-via-rpk'
```





---

## From EC2

```bash
rpk cloud login --no-browser
```
