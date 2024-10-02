-----

# RPG demo RPCN with AI chat

git clone https://github.com/weimeilin79/redpanda-connect-genai-gaming-demo.git


### 1.  spin up RP/Console/PG-vector

`docker-compose.yml`
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
      - --advertise-kafka-addr internal://redpanda-0:9092,external://localhost:19092
      - --pandaproxy-addr internal://0.0.0.0:8082,external://0.0.0.0:18082
      # Address the broker advertises to clients that connect to the HTTP Proxy.
      - --advertise-pandaproxy-addr internal://redpanda-0:8082,external://localhost:18082
      - --schema-registry-addr internal://0.0.0.0:8081,external://0.0.0.0:18081
      # Redpanda brokers use the RPC API to communicate with each other internally.
      - --rpc-addr redpanda-0:33145
      - --advertise-rpc-addr redpanda-0:33145
      # Mode dev-container uses well-known configuration properties for development in containers.
      - --mode dev-container
      # Tells Seastar (the framework Redpanda uses under the hood) to use 1 core on the system.
      - --smp 1
      - --default-log-level=info
    image: docker.redpanda.com/redpandadata/redpanda:v24.2.2
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
      - --advertise-kafka-addr internal://redpanda-1:9092,external://localhost:29092
      - --pandaproxy-addr internal://0.0.0.0:8082,external://0.0.0.0:28082
      - --advertise-pandaproxy-addr internal://redpanda-1:8082,external://localhost:28082
      - --schema-registry-addr internal://0.0.0.0:8081,external://0.0.0.0:28081
      - --rpc-addr redpanda-1:33145
      - --advertise-rpc-addr redpanda-1:33145
      - --mode dev-container
      - --smp 1
      - --default-log-level=info
      - --seeds redpanda-0:33145
    image: docker.redpanda.com/redpandadata/redpanda:v24.2.2
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
      - --advertise-kafka-addr internal://redpanda-2:9092,external://localhost:39092
      - --pandaproxy-addr internal://0.0.0.0:8082,external://0.0.0.0:38082
      - --advertise-pandaproxy-addr internal://redpanda-2:8082,external://localhost:38082
      - --schema-registry-addr internal://0.0.0.0:8081,external://0.0.0.0:38081
      - --rpc-addr redpanda-2:33145
      - --advertise-rpc-addr redpanda-2:33145
      - --mode dev-container
      - --smp 1
      - --default-log-level=info
      - --seeds redpanda-0:33145
    image: docker.redpanda.com/redpandadata/redpanda:v24.2.2
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
    image: docker.redpanda.com/redpandadata/console:v2.7.0
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
  postgres:
    image: pgvector/pgvector:pg16
    container_name: postgres
    ports:
      - 5432:5432
    environment:
      POSTGRES_PASSWORD: secret
      POSTGRES_USER: root
      POSTGRES_DB: root
    volumes:
    - ./files/postgres:/docker-entrypoint-initdb.d
```

`docker compose up -d`


### 2.  set rpk profile

```bash
rpk profile create local
rpk profile set kafka_api.brokers=localhost:19092,localhost:29092,localhost:39092
rpk profile set admin_api.addresses=localhost:19644,localhost:29644,localhost:39644
rpk profile set prompt=hi-green
rpk profile use local
```

### 3.  create some topics

```
rpk topic create bonus  npc-request npc1-request npc2-request npc3-request rpg-response
```

### 4.  put the broker addresses into `.env`

```
cd ~/redpanda-connect-genai-gaming-demo
cat > .env <<EOF
REDPANDA_BROKERS="localhost:19092,localhost:29092,localhost:39092"
EOF
```

### 5.  pull the ollama model

#### install ollama?

Download from ollama.com/download

#### pull model

```
ollama pull llama3.1:8b
```


### 6.  env var for the local llm addr (localhost)

```bash
cd ~/redpanda-connect-genai-gaming-demo
echo 'LOCAL_LLM_ADDR="http://127.0.0.1:11434"' >> .env
```

### 7.  env var for OPENAPI key

You'll need your OpenAI API key here.

```bash
echo 'OPENAI_KEY="YOUR_OPENAI_KEY"' >> .env
```

### 8.  npm install the front end  (not truly necessary)

```bash
cd ~/redpanda-connect-genai-gaming-demo/frontend
npm install
```

### 9.  create npc1 pipeline (yaml below)

This pipeline will read from an input topic and send that content to your locally running ollama model, then the response will be published to the response topic.

`npc1-ollama.yaml`
```yaml
input:
  kafka_franz:
    seed_brokers:
      - ${REDPANDA_BROKERS}
    topics: ["npc1-request"]
    consumer_group: "ollama-npc1"
pipeline:
  processors:
    - log:
        message: ${! content() }
    - ollama_chat:
        server_address: "${LOCAL_LLM_ADDR}"
        model: llama3.1:8b
        prompt:  \${! content().string() }
        system_prompt: Answer like having a conversation, you are a hero who lives in a fantasy world and say no more than 5 sentences and in an upbeat tone.
    - mapping: |
        root = {
          "who": "npc1",
          "msg":  content().string()
        }
    - log:
        message: ${! json() }
output:
  kafka_franz:
    seed_brokers:
      - ${REDPANDA_BROKERS}
    topic: "rpg-response"
    compression: none
```

### 10. Run the pipeline in the background (may have to hit Enter) using the `.env` file we've been building.

`rpk connect run -e .env npc1-ollama.yaml &`


### 11.  ask it a question:  

`echo "how are you?" | rpk topic produce npc1-request`  

Response will look something like this:

```log
INFO how are you?                                  @service=redpanda-connect label="" path=root.pipeline.processors.0
INFO {"msg":"I'm fantastic, thanks for asking! Just saved the kingdom from a dragon's fiery wrath yesterday and I'm still on cloud nine! The villagers are celebrating my heroism with a grand feast tonight, so I get to enjoy some well-deserved roasted meats and merriment. It's days like these that remind me why I love being a hero!","who":"npc1"}  @service=redpanda-connect label="" path=root.pipeline.processors.3
```

The response will be in the `rpg-response` topic (check console, but be patient)


### 12.  create npc2 pipeline (this is the OpenAI yaml below)

This is very similar to the pipeline from step 9, except that it calls out to OpenAI.com to have them run the model.

`npc2-openai.yaml`
```yaml
input:
  kafka_franz:
    seed_brokers:
      - ${REDPANDA_BROKERS}
    topics: ["npc2-request"]
    consumer_group: "openai-npc2"
pipeline:
  processors:
    - log:
        message: ${! content() }
    - openai_chat_completion:
        server_address: https://api.openai.com/v1
        api_key: ${OPENAI_KEY}
        model: gpt-4o
        system_prompt: Answer like having a conversation, you are a sorcerer in a fantasy world, specialized in light magic and say no more than 5 sentences and in an shy tone.
    - mapping: |
        root = {
          "who": "npc2",
          "msg":  content().string()
        }
    - log:
        message: ${! json() }
output:
  kafka_franz:
    seed_brokers:
      - ${REDPANDA_BROKERS}
    topic: "rpg-response"
    compression: none
```


### 13.  run pipeline in the background

`rpk connect run -e .env npc2-openai.yaml &`  (hit enter to shove into the background)

### 14.  ask it a question

`echo "how are you?" | rpk topic produce npc2-request`


15.  response should come back in the terminal


---

## Now for the complex stuff.


###17.  create the routing rpcn config

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


### 18.  run the pipeline 

```
rpk connect run -e .env npc-reroute.yaml &
```


### 19.  ask it a qeustion 

```
rpk topic produce npc-request
```

Then produce a message from npc1

```json
{"who: "npc1", "tell me about your hat."}
```

This one should take a little while to return since it is running against your local LLM, and it should be in the "voice" of NPC1 based on the prompt we included in the pipeline config for NPC1.


```json
{"who: "npc2", "tell me about your hat."}
```

This one should return very quicly since it is running against OpeanAI, and it should be in the "voice" of NPC2 based on the prompt we included in the pipeline config for NPC2.



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

export REDPANDA_BROKERS=localhost:19092,localhost:29092,localhost:39092

cd ~/redpanda-connect-genai-gaming-demo/frontend
node index.js &
echo http://$HOSTNAME.$_SANDBOX_ID.instruqt.io






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


