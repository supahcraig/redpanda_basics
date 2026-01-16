

Run the serverless-specific terraform.

# Networking/Security

You may need to peer VPCs, depending on your delpoyment.   Also, terraform creates a security group for Aurora that allows inbound traffic on 5432 from it's own SG.  So if you need to peer, you'll also need to add a firewall rule to allow 5432 from the Redpanda CIDR.


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


The role on the RDS side needs this tag to allow for the assuming of the role

aws iam tag-role \
  --role-name demo-aurora-iam-demo-user \
  --tags Key=redpanda_scope_redpanda_connect,Value=true \
  --profile se_demo


psql "host=demo-aurora-pg.cluster-cz84a4eu2syk.us-east-2.rds.amazonaws.com \
  port=5432 \
  dbname=demo_db \
  user=postgres \
  sslmode=require"


-- Example replication user that will authenticate via IAM token (no password needed)
CREATE USER iam_demo_user;

-- Allow IAM token auth for this user
GRANT rds_iam TO iam_demo_user;

-- Allow logical replication privileges
GRANT rds_replication TO iam_demo_user;

-- (Optional but common) allow connecting to your DB
GRANT CONNECT, CREATE ON DATABASE demo_db TO iam_demo_user;

-- Create the publication as the table owner
CREATE PUBLICATION pglog_stream_rpcn_iam_test FOR TABLE public.iamuser_test;




"arn:aws:iam::211125444193:role/demo-aurora-iam-demo-user"


