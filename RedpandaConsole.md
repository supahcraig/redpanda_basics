
installation steps found in the Redpanda docs online.

Console configuration docs:  https://docs.redpanda.com/docs/reference/console/config/#yaml-configuration

## Install Console

You can install this anywhere, though in practice it's convenient to deploy to one or more Redpanda brokers.

https://docs.redpanda.com/docs/deploy/deployment-option/self-hosted/manual/production/production-deployment/

```
curl -1sLf 'https://dl.redpanda.com/nzc4ZYQK3WRGd9sy/redpanda/cfg/setup/bash.deb.sh' | \
sudo -E bash && sudo apt-get install redpanda-console -y
```

This will create a new empty configuration file under `/etc/redpanda` called `redpanda-console.yaml`


## Minimal Configuration

The minimal config needed to bring up the console service is to simply list the brokers.  If the brokers are using TLS, however, this might not be enough to start the service.

```
kafka:
  brokers:
    - 10.100.8.26:9092
    - 10.100.3.15:9092
    - 10.100.10.47:9092
```

To use the admin endpoint you'll need to add another section (at the document root level):

```
redpanda:
  adminApi:
    enabled: true
    urls: ["https://10.100.8.26:9644", "https://10.100.3.15:9644", "https://10.100.10.47:9644"]
```


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

Note that the urls require `https://` because we have TLS enabled on the adminAPI (this is set on the broker, we're just pointing to it here).

YAML noob note:  rather than using the bracketed array notation you can use this style (without quotes):

```
urls:
- https://10.100.8.26:9644
- https://10.100.3.15:9644
- https://10.100.10.47:9644
```


Then restart redpanda-console and verify it comes up using `journalctl -u redpanda-console -f`

_NOTE:  At least ONE broker must have the adminAPI configured for TLS or else the service will not successfully start._

