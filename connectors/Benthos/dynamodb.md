# Sink to DynamoDB



```yaml
input:
  stdin: {}


output:
  label: ""
  aws_dynamodb:
    table: cnelson-benthos-test
    string_columns:
      id: ${!json("id")}
      full_content: ${!content()}

    batching:
      count: 5
      period: 2m

    credentials:
      id: YOUR_ACCESS_ID
      secret: YOUR_SECRET_KEY
```


# Input

type some json into stdin and it will show up in dynamo after 5 messages or 2 minutes, whichever comes first.  It uses the PutItem dynamoDB method, which will overwrite/update if there is a key collision.


```json
{"id": 99, "stuff": "more stuff"}
{"id": 99, "stuff": "different stuff"}
{"id": 1007, "idk": "try this"}
{"id": 1007, "check": "updated brah"}
```

---

# Using Vault for credentials.

## Set up Vault

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/vault

vault server -dev
vault secrets enable -version=1 kv
```

Find the vault token & address from when you started the server.  

```bash
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN="hvs.YOURvaultTOKEN"
```

```bash
vault kv put -mount=secret myAWS id=myAWSid secret=myAWSsecretKEY
vault kv get -mount=secret myAWS
```

I have my aws ID & secret stored in `myAWS.id` & `myAWS.secret` respectively.  Setting the secret reference on the command line will override the credentials in the yaml, so you can quite literally have `id: YOUR_ACCESS_KEY` in the yaml as I do above, and the below command will still work.

```bash
benthos -c dynamoDB-local.yaml \
--set "output.aws_dynamodb.credentials.id=`vault kv get -mount=secret -field=id myAWS`" \
--set "output.aws_dynamodb.credentials.secret=`vault kv get -mount=secret -field=secret myAWS`"
```

or using `rpk`:

Note that the `--set` flags need to precede the config in the args list.

```
rpk connect run \
--set "output.aws_dynamodb.credentials.id=`vault kv get -mount=secret -field=id myAWS`" \
--set "output.aws_dynamodb.credentials.secret=`vault kv get -mount=secret -field=secret myAWS`" \
dynamoDB-local.yaml
```



