# Allowing rpk to talk to remote cluster

Assuming you have rpk installed on your local machine, you may want to use rpk to talk to your remote BYOC cluster.   The brute force way is to issue all the flags on the command line, like this:

`export REDPANDA_BROKERS="blahblahblah.byoc.prd.cloud.redpanda.com:9092"`

That environment variable is leveraged by rpk, although you can list the brokers out in the command with the `--brokers` flag.

```
rpk topic list \
  --tls-enabled \
  --sasl-mechanism SCRAM-SHA-256 \
  --user "your user name" \
  --password "your password"
```

But you probably don't want to do that every time you run an rpk command.  Instead, you can put all this into a yaml config file.   Let's not worry about the fact that a plaintext password in a plaintext file is probably not all that secure.  `rpk` will look for `redpanda.yaml` in the following locations, in order of precedence:

1.  `--config` flag pointing to a specific instance of `redpanda.yaml`
2.  `/etc/redpanda/redpanda.yaml`
3.  current working directory
4.  `~/redpanda.yaml` _(this location may not be supported long term, and isn't documented)_

More/better options for using evironment variables and `./config/rpk` are coming soon, per Rogger Vasquez

---

In `redpanda.yaml` you'll only need this section to perform rpk functions.   Much more on `redpanda.yaml` can be found in the docs (https://docs.redpanda.com/docs/reference/node-configuration-sample/)

```
rpk:
    kafka_api:
        brokers:
        - seed-2217bb6c.ch08a3a80qtl7p20ouv0.byoc.prd.cloud.redpanda.com:9092

        tls:
            enabled: true
            
        sasl:
            user: user_name_no_quotes
            password: your_password_no_quotes
            type: SCRAM-SHA-256
```


