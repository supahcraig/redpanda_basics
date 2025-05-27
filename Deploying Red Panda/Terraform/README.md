Redpanda Docs:  https://docs.redpanda.com/redpanda-cloud/manage/terraform-provider/

They reference version `1.0` but that currently (as of 5/27/2025) has an issue where no cidr range is accepted.   Version `0.10.1` is a known working version.


## Assumptions

The redpanda provider block can run off environment variables, or be specified in the block:

If you have environment variables defined like this, you can leave the provider block empty:

```bash
REDPANDA_CLIENT_ID="<your_client_id>"
REDPANDA_CLIENT_SECRET="<your_client_secret>"
```

```hcl
# Redpanda provider configuration
provider "redpanda" {
}
```


Or you can specify them in the block:

```hcl
# Redpanda provider configuration
provider "redpanda" {
  client_id     = "<your_client_id>"
  client_secret = "<your_client_secret>"
}
```
