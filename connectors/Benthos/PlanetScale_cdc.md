# PlanetScale Postgres CDC with RPCN

I used my CC to spin up a postgres instance on PlanetScale and created a default superuser role to eliminate PG privs as a potential variable.


## Database setup

From anywhere, connect in via psql.   I got this connection string by going to "Connect to your database" and selecting PostgreSQL CLI.  It had my username (role?) & password already populated.  I have no idea how those were set; I didn't do it explicitly.


```bash
psql 'host=aws-us-east-2-2.pg.psdb.cloud port=5432 user=postgres.3qo6fzyr5s2s password=<supplied by planetscale> dbname=postgres sslnegotiation=direct sslmode=verify-full sslrootcert=system'
```


```sql
CREATE TABLE test_events (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    message TEXT
);

CREATE PUBLICATION my_cdc_publication FOR TABLE test_events;

SELECT pg_create_logical_replication_slot(
  'my_cdc_slot',
  'pgoutput',
  false,
  false,
  true
);


INSERT INTO test_events (message)
VALUES ('hello from planetscale');
```

That's all I had to do from the PlanetScale side.


## Redpanda Connect

First create a topic `planetscale.cdc` that will hold the CDC messages.


### Certs

You can make this work without any sort of certs by speficying `skip_cert_verify: false` but that's not going to work for a production deployment.  Instead, get the PlanetScale public cert:

```bash
openssl s_client -showcerts -connect aws-us-east-2-2.pg.psdb.cloud:5432 </dev/null
```

which will return 2 certs.   You want the 2nd one, which you'll stick into the `root_cas` section. 


```yaml
input:
  postgres_cdc:
    dsn: postgresql://postgres.3qo6fzyr5s2s:${secrets.PLANETSCALE_PASS}@aws-us-east-2-2.pg.psdb.cloud:5432/postgres?sslmode=require

    # Limit capture scope
    schema: public
    tables: [ test_events ]

    # Use the SAME slot you created in PlanetScale (failover=true)
    slot_name: rp_cdc_slot

    # Start with snapshot mode so you get initial data + then WAL changes
    stream_snapshot: true
    snapshot_batch_size: 1000

    # Optional but often helpful for debugging/ordering
    include_transaction_markers: true

    tls:
      skip_cert_verify: false
      root_cas: |
        -----BEGIN CERTIFICATE-----
        MIIEVzCCAj+gAwIBAgIRAKp18eYrjwoiCWbTi7/UuqEwDQYJKoZIhvcNAQELBQAw
        snip snip snip
        +VUwFj9tmWxyR/M=
        -----END CERTIFICATE-----

output:
  redpanda_common:
    topic: planetscale.cdc

redpanda:
  # From your Redpanda Serverless cluster connection info
  seed_brokers:
    - ${REDPANDA_BROKERS}
    
  tls:
    enabled: true

  sasl:
    - mechanism: SCRAM-SHA-256
      username: ${secrets.CNELSON_SASL_USER}
      password: ${secrets.CNELSON_SASL_PASSWORD}
```


That's it!
