# Low Latency data to Long-term Storage

## Pre-requisites

EC2 instance?
Docker locally
Clickhouse??

---

## Spin up 3 node redpanda cluster + console, locally in Docker
```yaml
networks:
  redpanda_network:
    driver: bridge
volumes:
  redpanda-0: null
  redpanda-1: null
  redpanda-2: null
services:
  redpanda-0:
    command:
      - redpanda
      - start
      - --kafka-addr internal://0.0.0.0:9092,external://0.0.0.0:19092
      # Address the broker advertises to clients that connect to the Kafka API.
      # Use the internal addresses to connect to the Redpanda brokers'
      # from inside the same Docker network.
      # Use the external addresses to connect to the Redpanda brokers'
      # from outside the Docker network.
      - --advertise-kafka-addr internal://redpanda-0:9092,external://redpanda:19092
      - --pandaproxy-addr internal://0.0.0.0:8082,external://0.0.0.0:18082
      # Address the broker advertises to clients that connect to the HTTP Proxy.
      - --advertise-pandaproxy-addr internal://redpanda-0:8082,external://redpanda:18082
      - --schema-registry-addr internal://0.0.0.0:8081,external://0.0.0.0:18081
      # Redpanda brokers use the RPC API to communicate with each other internally.
      - --rpc-addr redpanda-0:33145
      - --advertise-rpc-addr redpanda-0:33145
      # Mode dev-container uses well-known configuration properties for development in containers.
      - --mode dev-container
      # Tells Seastar (the framework Redpanda uses under the hood) to use 1 core on the system.
      - --smp 1
      - --default-log-level=info
    image: docker.redpanda.com/redpandadata/redpanda:v24.2.4
    container_name: redpanda-0
    volumes:
      - redpanda-0:/var/lib/redpanda/data
    networks:
      - redpanda_network
    ports:
      - 18081:18081
      - 18082:18082
      - 19092:19092
      - 19644:9644
  redpanda-1:
    command:
      - redpanda
      - start
      - --kafka-addr internal://0.0.0.0:9092,external://0.0.0.0:29092
      - --advertise-kafka-addr internal://redpanda-1:9092,external://redpanda:29092
      - --pandaproxy-addr internal://0.0.0.0:8082,external://0.0.0.0:28082
      - --advertise-pandaproxy-addr internal://redpanda-1:8082,external://redpanda:28082
      - --schema-registry-addr internal://0.0.0.0:8081,external://0.0.0.0:28081
      - --rpc-addr redpanda-1:33145
      - --advertise-rpc-addr redpanda-1:33145
      - --mode dev-container
      - --smp 1
      - --default-log-level=info
      - --seeds redpanda-0:33145
    image: docker.redpanda.com/redpandadata/redpanda:v24.2.4
    container_name: redpanda-1
    volumes:
      - redpanda-1:/var/lib/redpanda/data
    networks:
      - redpanda_network
    ports:
      - 28081:28081
      - 28082:28082
      - 29092:29092
      - 29644:9644
    depends_on:
      - redpanda-0
  redpanda-2:
    command:
      - redpanda
      - start
      - --kafka-addr internal://0.0.0.0:9092,external://0.0.0.0:39092
      - --advertise-kafka-addr internal://redpanda-2:9092,external://redpanda:39092
      - --pandaproxy-addr internal://0.0.0.0:8082,external://0.0.0.0:38082
      - --advertise-pandaproxy-addr internal://redpanda-2:8082,external://redpanda:38082
      - --schema-registry-addr internal://0.0.0.0:8081,external://0.0.0.0:38081
      - --rpc-addr redpanda-2:33145
      - --advertise-rpc-addr redpanda-2:33145
      - --mode dev-container
      - --smp 1
      - --default-log-level=info
      - --seeds redpanda-0:33145
    image: docker.redpanda.com/redpandadata/redpanda:v24.2.4
    container_name: redpanda-2
    volumes:
      - redpanda-2:/var/lib/redpanda/data
    networks:
      - redpanda_network
    ports:
      - 38081:38081
      - 38082:38082
      - 39092:39092
      - 39644:9644
    depends_on:
      - redpanda-0
  console:
    container_name: redpanda-console
    image: docker.redpanda.com/redpandadata/console:v2.7.2
    networks:
      - redpanda_network
    entrypoint: /bin/sh
    command: -c 'echo "$$CONSOLE_CONFIG_FILE" > /tmp/config.yml; /app/console'
    environment:
      CONFIG_FILEPATH: /tmp/config.yml
      CONSOLE_CONFIG_FILE: |
        kafka:
          brokers: ["redpanda-0:9092"]
          schemaRegistry:
            enabled: true
            urls: ["http://redpanda-0:8081"]
        redpanda:
          adminApi:
            enabled: true
            urls: ["http://redpanda-0:9644"]
    ports:
      - 8080:8080
    depends_on:
      - redpanda-0
```

## Create the bucket

```bash
aws configure set region us-east-1
BUCKET_NAME=redpanda-demo-$(shuf -i 10000-99999 -n 1)
aws s3api create-bucket --bucket $BUCKET_NAME --region us-east-1
```

Then echo some stuff into `.env` file

```bash
cd /connect-launch-2024/current/object-store
echo "AWS_ID=$(eval echo \${INSTRUQT_AWS_ACCOUNT_${INSTRUQT_AWS_ACCOUNTS}_AWS_ACCESS_KEY_ID})" >> .env
echo "AWS_SECRET=$(eval echo \${INSTRUQT_AWS_ACCOUNT_${INSTRUQT_AWS_ACCOUNTS}_AWS_SECRET_ACCESS_KEY})" >> .env
echo "AWS_BUCKET_NAME=$BUCKET_NAME" >> .env
echo "AWS_REGION=us-east-1" >> .env
```

