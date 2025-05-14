THis is a total work in progress.  If you're trying to follow along with any of this, shame on you.


# From Redpanda githug

https://github.com/redpanda-data/observability/tree/main/cloud



# A more DIY approach

This repo may cover some of the same ground:  https://github.com/redpanda-data/observability/blob/main/cloud/docker-compose.yml

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


Which you'll then supplement with additional Prometheus config for the scrape intervals, as well as (optionally) the Redpanda Connect target.

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

- job_name: benthos
  static_configs:
    - targets:
      - redpanda-0:4159
  metrics_path: /metrics
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


---


Via docker compose...not quite working just yet.   Seems like the networks aren't quite talking yet.

```yaml
version: '3.7'
services:
  grafana:
    image: grafana/grafana
    container_name: grafana
    ports: 
      - 3000:3000

  prometheus:
    image: prom/prometheus
    container_name: prometheus
    # Mount prometheus configuration
    volumes:
      - "./prometheus.yml:/etc/prometheus/prometheus.yml"
    ports: 
      - 9090:9090

networks:
  redpanda-quickstart-one-broker_redpanda_network:
    external: true
```


# Direct Install

(using Amazon Linux)

https://rm-rf.medium.com/how-to-install-and-configure-prometheus-on-centos-7-1505e5bd7a3d


## Install/Configure Prometheus

You'll need to open up your SG on 9090 to your home IP, but also maybe the sg of the instance itself, so that Grafana can hit the prometheus endpoint.

```bash
# wget https://github.com/prometheus/prometheus/releases/download/v2.27.1/prometheus-2.27.1.linux-amd64.tar.gz
wget https://github.com/prometheus/prometheus/releases/download/v2.27.1/prometheus-2.27.1.linux-arm64.tar.gz

sudo useradd --no-create-home --shell /bin/false prometheus

sudo mkdir /etc/prometheus
sudo mkdir /var/lib/prometheus

sudo chown prometheus:prometheus /etc/prometheus
sudo chown prometheus:prometheus /var/lib/prometheus

tar -xvzf prometheus-2.27.1.linux-arm64.tar.gz
sudo mv prometheus-2.27.1.linux-arm64 prometheuspackage

sudo cp prometheuspackage/prometheus /usr/local/bin/
sudo cp prometheuspackage/promtool /usr/local/bin/

sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool

sudo cp -r prometheuspackage/consoles /etc/prometheus
sudo cp -r prometheuspackage/console_libraries /etc/prometheus

sudo chown -R prometheus:prometheus /etc/prometheus/consoles
sudo chown -R prometheus:prometheus /etc/prometheus/console_libraries

sudo cat > /etc/prometheus/prometheus.yml <<EOF
global:
  scrape_interval: 10s
  evaluation_interval: 10s

scrape_configs:
- job_name: redpanda
  static_configs:
    - targets:
        - 10.100.11.20:9644
        - 10.100.2.59:9644
        - 10.100.2.61:9644
  metrics_path: /public_metrics
EOF

sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml

sudo vim /etc/systemd/system/prometheus.service

sudo cat > /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target
[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
--config.file /etc/prometheus/prometheus.yml \
--storage.tsdb.path /var/lib/prometheus/ \
--web.console.templates=/etc/prometheus/consoles \
--web.console.libraries=/etc/prometheus/console_libraries
[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start prometheus
```




## Install/Configure Grafana

https://000029.awsstudygroup.com/3-installgrafana/

You'll need to open up your SG on port 3000, for your home IP, in order to get to the UI

```bash
sudo yum update -y

sudo vi /etc/yum.repos.d/grafana.repo

[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt

sudo yum install -y grafana

sudo systemctl start grafana-server

```

UI runs on port 3000

user: `admin`
pass: `admin`


### Add a Data Source
From the grafana UI, add a data source.   It's the IP:9090 of the prometheus server.  No other stuff is req'd for a basic setup.

### Import a dashboard

From a rpk broker, or from a profile-configured location:

```bash
rpk generate grafana-dashboard > dash.json
```

And then import that into grafana



