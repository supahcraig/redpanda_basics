

Using the admin api within rpk

```
for t in `rpk topic list | awk '$1 !~/NAME/{print $1}'`; do rpk topic describe-storage $t | awk '$1~/NAME/{name = $2} $3~/[0-9]+/{sum += $3} END{print name, sum}'; done
```

---


Using grafana & public metrics:

```
sum by(redpanda_topic)(max by(redpanda_topic, redpanda_partition)(rate(redpanda_kafka_max_offset{redpanda_namespace="kafka",redpanda_id="cmnusu3qaeg64ledkssg"}[5m])))
```

and/or

```
sum by(redpanda_topic)(max by(redpanda_topic, redpanda_partition)(rate(redpanda_kafka_request_bytes_total{redpanda_namespace="kafka",redpanda_id="cmnusu3qaeg64ledkssg"}[5m])))
```


All of the above provided courtesy of James Flather.  Thanks James!
