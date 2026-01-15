placeholder



Run the serverless-specific terraform.




```sql
-- create a dedicated login role
CREATE ROLE iam_user LOGIN;

-- allow IAM authentication for it
GRANT rds_iam TO iam_user;

-- (optional) give it a simple capability for testing
GRANT CONNECT ON DATABASE app TO iam_user;

-- if you want it to be able to do logical replication later:  // this is not necessary/recommended
-- ALTER ROLE iam_user WITH REPLICATION;

GRANT rds_replication TO iam_user;

GRANT CREATE ON DATABASE app TO iam_user;

CREATE PUBLICATION pglog_stream_rpcn_iam_test FOR TABLE public.iamuser_test;

```



modified the cross-account role trust relationship, changing the principal from cnelson-aurpg-rpconnect-app-role to arn:aws:iam::861276079005:role/redpanda-curl3eo533cmsnt23dv0-redpanda-connect-pipeline
