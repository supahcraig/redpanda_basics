# High Watermark ETL with Redpanda Connect

You can use Redpanda Connect to track a high watermark column using a cache processor.


## Breaking down the pipeline

There is quite a bit going on here, let's break it down into the individual components.   Like the great man once said, thee's no trick.  It's just a little trick.

_NOTE: this assumes the high watermark column is numeric.  If it is a date or timestamp, it needs some special treatment._


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

From the jump, we need to fetch (get) the current high watermark (aka HWM) value from a cache.  The cache is defined as a resource near the end of the config.  What's important here is that the HWM is stored as a key/value pair in the cache.

```yaml
pipeline:
  processors:
    - cache:
        resource: cached_pgstate
        operator: get
        key: table_cursor
```

---

### Trick #3 - what if it's the first time running this and the cache doesn't exist yet?

Fetching the cache will throw an error if the cache key doesn't exist, so we'll use a `catch` to trap for that.   If the value isn't found, assume the current HWM is -1, which _theoretically_ would be the lowest value in your table.  But you should set it accordingly.   You could also set it to purposefully skip rows (i.e. "only pull new rows"). 

```yaml
    - catch:
      - mapping: 'root.seq = -1'
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
        args_mapping: root = [ this.seq ]

    - unarchive:
        format: json_array
```

---

### Trick #6 - no real trick here, just publish the messages to Redpanda

```yaml
output:
  broker:
    # send each processed message to each output sequentially
    pattern: fan_out_sequential
    outputs:
      - stdout: {}

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
              root.seq = json("seq").from_all().max()
        cache:
          target: cached_pgstate
          key: table_cursor
          max_in_flight: 1
```

---

### Trick #8 - Using a multi-level cache for speed & persistence

The cache itself is defined as a resource, which allows it to be referenced elsewhere in the pipeline.  It's a multi-level cache, with in-memory (`inmem`) being the primary and sql (`pgstate`)  being the fallback/persistent layer.  When `get` operations are performed against the cache, it will first check in memory for the requested key, and if not found, will then fall back to checking Postrges.

Here we set up the cache table (`rpcn_connect_state`) in Postgres, defining the key & value fields.  This will end up being a single row with a json object of the form `{key_column: key, value_column, val}` which you can query for yourself inside the database.  

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
      table: rpcn_connect_state
      key_column: key
      value_column: val
      set_suffix: ON CONFLICT(key) DO UPDATE SET val=excluded.val
      init_statement: |
        CREATE TABLE IF NOT EXISTS rpcn_connect_state (
          key bytea PRIMARY KEY,
          val bytea
        );
```
