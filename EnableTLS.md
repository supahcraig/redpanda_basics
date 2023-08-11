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

chown redpanda:redpanda *
```

### Breaking down the steps in the script

**1.  Generating the certificate authority private key**

`openssl genrsa -out ca.key 2048`

This uses openssl to generate a private key, which will be the private key for our CA.

**2.  Self signing the root certificate

`openssl req -new -x509 -config ca.cnf -key ca.key -days 365 -batch -out ca.crt`

Here we are creating a root certificate that validates itself.   Any certs which are later signed by this will be valid.  
