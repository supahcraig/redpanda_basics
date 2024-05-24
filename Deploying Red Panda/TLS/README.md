Terraform provided by Sir Michael Maltese to generate certs/keys for TLS w/o using `openssl`.

Currently it's hardcoded for `127.0.0.1` but you'll probably want to add the public/private IP's for your cluster.

## Generate Keys & Certs

```console
terraform init
terraform apply --auto-approve
```
