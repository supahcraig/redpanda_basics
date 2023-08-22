

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

```
sudo rpk redpanda config bootstrap --id 0 --self $(hostname -I)
sudo systemctl start redpanda
rpk cluster config set enable_metrics_reporter false
systemctl status redpanda
```

## Bring up Additional Nodes

### Node 1

```
sudo rpk redpanda config bootstrap --id 1 --self $(hostname -I)  --ips <seed server private ip>
```

### Node 2

```
sudo rpk redpanda config bootstrap --id 2 --self $(hostname -I)  --ips <seed server private ip>
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
