Makes use of context variables in BYOC, so you don't need to know the bootstrap or schema registry url.


```yaml
input:
    kafka_franz:
      seed_brokers:
        - ${REDPANDA_BROKERS}
      topics:
        - schema_reg_encode_test

      consumer_group: "schema_reg_consumer"

      tls:
        enabled: true

      sasl:
        - mechanism: SCRAM-SHA-256
          username: ${secrets.CNELSON_SASL_USER}
          password: ${secrets.CNELSON_SASL_PASSWORD}

pipeline:
  processors:
    - label: "schema_decoder"
      schema_registry_decode:
        url: ${REDPANDA_SCHEMA_REGISTRY_URL}
        cache_duration: 10m

        basic_auth:
          enabled: true
          username: cnelson
          password: test

    - catch:
      - log:
          level: ERROR
          message: ${! error() }
      - bloblang: root = deleted()

output:
    label: "the_producer"
    kafka_franz:
      seed_brokers:
        - ${REDPANDA_BROKERS}
      topic: schema_reg_decode_test

      tls:
        enabled: true

      sasl:
        - mechanism: SCRAM-SHA-256
          username: ${secrets.CNELSON_SASL_USER}
          password: ${secrets.CNELSON_SASL_PASSWORD}

