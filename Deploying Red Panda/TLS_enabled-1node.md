# One Node TLS enable setup

https://docs.redpanda.com/docs/manage/security/encryption/

Check my other docs for additional TLS info & troubleshooting.

**NOTE:  All these steps should be run on the broker.  They can be run locally, but then you have to copy them up.**


---

## Create the folder structure & permissions

```
sudo mkdir /etc/redpanda/certs
sudo chown redpanda:redpanda /etc/redpanda/certs
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

You will need to modify the `[ alt names ]` section as per your speficic needs.   For POC purposes, what you'll probably want is to include at a minimum the _private_ IP's of your brokers.   In this example I've included the private DNS, the private IP, and the public IP of my only broker.   


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
DNS.5 = ec2-3-15-15-272.us-east-2.compute.amazonaws.com
IP.1  = 10.0.8.1
IP.2  = 3.15.15.172
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

chown redpanda:redpanda broker.key broker.crt ca.crt
chmod 400 broker.key broker.crt ca.crt
```




```
# cleanup
rm -f *.crt *.csr *.key *.pem index.txt* serial.txt*

# create broker key
openssl genrsa -out broker.key 2048

# create a ca key to self-sign certificates
openssl genrsa -out ca.key 2048
chmod 400 ca.key

# create a public cert for the CA
openssl req -new -x509 -config ca.cnf -key ca.key -days 365 -batch -out ca.crt

# generate csr
openssl req -new -key broker.key -out broker.csr -nodes -config broker.cnf

# sign the certificate with the CA signature
touch index.txt
echo '01' > serial.txt
openssl ca -config ca.cnf -keyfile ca.key -cert ca.crt -extensions extensions -in broker.csr -out broker.crt -outdir . -batch

chown redpanda:redpanda broker.key broker.crt ca.crt
chmod 400 broker.key broker.crt ca.crt
```




