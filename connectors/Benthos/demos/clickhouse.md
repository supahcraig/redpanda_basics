# Low Latency data to Long-term Storage

## Pre-requisites

EC2 instance?
Docker locally
Clickhouse??

---

# Environment Setup

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

Export those to env vars:

```bash
export $(grep -v '^#' .env | xargs)
cat .env
```


## Clickhouse

Not sure why we can't just deploy this as part of the docker compose we ran earlier....

```bash
docker network create clickhouse-network
```

```bash
docker run -d \
    --name demo-clickhouse-server \
    --ulimit nofile=262144:262144 \
    --network clickhouse-network \
    -p 18123:8123 \
    -p 19000:9000 \
    clickhouse/clickhouse-server
```

Drop into the ClickHouse client within the container:

```bash
docker exec -it demo-clickhouse-server clickhouse-client
```


## Generate the table DDL

Run this the same place those environment variables are exported, OR just do the replacement yourself.

```bash
echo "CREATE TABLE music_logs_s3_raw (
        user_id UUID,
        gender String,
        geo String,
        music_type String,
        listening_device String,
        year_of_music UInt16,
        song_id UUID,
        timestamp DateTime
) ENGINE = S3('https://$AWS_BUCKET_NAME.s3.amazonaws.com/logs/music-listening-logs/*','$AWS_ID', '$AWS_SECRET', JSONEachRow);"
```

which should generate DDL looking like this:

```bash
CREATE TABLE music_logs_s3_raw (
        user_id UUID,
        gender String,
        geo String,
        music_type String,
        listening_device String,
        year_of_music UInt16,
        song_id UUID,
        timestamp DateTime
) ENGINE = S3('https://redpanda-demo-49446.s3.amazonaws.com/logs/music-listening-logs/*','AKIAXxxxxxIVNUPZEB', '9F5xxxxxxxxxx1H+LdLfTVPxxxForDte', JSONEachRow);
```

And then paste that output into the Clickhouse client to actually execute the create table DDL, response should look something like:

```
Query id: 59669988-af29-4b76-9396-cb2c076c0863

Ok.

0 rows in set. Elapsed: 0.013 sec.
```

----

# Data Pipeline


## Redpanda Connect kafka->S3 pipeline

```yaml
input:
  kafka_franz:
    seed_brokers: [ "redpanda:19092" ]
    topics: [ "music-listening-logs" ]
    consumer_group: "redpanda-s3-pipe"
    commit_period: 3s
pipeline:
  processors:
    - bloblang: |
        root = this
output:
  aws_s3:
    bucket: ${AWS_BUCKET_NAME}
    path: logs/music-listening-logs/${!timestamp_unix_nano()}.json
    tags: {}
    content_type: application/octet-stream
    metadata:
      exclude_prefixes: []
    max_in_flight: 64
    region: ${AWS_REGION}
    batching:
      count: 100
      processors:
        - archive:
            format: lines
    credentials:
      id: ${AWS_ID}
      secret: ${AWS_SECRET}
```

And execute it via:

```bash
rpk connect run -e .env music_log_store.yaml
```


------

## Kinley's demo

crk4h23v3oritbs0s0jg.any.us-east-1.mpx.prd.cloud.redpanda.com:9092

```yaml
input:
  kafka:
    addresses: [ crgsf2gj1v2u1117mal0.any.us-east-1.mpx.prd.cloud.redpanda.com:9092 ]
    tls:
      enabled: true
    sasl:
      mechanism: "SCRAM-SHA-256"
      user: test-user
      password: test-pass
    consumer_group: benthos
    start_from_oldest: true
    topics: [ documents-serverless ]

pipeline:
  processors:
    - branch:
        request_map: |
          root = this.text
        processors:
          - openai_embeddings:
              api_key: \${OPENAI_KEY}
              model: gpt-4o
        result_map: |
          root.embedding = this

output:
  mongodb:
    url: mongodb+srv://craig:\${MONGO_PASSWORD}@cluster0.yyels.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0
    database: VectorStore
    collection: Embeddings
    operation: "insert-one"
    write_concern:
      w: 1
      j: false
      w_timeout: "10s"
    document_map: |-
      root.text = this.text
      root.metadata = this.metadata
      root.embedding = this.embedding

metrics:
  prometheus: {}
```32rh explo

-----

## RPG demo

1.  spin up RP/Console/PG-vector
2.  set rpk profile
3.  create some topics
4.  put the broker addresses into an env var
(5) install ollama
6.  pull the ollama model
7.  env var for the local llm addr (localhost)
8.  env var for OPENAPI key
9.  npm install the front end
10.  createa npc1 pipeline (yaml below)
11.  run pipeline in the background:  `rpk connect run -e .env npc1-ollama.yaml &`  (hit enter to shove into the background)
12.  ask it a question:  `echo "how are you?" | rpk topic produce npc1-request`  ==> response will be in the `rpg-response` topic (check console, but be patient)
13.  create npc2 pipeline (this is the OpenAI yaml below)
14.  run pipeline in the background:  `rpk connect run -e .env npc2-openai.yaml &`  (hit enter to shove into the background)
15.  ask it a question:  echo "how are you?" | rpk topic produce npc2-request`
16.  response should come back in the terminal

Now for the complex stuff.

17.  create the routing rpcn config
18.  run the pipeline `nohup rpk connect run -e .env npc-reroute.yaml &`
19.  ask it a qeustion:  `echo "how are you?" | rpk topic produce npc2-request`

Add in some RAG stuff.

20.  pull the ollama model we want to use:  `ollama pull nomic-embed-text`
21.  log into pgsql:  `psql -h localhost -p 5432 --username root` (password is `secret`)
22.  create a HNSW index:  `CREATE INDEX IF NOT EXISTS text_hnsw_index ON whisperingrealm USING hnsw (embedding vector_l2_ops);`
23.  put pg creds into env var
24.  createe embeddings pipeline (`pg-embedding.yaml`)
25.  `redpanda-connect run -e .env pg-embedding.yaml`
26.  Rag pipeline (`npc21-genai-rag.yaml`)
27.  run the RAG pipeline:  `nohup redpanda-connect run -e .env npc1-genai-rag.yaml &`
28 then the npc2 rag pipeline `nohup redpanda-connect run -e .env npc2-openai-rag.yaml &`

run the app
```
cd ~/redpanda-connect-genai-gaming-demo/frontend
node index.js &
echo http://$HOSTNAME.$_SANDBOX_ID.instruqt.io
```

`npc1-ollama.yaml`
```yaml
input:
  kafka_franz:
    seed_brokers:
      - \${REDPANDA_BROKERS}
    topics: ["npc1-request"]
    consumer_group: "ollama-npc1"
pipeline:
  processors:
    - log:
        message: \${! content() }
    - ollama_chat:
        server_address: "\${LOCAL_LLM_ADDR}"
        model: llama3.1:8b
        prompt:  \${! content().string() }
        system_prompt: Answer like having a conversation, you are a hero who lives in a fantasy world and say no more than 5 sentences and in an upbeat tone.
    - mapping: |
        root = {
          "who": "npc1",
          "msg":  content().string()
        }
    - log:
        message: \${! json() }
output:
  kafka_franz:
    seed_brokers:
      - \${REDPANDA_BROKERS}
    topic: "rpg-response"
    compression: none
```


`npc2-openai.yaml`
```yaml
input:
  kafka_franz:
    seed_brokers:
      - \${REDPANDA_BROKERS}
    topics: ["npc2-request"]
    consumer_group: "openai-npc2"
pipeline:
  processors:
    - log:
        message: \${! content() }
    - openai_chat_completion:
        server_address: https://api.openai.com/v1
        api_key: \${OPENAI_KEY}
        model: gpt-4o
        system_prompt: Answer like having a conversation, you are a sorcerer in a fantasy world, specialized in light magic and say no more than 5 sentences and in an shy tone.
    - mapping: |
        root = {
          "who": "npc2",
          "msg":  content().string()
        }
    - log:
        message: \${! json() }
output:
  kafka_franz:
    seed_brokers:
      - \${REDPANDA_BROKERS}
    topic: "rpg-response"
    compression: none
```


`npc-reroute.yaml`
```yaml
input:
  kafka_franz:
    seed_brokers:
      - \${REDPANDA_BROKERS}
    topics: ["npc-request"]
    consumer_group: "npc-reroute"
output:
  switch:
    cases:
      - check: this.who == "npc1"
        output:
          kafka_franz:
            seed_brokers:
              - \${REDPANDA_BROKERS}
            topic: npc1-request
          processors:
            - type: bloblang
              bloblang: |
                root = this.msg
      - check: this.who == "npc2"
        output:
          kafka_franz:
            seed_brokers:
              - \${REDPANDA_BROKERS}
            topic: npc2-request
          processors:
            - type: bloblang
              bloblang: |
                root = this.msg
```

`pg-embedding.yaml`
```yaml
input:
  file:
    paths: [ ./story/*.md ]
    scanner:
      to_the_end: {}
pipeline:
  processors:
    - mapping: |
        meta text = content()
    - branch:
        processors:
          - ollama_embeddings:
              server_address: "\${LOCAL_LLM_ADDR}"
              model: nomic-embed-text
        result_map: |-
          root.embeddings = this
          root.text = metadata("text").string()
          root.key = metadata("path").string()
    - log:
        message: \${! json("embeddings") }
output:
 sql_insert:
    driver: postgres
    dsn: "postgresql://\${PGVECTOR_USER}:\${PGVECTOR_PWD}@localhost:5432/root?sslmode=disable"
    table: whisperingrealm
    columns: ["key", "doc", "embedding"]
    args_mapping: "[this.key, this.text, this.embeddings.vector()]"
```

`npc1-ganai-rag.yaml`
```yaml
input:
  kafka_franz:
    seed_brokers:
      - \${REDPANDA_BROKERS}
    topics: ["npc1-request"]
    consumer_group: "ollama-npc1"
pipeline:
  processors:
    - log:
        message: \${! content() }
    - mapping: |
        meta original_question = content()
    - branch:
        processors:
          - ollama_embeddings:
              server_address: "\${LOCAL_LLM_ADDR}"
              model: nomic-embed-text
        result_map: |-
            root.embeddings = this
            root.question = content()
    - branch:
       processors:
          - sql_raw:
              driver: "postgres"
              dsn: "postgresql://\${PGVECTOR_USER}:\${PGVECTOR_PWD}@localhost:5432/root?sslmode=disable"
              query: SELECT doc FROM whisperingrealm ORDER BY embedding <-> \$1 LIMIT 1
              args_mapping: root = [ this.embeddings.vector() ]
       result_map: |-
          root.embeddings = deleted()
          root.question = deleted()
          root.search_results = this
    - log:
        message: \${! json("search_results") }
    - ollama_chat:
        server_address: "\${LOCAL_LLM_ADDR}"
        model: llama3.1:8b
        prompt:  \${! meta("original_question") }
        system_prompt: You are the hero Corin in this fantasy world and say no more than 5 sentences and in an upbeat tone. \${! json("search_results") }
    - mapping: |
        root = {
          "who": "npc1",
          "msg":  content().string()
        }
    - log:
        message: \${! json() }
output:
  kafka_franz:
    seed_brokers:
      - \${REDPANDA_BROKERS}
    topic: "rpg-response"
    compression: none
```

`npc2-openai-rag.yaml`
```yaml
input:
  kafka_franz:
    seed_brokers:
      - \${REDPANDA_BROKERS}
    topics: ["npc2-request"]
    consumer_group: "openai-npc2"
pipeline:
  processors:
    - log:
        message: \${! content() }
    - mapping: |
        meta original_question = content()
    - branch:
        processors:
          - ollama_embeddings:
              server_address: "\${LOCAL_LLM_ADDR}"
              model: nomic-embed-text
        result_map: |-
            root.embeddings = this
            root.question = content()
    - branch:
       processors:
          - sql_raw:
              driver: "postgres"
              dsn: "postgresql://\${PGVECTOR_USER}:\${PGVECTOR_PWD}@localhost:5432/root?sslmode=disable"
              query: SELECT doc FROM whisperingrealm ORDER BY embedding <-> \$1 LIMIT 3
              args_mapping: root = [ this.embeddings.vector() ]
       result_map: |-
          root.embeddings = deleted()
          root.question = meta("original_question")
          root.search_results = this
    - log:
        message: \${! json("search_results") }
    - openai_chat_completion:
        server_address: https://api.openai.com/v1
        api_key: \${OPENAI_KEY}
        model: gpt-4o
        system_prompt: You are a sorcerer Lyria in this fantasy world, specialized in light magic and say no more than 5 sentences and in an shy tone.
    - mapping: |
        root = {
          "who": "npc2",
          "msg":  content().string()
        }
    - log:
        message: \${! json() }
output:
  kafka_franz:
    seed_brokers:
      - \${REDPANDA_BROKERS}
    topic: "rpg-response"
    compression: none
```


