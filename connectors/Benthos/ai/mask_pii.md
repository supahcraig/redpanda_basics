


```yaml
input:
  file:
    paths: ["emails/email_one.txt"]
    scanner:
      to_the_end: {}
pipeline:
  processors:
    - ollama_chat:
        model: llama3.1:70b
        prompt: |
          The current context information is provided.
          A task is also provided to mask the PII within the context.
          Return the text, with all PII masked out, and a mapping of the original PII to the masked PII.
          Return the output of the task in JSON ONLY.
          Context:
          Hello Zhang Wei, I am John. Your AnyCompany Financial Services, LLC credit card account 1111-0000-1111-0008 has a minimum payment of $24.53 that is due by July 31st. Based on your autopay settings, we will withdraw your payment.
          Task: Mask out the PII, replace each PII with a tag, and return the text. Return the mapping in JSON ONLY.
          Output:
          {
            "content": "Hello [NAME1], I am [NAME2]. Your AnyCompany Financial Services, LLC credit card account [CREDIT_CARD_NUMBER] has a minimum payment of $24.53 that is due by [DATE_TIME]. Based on your autopay settings, we will withdraw your payment.",
            "replacements": {"NAME1": "Zhang Wei", "NAME2": "John", "CREDIT_CARD_NUMBER": "1111-0000-1111-0008", "DATE_TIME": "July 31st"}
          }
          Context:
          ${!content().string()}
          Task: Mask out the PII, replace each PII with a tag, and return the text. Return the mapping in JSON ONLY.
          Output:
output:
  stdout:
    codec: lines
```


```bash
docker run -v $PWD/connect.yaml:/connect.yaml redpanda-data/connect:4-ai -- run --log.level=trace
docker run -v $PWD/pii.yaml:/connect.yaml redpandadata/connect:4-ai -- run --log.level=trace
```

Simple AI example

using `kafka`

```yaml
input:
  kafka:
    addresses: ["crgsf2gj1v2u1117mal0.any.us-east-1.mpx.prd.cloud.redpanda.com:9092"]
    topics: ["input_topic"]
    consumer_group: "redpanda-connect-ai-consumer-group"

    tls:
      enabled: true
    sasl:
      - mechanism: SCRAM-SHA-256
        username: test-user
        password: test-pass

pipeline:
  processors:
    - ollama_chat:
        model: llama3.1
        system_prompt: "You are to summarize user input in a concise sentence"
output:
  kafka:
    addresses: ["crgsf2gj1v2u1117mal0.any.us-east-1.mpx.prd.cloud.redpanda.com:9092"]
    topic: "summarized-articles"

    tls:
      enabled: true
    sasl:
      - mechanism: SCRAM-SHA-256
        username: test-user
        password: test-pass

```



using `kafka_franz`

```yaml
input:
  kafka_franz:
    seed_brokers:
      - crgsf2gj1v2u1117mal0.any.us-east-1.mpx.prd.cloud.redpanda.com:9092
    topic: "input_topic"
    consumer_group: "redpanda-connect-ai-consumer-group"

    tls:
      enabled: true
    sasl:
      - mechanism: SCRAM-SHA-256
        username: test-user
        password: test-pass

pipeline:
  processors:
    - ollama_chat:
        model: llama3.1
        system_prompt: "You are to summarize user input in a concise sentence"

output:
  kafka_franz:
    seed_brokers:
      - crgsf2gj1v2u1117mal0.any.us-east-1.mpx.prd.cloud.redpanda.com:9092
    topic: "summarized-articles"

    tls:
      enabled: true
    sasl:
      - mechanism: SCRAM-SHA-256
        username: test-user
        password: test-pass
```
