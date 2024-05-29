
# Generate Certs

You can do this via terraform (https://github.com/supahcraig/redpanda_basics/blob/main/Deploying%20Red%20Panda/TLS/README.md)

OR you can do it by hand using `openssl` by following the instructions below. 

Regardless of the method, once you have the keys on the server with the correct permissions, all the remaning steps are the same.


## Create the folder structure & permissions

```console
sudo mkdir /etc/redpanda/certs
sudo chown redpanda:redpanda /etc/redpanda/certs
sudo chmod 777 /etc/redpanda/certs
cd /etc/redpanda/certs
```

---

## Certificate Authority Config

This will need to go as-is into a file named `ca.cnf`

```ini
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

You will need to modify the `[ alt names ]` section as per your speficic needs.   For POC purposes, what you'll probably want is to include at a minimum the _private_ IP's of your brokers.   In this example I've included the private DNS, the private IP, and the public IP of my only broker.   If you happen to have multiple brokers, the `broker.cnf` will need additional entries for the DNS & IP's of the brokers.


```ini
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


```console
# cleanup
rm -f *.crt *.csr *.key *.pem index.txt* serial.txt*

# create a ca key to self-sign certificates  // OUTPUT = ca.key
openssl genrsa -out ca.key 2048
chmod 400 ca.key

# create a public cert for the CA  // OUTPUT = ca.crt
openssl req -new -x509 -config ca.cnf -key ca.key -days 365 -batch -out ca.crt

# create broker key  // OUTPUT = broker.key
openssl genrsa -out broker.key 2048

# generate Certificate Signing Request  // OUTPUT = broker.csr
openssl req -new -key broker.key -out broker.csr -nodes -config broker.cnf

# sign the certificate with the CA signature  // OUTPUT = broker.crt
touch index.txt
echo '01' > serial.txt
openssl ca -config ca.cnf -keyfile ca.key -cert ca.crt -extensions extensions -in broker.csr -out broker.crt -outdir . -batch

sudo chown redpanda:redpanda broker.key broker.crt ca.crt
sudo chmod 444 broker.key broker.crt ca.crt
```
