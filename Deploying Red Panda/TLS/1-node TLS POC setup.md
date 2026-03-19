Setup:   I have a single node RP "cluster" in ec2 that we need to set up TLS on.

They already have their signed certs, but we need to generate our own using the terraform in this folder.   

## Install terraform on EC2

```bash
# Install prerequisites
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common

# Add HashiCorp's GPG key
wget -O- https://apt.releases.hashicorp.com/gpg | \
  gpg --dearmor | \
  sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

# Add the HashiCorp repo
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list

# Install Terraform
sudo apt-get update && sudo apt-get install -y terraform
```


## Generate the certs

You'll need to modify this resource section with your addresses.  I needed the public IP as well because I'm also testing remote connectivity.   You can also/instead use the FQDN hostnames...ultimately whatever string a client types to connect to the broker must be in the cert.

```hcl
resource "tls_cert_request" "broker" {
  ip_addresses    = ["127.0.0.1", "13.59.253.84", "10.100.1.11"]
  dns_names    = ["localhost", "ip-10-100-1-11.us-east-2.compute.internal", "ec2-13-59-253-84.us-east-2.compute.amazonaws.com"]  
  private_key_pem = tls_private_key.broker.private_key_pem
}
```

```bash
terraform init
terraform apply --auto-approve
```

I ran this from `/etc/redpanda` because that's where I wanted the certs.  You'll see where this matters in a bit.

### Cert ownership/permissions

`redpanda:redpanda` must own the certs, and they will need these permissions or else the service won't even start.

```bash
sudo chown redpanda:redpanda /etc/redpanda/ca.crt /etc/redpanda/broker.crt /etc/redpanda/broker.key
sudo chmod 640 /etc/redpanda/ca.crt /etc/redpanda/broker.crt
sudo chmod 600 /etc/redpanda/broker.key
```


## Update redpanda.yaml

To force the brokers to require TLS we need to add a section for `kafka_api_tls` & `admin_api_tls` and then make sure our "name" tags match:

```yaml
redpanda:
    data_directory: /var/lib/redpanda/data
    seed_servers:
        - host:
            address: 10.100.1.11
            port: 33145
    rpc_server:
        address: 0.0.0.0
        port: 33145
    kafka_api:
        - name: internal
          address: 0.0.0.0
          port: 9092
          authentication_method: sasl
        - name: external
          address: 0.0.0.0
          port: 19092
          authentication_method: sasl

    kafka_api_tls:                                       # NEW SECTION
        - name: internal                                 # matches listener name above
          enabled: true
          cert_file: /etc/redpanda/broker.crt
          key_file: /etc/redpanda/broker.key
          truststore_file: /etc/redpanda/ca.crt
          require_client_auth: false
        - name: external                                 # matches listener name above
          enabled: true
          cert_file: /etc/redpanda/broker.crt
          key_file: /etc/redpanda/broker.key
          truststore_file: /etc/redpanda/ca.crt
          require_client_auth: false

    admin:
        - name: admin
          address: 0.0.0.0
          port: 9644

    admin_api_tls:
        - name: admin
          enabled: true
          cert_file: /etc/redpanda/broker.crt
          key_file: /etc/redpanda/broker.key
          truststore_file: /etc/redpanda/ca.crt
          require_client_auth: false

    advertised_kafka_api:
        - name: internal
          address: 10.100.1.11
          port: 9092
        - name: external
          address: 13.59.253.84
          port: 19092
    advertised_rpc_api:
        address: 10.100.1.11
        port: 33145

    enable_sasl: true
    superusers:
        - admin
    admin_api_require_auth: true
rpk:
    coredump_dir: /var/lib/redpanda/coredump
```

And then restart the redpanda service.


## Update rpk profiles

You'll need to add a small section to your rpk profile to use tls....but since we are using self-signed certs we need to add a little extra sugar.

```yaml
name: admin
description: ""
prompt: ""
from_cloud: false
kafka_api:
    brokers:
        - 127.0.0.1:9092
    tls:
        insecure_skip_verify: true  ### if your certs are properly signed, all you need is tls: {}
    sasl:
        user: admin
        password: '[REDACTED]'
        mechanism: PLAIN
admin_api:
    addresses:
        - 127.0.0.1:9644
    tls:
        insecure_skip_verify: true  ### if your certs are properly signed, all you need is tls: {}
schema_registry: {}
```

### Why no admin auth section?

Great question. The admin API uses HTTP Basic Auth, not SASL — they're completely separate authentication mechanisms.
SASL is a Kafka protocol concept and only applies to the kafka_api section. The admin API is a plain REST API, so it uses HTTP Basic Auth instead.
rpk handles this automatically — when admin_api_require_auth: true is set in redpanda.yaml, rpk pulls the credentials from the sasl block in your profile's kafka_api section and uses them as the HTTP Basic Auth username/password when talking to the admin API.

So the existing profile already has everything it needs.

---

# Redpanda Console

## Install Redpanda Console

```bash
curl -1sLf 'https://dl.redpanda.com/nzc4OOIPU8YsaGar/redpanda/cfg/setup/bash.deb.sh' | sudo bash
sudo apt-get install -y redpanda-console
```

This will put a default console config under `/etc/redpanda/redpanda-console.yaml` but we'll need to modify it before we go any further.


## redpanda-console.yaml

Again, we have to use `insecureSkipTlsVerify` because my certs are self-signed.  Properly signed certs can omit those lines.

```yaml
kafka:
    brokers:
        - 10.100.1.11:9092
    tls:
        enabled: true
        insecureSkipTlsVerify: true        # since we're using self-signed certs
    sasl:
        enabled: true
        username: admin
        password: adminpassword
        mechanism: PLAIN

redpanda:
    adminApi:
        enabled: true
        urls:
            - https://10.100.1.11:9644
        tls:
            enabled: true
            insecureSkipTlsVerify: true
```

And then restart the redpanda-console service.
