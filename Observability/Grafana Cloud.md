Table of Contents
* Link to Public BYOC Grafana Cloud setup
* Link to Private BYOC Grafana Cloud setup
* Link to Private BYOC with AWS PrivateLink Grafana Cloud setup


# Public BYOC with Grafana Cloud

This is actually pretty easy, since Grafana cloud can hit the BYOC Prometheus endpoint directly.    The default BYOC security allows traffic from 0.0.0.0/0, so if your cluster has tighter security it would require that the Prometheus endpoint be open to wherever Grafana traffic is originating from.

## Create a Metrics Endpoint

From the Grafana Cloud UI, add a new Connection under Connections -> Add New Connection on the left hand nav bar.   Search for Metrics Endpoint and add a New Scrape Job.    This will scrape the BYOC Prometheus endpoing on an interval.   It will have the side effect of createing a new Data Source in Grafana Cloud.

Give it the full prometheus endpoint, username, and password, all found in the BYOC console, something like:

* `https://console-6234e08e.yourClusterID.byoc.prd.cloud.redpanda.com/api/cloud/prometheus/public_metrics`
* `prometheus`
* `exdoNxGUNSoutFORharambeIZnok-2OvG9`

And then test the connection.   Once successful, it will create a new Data Source for you.   Mine was named `grafana-myUserName-prom` and I didn't have any control over this naming.   


## Create a Dashboard

If you don't already have one, rpk can generate the json for a basic dashboard.  Assuming you have your rpk profile pointed to your cluster:

```bash
rpk generate grafana-dashboard > grafana-dash.json
```

From the left hand nav bar on Grafana Cloud, go to Dashboards.   Then click New -> Import to pull in your dashboard definition.

You should see your cluster info populate on the dashbaord straight away.

---

# Private BYOC with Grafana Cloud

_this is really confusing on Grafana Cloud, this is very much a Work in Progress_

Pre-requisites
* a VPC peered to your Redpanda VPC
* an EC2 instance in the peered VPC to host Grafana Alloy

## Peering your VPC to the Redpanda VPC

https://docs.redpanda.com/redpanda-cloud/networking/byoc/aws/vpc-peering-aws/

1.  Create a peering connection from your Redpanda VPC (the requester) to your existing VPC (the accepter).  Then accept the peering request.

2.  Creeate routes from Redpanda VPC to your VPC

```bash
aws ec2 describe-route-tables --filter "Name=tag:Name,Values=network-d327sjl5akisag7hahgg" "Name=tag:purpose,Values=private" | jq -r '.RouteTables[].RouteTableId' | \
while read -r route_table_id; do \
aws ec2 create-route --route-table-id $route_table_id --destination-cidr-block 10.100.0.0/16 --vpc-peering-connection-id pcx-07cf11620ae6bda66; \
done;
```

3.  Create routes from your VPC to Redpanda VPC

```bash
REGION=us-east-2 VPC_ID=vpc-0342476ccc1ef05f4 PCX_ID=pcx-07cf11620ae6bda66 DEST_CIDR=10.30.0.0/16; \
for rt in $(aws ec2 describe-route-tables --region "$REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'RouteTables[].RouteTableId' --output text); do
  aws ec2 create-route  --region "$REGION" --route-table-id "$rt" \
    --destination-cidr-block "$DEST_CIDR" --vpc-peering-connection-id "$PCX_ID" \
  || \
  aws ec2 replace-route --region "$REGION" --route-table-id "$rt" \
    --destination-cidr-block "$DEST_CIDR" --vpc-peering-connection-id "$PCX_ID";
done
```

4.  Test Connectivity from an EC2 instance in your VPC

Create an RPK profile that points to your cluster.   This is a very basic example.  Then test with `rpk cluster info`

```yaml
name: byoc-profile
from_cloud: false
kafka_api:
    brokers:
        - seed-22a26b8c.yourClusterID.byoc.prd.cloud.redpanda.com:9092
    tls: {}
    sasl:
        user: cnelson
        password: <your passwrod>
        mechanism: SCRAM-SHA-256
```

## Find all the Grafana Cloud junk you'll need

### Grafana Cloud Endpoint

Home -> Connections -> Data sources -> grafanacloud-supahcraig-prom

You'll need:
* Prometheus Server URL:   `https://prometheus-prod-56-prod-us-east-2.grafana.net/api/prom`
* User: `2672937`
* Password:   _tbd_

### Password

Your password is actually a CAP (cloud access policy) token, which you'll need to create.

Administraion -> Users and Access -> Cloud access policies

You'lll want to create a new cloud access policy and give it the metric:write policy under Scopes/Permissions.

Once you creeate the policy, go back into it and Add a Token.    Copy that token, it is what you'll need in your alloy config file.

Use this token as the password in Alloy’s prometheus.remote_write block. The username is your Prometheus instance ID (the number you already have). Docs confirm CAP tokens are what you use for write access. 
Grafana Labs



## Set up Grafana Alloy

```bash
curl -fsSL https://apt.grafana.com/gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/grafana.gpg  
echo "deb [signed-by=/usr/share/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list  
  
sudo apt update  
sudo apt install alloy
```

```bash
sudo mkdir -p /opt/alloy  
cd /opt/alloy
```

Create `config.alloy`

```yaml
prometheus.scrape "redpanda_byoc" {
  targets = [
    { __address__ = "console-6234e08e.curl3eo533cmsnt23dv0.byoc.prd.cloud.redpanda.com" },
  ]

  metrics_path = "/api/cloud/prometheus/public_metrics"
  scheme       = "https"

  // Your BYOC Prometheus credentials
  basic_auth {
    username = "prometheus"
    password = "<prometheus password>"
  }

  forward_to = [prometheus.remote_write.grafana_cloud.receiver]
}

// Send to your existing Grafana Cloud
prometheus.remote_write "grafana_cloud" {
  endpoint {
    // Your existing Grafana Cloud endpoint
    url = "https://prometheus-prod-56-prod-us-east-2.grafana.net/api/prom/push"

    basic_auth {
      username = "2672937"      // Same as before
      password = "glc_SomethingSomethingLCJtIjp7InIiOiJwcm9kLXVzLWVhc3QtMCJ9fQ=="
    }
  }
}
```




Spin up the container
```bash
docker run -d \
  --name alloy \
  --restart unless-stopped \
  -p 12345:12345 \
  -v /opt/alloy/config.alloy:/etc/alloy/config.alloy:ro \
  grafana/alloy:latest \
  run /etc/alloy/config.alloy \
  --server.http.listen-addr=0.0.0.0:12345
```

Check the docker logs.  There is a 200% chance you got something wrong, Grafana Cloud & their AI _sucks_

```bash
# From your EC2 instance, test the exact credentials Alloy is using  
curl -u "2672937:glc_SomethingSomethingLCJtIjp7InIiOiJwcm9kLXVzLWVhc3QtMCJ9fQ==" \
  -H "Content-Type: application/x-protobuf" \
  -H "X-Prometheus-Remote-Write-Version: 0.1.0" \
  https://prometheus-prod-56-prod-us-east-2.grafana.net/api/prom/push
```


Test the prometheus endpoint from your EC2 instance, should return a huge list of metrics.

```bash
curl -u "prometheus:prom_password" https://prometheus.endpoint
```

