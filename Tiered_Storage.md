

This was done using a cluster built via deployment-automation using the tiered storage playbook....it's not evident exactly how that particular playbook has anything to do with tiered storage.

Following this doc, for the most part:

https://docs.redpanda.com/docs/manage/tiered-storage/#enable-tiered-storage-for-a-cluster

## License

go to license.redpanda.com, then apply it:

`rpk cluster license set --path ~/path/to/redpanda.license`

and then verify as follows:

`rpk cluster license info`

should return something like:

```
LICENSE INFORMATION
===================
Organization:      redpanda
Type:              free_trial
Expires:           Aug 26 2023
warning: your license will expire soon
```

^^^^ This assumes you have your redpanda.yaml configured for rpk & admin stuff.   Your `redpanda.yaml` could look like this:

```
rpk:

  kafka_api:
    brokers:
    - 3.144.124.82:9092
    - 18.217.34.238:9092
    - 3.133.120.186:9092

    tls:
      key_file: /Users/cnelson/sandbox/deployment-automation/ansible/tls/ca/ca.key
      cert_file: /Users/cnelson/sandbox/deployment-automation/ansible/tls/ca/ca.crt
      truststore_file: /Users/cnelson/sandbox/deployment-automation/ansible/tls/ca/ca.crt

  admin_api:
    addresses:
    - 3.144.124.82:9644
    - 18.217.34.238:9644
    - 3.133.120.186:9644

    tls:
      key_file: /Users/cnelson/sandbox/deployment-automation/ansible/tls/ca/ca.key
      cert_file: /Users/cnelson/sandbox/deployment-automation/ansible/tls/ca/ca.crt
      truststore_file: /Users/cnelson/sandbox/deployment-automation/ansible/tls/ca/ca.crt
```

---

## Tiered Storage Properties

From a remote machine (where you have already established you can connect into via the admin endpoint..)

`rpk cluster config edit`

And set these properties:

```
cloud_storage_enabled: true
cloud_storage_credentials_source: aws_instance_metadata
cloud_storage_region: us-east-2
cloud_storage_bucket: craignelson7007-tieredstorage
```

The doc then says you need to set two other properties but (a) they aren't always returned by the cluster config edit command and (b) you can use the get/set function to maybe do it a little easier.

To make those properties show up in the cluster config edit:

`rpk cluster config edit --all`


To use the get/set method:

```
rpk cluster config set cloud_storage_enable_remote_write true
rpk cluster config set cloud_storage_enable_remote_read true
```



