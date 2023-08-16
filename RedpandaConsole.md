
installation steps found in the Redpanda docs online.

Console configuration docs:  https://docs.redpanda.com/docs/reference/console/config/#yaml-configuration



## Redpanda Console with TLS

copy the `broker.key`, `broker.crt`, and `ca.crt` to the node(s) where Console will be running.   They should probalby already be there if the cluster is configured to use TLS.

Update `/etc/redpanda/redpanda-console.yaml` as follows, changing the broker addresses to whatever yours are.

```
kafka:
  brokers:
    - 10.100.8.26:9092
    - 10.100.3.15:9092
    - 10.100.10.47:9092

  tls:
    enabled: true
    caFilePath: /etc/redpanda/certs/ca.crt
    certFilepath: /etc/redpanda/certs/broker.crt
    keyFilepath: /etc/redpanda/certs/broker.key
```

The Redpanda docs use different names in `redpanda.yaml` as they do in `redpanda-console.yaml`.  This mapping connects those dots.

| Console | Redpanda | Actual File |
|---|---|---|
| `caFilepath` | `truststore_file` | `ca.crt` |
| `certFilepath` | `cert_file` | `broker.crt` |
| `keyFilepath` | `key_file` | `broker.key` |


then start/restart the `redpanda-console` service:

`systemctl start redpanda-console`

From a browser, navigate to the public IP of the node where console is running, port 8080.  Make sure your security group allows for traffic on 8080.

http://public.ip.of.consonle:8080

If the page does not come up, check the logs via `journalctl -xeu redpanda-console` or `systemctl -u redpanda-console -f`


## Configuring Admin API for TLS

The above will bring up the Redpanda console with TLS, but the admin API won't work without further work.  You'll have to add a new section to `redpanda-console.yaml` for `redpanda:` at the root level.   

```
redpanda:
  adminApi:
    enabled: true
    urls: ["https://10.100.8.26:9644", "https://10.100.3.15:9644", "https://10.100.10.47:9644"]
    tls:
      enabled: true
      caFilepath: /etc/redpanda/certs/ca.crt
      certFilepath: /etc/redpanda/certs/broker.crt
      keyFilepath: /etc/redpanda/certs/broker.key
```

Note that the urls are presented differently than in other places in Redpanda yaml files.   Further note that because we are using TLS, we must use `https`

Then restart redpanda-console.

_NOTE:  At least ONE broker must have the adminAPI configured for TLS or else the service will not successfully start._

