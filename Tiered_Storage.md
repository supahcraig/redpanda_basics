

This was done using a cluster built via deployment-automation using the tiered storage playbook....it's not evident exactly how that particular playbook has anything to do with tiered storage.

Following this doc, for the most part:

https://docs.redpanda.com/docs/manage/tiered-storage/#enable-tiered-storage-for-a-cluster


This doc is aimed at configuring tiered storage on a self-hosted cluster.   For BYOC, tiered storage is enabled & configured out of the box.   You probalby don't want to mess with it, but pure curiosity will make you want to look at it.   The bucket name will be of the form `redpanda-cloud-storage-<REDPANDA CLUSTER ID>`


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

*Quick Note on `redpanda.yaml`*:
There will be a `redpanda.yaml` on each broker, but you can also have one on your client machine.   The easiest place to put it is in your working directory, but `/etc/redpanda/redpanda.yaml` is another valid location.   

Here is a sample of "all" the rpk config options.   
https://docs.redpanda.com/current/reference/node-configuration-sample/

_NOTE: rpk profiles have removed the need for a local redpanda.yaml_


---

## Tiered Storage Properties

From a remote machine (where you have already established you can connect into via the admin endpoint..)

`rpk cluster config edit`

### Using rpk cluster config edit

And set these properties using `rpk cluster config edit --all`  (`--all` is needed to ensure all the paramters are returned)

```
cloud_storage_enabled: true
cloud_storage_credentials_source: aws_instance_metadata
cloud_storage_region: us-east-2
cloud_storage_bucket: craignelson7007-tieredstorage
cloud_storage_enable_remote_write true
cloud_storage_enable_remote_read true
```

The doc then says you need to set two other properties but (a) they aren't always returned by the cluster config edit command and (b) you can use the get/set function to maybe do it a little easier.   It might be easier to use the get/set for the above parameters too.

To make those properties show up in the cluster config edit:

`rpk cluster config edit --all`


### Using the get/set method:

```
rpk cluster config set cloud_storage_enabled: true
rpk cluster config set cloud_storage_credentials_source: aws_instance_metadata
rpk cluster config set cloud_storage_region: us-east-2
rpk cluster config set cloud_storage_bucket: craignelson7007-tieredstorage
rpk cluster config set cloud_storage_enable_remote_write true
rpk cluster config set cloud_storage_enable_remote_read true
```

---

## IAM Policy

We have example policies in our docs, but the basic steps are:

1.  Create IAM policy granting privs to the bucket
2.  Create an IAM role & attach that policy
3.  Add that IAM role to each broker

Initially I had public access turned on for the bucket, but I turned it back off and I think it's still working.


## Errors

I missed capturing the error message, but it was essentially a curl response with a 404


## Sucess

You should see messages like this in the logs (`sudo journalctl -f -u redpanda`)

```
Jul 28 14:40:01 ip-172-31-2-198 rpk[6427]: TRACE 2023-07-28 14:40:01,752 [shard 6] s3 - s3_client.cc:652 - send https request:
Jul 28 14:40:01 ip-172-31-2-198 rpk[6427]: PUT /e0000000/meta/kafka/ts/0_53/manifest.bin HTTP/1.1
Jul 28 14:40:01 ip-172-31-2-198 rpk[6427]: User-Agent: redpanda.vectorized.io
Jul 28 14:40:01 ip-172-31-2-198 rpk[6427]: Host: craignelson7007-tieredstorage.s3.us-east-2.amazonaws.com
Jul 28 14:40:01 ip-172-31-2-198 rpk[6427]: Content-Type: text/plain
Jul 28 14:40:01 ip-172-31-2-198 rpk[6427]: Content-Length: 2341
Jul 28 14:40:01 ip-172-31-2-198 rpk[6427]: x-amz-tagging: rp-type=partition-manifest&rp-ns=kafka&rp-topic=ts&rp-part=0&rp-rev=53
Jul 28 14:40:01 ip-172-31-2-198 rpk[6427]: x-amz-date: 20230728T144001Z
Jul 28 14:40:01 ip-172-31-2-198 rpk[6427]: x-amz-content-sha256: [secret]
Jul 28 14:40:01 ip-172-31-2-198 rpk[6427]: x-amz-security-token: [secret]
Jul 28 14:40:01 ip-172-31-2-198 rpk[6427]: Authorization: [secret]
Jul 28 14:40:01 ip-172-31-2-198 rpk[6427]:
Jul 28 14:40:02 ip-172-31-2-198 rpk[6427]: INFO  2023-07-28 14:40:02,598 [shard 1] archival - scrubber.cc:350 - Running with 4 quota, 0 topic lifecycle markers
```

Also looking at the topic itself can show you if it is doing any cloud-related stuff:

`rpk topic describe-storage ts` (ts is my tiered storage topic)

```
SUMMARY
=======
NAME                ts
PARTITIONS          1
REPLICAS            1
CLOUD-STORAGE-MODE  full
LAST-UPLOAD         1120

SIZE
====
PARTITION  CLOUD-BYTES  LOCAL-BYTES  TOTAL-BYTES  CLOUD-SEGMENTS  LOCAL-SEGMENTS
0          5661         5937         5661         0               6
```

The CLOUD-BYTES will be 0 until it starts pushing to tiered storage.   TODO:  understand what CLOUD-SEGMENTS means and why it is zero even though data has been written to the bucket.
