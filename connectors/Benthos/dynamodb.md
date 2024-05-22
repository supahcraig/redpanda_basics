# Sink to DynamoDB



```
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


```
{"id": 99, "stuff": "more stuff"}
{"id": 99, "stuff": "different stuff"}
{"id": 1007, "idk": "try this"}
{"id": 1007, "check": "updated brah"}
```
