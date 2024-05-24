Terraform provided by Sir Michael Maltese to generate certs/keys for TLS w/o using `openssl`.

Currently it's hardcoded for `127.0.0.1` but you'll probably want to add the public/private IP's for your cluster.

## Generate Keys & Certs

```console
terraform init
terraform apply --auto-approve
```

## Copy certs to broker(s)

You'll need `/etc/redpanda/certs` already created on all your brokers.

```console
scp -i ~/pem/cnelson-kp.pem broker.key broker.crt ca.crt ubuntu@18.217.77.188:/etc/redpanda/certs
```

## Update ownership & permissions

The certs/keys need to be readable by redpanda on each broker, so you'll need to set the ownership & permissions on each broker.

```console
sudo chown redpanda:redpanda broker.key broker.crt ca.crt
sudo chmod 444 broker.key broker.crt ca.crt
```


