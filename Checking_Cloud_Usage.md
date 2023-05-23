# How much throughput is a Dedicated/BYOC cluster using?


## Find your customers cluster ID

1.  Go to Cloud V2 Admin from okta
2.  Go to Organizations, and search for your customer name
3.  Navigate to clusters and look at the cluster ID for the cluster you are interested in 


## Go to Grafana

Go to Grafana Cloud from okta


### Overall Cluster Usage

You will want to use this dashboard:   https://grafana.com/grafana/dashboards/18135-redpanda-ops-dashboard/

I created a new folder called `cnelson` and uploaded the json dashboard definition, but it may already exist in our Grafana.

* *Data Source* = `metrics-cloud-prod-v2` (but `Prometheus` also seems to produce the same result)
* Add a new filter for `redpanda_id` and paste in your Cluster ID


### Connector Usage


Find the `Cloud V2 Data Plane` dashboard set
For connectors throughput open `DP - Connectors`

* Set the `redpanda id` field near the top of the dashboardto be your Cluster ID.  It should do a context search as you type so you probably only need to know the first 4 or 5 characters.



## Getting the info you need

Lots of good info in here, but you're probably here to establish pricing, so you'll want to look at Bytes In (or out) and Connector Tasks.  Be sure to look at a wide enough time window to get a good feel for overall usage & trends.

Lots to learn & understand in this one dashboard.   Have fun.





https://vectorizedio.grafana.net/d/aCb4GOW4z/dp-connectors?orgId=1&refresh=30s&var-datasource=metrics-prod-cloudv2&var-redpanda_id=cfe0f6m2gj23h4urbe00&var-container=connectors-cluster&var-instance=All&var-connector=RedpandaEdgeDataProd&var-connector=snowflake-prod-test&var-task=All&var-search=&var-query0=&var-node_ip=10.0.0.145&from=now-30d&to=now
