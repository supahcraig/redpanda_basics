# Creating a Lambda Redpanda Conumser against BYOC 

This is a very simple use case of a Lambda in a system-managed VPC connecting to a public-facing BYOC cluster.  


## Pre-reqs

* Redpanda SASL/SCRAM user/pass
* Bootstrap server URL
* Topic name


## Create IAM Role

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "lambda.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

Create the role using the saved json

```bash
aws iam create-role \
  --role-name lambda-redpanda-kafka-role \
  --assume-role-policy-document file://trust-policy.json
```

Then attach policies for execution and secrets
```bash
aws iam attach-role-policy \
  --role-name lambda-redpanda-kafka-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam attach-role-policy \
  --role-name lambda-redpanda-kafka-role \
  --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite
```


## Create a secret for the Redpanda SASL username/password

```bash
aws secretsmanager create-secret \
  --name redpanda/kafka/sasl-scram \
  --secret-string '{"username":"<your-username>","password":"<your-password>"}'
```

## Package up Lambda code

```python
import base64

def lambda_handler(event, context):
    for tp, records in event['records'].items():
        for record in records:
            msg = base64.b64decode(record['value']).decode('utf-8')
            print(f"From {tp}: {msg}")
```

and zip it up...

```bash
zip function.zip lambda_function.py
```

## Create the Lambda function

```bash
aws lambda create-function \
  --function-name RedpandaKafkaConsumer \
  --runtime python3.12 \
  --role arn:aws:iam::<your-account-id>:role/lambda-redpanda-kafka-role \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://function.zip
```


## Add the Kafka event source trigger

Replace the Kafka bootstrap server with your bootstrap url.  In Redpanda BYOC, this will be a single load balanced endpoint.   In self-hosted, you'll want to list all your brokers here.  Also use `SCRAM_256` or `SCRAM_512` consisitent with how you defined your user.  And then your topic name to consume.

```bash
aws lambda create-event-source-mapping \
  --function-name RedpandaKafkaConsumer \
  --self-managed-event-source '{"Endpoints": {"KafkaBootstrapServers": ["mycluster.redpanda.cloud:9093"]}}' \
  --topics my-topic \
  --source-access-configurations \
      Type=SASL_SCRAM_512_AUTH,URI="arn:aws:secretsmanager:<region>:<account-id>:secret:redpanda/kafka/sasl-scram-XXXXXX" \
  --batch-size 100 \
  --starting-position LATEST
```

Once it enables, you should see your consumed messages in CloudWatch.


# Destroy everything

```bash
aws lambda delete-event-source-mapping --uuid <mapping-uuid>
aws lambda delete-function --function-name RedpandaKafkaConsumer
aws iam delete-role --role-name lambda-redpanda-kafka-role
aws secretsmanager delete-secret --secret-id redpanda/kafka/sasl-scram
```
