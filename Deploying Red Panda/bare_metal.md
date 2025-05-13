

This process is documented in our public facing docs, but I'm not convinced they're correct.
https://docs.redpanda.com/current/deploy/deployment-option/self-hosted/manual/production/dev-deployment/?tab=tabs-1-debianubuntu
https://docs.redpanda.com/current/deploy/deployment-option/self-hosted/manual/production/production-deployment/?tab=tabs-1-debianubuntu


Customer facing PDF of these instructions:
https://docs.google.com/document/d/1eYtScIL7wZWB-ae9E-2QoJMBox4mz_zM9Uf0eFIAkGg/edit?usp=sharing


## Install redpanda on all nodes
```
curl -1sLf 'https://dl.redpanda.com/nzc4ZYQK3WRGd9sy/redpanda/cfg/setup/bash.deb.sh' | \
sudo -E bash && sudo apt install redpanda -y
```

## Configure for production/autotune on all nodes

```
sudo rpk redpanda mode production
sudo rpk redpanda tune all
```

# Bootstrapping

Bootstrapping with rpk is how the redpanda.yaml configuration file is created.  There are several ways to do this but probably the easiest is to pick a node to be "the first node."  It doesn't actually matter which, you just have to pick one to be the one to initiate the creation of the cluster.   The others will join it to form the complete cluster.


_NOTE:_  The rpk bootstrap command will build out the configuration found in `/etc/redpanda/redpanda.yaml`.  There is currently (as of 2/28/20224) a bug with how this file is built, so it must be manually corrected on each node to change the listeners to `0.0.0.0` and the advertised addresses to their own private IP.  See script in appendix at the end of this document for a quick way to update the config _after_ the bootstrapping step has been run.



## Bootstrap Brokers

```
sudo rpk redpanda config bootstrap --self $(hostname -I) --ips 10.100.14.84,10.100.2.89,10.100.13.133
sudo rpk redpanda config set redpanda.empty_seed_starts_cluster false
```

NOTE:  wes uses something like this:
```bash
sudo rpk redpanda config bootstrap --self <listener-address> --advertised-kafka <advertised-kafka-address> --ips <seed-server1-ip>,<seed-server2-ip>,<seed-server3-ip>

sudo rpk redpanda config set redpanda.empty_seed_starts_cluster false
```



### Example of the incorrect bootstrap config file


Note that the advertised addresses are 127.0.0.1, and the rpc/kafka/admin addresses are it's own private IP.

`/etc/redpanda/redpanda.yaml`:

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



Once the config is set properly, you can start the services on all your nodes

```
sudo systemctl start redpanda
rpk cluster config set enable_metrics_reporter false
systemctl status redpanda
```


## Verify Cluster Operation

From each broker, test the kafka api as well as the admin api:

```
rpk cluster health
rpk cluster info
rpk topics list
```

All those commands should return results, indicating you have connectivity to both endpoints.

---

# Appendix


## Script to update redpanda.yaml

Run this script (as sudo) after the bootstrapping step to make the necessary modifications to `/etc/redpanda/redpanda.yaml`


```
#!/bin/bash

file_path="/etc/redpanda/redpanda.yaml"

function update () {
    target_key="$1"
    new_value="$2"

    line_number=$(grep -n "$target_key" "$file_path" | cut -d ':' -f1)

    next_line_number=$((line_number + 1))

    sed -i "${next_line_number}s/.*/$new_value/" "$file_path"

    echo "$1 changed to $2"
}

update " rpc_server:" "        address: 0.0.0.0"
update " kafka_api:" "        - address: 0.0.0.0"
update " admin:" "        - address: 0.0.0.0"

update "advertised_rpc_api:" "        address: $(hostname -i)"
update "advertised_kafka_api:" "        - address: $(hostname -i)"

```

## Borked broker?

If you need to start over re-using the same VM, try this:

```
sudo rm -rf /var/lib/redpanda
sudo apt-get purge --auto-remove redpanda
```

Then start over from the top.



