# Logging with Benthos

By default logging is written to stdout/stderr.  You need to add a logging section to your config.

The logs are written to the file specified in the `file.path` field.  If rotation is enabled, once the log file gets to 10MB it will roll to a timestamp-appended version of that file and will be gzip'd.

Active log file:  `test.log`
Rolled log file:  `test-2024-06-21T15-22-35.698.log.gz`

${\color{red}TODO:}$  
currently only one iteration of the rotated logs are being retained.  Need to understand how to actually retain the `rotate_max_age_days` number of logs.
Discussion on the topic:  https://redpandadata.slack.com/archives/C0731175XA4/p1718983144093549


```yaml
input:
  generate:
    interval: 0.001s
    mapping: |
      root.ID = uuid_v4()
      root.Name = ["frosty", "spot", "oodles"].index(random_int() % 3)
      root.Gooeyness = (random_int() % 100) / 100



output:
  stdout: {}

logger:
  level: TRACE
  format: logfmt
  add_timestamp: true
  timestamp_name: ts
  file:
    path: test.log
    rotate: true
    rotate_max_age_days: 5
```
