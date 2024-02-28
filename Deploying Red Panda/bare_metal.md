

This process is documented in our public facing docs, but I'm not convinced they're correct.
https://docs.redpanda.com/current/deploy/deployment-option/self-hosted/manual/production/dev-deployment/?tab=tabs-1-debianubuntu


## Install redpanda
```
curl -1sLf 'https://dl.redpanda.com/nzc4ZYQK3WRGd9sy/redpanda/cfg/setup/bash.deb.sh' | \
sudo -E bash && sudo apt install redpanda -y
```

## Configure for production/autotune

```
sudo rpk redpanda mode production
sudo rpk redpanda tune all
```

## Bootstrap Node 0

The rpk bootstrap command will build out the configuration found in `/etc/redpanda/redpanda.yaml`.  There is currently (as of 2/28/20224) a bug with how this file is built, so it must be manually corrected.

```
sudo rpk redpanda config bootstrap --self $(hostname -I) --ips 10.100.14.84,10.100.2.89,10.100.13.133
sudo rpk redpanda config set redpanda.empty_seed_starts_cluster false
```

### Example of the incorrect bootstrap config file

Note that the advertised addresses are 127.0.0.1, and the rpc/kafka/admin addresses are it's own private IP.

```
redpanda:
    data_directory: /var/lib/redpanda/data
    empty_seed_starts_cluster: false
    seed_servers:
        - host:
            address: 10.100.14.84
            port: 33145
        - host:
            address: 10.100.2.89
            port: 33145
        - host:
            address: 10.100.13.133
            port: 33145
    rpc_server:
        address: 10.100.14.84
        port: 33145
    kafka_api:
        - address: 10.100.14.84
          port: 9092
    admin:
        - address: 10.100.14.84
          port: 9644
    advertised_rpc_api:
        address: 127.0.0.1
        port: 33145
    advertised_kafka_api:
        - address: 127.0.0.1
          port: 9092
```



### Example of a corrected bootstrap config file

Note that the advertised addresses are the self private IP, but the listeners are on 0.0.0.0

```
redpanda:
    data_directory: /var/lib/redpanda/data
    empty_seed_starts_cluster: false
    seed_servers:
        - host:
            address: 10.100.14.84
            port: 33145
        - host:
            address: 10.100.2.89
            port: 33145
        - host:
            address: 10.100.13.133
            port: 33145
    rpc_server:
        address: 0.0.0.0
        port: 33145
    kafka_api:
        - address: 0.0.0.0
          port: 9092
    admin:
        - address: 0.0.0.0
          port: 9644
    advertised_rpc_api:
        address: 10.100.14.84
        port: 33145
    advertised_kafka_api:
        - address: 10.100.14.84
          port: 9092
```



Once the config is set properly, you can start the services

```
sudo systemctl start redpanda
rpk cluster config set enable_metrics_reporter false
systemctl status redpanda
```

## Bring up Additional Nodes

There was a time when you would specify the node id using the `--id <integer>` switch, but that is no longer necessary.

### Node 1

```
sudo rpk redpanda config bootstrap --self $(hostname -I)  --ips <seed server private ip>
sudo rpk redpanda config bootstrap --self $(hostname -I) --ips 10.100.14.84,10.100.2.89,10.100.13.133

```

### Node 2

```
sudo rpk redpanda config bootstrap --self $(hostname -I)  --ips <seed server private ip>
sudo rpk redpanda config bootstrap --self $(hostname -I) --ips 10.100.14.84,10.100.2.89,10.100.13.133
```

### Example of the incorrect bootstrap config file

Note that the advertised addresses are 127.0.0.1, and the rpc/kafka/admin addresses are it's own private IP.

```
redpanda:
    data_directory: /var/lib/redpanda/data
    seed_servers:
        - host:
            address: 10.100.14.84
            port: 33145
        - host:
            address: 10.100.2.89
            port: 33145
        - host:
            address: 10.100.13.133
            port: 33145
    rpc_server:
        address: 10.100.13.133
        port: 33145
    kafka_api:
        - address: 10.100.13.133
          port: 9092
    admin:
        - address: 10.100.13.133
          port: 9644
    advertised_rpc_api:
        address: 127.0.0.1
        port: 33145
    advertised_kafka_api:
        - address: 127.0.0.1
          port: 9092
```


### Example of a corrected bootstrap config file

```
redpanda:
    data_directory: /var/lib/redpanda/data
    seed_servers:
        - host:
            address: 10.100.14.84
            port: 33145
        - host:
            address: 10.100.2.89
            port: 33145
        - host:
            address: 10.100.13.133
            port: 33145
    rpc_server:
        address: 0.0.0.0
        port: 33145
    kafka_api:
        - address: 0.0.0.0
          port: 9092
    admin:
        - address: 0.0.0.0
          port: 9644
    advertised_rpc_api:
        address: 10.100.2.89
        port: 33145
    advertised_kafka_api:
        - address: 10.100.2.89
          port: 9092
```


## Start services on the additional nodes

```
sudo systemctl start redpanda
rpk cluster config set enable_metrics_reporter false
systemctl status redpanda
```


## Verify Cluster Operation

From each broker, test the kafka api as well as the admin api:

```
rpk cluster info
rpk topics list
```

Both commands should return results, indicating you have connectivity to both endpoints.
