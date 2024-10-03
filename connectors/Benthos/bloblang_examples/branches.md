
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



