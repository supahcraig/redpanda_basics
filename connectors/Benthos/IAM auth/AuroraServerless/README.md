

Run the serverless-specific terraform.


# Database setup

## db user setup

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

## SQL to test

```sql

CREATE TABLE iamuser_test(x int);

INSERT INTO iamuser_test VALUES (1);
```

---


# IAM Roles

RPCN ships with a role named `redpanda-<your cluster ID>-redpanda-connect-pipeline` and it has 2 things out of the box:  a policy for secrets access, and a complext trust policy for the ODIC provider and a bunch of stuff you should never have to touch.

To get this to work on BYOC, we'll need do 2 things in IAM:

1.  add an additional policy to the `redpanda-<your cluster ID>-redpanda-connect-pipeline` role that allows for the pod to assume the role that allows access to RDS.
2.  > Gavin has indicated that he might like to make this be a default policy with a wildcard for the assumed role, which means that you would not have to modify this policy for each database, for example.    
3.  ensure our "cross account rds access role" has a trust policy that points back to the `redpanda-<your cluster ID>-redpanda-connect-pipeline` role.



## Assume Role Policy

> I don't yet understand the importance of the Condition section.

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "sts:AssumeRole"
            ],
            "Resource": [
                "arn:aws:iam::861276079005:role/cnelson-aurpg-cross-account-db-access-role"
            ],
            "Condition": {
                "StringEquals": {
                    "aws:ResourceTag/redpanda_scope_redpanda_connect": "true"
                }
            }
        }
    ]
}
```



## cross acct role:  cnelson-aurpg-cross-account-db-access-role

### policy:  cnelson-aurpg-rds-db-connect

The resource here is the arn of the database user.

> I'm not sure how to find this; terraform built it for me.

```json
{
    "Statement": [
        {
            "Action": "rds-db:connect",
            "Effect": "Allow",
            "Resource": "arn:aws:rds-db:us-east-2:861276079005:dbuser:cluster-X4BNAQ55GVOVZDA3IYK7B6YCAQ/iam_user"
        }
    ],
    "Version": "2012-10-17"
}
```


### Trust policy

This trust policy must reference the shipped role as the principal.

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::861276079005:role/redpanda-curl3eo533cmsnt23dv0-redpanda-connect-pipeline"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
```
