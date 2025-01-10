# DB2 CDC with Kafka Connect

You'll need an EC2 instance open on port 8080 (if you want to use Redpanda Console) and 50000 (if you want to use a remote SQL client).

---

# Install DB2 via Docker

## First install Docker on an Ubuntu instance.

https://docs.docker.com/engine/install/ubuntu/

```bash
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
```

Then actually install Docker:

```bash
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo apt-get install docker-compose
```



## Spin up the Environment


### Use the Debezium-Examples repo, with some redpanda mods



### Clone the debezium-examples repo

```bash
git clone https://github.com/debezium/debezium-examples.git
cd debezium-examples/tutorial
```

There are are two files we'll need to modify for this to work _on our terms._

#### Modify the docker-compose

The docker-compose in their repo uses kafka + zookeeper, so we'll need to replace that with Redpanda & Console, but it's probably easier to just create a new docker-compose called `redpanda-db2-cdc-compose.yaml`

Note that the db2 & kafka connect containers aren't yet built; we'll do that as part of the compose up step.

```yaml
#version: '3.7'

networks:
  redpanda_network:
    driver: bridge
volumes:
  redpanda-0: null

services:
  redpanda-0:
    command:
      - redpanda
      - start
      - --kafka-addr internal://0.0.0.0:9092,external://0.0.0.0:19092
      - --advertise-kafka-addr internal://redpanda-0:9092,external://localhost:19092
      - --pandaproxy-addr internal://0.0.0.0:8082,external://0.0.0.0:18082
      - --advertise-pandaproxy-addr internal://redpanda-0:8082,external://localhost:18082
      - --schema-registry-addr internal://0.0.0.0:8081,external://0.0.0.0:18081
      - --rpc-addr redpanda-0:33145
      - --advertise-rpc-addr redpanda-0:33145
      - --mode dev-container
      - --smp 1
      - --default-log-level=info
    image: docker.redpanda.com/redpandadata/redpanda:latest
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
      - 4199:4199

  console:
    container_name: redpanda-console
    image: docker.redpanda.com/redpandadata/console:v2.5.2
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


  db2server:
    build:
      context: ./debezium-db2-init/db2server
    privileged: True
    ports:
     - 50000:50000
    environment:
     - LICENSE=accept
     - DBNAME=TESTDB
     - DB2INST1_PASSWORD=password
    volumes:
     - ./db2data:/database
    networks:
      - redpanda_network
  connect:
    image: debezium/connect-db2:${DEBEZIUM_VERSION}
    build:
      context: ./debezium-db2-init/db2connect
      args:
        DEBEZIUM_VERSION: ${DEBEZIUM_VERSION}
    ports:
     - 8083:8083
    networks:
      - redpanda_network
    links:
     - redpanda-0
     - db2server
    environment:
     - BOOTSTRAP_SERVERS=redpanda-0:9092
     - GROUP_ID=1
     - CONFIG_STORAGE_TOPIC=my_connect_configs
     - OFFSET_STORAGE_TOPIC=my_connect_offsets
     - STATUS_STORAGE_TOPIC=my_connect_statuses
    depends_on:
      - redpanda-0
      - db2server
```




### Spin up the container

Set an environment variable for the Debezium Version:

```bash
export DEBEZIUM_VERSION=2.1
```

And bring up the compose environment:

```bash
docker-compose -f redpanda-db2-cdc-compose.yaml up --build -V
```

This will build the db2 & Kafka Connect containers as part of the spin up process.  The `-V` flag should remove the volumes, but it might not.   `rm -rf db2data` might be necessary. 


This should create 4 containers:

* **redpanda-0** - A single node Redpanda "cluster"
* **redpanda-console** - The console, which is available on port 8080
* **tutorial_db2server_1** - The DB2 instance, which is available on port 50000; unsure why "tutorial" shows up in the name
* **tutorial_connect_1** - THe Kafka Connect instance

Monitor the logs here, as it can take a minute for everything to come up, especially the DB2 stuff.  Once it's done, you should see 4 tables in the `db2inst1` schema, as well as corresponding tables in the `ASNCDC` schema.

Here is the relevant connection info for the db2 instance to verify.  I use dbeaver, but there is a db2 console that would probably also work.
* **Username:** db2inst1
* **password:** password
* **database:** TESTDB
* **port:** _<defalt is 50000>_


### Register the connector

_Open another terminal window, again connected to your Ubuntu host._

The Kafka Connect instance is just the KC framework, you'll need to register the actual connector.

Save this config into a file called `db2-kc-config.json`

```json
{
    "name": "inventory-connector",
    "config": {
        "connector.class" : "io.debezium.connector.db2.Db2Connector",
        "tasks.max" : "1",
        "topic.prefix" : "db2server",
        "database.hostname" : "tutorial_db2server_1",
        "database.port" : "50000",
        "database.user" : "db2inst1",
        "database.password" : "password",
        "database.dbname" : "TESTDB",
        "database.cdcschema": "ASNCDC",
        "schema.history.internal.kafka.bootstrap.servers" : "redpanda-0:9092",
        "schema.history.internal.kafka.topic": "schema-changes.inventory"
    }
}
```

Note that these fields correspond to things we set up in kafka connect, but ALSO could things defined in the shell scripts that the container is using.   

Register the connector by using the Kafka Connect REST API:

```bash
curl -i -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @db2-kc-config.json
```

You should see a reponse like this:

```json
HTTP/1.1 201 Created
Date: Fri, 10 Jan 2025 21:05:21 GMT
Location: http://localhost:8083/connectors/copy-connector
Content-Type: application/json
Content-Length: 504
Server: Jetty(9.4.48.v20220622)

{
  "name":"inventory-connector",
  "config": {
    "connector.class":"io.debezium.connector.db2.Db2Connector",
    "tasks.max":"1",
    "topic.prefix":"db2server",
    "database.hostname":"tutorial_db2server_1",
    "database.port":"50000",
    "database.user":"db2inst1",
    "database.password":"password",
    "database.dbname":"TESTDB",
    "database.cdcschema":"ASNCDC",
    "schema.history.internal.kafka.bootstrap.servers":"redpanda-0:9092",
    "schema.history.internal.kafka.topic":"schema-changes.inventory",
    "name":"inventory-connector"},
    "tasks":[],
    "type":"source"
}
```


## Generate some CDC action

From you SQL client of choice, verify that ASNCDC is running.  If it's not running, look at the Debezium setup docs here:  https://debezium.io/documentation/reference/connectors/db2.html#setting-up-db2

```sql
VALUES ASNCDC.ASNCDCSERVICES('start','asncdc');
```

It should return `asncap is already running`.   If it returns a command to run, you're probably going to have a bad time the rest of the way.   The Debezium docs do tell you what to do in this scenario, but they are untested (and most of that didn't work for me anyway).



### Insert some data

```sql
INSERT INTO DB2INST1.CUSTOMERS (FIRST_name, last_name, email) VALUES ('Robert', 'Plant', 'feather@zep.com');
INSERT INTO DB2INST1.CUSTOMERS (FIRST_name, last_name, email) VALUES ('Jimmy', 'Page', 'zoso@zep.com');
INSERT INTO DB2INST1.CUSTOMERS (FIRST_name, last_name, email) VALUES ('John Paul', 'Jones', 'celtic@zep.com');
INSERT INTO DB2INST1.CUSTOMERS (FIRST_name, last_name, email) VALUES ('John', 'Bonham', 'circles@zep.com');
```

Within a few seconds after running each insert, you should see a corresponding row in the corresponding `ASNCDC` table.

If the connector is running, you should see corresponding messages show up in a topic called `db2server.DB2INST1.CUSTOMERS`

There is a TON of info in the CDC payload, but for right now we're primarily interested in the `payload` key.   Of course there is also all the relevent schema info

```json
{
 "schema": {
    "type":"struct"
    "fields":[...]
    "optional":false
    "name":"db2server.DB2INST1.CUSTOMERS.Envelope"
    "version":1
  }
 "payload": {
    "before":NULL
    "after":{
        "ID":1006
        "FIRST_NAME":"Robert"
        "LAST_NAME":"Plant"
        "EMAIL":"feather@zep.com"
  }
  "source": {
      "version":"2.1.4.Final"
      "connector":"db2"
      "name":"db2server"
      "ts_ms":1736540103938
      "snapshot":"false"
      "db":"TESTDB"
      "sequence":NULL
      "schema":"DB2INST1"
      "table":"CUSTOMERS"
      "change_lsn":"00000000:00000000:00000000048cc972"
      "commit_lsn":"00000000:0000187a:000000000004c4e9"
  }
"op":"c"
"ts_ms":1736540103938
"transaction":NULL
}
```

You'll also see new entries in the `my_connect_offsets` topic, which is where Debezium keeps track of what DB2 commits it has processed.



## Tearing it all down

```bash
docker-compose down
```


---
---
___

# Appendix of junk that might be helpful

## Docs & repos
https://debezium.io/documentation/reference/connectors/db2.html#_putting_tables_into_capture_mode

https://github.com/debezium/debezium-connector-db2/blob/main/src/test/docker/db2-cdc-docker/Dockerfile

https://github.com/debezium/debezium-examples/tree/main/tutorial#using-db2

You can maybe build the container using the above, but I manually copied those files into the running container.   Remains to be seen if this will work.  ==> _Narrator:  it did not._

---


## Bare metal install using a trial license

ae8oalim*(nkllC

https://debezium.io/documentation/reference/connectors/db2.html#_putting_tables_into_capture_mode

trial license is limited to 4 core/8GB

it also has some T&C about restrictions around replication & CDC.  YOLO.

```
- SQL Replication with non-Db2 databases ("Db2 databases" includes databases hosted on IBM Db2 Hosted). Use of SQL Replication for any other purpose, source or target besides homogeneous uses (Db2 LUW to Db2 LUW replication), for example to source or target Db2 for z/OS, Db2 iSeries, any Db2 Warehouse edition, and any appliance that embeds Db2 Warehouse, is not allowed

- Q Replication Functionality

- Change Data Capture functionality, except for supporting shadow table functionality within a single Db2 instance to replicate from row-organized tables into column-organized tables
```

https://early-access.ibm.com/software/support/trial/cst/programwebsite.wss?siteId=1120&h=null&tabId=


*trying to install this on bare metal is a nightmare.*

## IBM docker repo

Here are some random notes from stuff I built along the way.

https://www.ibm.com/docs/en/db2/11.5?topic=system-linux

The official IBM DB2 image can be had here, but it will be easier to use the debezium-examples docker build, which has cdc already enabled.

IBM Docker image: `icr.io/db2_community/db2`

_it remains unclear how to take this "base" image and make it CDC-enabled.  I tried, and failed._



