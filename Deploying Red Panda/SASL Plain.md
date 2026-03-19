Assumes you have a 1-node SH cluster


## Overview

1.  Edit `redpanda.yaml` for sasl auth & superusers

2.  Restart redpanda

3.  Create the superuser (create profile?)

4.  Create normal user

5.  Grant ACLs to the user

6.  Create an rpk profile for you user

7.  Enable SASL PLAIN

8.  Verify SASL PLAIN with kcat

---

## (1) Edit redpanda.yaml

We need to take our existing yaml and:

* add the authentication method to the listner
* enable sasl
* add the superuser to the list
* require auth on the admin api

This change needs to be made to every broker.

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
        - name: external
          address: 0.0.0.0
          port: 9092
          authentication_method: sasl
    admin:
        - address: 0.0.0.0
          port: 9644
    advertised_kafka_api:
        - name: external
          address: 10.100.1.11
          port: 9092
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

Or the two-listener approach:

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
    admin:
        - address: 0.0.0.0
          port: 9644
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


## (2) Restart Redpanda

Once you have edited the yaml on all brokers, each broker must be restarted for the change to take effect.

```bash
sudo systemctl restart redpanda
```

## (3) Create the superuser & profile

No auth required for the first user bootstrap. 

```bash
rpk acl user create admin --password 'adminpassword' --api-urls localhost:9644
```

To aid in future steps, create an `rpk profile` for the admin user.

```bash
rpk profile create admin \
  --set kafka_api.brokers=localhost:9092 \
  --set kafka_api.sasl.user=admin \
  --set kafka_api.sasl.password=adminpassword \
  --set kafka_api.sasl.mechanism=SCRAM-SHA-256 \
  --set admin_api.addresses=localhost:9644
```

This will also tell rpk to use this profile going forward.  Verify it's working with `rpk cluster info`

This is still using SASL SCRAM, we're just verifying things are working.

## (4) Create a normal user

```bash
rpk acl user create test-user --password test
```

## (5) Create ACLs for your user

```bash
rpk acl create \
  --allow-principal User:cnelson \
  --operation describe \
  --topic '*' \
  --brokers localhost:9092 \
  --user admin --password 'adminpassword'
```

## (6) Create an `rpk profile` for your user


```bash
rpk profile create cnelson \
  --set kafka_api.brokers=localhost:9092 \
  --set kafka_api.sasl.user=cnelson \
  --set kafka_api.sasl.password=yourpassword \
  --set kafka_api.sasl.mechanism=SCRAM-SHA-256 \
  --set admin_api.addresses=localhost:9644

rpk profile use cnelson
```

Test your profile, user, and ACLs by again running `rpk cluster info`

## (7) Enable SASL PLAIN

First switch back to the admin user...

```bash
rpk profile use admin
```

Then update the cluster settings, which Redpanda will automatically propagate to all brokers.  No restart is required.

```bash
rpk cluster config set sasl_mechanisms '["SCRAM","PLAIN"]'
```

Redpanda requires SCRAM to be enabled if PLAIN is enabled.  You can verify the settings are in effect by fetching the cluster settings.

```bash
rpk cluster config get sasl_mechanisms
```

should return:

```bash
- SCRAM
- PLAIN
```

## (8) Verify SASL PLAIN with kcat

Since rpk can't be configured to use SASL PLAIN, we will need to use `kcat` to test this.  Install kcat:

```bash
sudo apt install kcat
```

Then make a call to your cluster using SASL PLAIN:

```bash
kcat -b localhost:9092 \
  -X security.protocol=SASL_PLAINTEXT \
  -X sasl.mechanism=PLAIN \
  -X sasl.username=myuser \
  -X sasl.password=yourpassword \
  -L
```

Should return some info on your topics via SASL PLAIN.  You can further verify this is working by setting the sasl_mechanisms back to SCRAM and re-running kcat.  It should fail with a SASL error.

## (9) Test remotely

On your local machine (for example), create a new profile and prove you have clean connectivity & auth, albeit via SCRAM.

```bash
rpk profile create sasl_remote \
  --set kafka_api.brokers=13.59.253.84:19092 \
  --set kafka_api.sasl.user=cnelson \
  --set kafka_api.sasl.password=yourpassword \
  --set kafka_api.sasl.mechanism=SCRAM-SHA-256

rpk profile use remote
rpk topic list
```

Use kcat to test SASL PLAIN.

```bash
kcat -b 13.59.253.84:19092 \
  -X security.protocol=SASL_PLAINTEXT \
  -X sasl.mechanism=PLAIN \
  -X sasl.username=myuser \
  -X sasl.password=yourpassword \
  -L
```


