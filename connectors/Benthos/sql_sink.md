## Spin up a Postgres container

```console
docker run --name pg -p 5432:5432 -e POSTGRES_PASSWORD=mypass -e POSTGRES_USERNAME=myuser -d postgres
```



## Insert random data into Postgres

This should take about a minute forty-five to generate ~100k records.

```yaml
input:
  generate:
    interval: 0.001s
    mapping: |
      root.ID = uuid_v4()
      root.Name = ["frosty", "spot", "oodles"].index(random_int() % 3)
      root.Gooeyness = (random_int() % 100) / 100


output:
  sql_insert:
    driver: postgres
    dsn: postgres://myuser:mypass@localhost:5432/postgres?sslmode=disable
    table: z
    columns: [id, name, gooeyness, ts]
    args_mapping:  root = [this.ID, this.Name, this.Gooeyness, timestamp_unix_micro()]
    init_statement: |
      create table if not exists z (
      id varchar(100),
      name varchar(100),
      gooeyness decimal(10, 2),
      ts bigint);
```


## Fetch data from Postgres to stdout


```yaml
input:
  sql_select:
    driver: postgres
    dsn: postgres://postgres:postgres@localhost:5432/postgres?sslmode=disable
    table: z
    columns: [id, name, gooeyness, ts]


output:
  stdout: {}
```


## Read from PG, send to Redpanda

```yaml
input:
  sql_select:
    driver: postgres
    dsn: postgres://myuser:mypass@localhost:5432/postgres?sslmode=disable
    table: z
    columns: [id, name, gooeyness, ts]

output:
  label: ""
  kafka:
    addresses: [localhost:19092]
    topic: "pg_sink"
```
