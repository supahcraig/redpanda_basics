Use switch to conditionally route output.

Using the `log_level` field of the input document, switch/case can route the output to different outputs.   Here they are different kafka topics, but there is no reason the different cases couldn't use completely different output processors (i.e. kafka, file, http, database, etc)

```yaml
output:
  switch:
    cases:
      - check: this.log_level == "ERROR"
        output:
          kafka_franz:
            seed_brokers: [ ${RP_ADDRESS} ]
            topic: "raw_error"
      - check: this.log_level == "WARNING"
        output:
          kafka_franz:
            seed_brokers: [ ${RP_ADDRESS} ]
            topic: "raw_warning"
      - output:
          kafka_franz:
            seed_brokers: [ ${RP_ADDRESS} ]
            topic: "raw_info"
```
