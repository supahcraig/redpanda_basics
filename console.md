# Installing Redpanda Console

this is defined in our docs, it creates a lot of the stuff, but you'll still need to configure it.



# Configuring Redpanda Console

## Basic
https://docs.google.com/document/d/10uBI18j4AoxnFOovCmJYjBuk2VkLTIC-8QJZic0cM_o/edit#heading=h.6qdilogh9pqr

Where you will substitute “brokerN” with your broker private IP’s.  Full documentation on the console configuration options can be found here:  https://docs.redpanda.com/docs/console/reference/config/

```
kafka:
  brokers: ["broker1:9092", "broker2:9092", "broker3:9092"]
  clientId: console


  schemaRegistry:
    enabled: true
    urls: ["http://broker1:8081", "http://broker2:8081", "http://broker3:8081"]


redpanda:
  adminApi:
    enabled: true
    urls: ["http://broker1:9644", "http://broker2:9644", "http://broker3:9644"]
```





Where the IP’s are the private IP’s of the brokers (assuming you enabled schema registry on all nodes)


## With TLS

