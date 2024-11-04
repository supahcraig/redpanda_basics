# Snoflake Streaming

This is the new connector that uses the snowflake SDK behind the scenes, bypassing snowpipe (I think!)


## Snowflake setup

create an account


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



