# Enabling TLS from Ground Zero

https://docs.redpanda.com/docs/manage/security/encryption/

Josh Purcell repo also has good info:  https://github.com/vuldin/redpanda-tls-sso/blob/main/README-rhel.md



# USING TERRAFORM

you may find it easier to create the certs locally using Terraform, and then copy them up to the server.   Check the README in the TLS section of this repo for details.


## Pre-requisites

### Certificate Authority Config

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


### Broker Config

This will need to go into a file called `broker.cnf`

You will need to modify the `[ alt names ]` section as per your speficic needs.   For POC purposes, what you'll probably want is to include at a minimum the _private_ IP's of your brokers.   In this example I've included the private DNS, the private IP, and the public IP of _one_ of my brokers.   

_TODO:  verify that including all those addresses for all brokers in this one file works_

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
DNS.5 = ec2-3-15-15-272.us-east-2.compute.amazonaws.com
IP.1  = 10.0.8.1
IP.2  = 3.15.15.172
```


---


## Generate & sign the certs

This can be done from anywhere, but ultimately the 3 files (`ca.crt`, `ca.key`, and `broker.crt`) will need to be on each broker, owned & readable by redpanda


## Redpanda doc, distilled & re-sequenced (plus the missing step)


```console
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
sudo chmod 444 broker.key broker.crt ca.crt
```



_THIS SECTION IS DEPRECATED....probably?_

```console
rm -f *.crt *.csr *.key *.pem index.txt* serial.txt*

openssl genrsa -out ca.key 2048
chmod 400 ca.key
openssl req -new -x509 -config ca.cnf -key ca.key -days 365 -batch -out ca.crt


# Create a certificate for your broker
openssl genrsa -out broker.key 2048
openssl req -new -key broker.key -out broker.csr -nodes -config broker.cnf
touch index.txt
echo '01' > serial.txt
openssl ca -config ca.cnf -keyfile ca.key -cert ca.crt -extensions extensions -in broker.csr -out broker.crt -outdir . -batch

chown redpanda:redpanda ca.key
chown redpanda:redpanda ca.crt
chown redpanda:redpanda broker.crt
```



---

### Breaking down the steps in the script

These steps can be run from anywhere.   There are several ancillary output files that can be removed later, but the three important ones are:
* `ca.crt`
* `ca.key`
* `broker.crt`

These will need to be owned & accessible by redpanda.  The standard location for these is `/etc/redpanda/certs/` but you will specify this location in your `redpanda.yaml` (unless you want to specify it for every `rpk` command on the CLI).


**1.  Generating the certificate authority private key**

`openssl genrsa -out ca.key 2048`

This uses openssl to generate a private key, which will be the private key for our certificate authority (CA).


**2.  Generate a public cert for the CA**

`openssl req -new -x509 -config ca.cnf -key ca.key -days 365 -batch -out ca.crt`

Here we are creating a root certificate that validates itself.   Any certs which are later signed by this will be valid.   


**3.  Generate your broker private key**

`openssl genrsa -out broker.key 2048`

This uses openssl to generate a private key which your brokers will use.  You will use this one key for ALL your brokers.


**4.  Generate the private broker certificate signing request (csr)**

`openssl req -new -key broker.key -out broker.csr -nodes -config broker.cnf`

This generates a certificate signing request (which is really just an unsigned cert) for your broker.


**5.  Pure black magic**

```
touch index.txt
echo '01' > serial.txt
```

I mean, I understand what in the unix this is doing, but I have no idea why it's important.  These files have something to do with a sort of database which is referred (implicitly) to in the `ca.cnf`


**6.  Have the CA sign the broker cert**

`openssl ca -config ca.cnf -keyfile ca.key -cert ca.crt -extensions extensions -in broker.csr -out broker.crt -outdir . -batch`

This will sign the broker cert signing request (`broker.csr`) using the CA certficate (`ca.crt`) and apparently the CA private key (`ca.key`), the output will by the signed broker cert (`broker.crt`) into the current directory.


**7.  Make redpanda the owner of the certs & keys

`chmod 444` here allows rpk commands to be run from the broker w/o needing `sudo`.  `chmod 400` is probably a better practice but is a hassle for what we're doing here.

```
chown redpanda:redpanda broker.key broker.crt ca.crt 
chmod 444 broker.key broker.crt ca.crt 
```

---

## Conifguring `redpanda.yaml`

In order for redpanda to use TLS it must be configured to use TLS for various services.   More docs (which may or may not be helpful) on configuration options in `redpanda.yaml` can be found here:  https://docs.redpanda.com/docs/reference/node-configuration-sample/

### Redpanda

To allow TLS on the kafka api, you'll need to add a `kafka_api_tls` section under `redpanda`, where the path to the certs corresponds to the final resting place of the certs you created above.   Most commonly this is `/etc/redpanda/certs/`

```yaml
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

```yaml
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

## Copying the keys to the other brokers

There is probably a more secure way to do this, such as copying up to s3.

1.  Copy the certs down to your local machine
   
```console
scp -v -i ~/pem/cnelson-kp.pem ubuntu@18.118.226.7:/etc/redpanda/certs/{broker.key,broker.crt,ca.crt} .
```

2.  Copy the certs back up to the remaining remote machines

```console
scp -i ~/pem/cnelson-kp.pem broker.key broker.crt ca.crt ubuntu@3.128.255.84:/home/ubuntu/broker.key
scp -i ~/pem/cnelson-kp.pem broker.key broker.crt ca.crt ubuntu@3.138.101.143:/home/ubuntu/broker.key
```


3.  On each broker, move certs to `/etc/redpanda/certs` + chown/chmod to allow redpanda to read the certs

Run this as sudo

```console
sudo -i
mkdir /etc/redpanda/certs/
cp /home/ubuntu/broker.key /etc/redpanda/certs/broker.key
cp /home/ubuntu/broker.crt /etc/redpanda/certs/broker.crt
cp /home/ubuntu/ca.crt /etc/redpanda/certs/ca.crt

chown redpanda:redpanda /etc/redpanda/certs/broker.key /etc/redpanda/certs/broker.crt /etc/redpanda/certs/ca.crt 
chmod 444 /etc/redpanda/certs/broker.key /etc/redpanda/certs/broker.crt /etc/redpanda/certs/ca.crt 
```

---
---


# Troubleshooting


## Invalid large response 

```logtalk
unable to request metadata: invalid large response size 352518912 > limit 104857600; the first three bytes received appear to be a tls alert record for TLS v1.2; is this a plaintext connection speaking to a tls endpoint?
```

This is usually indicative of having not enabled TLS for `rpk`.   Add `enabled: true` to the `tls:` section under `rpk:` in your `redpanda.yaml`, OR add `--tls-enabled` to your `rpk` CLI call.


## Certificate is not trusted

```logtalk
unable to request metadata: unable to dial: tls: failed to verify certificate: x509: “Redpanda” certificate is not trusted
```

This is usually because `rpk` isn't looking at the truststore.   Add `truststore_file: /path/to/ca.crt` to the `tls:` section under `rpk:` in your `redpanda.yaml`, OR add `--tls-truststore /path/to/ca.crt` to your `rpk` CLI call.

I think it could also be because of self-signed certs, which is resolved by adding `-X admin.tls.insecure_skip_verify=true` to admin api calls (unsure what the exact flag is for kafka API or RPC) OR you can add it to the rpk section of your yaml:

```yaml
kafka_api:
    brokers:
        - 3.17.174.176:9092
    tls:
        insecure_skip_verify: true
admin_api:
    addresses:
        - 3.17.174.176:9644
    tls:
        insecure_skip_verify: true
```


## Valid for [IP/host], not valid for [IP/host]

```logtalk
unable to request metadata: unable to dial: tls: failed to verify certificate: x509: certificate is valid for 10.100.8.26, not 3.15.15.172
```

This is usually because your `rpk` call is specifiying a broker address that was not part of the `broker.cnf` when the certificates were created & signed.   To resolve this, add the IP address (or DNS name) to the `[ alt_names ]` section of `broker.cnf` 

```ini
[ alt_names ]
DNS.1 = localhost
DNS.2 = redpanda
DNS.3 = console
DNS.4 = connect
DNS.5 = ec2-3-15-15-172.us-east-2.compute.amazonaws.com
IP.1  = 10.100.8.26
IP.2  = 3.15.15.172
```

You may _still_ see this error in some cases... perhaps the most common case would be trying to access the cluster remotely using the public IP.  Internally AWS does a NAT translation at the gateway to turn that public IP to a private IP, meaning that the EC2 instance never sees the public IP.  The `alt_names` section of your `broker.cnf` needs to have the private IP, even for public access.   This could also cause you problems when setting up your redpanda listeners, since redpanda can't really bind to the public IP due to this routing.  More info here:  https://repost.aws/questions/QUGknveVnmTfyJ4auBUEeJqg/public-ip-address-connectivity-in-aws



---

## Redpanda doc, distilled & re-sequenced (plus the missing step)


```console
rm -f *.crt *.csr *.key *.pem index.txt* serial.txt*

openssl genrsa -out ca.key 2048
chmod 400 ca.key
openssl req -new -x509 -config ca.cnf -key ca.key -days 365 -batch -out ca.crt


# Create a certificate for your broker
openssl genrsa -out broker.key 2048
openssl req -new -key broker.key -out broker.csr -nodes -config broker.cnf
touch index.txt
echo '01' > serial.txt
openssl ca -config ca.cnf -keyfile ca.key -cert ca.crt -extensions extensions -in broker.csr -out broker.crt -outdir . -batch
```
