# Snowflake Streaming

This is the new connector that uses the snowflake SDK behind the scenes (ported to golang), bypassing snowpipe & explicit stages etc.   


## Snowflake setup



### Create a trial account at snowflake.com

It's free.  Just do it.


### Create the minimum required objects

```sql
create database redpanda;

use database redpanda;
use schema public;


drop table public.rpcn_streaming;
create table public.rpcn_streaming
(id string,
 gooeyness number(10, 3),
 name varchar,
 ts int);
```


### Public/Private key stuff

```bash
openssl genrsa -out snowflake_private_key.p8 2048

openssl pkcs8 -topk8 -inform PEM -outform PEM -in snowflake_private_key.p8 -out snowflake_private_key.pem -nocrypt

openssl rsa -in snowflake_private_key.p8 -pubout -out snowflake_public_key.pub
```


From the Snowflake UI:

```sql
alter user craignelson7007@ set rsa_public_key = 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAkpuXnZ0XmMbLvT3PVeEV
SGparWNnzXQ6dBjznxnaD6PwLyUGFUxzFsNFr77J/k+r+w1DAyPDD3gKp8p6Ub0S
5NJTHIS IS A FAKE PUBLIC KEY BUT YOURS GOES HERE!bHdPQGqQuB4tWKN
C8IdJi84zKv7R+ayuCYn532wreEzlSdbMYJlKJnJeyo+2r/OfM84ORGJnXVZ+YFW
PQpGQ7lR6BLAH-BLAH-BLAH-BLAH-BLAH-BLAH-wFRddfRizpbIEEbvj5VvL4x+T
HvvD5j61WxTwkkACGgNmHbcr5mwDL2XEjTaaSlWlKC4eo/YOEL8gedNCFVunAgyS
AQIDAQAB';
```

Also from the snowflake UI, run this "query" to get your account name:

```sql
select current_organization_name() || '-' || current_account_name();
```






## Redpanda Connect


```yaml
output:
  snowflake_streaming:
    account: "SLJFEJQ-ZM37871"
    user: "CRAIGNELSON7007"
    role: ACCOUNTADMIN
    database: "REDPANDA"
    schema: "PUBLIC"
    table: "rpcn_streaming"
    private_key_file: "./snowflake_private_key.pem"
    max_in_flight: 16
```


The output (apparently) maps the fields in the input document to the columns in the target table.  So your table must match your columns or else you'll need to inject a mapping step to map your input fields to your target columns.  Or make your target table be a `VARIANT` type and then sort it all out once it's landed into Snowflake.


---

## Examples


## Random Data Generation

```sql
create table public.rpcn_streaming
(id string,
 gooeyness number(10, 3),
 name varchar,
 ts int );
```


```yaml
input:
  generate:
    interval: 1s
    mapping: |
      root.ID = uuid_v4()
      root.Name = ["frosty", "spot", "oodles"].index(random_int() % 3)
      root.Gooeyness = (random_int() % 100) / 100
      root.ts = timestamp_unix_micro()


output:
  snowflake_streaming:
    account: "SLJFEJQ-ZM37871"
    user: "CRAIGNELSON7007"
    role: ACCOUNTADMIN
    database: "REDPANDA"
    schema: "PUBLIC"
    table: "rpcn_streaming"
    private_key_file: "./snowflake_private_key.p8"
```


## JSON data from Coinbase

```sql
create table coinbase_raw
(data variant, 
 ts int);
```


```yaml
input:
  label: "crypto_data_in"
  http_client:
    url: "https://api.coincap.io/v2/assets"
    verb: GET
    headers: {}
    rate_limit: "crypto_rate"
    timeout: 5s
    payload: ""
    auto_replay_nacks: true

rate_limit_resources:
  - label: crypto_rate
    local:
      count: 1
      interval: 10s

pipeline:
  processors:
    - mapping: |
        root = this
        root.ts = timestamp_unix_micro()

output:
  snowflake_streaming:
    account: "SLJFEJQ-ZM37871"
    user: "CRAIGNELSON7007"
    role: ACCOUNTADMIN
    database: "REDPANDA"
    schema: "PUBLIC"
    table: "coinbase_raw"
    private_key_file: "./snowflake_private_key.p8"
```

The data from this output is of this form:

```json
{"data":
  [
    {
      "changePercent24Hr": "-1.3753232779695647",
      "explorer": "https://blockchain.info/",
      "id": "bitcoin",
      "marketCapUsd": "1341600941536.2097327440519066",
      "maxSupply": "21000000.0000000000000000",
      "name": "Bitcoin",
      "priceUsd": "67833.7547087549335797",
      "rank": "1",
      "supply": "19777778.0000000000000000",
      "symbol": "BTC",
      "volumeUsd24Hr": "10692384482.8028490996449287",
      "vwap24Hr": "68260.1742360052591671"
    },
    {
      "changePercent24Hr": "-2.3703056834113872",
      "explorer": "https://etherscan.io/",
      "id": "ethereum",
      "marketCapUsd": "288943878648.7185089018275998",
      "maxSupply": null,
      "name": "Ethereum",
      "priceUsd": "2399.5652822016570620",
      "rank": "2",
      "supply": "120415093.8471679200000000",
      "symbol": "ETH",
      "volumeUsd24Hr": "4914739424.9312602514876560",
      "vwap24Hr": "2436.7446948299770532"
    }
  ]
}
```

So our Snowflake table _must_ have a column called `data` where the _value_ of `data` in that payload will land (since `data` is the parent key for this document).  You may be tempted to name your column something like `raw_json`, but what will end up happening is that the RPCN pipeline will run, but it will insert `null` into your table.  Why?  Because the payload you're trying to ingest doesn't have a corresponding key for `raw_json`.   Either re-map your inbound document or add a column to your table that corresponds to your inbound document.   Once your input & table match, what actually gets inserted into your column is the value for that key, which in this case is an array.  If you want the parent key to be included, you'll need to add a parent key via bloblang mapping.

This SQL shows how to flatten an array into a row-per-item, as well as how to pull out individual keys from the payload, since the array items are themselves json.

```sql
select f.value:explorer::string as explorer
     , f.value:name::string     as name
     , f.value:priceUsd::float  as price_usd
     , to_timestamp(r.ts/1000/1000) as date_added
from coinbase_raw r,
    LATERAL FLATTEN(input => r.data) AS f
where 1 = 1
  and f.value:name = 'Bitcoin'
  and 1 = 1
order by date_added desc;
```


## Using other SQL Tools

### Dbeaver

You can find the jdbc jar here:  https://repo1.maven.org/maven2/net/snowflake/snowflake-jdbc/3.19.1/
but it also prompted me to download it which was much easer.


#### Connection properties

* Host:  `<account>.snowflakecomputing.com`
  * Your account can be found from the Snowflake UI:  `select current_organization_name() || '-' || current_account_name();`
* Port:  `443`
* Authenticator:  `snowflake` (not sure what the other options do)

It did not require any other fancy settings.


### CLI / snowsql

```bash
brew install --cask snowflake-snowsql
```

```bash
snowsql -a <account> -u <username>
```

Then supply your password when prompted.


---
---
---


# Snowflake Customer Demo

https://docs.redpanda.com/redpanda-cloud/develop/connect/cookbooks/snowflake_ingestion/


## Data Generation Alpha

```yaml
input:
  generate:
    interval: 0.05s
    mapping: |
      root.event_id = uuid_v4()
      root.destination_system = ["DFW", "ORD", "YYZ"].index(random_int() % 3)
      root.notification_type = ["INITIAL", "UPDATE", "TOMBSTONE"].index(random_int() % 3)
      root.status = ["SUCCESS", "FAILURE", "IN-PROCESS"].index(random_int() % 3)
      root.duration = random_int(seed:timestamp_unix_nano(), min:0, max:100)

output:
  kafka_franz:
    seed_brokers:
        - seed-250c2947.cups29shnemutsavv9sg.byoc.prd.cloud.redpanda.com:9092
    topic: dg_alpha

    tls:
      enabled: true

    sasl:
      - mechanism: SCRAM-SHA-256
        username: testUser
        password: ${secrets.REDPANDA_PASS}
```

### Add a field to the payload

```yaml
pipeline:
  processors:
    - mapping: |
        root = this
        root.ts = timestamp_unix_micro()
```


## Data Generation Bravo

```yaml
input:
  generate:
    interval: 0.05s
    mapping: |
      root.assignment_id = uuid_v4()
      root.name = ["Craig", "Taylor", "Travis", "Sammy"].index(random_int() % 4)
      root.class = ["Calculus", "Differential Equations", "Linear Algebra", "Computer Science", "FORTRAN"].index(random_int() % 5)
      root.assignment_score =  random_int(seed:timestamp_unix_nano(), min:0, max:100)

output:
  kafka_franz:
    seed_brokers:
        - seed-250c2947.cups29shnemutsavv9sg.byoc.prd.cloud.redpanda.com:9092
    topic: dg_bravo
    key: ${! this.name }

    tls:
      enabled: true

    sasl:
      - mechanism: SCRAM-SHA-256
        username: testUser
        password: ${secrets.REDPANDA_PASS}
```

### Add some Transformations:  drop rows, calculate a new field, modify text

```yaml
pipeline:
  processors:
    - mutation: |
        root = if this.class == "FORTRAN" { deleted() }
        root.status = if this.assignment_score >= 50 { "passed" } else { "failed" }
        root.name = this.name.uppercase()
```


## Snowflake Streaming - BYOC

_note:  I used `private_key` rather than `private_key_file` and used the output from this command for the private key secret:

```bash
awk '{printf "%s\\n", $0}' snowflake_private_key.p8
```



```yaml
input:
  kafka_franz:
    seed_brokers: ["${REDPANDA_BROKERS}"]
    topics: ["dg_alpha", "dg_bravo"]
    consumer_group: "redpanda_connect_to_snowflake"
    tls: {enabled: true}
    checkpoint_limit: 4096
    sasl:
      - mechanism: SCRAM-SHA-256
        username: testUser
        password: ${secrets.REDPANDA_PASS}
    # Define the batching policy. This cookbook creates small batches,
    # but in a production environment use the largest file size you can.
    batching:
      count: 100 # Collect 10 messages before flushing
      period: 5s # or after 10 seconds, whichever comes first
output:
  snowflake_streaming:
    # Use your Snowflake account identifier
    account: "qakjoow-rp25422"
    user: STREAMING_USER
    role: REDPANDA_CONNECT
    database: STREAMING_DB
    schema: STREAMING_SCHEMA
    table:  ${!@kafka_topic}
    private_key: "${secrets.SNOWFLAKE_KEY}"
    schema_evolution:
      enabled: true
    max_in_flight: 1
```


## Custom topic:table mapping & dumping raw JSON

You'll have to pre-create the snowflake table with a variant column called `json_payload` ==> need to verify schema evolution won't auto-create the table here

```yaml
input:
  kafka_franz:
    seed_brokers: ["${REDPANDA_BROKERS}"]
    topics: ["dg_alpha", "dg_bravo"]
    consumer_group: "redpanda_connect_to_snowflake"
    tls: {enabled: true}
    checkpoint_limit: 4096
    sasl:
      - mechanism: SCRAM-SHA-256
        username: testUser
        password: ${secrets.REDPANDA_PASS}
    # Define the batching policy. This cookbook creates small batches,
    # but in a production environment use the largest file size you can.
    batching:
      count: 100 # Collect 100 messages before flushing
      period: 5s # or after 5 seconds, whichever comes first

pipeline:
  processors:
    # wraps the entire incoming message payload into a new json document 
    - mapping: |
        root = {
          "message_key": this.meta("kafka_key"),
          "insert_timestamp": now(),
          "message_timestamp": this.meta("kafka_timestamp_ms")
          "raw_json": this
        }

output:
  snowflake_streaming:
    # Use your Snowflake account identifier
    account: "qakjoow-rp25422"
    user: STREAMING_USER
    role: REDPANDA_CONNECT
    database: STREAMING_DB
    schema: STREAMING_SCHEMA
    # maps incoming topic names to output Snowflake table names
    table: ${! match @kafka_topic {
      "dg_alpha" => "json_raw_alpha",
      "dg_bravo" => "json_raw_bravo"
      } }
    private_key: "${secrets.SNOWFLAKE_KEY}"
    schema_evolution:
      enabled: true
      new_column_type_mapping: |-
        root = match this.name {
          this == "message_key" => "STRING",
          this == "insert_timestamp" => "TIMESTAMP",
          this == "message_timestamp" => "TIMESTAMP",
          _ +> "VARIANT"
        }
    max_in_flight: 1
```


# More than one way to skin a cat


##  pushing the content to a single json variant column

Also note that you could move the mapping from the pipeline and push it into the output itself:

```yaml
output:
  snowflake_streaming:
    # Use your Snowflake account identifier
    <snip>...
    mapping: |
      root = {
        "json_payload": this
      }
```

## Using metadata to handle the table mapping

```yaml
output:
  processors:
    - mapping: |
        root = this
        meta table_name = match {
          meta("kafka_topic") == "topic_1" => "table_alpha",
          meta("kafka_topic") == "topic_2" => "table_beta",
          _ => meta("kafka_topic")
        }
```

and then in your output, use `@table_name` or `${!metadata("table_name")}` as the dynamic table name.
