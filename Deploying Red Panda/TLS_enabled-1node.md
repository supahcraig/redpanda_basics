# One Node TLS enable setup

https://docs.redpanda.com/docs/manage/security/encryption/

Assumes you already have a single node cluster up.  Check my other docs for additional TLS info & troubleshooting.

**NOTE:  All these steps should be run on the broker.  They can be run locally, but then you have to copy them up.**


---

## Create the folder structure & permissions

```
sudo mkdir /etc/redpanda/certs
sudo chown redpanda:redpanda /etc/redpanda/certs
sudo chmod 777 /etc/redpanda/certs
cd /etc/redpanda/certs
```

---

## Certificate Authority Config

This will need to go as-is into a file named `ca.cnf`

```
[ ca ]
default_ca = CA_default

[ CA_default ]
default_days    = 365
database        = index.txt
serial          = serial.txt
default_md      = sha256
copy_extensions = copy
unique_subject  = no
policy          = signing_policy
[ signing_policy ]
organizationName = supplied
commonName       = optional

# Used to create the CA certificate.
[ req ]
prompt             = no
distinguished_name = distinguished_name
x509_extensions    = extensions

[ distinguished_name ]
organizationName = Redpanda
commonName       = Redpanda CA

[ extensions ]
keyUsage         = critical,digitalSignature,nonRepudiation,keyEncipherment,keyCertSign
basicConstraints = critical,CA:true,pathlen:1

# Common policy for nodes and users.
[ signing_policy ]
organizationName = supplied
commonName       = optional
```


---

## Broker Config

This will need to go into a file called `broker.cnf`

You will need to modify the `[ alt names ]` section as per your speficic needs.   For POC purposes, what you'll probably want is to include at a minimum the _private_ IP's of your brokers.   In this example I've included the private DNS, the private IP, and the public IP of my only broker.   If you happen to have multiple brokers, the `broker.cnf` will need additional entries for the DNS & private IP's of the brokers.


```
[ req ]
prompt             = no
distinguished_name = distinguished_name
req_extensions     = extensions

[ distinguished_name ]
organizationName = Redpanda

[ extensions ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = localhost
DNS.2 = redpanda
DNS.3 = console
DNS.4 = connect
DNS.5 = <aws private DNS>
IP.1  = 127.0.0.1
IP.2  = <private IP>
IP.3  = <public IP>
```

---

## Generate & Sign Certificates

This is the distilled version of the public facing Redpanda TLS docs.


```
# cleanup
rm -f *.crt *.csr *.key *.pem index.txt* serial.txt*

# create a ca key to self-sign certificates
openssl genrsa -out ca.key 2048
chmod 400 ca.key

# create a public cert for the CA
openssl req -new -x509 -config ca.cnf -key ca.key -days 365 -batch -out ca.crt

# create broker key
openssl genrsa -out broker.key 2048

# generate Certificate Signing Request
openssl req -new -key broker.key -out broker.csr -nodes -config broker.cnf

# sign the certificate with the CA signature
touch index.txt
echo '01' > serial.txt
openssl ca -config ca.cnf -keyfile ca.key -cert ca.crt -extensions extensions -in broker.csr -out broker.crt -outdir . -batch

sudo chown redpanda:redpanda broker.key broker.crt ca.crt
sudo chmod 400 broker.key broker.crt ca.crt
```

---

## Broker-side redpanda.yaml

Some of this is boilerplate from the bootstrap process, but the `rpk:` section & anything TLS-related has to be added by hand.

```
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
    kafka_api_tls:
          enabled: true
          key_file: /etc/redpanda/certs/broker.key
          cert_file: /etc/redpanda/certs/broker.crt
          truststore_file: /etc/redpanda/certs/ca.crt
    admin:
          address: 0.0.0.0
          port: 9644
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
            enabled: false
            ca_file: /etc/redpanda/certs/ca.crt

    admin_api:
      tls:
          #key_file: /etc/redpanda/certs/broker.key
          #cert_file: /etc/redpanda/certs/broker.crt
          truststore_file: /etc/redpanda/certs/ca.crt

    overprovisioned: true

pandaproxy: {}
schema_registry: {}
```

## Restart redpanda

Most changes to `redpanda.yaml` require redpanda to be restarted to take effect.

```
sudo systemctl restart redpanda
```


---

## Local rpk profile (for remote connections)


From your local machine (that is, not the broker)

```
rpk profile create one-node-TLS
rpk profile use one-node-TLS
rpk profile edit
```

There are probably a thousand ways to do this.  This is one way I've found to work.  
_NOTE: I'm 90% sure the insecure skip verify flag is needed becuase of a self-signed cert that the remote client can't verify_

```
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

## Verity remote TLS connectivity

We'll need to verify both the admin api as well as the kafka api.  See other TLS docs for troubleshooting help.

### Kafka API (port 9092)
```
rpk cluster info -v
```




