Connecting to a cluster with mTLS

The `tls` section is the relevant section here.

```yaml
input:
  redpanda_replicator:
    seed_brokers: [ "your.msk.endpoint:9092" ]
    topics:
      - '^[^_]' # Skip internal topics which start with `_`
    regexp_topics: true
    consumer_group: ""
    start_from_oldest: true

    tls:
      enabled: true
      skip_cert_verify: false
      client_certs:
        - cert_file: clientCert.pem
          key_file: clientCert.key
```


Note that you can have a situation where topics could require different certs:

https://redpandadata.slack.com/archives/C07J4ARJTA5/p1724185967487709


```yaml
    tls:
      enabled: true
      skip_cert_verify: false
      client_certs:
        - cert_file: foo.pem
          key_file: bar.key
          password: 00
        - cert_file: bar.pem
          key_file: bar.key
          password: 00
```
