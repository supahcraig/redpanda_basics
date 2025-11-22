# Installing Console

It's probably somewhat dangerous to run console on one of the OMB worker nodes, since Ansible will probalby blow it away if you have to re-run the playbook, but oh well.


## Install Console

This will install it, but you'll have to configure it before you actually start the service.

```bash
curl -1sLf 'https://dl.redpanda.com/nzc4ZYQK3WRGd9sy/redpanda/cfg/setup/bash.deb.sh' | \
sudo -E bash && sudo apt-get install redpanda-console -y
```


## Configure Console

You'll probably already have a stubbed out file named `/etc/redpanda/redpanda-console-config.yaml`

If you have a self-hosted cluster, a basic console config will look like this.   If you're using BYOC, you'll definitely need to account for tls & sasl user stuff.


```yaml
server:
  listenPort: 8888
kafka:
  brokers:
    - 10.202.0.227:9092
    - 10.202.0.38:9092
    - 10.202.0.170:9092
redpanda:
  adminApi:
    enabled: true
    urls:
      - http://10.202.0.227:9644
      - http://10.202.0.38:9644
      - http://10.202.0.170:9644
schemaRegistry:
  enabled: true
  urls:
    - "http://localhost:8081"
```

## Enable the Service

```bash
sudo systemctl enable --now redpanda-console
```

You can check the status with

```bash
sudo systemctl status redpanda-console
```

And if you have any issues, you can look at the logs...

```bash
sudo journalctl -u redpanda-console -n 200 --no-pager
```

