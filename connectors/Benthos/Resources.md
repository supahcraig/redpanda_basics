# Using Resources within Redpanda Connect

https://docs.redpanda.com/redpanda-connect/configuration/resources/


## Completee Section Injection

```yaml
input:
  generate:
    interval: 1s
    mapping: |
      root.id = random_int()
      root.generic_text = ["frosty", "spot", "oodles"].index(random_int() % 3)
      root.ts = now()

output:
  resource: rez


output_resources:
  - label: rez
    aws_dynamodb:
      table: cnelson-benthos-test
      string_columns:
        id: ${!json("id")}
        full_content: ${!content()}

      batching:
        count: 5
        period: 2m

      credentials:
        id: <your aws id>
        secret: <your aws secret>
```


```console
rpk connect run \
--set "output_resources.0.aws_dynamodb.credentials.id=`vault kv get -mount=secret -field=id myAWS`" \
--set "output_resources.0.aws_dynamodb.credentials.secret=`vault kv get -mount=secret -field=secret myAWS`" \
dynamoDB-with-resource-local.yaml
```

## Partial Injection

(( work in progress ))


```yaml
input:
  generate:
    interval: 1s
    mapping: |
      root.id = random_int()
      root.generic_text = ["frosty", "spot", "oodles"].index(random_int() % 3)
      root.ts = now()

output:
  aws_dynamodb:
  resource: rez


output_resources:
  - label: rez
    table: cnelson-benthos-test
    string_columns:
      id: ${!json("id")}
      full_content: ${!content()}

    batching:
      count: 5
      period: 2m

    credentials:
      id: <your aws id>
      secret: <your aws secret>
```
