# Basic Profile

this profile is a WIP, but can be used locally when trying to communicate with a single node instance created via the public Redpanda Docker Compose


```
name: docker
description: Docker Quickstart
prompt: hi-red, "[%n]"
kafka_api:
    brokers:
        - localhost:19092
admin_api:
    addresses:
        - localhost:19644
```
