
what does this do?

looks like it does the geo_location & error_count in parallel.


```yaml
pipeline:
  processors:
    - workflow:
        meta_path: meta.workflow
        branches:
          geo_location:
            request_map: |
              root.ip = this.client_ip
            processors:
              - cached:
                  key: '${! ip }'
                  cache: ip_cache
                  processors:
                    - http:
                        url: http://localhost:8081/geo/lookup
                        verb: POST
            result_map: |
              root.ip = deleted()
              root.ip_continent = deleted()
              root.geo_info = this.geo_info
          error_count:
            request_map: |
              root.ip = this.client_ip
              root.source_system = this.source_system
              root.message = this.message
              root.priority = this.priority
            processors:
              - http:
                  url: http://localhost:8082/error/count
                  verb: POST
```



This example will add a field to the payload in each branch

```yaml
input:
  generate:
    interval: 1s
    mapping: |
      root.Name = ["frosty", "spot", "oodles"].index(random_int() % 3)
      root.Gooeyness = (random_int() % 100) / 100

pipeline:
  processors:
    - workflow:
        meta_path:  meta.workflow
        branches:
          b1:
            processors:
              - mapping: |-
                  root = this

            result_map: root.b1 = "branch b1"

          b2:
            processors:
              - mapping: |-
                  root = this
                  root.processorb1 = "processor mapping b2"

            result_map: root.b2 = "branch b2"
output:
   stdout: {}
```
