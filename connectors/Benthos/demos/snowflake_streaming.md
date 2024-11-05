# Snoflake Streaming

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
