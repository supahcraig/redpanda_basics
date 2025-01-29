# High Watermark ETL with Redpanda Connect

You can use Redpanda Connect to track a high watermark column using a cache processor.


```bash
git clone https://github.com/supahcraig/redpanda_basics.git
cd redpanda_basics/connectors/Benthos/demos/SQL_delta
```

## Create the Docker Environment

Use docker-compose to create containers for Postgres, Redpanda, Redpanda Console, and PGadmin.   Default users/passwords are defined in the docker-compose yaml, but also carried through to the `pgpass` and `servers.json` files that are used by PGadmin for mounting the database at startup.

```bash
docker-compose up -V
```

## CDC in action




---

## Breaking down the pipeline

There is quite a bit going on here, let's break it down into the individual components.   Like the great man once said, thee's no trick.  It's just a little trick.



### Trick #1 - making it run continually

By nature, the SQL-based connectors tend to operate as one-shot connectors, so you need to coerce them into running perpetually.   We do that here by pushing the SQL logic into a procesing pipeline, and using a `generate` input on a short interval to send a dummy message that will trigger the actual processing contained in the pipeline.

```yaml
input:
  generate:
    interval: '@every 5s'
    mapping: 'root = {}'
```

---

### Trick #2 - Using a cache store the high watermark

From the jump, we need to fetch (get) the current high watermark (aka HWM) value from a cache.  The cache is defined as a resource near the end of the config.  What's important here is that the HWM is stored as a key/value pair in the cache, where the key is `content_notification_id`.  This can be whatever you like, but I've chosen to align my key name with the table & field I'm tracking.  This will allow us to use a single cache table to track the HWM across multiple tables.

```yaml
pipeline:
  processors:
    - cache:
        resource: cached_pgstate
        operator: get
        key: content_notification_id
```

---

### Trick #3 - what if it's the first time running this and the cache doesn't exist yet?

Fetching the cache will throw an error if the cache key doesn't exist, so we'll use a `catch` to trap for that.   If the value isn't found, assume the current high watermark (aka HWM) is -1, which _theoretically_ would be the lowest value in your table.  But you should set it accordingly.   You could also set it to purposefully skip rows (i.e. "only pull new rows"). 

```yaml
    - catch:
      - mapping: 'root.hwm_id = -1'
```

If you're tracking a timestamp column, it is a little trickier since we have to assume the starting point is some date arbitratily in the past, and then cast that as a unix timestamp.

```yaml
    - catch:
      - mapping: 'root.hwm_ts = "1980-01-01 00:00:00.000".ts_parse("2006-01-02 15:04:05.000").ts_unix_milli()'
```

---

### Trick #4 - log which cache is being used

It's very easy to accidentally use the wrong cache, so logging it is very helpful for troubleshooting.

```yaml
    - log:
        message: 'Using cached value: ${! content() }'
```

---

### Trick #5 - fetching the data from within the pipeline processors section, rather than as the primary input

This will connect to the database and run the query, injecting the cached value (`this.seq`) into the where clause.  The response will be an array of json objects, so we use `unarchive` to remove them from the array and instead have a json object for each row returned by the query.

```yaml
    - sql_raw:
        driver: postgres
        dsn: postgres://root:secret@localhost:5432/root?sslmode=disable

        query: 'select * from cms.content_notification_status where seq > $1'
        args_mapping: root = [ this.hwm_id ]

    - unarchive:
        format: json_array
```

For timestamps, we need to handle the data type casting inside the SQL, like this:

```yaml
        query: 'select * from content_notification where notification_timestamp > to_timestamp( $1 / 1000.0)'
        args_mapping: root = [ this.hwm_ts ]
```

_TODO:  store the actual "pretty" timestamp in the cache.  This would be nice becasue you could quickly see where the HWM is relative to the current time._


---

### Trick #6 - no real trick here, just publish the messages to Redpanda

_I have the output logging commented out here to allow for easy visibility to the cache value that is being used._

```yaml
output:
  broker:
    # send each processed message to each output sequentially
    pattern: fan_out_sequential
    outputs:
      #- stdout: {}

      - kafka_franz:
          seed_brokers:
            - localhost:19092
            - localhost:29092
            - localhost:39092
          topic: content_delta
```

---

### Trick #7 - record the new HWM into the cache

The new HWM will be set by finding the max value of the HWM field in each batch of data returned by the query.   This eliminates the need to explictily sort the data here, or by adding an ORDER BY in the query, which could be an expensive operation.  The HWM is put into `root.seq` and then sent to the cache.   It's important to only update the cache _after_ the messages have been published to Redpanda.  Otherwise data loss could occur if there was a problem publishing.

```yaml
      - processors:
          - mapping: |
              root.hwm_id = json("id").from_all().max()
        cache:
          target: cached_pgstate
          key: content_notification_id
          max_in_flight: 1
```

Timestamps require special handling, since bloblang doesn't really have a concept of datetimes, and therefore can't do a comparison to see what the max value is.  So we have to convert to a unix timestamp, but _of course_ Postgres doesn't return the timestamp in the RFC3339 format that bloblang requires so we need to `ts_parse` it from the ISO 8601 format into RFC3339 format.   _IF_ the timestamp were already in RFC3339 format, we could simply call `ts_parse` without any arguments.   And then since we're actually operating on a set, we need to map this conversion onto each row in the set.  That 2006 date buried in the conversion is how Golang identifies date components; it's not actually using 2006 as the date, only as a formatting directive.

```yaml
      - processors:
          - mapping: |
              root.hwm_ts = json("notification_timestamp").from_all().map_each(str -> str.ts_parse("2006-01-02T15:04:05.999999Z").ts_unix()).max()
```

---

### Trick #8 - Using a multi-level cache for speed & persistence

The cache itself is defined as a resource, which allows it to be referenced elsewhere in the pipeline.  It's a multi-level cache, with in-memory (`inmem`) being the primary and sql (`pgstate`)  being the fallback/persistent layer.  When `get` operations are performed against the cache, it will first check in memory for the requested key, and if not found, will then fall back to checking Postrges.

Here we set up the cache table (`rpcn_connect_state`) in Postgres, defining the key & value fields.  This will end up being a single row with a json object of the form `{key_column: key, value_column, val}` which you can query for yourself inside the database.  You don't have to pre-create the cache table, the `init_statement` will create it for you if it doesn't already exist.

```yaml

cache_resources:
  - label: cached_pgstate
    multilevel: [ inmem, pgstate ]

  - label: inmem
    memory:
      compaction_interval: ''

  - label: pgstate
    sql:
      driver: postgres
      dsn: postgres://root:secret@localhost:5432/root?sslmode=disable
      table: rpcn_hwm_state
      key_column: key
      value_column: val
      set_suffix: ON CONFLICT(key) DO UPDATE SET val=excluded.val
      init_statement: |
        CREATE TABLE IF NOT EXISTS rpcn_hwm_state (
          key bytea PRIMARY KEY,
          val jsonb
        );
```

The row in the cache table will look like this:

`rpcn_hwm_state`

|Key|Val|
|---|---|
|`content_notification_id`|`{"hwm_id": 4005}`|
|`content_notification_ts`|`{"hwm_ts": 1738158502`|
