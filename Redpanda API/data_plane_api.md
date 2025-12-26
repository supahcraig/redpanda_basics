

## Get a token

```bash
TOKEN=$(
  curl -sS -X POST "https://auth.prd.cloud.redpanda.com/oauth/token" \
    -H "content-type: application/x-www-form-urlencoded" \
    --data-urlencode "grant_type=client_credentials" \
    --data-urlencode "client_id=$REDPANDA_CLIENT_ID" \
    --data-urlencode "client_secret=$REDPANDA_CLIENT_SECRET" \
    --data-urlencode "audience=cloudv2-production.redpanda.cloud" \
  | jq -r '.access_token'
)
```


## find your dataplane url

### curl

```bash
curl -H "Authorization: Bearer ${TOKEN}" "https://api.cloud.redpanda.com/v1/clusters/${CLUSTER_ID}" | jq '.cluster.dataplane_api.url'
```

or 

```bash
RP_DATAPLANE_URL=$(
  curl -H "Authorization: Bearer ${TOKEN}" \
    "https://api.cloud.redpanda.com/v1/clusters/${CLUSTER_ID}" \
  | jq '.cluster.dataplane_api.url'
}
```



## make a call

```bash
curl "${RP_DATAPLANE_URL}/v1/redpanda-connect/pipelines/d53gd91slkmc738b6jgg" \
  -H "Authorization: Bearer ${TOKEN}" \
| jq '.pipeline.url'
```

And then call your RPCN Gateway input:

```bash
curl -i -X POST "${GATEWAY_URL}${WEBHOOK_ROUTE}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "test": "hello from curl",
    "source": "manual"
  }'
```

Should return a 200 repsonse, then check the output of your pipeline!
