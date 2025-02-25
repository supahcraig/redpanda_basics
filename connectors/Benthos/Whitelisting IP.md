# What IP does RPCN run from?

Many cloud services will require an IP adress/range to be whitelisted in order to allow inbound traffic.   That traffic will all be NAT'd behind the NAT gateway, which can be found in the cloud console.  But not every user will have access to that, so we can instead use RPCN to reveal the address of the NAT Gateway.   The gateway itself is expected to be long-lived with respect to the life of the cluster, but we can't actually guarantee that it won't ever change.

Relevant Slack thread:






```yaml
rate_limit_resources:
  - label: throttle
    local:
      count: 1
      interval: 30s

input:
  http_client:
    url: "http://ifconfig.me"
    verb: GET
    headers: {}
    rate_limit: throttle
    timeout: 5s
    payload: "" 
    stream:
      enabled: false
      reconnect: false
      scanner:
        lines: {}
    auto_replay_nacks: true

pipeline:
  processors:
    - xml:
        operator: to_json
        cast: false

    - log: {message: "${! this.html.body.div.index(1).div.index(1).table.tr.index(0).td.index(1).strong }"}

output:
  drop: {}
```
