This generates some data randomly, which may or may not have the `foo` field present.  It checks for the existence of `foo` and throws an error if not found.   Then updates the message medata data accordingly, and the output will route to the topic defined in the metadata.


```yaml
input:
  generate:
    interval: 1s
    count: 0
    mapping: |
      root = if random_int() % 2 == 0 {
        { "foo": "some value", "bar": "always here" }
      } else {
        { "bar": "always here" }
      }

pipeline:
  processors:
    - mapping: |
        meta topic = "topic_validated"
    - mapping: |
        root = if this.foo == null {
          throw("Missing 'foo' field")
        } else {
          this
        }
    - catch:
        - log:
            level: ERROR
            message: "Validation failed: ${!error()}"
        - mapping: |
            meta topic = "topic_failed"


output:
    label: "the_producer"
    kafka_franz:
      seed_brokers:
        - ${REDPANDA_BROKERS}
      topic: ${! meta("topic") }

      tls:
        enabled: true

      sasl:
        - mechanism: SCRAM-SHA-256
          username: ${secrets.CNELSON_SASL_USER}
          password: ${secrets.CNELSON_SASL_PASSWORD}
