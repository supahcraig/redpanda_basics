# Enabling TLS from Ground Zero

The Redpanda docs suck.

## Pre-requisites

### Certificate Authority Config

This will need to go as-is into a file named `ca.cnf`

```
# OpenSSL CA configuration file
[ ca ]
default_ca = CA_default
[ CA_default ]
default_days = 365
database = index.txt
serial = serial.txt
default_md = sha256
copy_extensions = copy
unique_subject = no
policy = signing_policy
[ signing_policy ]
organizationName = supplied
commonName = optional

# Used to create the CA certificate.
[ req ]
prompt=no
distinguished_name = distinguished_name
x509_extensions = extensions
[ distinguished_name ]
organizationName = Redpanda
commonName = Redpanda CA
[ extensions ]
keyUsage = critical,digitalSignature,nonRepudiation,keyEncipherment,keyCertSign
basicConstraints = critical,CA:true,pathlen:1
# Common policy for nodes and users.
[ signing_policy ]
organizationName = supplied
commonName = optional
# Used to sign node certificates.
[ signing_node_req ]
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth,clientAuth
# Used to sign client certificates.
[ signing_client_req ]
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = clientAuth
```


### Broker Config

This will need to go into a file called `broker.cnf`

You will need to modify the `[ alt names ]` section as per your speficic needs.   For POC purposes, what you'll probably want is to include at a minimum the _private_ IP's of your brokers.   In this example I've included the private DNS, the private IP, and the public IP of _one_ of my brokers.   

_TODO:  verify that including all those addresses for all brokers in this one file works_

```
# Used to create the CA certificate.
[ req ]
prompt=no
distinguished_name = distinguished_name
x509_extensions = extensions
[ distinguished_name ]
organizationName = Redpanda
commonName = Redpanda CA
[ extensions ]
keyUsage = critical,digitalSignature,nonRepudiation,keyEncipherment,keyCertSign
basicConstraints = critical,CA:true,pathlen:1
# Common policy for nodes and users.
[ signing_policy ]
organizationName = supplied
commonName = optional
# Used to sign node certificates.
[ signing_node_req ]
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth,clientAuth
# Used to sign client certificates.
[ signing_client_req ]
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = clientAuth
root@ip-10-100-8-26:/etc/redpanda/certs# cat broker.cnf
[ req ]
prompt=no
distinguished_name = distinguished_name
req_extensions = extensions
[ distinguished_name ]
organizationName = Redpanda
[ extensions ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = localhost
DNS.2 = redpanda
DNS.3 = console
DNS.4 = connect
DNS.5 = ec2-3-15-15-172.us-east-2.compute.amazonaws.com
IP.1  = 10.100.8.26
IP.2  = 3.15.15.172
```


---


## Generate & sign the certs

This can be done from anywhere, but ultimately the 3 files (`ca.crt`, `ca.key`, and `broker.crt`) will need to be on each broker, owned & readable by redpanda

```
rm -f *.crt *.csr *.key *.pem index.txt* serial.txt*

openssl genrsa -out ca.key 2048
chmod 400 ca.key
openssl req -new -x509 -config ca.cnf -key ca.key -days 365 -batch -out ca.crt


### Create a certificate for your broker
openssl genrsa -out broker.key 2048
openssl req -new -key broker.key -out broker.csr -nodes -config broker.cnf
touch index.txt
echo '01' > serial.txt
openssl ca -config ca.cnf -keyfile ca.key -cert ca.crt -extensions extensions -in broker.csr -out broker.crt -outdir . -batch

chown redpanda:redpanda ca.key
chown redpanda:redpanda ca.crt
chown redpanda:redpanda broker.crt
```

_TODO:  is the `chmod 400` neccesary?_

---

### Breaking down the steps in the script

These steps can be run from anywhere.   There are several ancillary output files that can be removed later, but the three important ones are:
* `ca.crt`
* `ca.key`
* `broker.crt`

These will need to be owned & accessible by redpanda.  The standard location for these is `/etc/redpanda/certs/` but you will specify this location in your `redpanda.yaml` (unless you want to specify it for every `rpk` command on the CLI).


**1.  Generating the certificate authority private key**

`openssl genrsa -out ca.key 2048`

This uses openssl to generate a private key, which will be the private key for our CA.


**2.  Self signing the root certificate**

`openssl req -new -x509 -config ca.cnf -key ca.key -days 365 -batch -out ca.crt`

Here we are creating a root certificate that validates itself.   Any certs which are later signed by this will be valid.   


**3.  Generate your broker private key**

`openssl genrsa -out broker.key 2048`

This uses openssl to generate a private key which your brokers will use.  You will use this one key for ALL your brokers.


**4.  Generate the private broker certificate (csr)**

`openssl req -new -key broker.key -out broker.csr -nodes -config broker.cnf`

This generates a certificate signing request (which is really just an unsigned cert) for your broker.


**5.  Pure black magic**

```
touch index.txt
echo '01' > serial.txt
```

I mean, I understand what in the unix this is doing, but I have no idea why it's important.  These files have something to do with a sort of database which is referred to in the `ca.cnf`


**6.  Have the CA sign the broker cert**

`openssl ca -config ca.cnf -keyfile ca.key -cert ca.crt -extensions extensions -in broker.csr -out broker.crt -outdir . -batch`

This will sign the broker cert signing request (`broker.csr`) using the CA certficate (`ca.crt`) and apparently the CA private key (`ca.key`), the output will by the signed broker cert (`broker.crt`) into the current directory.

_TODO:  determine what of these options is not actually required, i.e. `ca.cnf` and/or `ca.key`


**7.  Make redpanda the owner of the certs & keys

```
chown redpanda:redpanda ca.key
chown redpanda:redpanda ca.crt
chown redpanda:redpanda broker.crt
```

---

## Conifguring `redpanda.yaml`

In order for redpanda to use TLS it must be configured to use TLS for various services.   More docs (which may or may not be helpful) on configuration options in `redpanda.yaml` can be found here:  https://docs.redpanda.com/docs/reference/node-configuration-sample/

### Redpanda

To allow TLS on the kafka api, you'll need to add a `kafka_api_tls` section under `redpanda`, where the path to the certs corresponds to the final resting place of the certs you created above.   Most commonly this is `/etc/redpanda/certs/`

```
    kafka_api_tls:
        enabled: true
        requrie_client_auth: false
        cert_file: /etc/redpanda/certs/broker.crt
        key_file: /etc/redpanda/certs/broker.key
        truststore_file: /etc/redpanda/certs/ca.crt
```




### rpk

To allow TLS when using `rpk`, you'll need to add a `tls` section under `rpk/kafka_api`,  where the path to the certs corresponds to the final resting place of the certs you created above.   Again, this is most commonly this is `/etc/redpanda/certs/`.  Your `rpk` section may not look exactly like this, the important part for TLS is that the `tls:` section is under `kafka_api:`, which itself is under `rpk:`

It is important to note that the `rpk` section of `redpanda.yaml` applies to the machine that it is running on.   So if you use `rpk` from one of the brokers, you would add it to `/etc/redpanda/redpanda.yaml` but if you were running `rpk` on your local machine you would need to add it to your `rpk` profile or however you're running your local `rpk` config.

Lastly, to use TLS with `rpk` remotely, you will need to have the truststore (that is, `ca.crt`) there as well.

```
rpk:
    kafka_api:
      brokers:
      - 10.100.8.26
      tls:
        enabled: true
        #cert_file: /etc/redpanda/certs/broker.crt
        #key_file: /etc/redpanda/certs/broker.key
        truststore_file: /etc/redpanda/certs/ca.crt
```


## Or manually on the command line

You might not want to mess with editing your `redpanda.yaml` when using `rpk`, so you can add these configurations via the CLI:

`rpk cluster info --brokers 3.15.15.173:9092 --tls-enabled --tls-truststore /path/to/ca.crt`

Here I've used my broker's public IP, which is allowed because it was included in the `broker.cnf` when the certs were generated.  If that IP address had not been included at that time you would see this error:

```
unable to request metadata: unable to dial: tls: failed to verify certificate: x509: certificate is valid for 10.100.8.26, not 3.15.15.172
```

---

# Troubleshooting


## Invalid large response 

```
unable to request metadata: invalid large response size 352518912 > limit 104857600; the first three bytes received appear to be a tls alert record for TLS v1.2; is this a plaintext connection speaking to a tls endpoint?
```

This is usually indicative of having not enabled TLS for `rpk`.   Add `enabled: true` to the `tls:` section under `rpk:` in your `redpanda.yaml`, OR add `--tls-enabled` to your `rpk` CLI call.


## Certificate is not trusted

```
unable to request metadata: unable to dial: tls: failed to verify certificate: x509: “Redpanda” certificate is not trusted
```

This is usually because `rpk` isn't looking at the truststore.   Add `truststore_file: /path/to/ca.crt` to the `tls:` section under `rpk:` in your `redpanda.yaml`, OR add `--tls-truststore /path/to/ca.crt` to your `rpk` CLI call.


## Valid for [IP/host], not valid for [IP/host]

```
unable to request metadata: unable to dial: tls: failed to verify certificate: x509: certificate is valid for 10.100.8.26, not 3.15.15.172
```

This is usually because your `rpk` call is specifiying a broker address that was not part of the `broker.cnf` when the certificates were created & signed.   To resolve this, add the IP address (or DNS name) to the `[ alt_names ]` section of `broker.cnf` 

```
[ alt_names ]
DNS.1 = localhost
DNS.2 = redpanda
DNS.3 = console
DNS.4 = connect
DNS.5 = ec2-3-15-15-172.us-east-2.compute.amazonaws.com
IP.1  = 10.100.8.26
IP.2  = 3.15.15.172
```
