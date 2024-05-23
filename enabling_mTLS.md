

Certs are not my superpower.  This is was done via chatGPT.   No idea how this is going to go.


## 1.  Generate Certificates

### 1a.  Create Certificate Authority (CA)

From local machine...

```
openssl req -x509 -new -nodes -keyout ca.key -out ca.crt -days 365 \
-subj "/C=US/ST=State/L=Locality/O=Organization/OU=Unit/CN=example.com"
```

---

### 1b.  Create a Server Certificate


#### 1b-1.  Generate a private key for the server

From same place where the ca.crt lives

```
openssl genpkey -algorithm RSA -out server.key
```

#### 1b-2.  Create a certificate signing request (CSR)

From the same place where the server.key lives



And then generate server key & CSR using the config.


If you need a san.cnf:

```
openssl req -new -nodes -out server.csr -keyout server.key -config san.cnf
```


If you do not need a san.cnf:

```
openssl req -new -key server.key -out server.csr -subj "/C=US/ST=State/L=Locality/O=Organization/OU=Unit/CN=server.example.com"
```

So we need to use a Configuration file for the SANs.   I've previously got this piece working from my `enable_TLS.md` doc in this repo, so we'll leverage it here (slightly modified)

Save this into `san.cnf`

```
[ req ]
prompt             = no
distinguished_name = req_distinguished_name
req_extensions     = v3_req

[ req_distinguished_name ]
organizationName = Redpanda

[ v3_req ]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = localhost
DNS.2 = redpanda
DNS.3 = console
DNS.4 = connect
DNS.5 = ec2-3-17-174-176.us-east-2.compute.amazonaws.com
IP.1  = 127.0.0.1
IP.2  = 10.100.7.153
IP.3  = 3.17.174.176
```


---

#### 1b-3.  Sign the CSR with the CA:

_This is what was recommended prior to the inclusion of the configuration file for the SAN_

```
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365
```

Using the `san.cnf` requires some slight modifications to the signing step:

```
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 -extensions v3_req -extfile san.cnf
```

And then verify with this command:

```
openssl x509 -in server.crt -noout -text | grep -A 1 "Subject Alternative Name"
```

---

### 1c.  Create a Client Certificate

From local machine...

#### 1c-1.  Generate a private key for the client

```
openssl genpkey -algorithm RSA -out client.key
```

#### 1c-2.  Create a CSR

```
openssl req -new -key client.key -out client.csr \
-subj "/C=US/ST=State/L=Locality/O=Organization/OU=Unit/CN=client.example.com"
```


#### 1c-3.  Sign the CSR with the CA

```
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 365
```

---

### 1d.  Transfer the Certficiates

_On the broker_, you'll need a folder for the certs:

```
sudo mkdir /etc/redpanda/certs
sudo chown redpanda:redpanda /etc/redpanda/certs
sudo chmod 777 /etc/redpanda/certs
```

The 777 permission is to allow ubuntu to write to the directory when the scp command is issued.


```
scp -i ~/pem/cnelson-kp.pem ca.crt server.key server.crt ubuntu@3.17.174.176:/etc/redpanda/certs
```

These files must have 444 permissions on the server.

---


## 2.  Configure Redpanda for TLS

Edit the `redpanda.yaml` to (minimally) allow for TLS on the kafka api:

```
redpanda:
    data_directory: /var/lib/redpanda/data
    empty_seed_starts_cluster: false
    seed_servers:
        - host:
            address: 10.100.7.153
            port: 33145
    rpc_server:
        address: 0.0.0.0
        port: 33145
    kafka_api:
        - address: 0.0.0.0
          port: 9092
          name: tls_listener
    kafka_api_tls:
        - name: tls_listener
          key_file: /etc/redpanda/certs/server.key
          cert_file: /etc/redpanda/certs/server.crt
          truststore_file: /etc/redpanda/certs/ca.crt
          enabled: true
          require_client_auth: false
    admin:
        - address: 0.0.0.0
          port: 9644
    advertised_rpc_api:
        address: 10.100.7.153
        port: 33145
    advertised_kafka_api:
        - address: 10.100.7.153
          port: 9092
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
    overprovisioned: true
    coredump_dir: /var/lib/redpanda/coredump
pandaproxy: {}
schema_registry: {}
```


As it stands, rpk from on-broker barks about TLS when I don't specify `--tls-enabled` and if you change the permissions on the certs/keys Redpanda won't even start.   So the issue would appear to be with the certs themselves.

`rpk cluster info --tls-enabled -v` returns this:

```
22:05:34.733  DEBUG  opening connection to broker  {"addr": "127.0.0.1:9092", "broker": "seed_0"}
22:05:34.734  WARN  unable to open connection to broker  {"addr": "127.0.0.1:9092", "broker": "seed_0", "err": "remote error: tls: handshake failure"}
```


Adding an rpk section to the redpanda.yaml specifially for TLS & kafka api just changes the IP to the private IP rather than 127.0.0.1, but the same error is returned.





