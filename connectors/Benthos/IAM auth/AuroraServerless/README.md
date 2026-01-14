placeholder



Run the serverless-specific terraform.




```sql
-- create a dedicated login role
CREATE ROLE iam_user LOGIN;

-- allow IAM authentication for it
GRANT rds_iam TO iam_user;

-- (optional) give it a simple capability for testing
GRANT CONNECT ON DATABASE app TO iam_user;

-- if you want it to be able to do logical replication later:
-- ALTER ROLE iam_user WITH REPLICATION;
```
