# One Node TLS enable setup (with on-broker Console)

https://docs.redpanda.com/docs/manage/security/encryption/

Assumes you already have a single node cluster up.  Check my other docs for additional TLS info & troubleshooting.

**NOTE:  All these steps can be run on the broker or on your local machine.  If locally, but then you have to copy them up to each broker.**



---

## Generate Certs

You can do this via terraform here:  https://github.com/supahcraig/redpanda_basics/blob/main/Deploying%20Red%20Panda/TLS/README.md

OR 

You can do it by hand using `openssl` by following the instructions here:  https://github.com/supahcraig/redpanda_basics/blob/main/Deploying%20Red%20Panda/TLS/Generating%20Certs.md

Regardless of the method, once you have the keys on the server with the correct permissions, all the remaning steps are the same.


## Create the folder structure & permissions to hold the certs on the brokers


```console
sudo mkdir /etc/redpanda/certs
sudo chown redpanda:redpanda /etc/redpanda/certs
sudo chmod 777 /etc/redpanda/certs
cd /etc/redpanda/certs
```


## Copy from local to brokers (if necessary)

```console
scp -i ~/pem/cnelson-kp.pem broker.key broker.crt ca.crt ubuntu@<YOUR PUBLIC IP>:/etc/redpanda/certs
```



---

## Broker-side redpanda.yaml

Some of this is boilerplate from the bootstrap process, but the `rpk:` section & anything TLS-related has to be added by hand.

```yaml
redpanda:
    data_directory: /var/lib/redpanda/data
    empty_seed_starts_cluster: false
    seed_servers:
        - host:
            address: <broker private IP>
            port: 33145
    rpc_server:
        address: 0.0.0.0
        port: 33145
    kafka_api:
        - address: 0.0.0.0
          port: 9092
    admin:
          address: 0.0.0.0
          port: 9644

    kafka_api_tls:
          enabled: true
          key_file: /etc/redpanda/certs/broker.key
          cert_file: /etc/redpanda/certs/broker.crt
          truststore_file: /etc/redpanda/certs/ca.crt

    admin_api_tls:
          enabled: true
          key_file: /etc/redpanda/certs/broker.key
          cert_file: /etc/redpanda/certs/broker.crt
          truststore_file: /etc/redpanda/certs/ca.crt

    advertised_kafka_api:
      - address: <broker public IP>
        port: 9092

    advertised_rpc_api:
        address: <broker public IP>
        port: 33145

    developer_mode: true
    auto_create_topics_enabled: true
    fetch_reads_debounce_timeout: 10
    group_initial_rebalance_delay: 0
    group_topic_partitions: 3
    log_segment_size_min: 1
    storage_min_free_bytes: 10485760
    topic_partitions_per_shard: 1000
    write_caching_default: "true"
rpk:
    kafka_api:
        tls:
            ca_file: /etc/redpanda/certs/ca.crt

    admin_api:
      tls:
          truststore_file: /etc/redpanda/certs/ca.crt

    overprovisioned: true

pandaproxy: {}
schema_registry: {}
```

## Restart redpanda

Most changes to `redpanda.yaml` require redpanda to be restarted to take effect.

```console
sudo systemctl restart redpanda
```


---

## Local rpk profile (for remote connections)


Before we get started, you don't HAVE to use an `rpk profile` to do this.  You can do it with environment variables, a custom rpk config, or by specifying  command line params.

From your local machine (that is, not the broker)

```console
rpk profile create one-node-TLS
rpk profile use one-node-TLS
rpk profile edit
```

There are probably a thousand ways to do this.  This is one way I've found to work.  
_NOTE: I'm 90% sure the insecure skip verify flag is needed becuase of a self-signed cert that the remote client can't verify_

```yaml
name: one-node-TLS
description: Single broker w/TLS enabled
prompt: hi-red, "[%n]"
kafka_api:
    brokers:
        - <broker public IP>:9092
    tls:
        insecure_skip_verify: true
admin_api:
    addresses:
        - <broker public IP>:9644
    tls:
        insecure_skip_verify: true
```

_NOTE: rpk will silently revert your profile changes if there is a yaml or other configuration error.  Best to `rpk profile print` to verify your changes stick._

---

## Verify broker-side TLS connectivity

We'll need to verify both the admin api as well as the kafka api.  See other TLS docs for troubleshooting help.

### Kafka API (port 9092)

`sudo` may be needed here if the truststore that `rpk` uses is owned by redpanda and is more than 444 restrictive.

```console
rpk cluster info -v
```

The equivalent CLI version using TLS would be:

`rpk cluster info --tls-enabled -X <some sort of insecure_skip_verify=true> -v`



Should return output like:

```logtalk
22:19:01.489  DEBUG  opening connection to broker  {"addr": "127.0.0.1:9092", "broker": "seed_0"}
22:19:01.493  DEBUG  connection opened to broker  {"addr": "127.0.0.1:9092", "broker": "seed_0"}
22:19:01.493  DEBUG  issuing api versions request  {"broker": "seed_0", "version": 3}
22:19:01.493  DEBUG  wrote ApiVersions v3  {"broker": "seed_0", "bytes_written": 31, "write_wait": "27.24µs", "time_to_write": "38.568µs", "err": null}
22:19:01.494  DEBUG  read ApiVersions v3  {"broker": "seed_0", "bytes_read": 296, "read_wait": "69.817µs", "time_to_read": "169.678µs", "err": null}
22:19:01.494  DEBUG  connection initialized successfully  {"addr": "127.0.0.1:9092", "broker": "seed_0"}
22:19:01.494  DEBUG  wrote Metadata v7  {"broker": "seed_0", "bytes_written": 22, "write_wait": "4.762109ms", "time_to_write": "36.232µs", "err": null}
22:19:01.494  DEBUG  read Metadata v7  {"broker": "seed_0", "bytes_read": 142, "read_wait": "71.291µs", "time_to_read": "126.633µs", "err": null}
CLUSTER
=======
redpanda.c2bad66b-4f63-46a6-aaf3-20d57afe27ad

BROKERS
=======
ID    HOST          PORT
0*    18.118.226.7  9092
```

### Kafka Admin API (port 9644)

`sudo` may be needed here if the truststore that `rpk` uses is owned by redpanda and is more than 444 restrictive.

```console
rpk cluster health -v
```

The equivalent CLI version using TLS would be:

`rpk cluster health -X admin.tls.enabled=true -X admin.tls.insecure_skip_verify=true -v`


Should return output like:

```logtalk
22:21:08.998  DEBUG  Sending request  {"method": "GET", "url": "https://127.0.0.1:9644/v1/cluster/health_overview", "bearer": false, "basic": false}
CLUSTER HEALTH OVERVIEW
=======================
Healthy:                          true
Unhealthy reasons:                []
Controller ID:                    0
All nodes:                        [0]
Nodes down:                       []
Leaderless partitions (0):        []
Under-replicated partitions (0):  []
```

---

## Verity remote TLS connectivity

We'll need to verify both the admin api as well as the kafka api.  See other TLS docs for troubleshooting help.

### Kafka API (port 9092)

```console
rpk cluster info -v
```

Should return output like this:

```logtalk
17:21:38.580  DEBUG  opening connection to broker  {"addr": "18.118.226.7:9092", "broker": "seed_0"}
17:21:38.693  DEBUG  connection opened to broker  {"addr": "18.118.226.7:9092", "broker": "seed_0"}
17:21:38.693  DEBUG  issuing api versions request  {"broker": "seed_0", "version": 3}
17:21:38.693  DEBUG  wrote ApiVersions v3  {"broker": "seed_0", "bytes_written": 31, "write_wait": "242.041µs", "time_to_write": "139.584µs", "err": null}
17:21:38.728  DEBUG  read ApiVersions v3  {"broker": "seed_0", "bytes_read": 296, "read_wait": "36.833µs", "time_to_read": "35.057292ms", "err": null}
17:21:38.728  DEBUG  connection initialized successfully  {"addr": "18.118.226.7:9092", "broker": "seed_0"}
17:21:38.728  DEBUG  wrote Metadata v7  {"broker": "seed_0", "bytes_written": 22, "write_wait": "148.596083ms", "time_to_write": "14.667µs", "err": null}
17:21:38.763  DEBUG  read Metadata v7  {"broker": "seed_0", "bytes_read": 142, "read_wait": "181.208µs", "time_to_read": "34.582584ms", "err": null}
CLUSTER
=======
redpanda.c2bad66b-4f63-46a6-aaf3-20d57afe27ad

BROKERS
=======
ID    HOST          PORT
0*    18.118.226.7  9092
```

### Kafka Admin API (port 9644)

```console
rpk cluster health -v
```

Should return output like:

```logtalk
17:25:04.150  DEBUG  Sending request  {"method": "GET", "url": "https://18.118.226.7:9644/v1/cluster/health_overview", "bearer": false, "basic": false}
CLUSTER HEALTH OVERVIEW
=======================
Healthy:                          true
Unhealthy reasons:                []
Controller ID:                    0
All nodes:                        [0]
Nodes down:                       []
Leaderless partitions (0):        []
Under-replicated partitions (0):  []
```

---

# Console Setup

Documentation on this is a little light/confusing.
https://docs.redpanda.com/current/reference/console/config/#redpanda-console-configuration-file


## Console Install

### On-broker option

Install Redpanda console on your broker:

```console
curl -1sLf 'https://dl.redpanda.com/nzc4ZYQK3WRGd9sy/redpanda/cfg/setup/bash.deb.sh' | \
sudo -E bash && sudo apt-get install redpanda-console -y
```

_NOTE: yaml configs found below are for an on-broker console install.


### Off-broker option

TODO:



## Security Groups

_This may be less complicated/more secure by using internal/exteral listeners_

* EC2 must be open on port 8080 to allow web console traffic
* I also had to open ports 9092 to the public IP of the instance, because some of the traffic is going across the internet.  This is _probably_ because my advertised address is the public IP.
  * I initially had to open it on 9644 as well, but changing the `urls` in the `adminApi` section to localhost rather than the private IP has removed the need for that particular security group rule.

## redpanda-console.yaml


```yaml
kafka:
  brokers: 10.100.7.153:9092

  tls:
    enabled: true
    caFilepath: /etc/redpanda/certs/ca.crt
    certFilepath: /etc/redpanda/certs/broker.crt
    keyFilepath: /etc/redpanda/certs/broker.key


redpanda:
  adminApi:
    enabled: true
    urls: ["https://localhost:9644"]
    tls:
      enabled: true
      caFilepath: /etc/redpanda/certs/ca.crt
      certFilepath: /etc/redpanda/certs/broker.crt
      keyFilepath: /etc/redpanda/certs/broker.key
```

Then restart the console service:

```console
sudo systemctl restart redpanda-console
```

