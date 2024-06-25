THis is a total work in progress.  If you're reading this, shame on you.



# Docker

1.  Spin up Redpanda via docker
2.  generate the prometheus config
3.  spin up prometheus via docker
4.  generate the grafana dashboard
5.  spin up grafana via docker

TODO:  get this all into either 1 docker compose, or an additional "observability stack" that can talk to the Redpanda stack.

## Redpanda Spin Up

https://docs.redpanda.com/current/get-started/quick-start/

Use Docker Compose


## Prometheus Config

Run this on the Redpanda broker:

```console
rpk generate prometheus-config
```

It will spit out something like this

```yaml
- job_name: redpanda
  static_configs:
    - targets:
        - redpanda-0:9644
  metrics_path: /public_metrics
```

TODO:  determine if `9644` is good or needs to be `19644`

Which you'll then supplement with additional Prometheus config info to get something like this:

```yaml
global:
  scrape_interval: 10s
  evaluation_interval: 10s

scrape_configs:
- job_name: redpanda
  static_configs:
    - targets:
        - redpanda-0:9644
  metrics_path: /public_metrics
```


## Spin up Prometheus

This will put it in the same network as the Redpanda cluster.

```console
docker run -d -p 9090:9090 --network redpanda-quickstart-one-broker_redpanda_network -v /Users/cnelson/sandbox/benthos/prometheus.yml:/etc/prometheus/prometheus.yml --name prometheus prom/prometheu
```


## Spin up Grafana

```console
docker run -d -p 3000:3000 --name=grafana --network redpanda-quickstart-one-broker_redpanda_network grafana/grafana-enterprise
```

Add a data source for your prometheus endpoint:  `http://prometheus:9090`

TODO:  build a useful dashboard in grafana & share json config here.


