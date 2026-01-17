# IAM authentication to RDS cross-account

Goal:  Allow for a BYOC cluster using Redpanda Connect's postgres_cdc connector to authenticating to Aurora Postgres Serverless where Aurora lives in a different account from the Redpanda cluster.

Repdanda will typically live in a separate account from other customer cloud resources.   So for Redpanda Connect to talk to things like Aurora Postgres in a different account using IAM auth, we have some IAM work to do.   First and foremost, we need an IAM Role that allows for rds-db:connect to the database/user.  This role must live in the same account as the Aurora instance.   This role will be assumed by Redpanda Connect, so it will need a trust policy to allow it to trust the RPCN role, and will allow RPCN to assume the dbconnect role.   It will make more sense when you see it in practice.   That RPCN role will also need a policy that allows it to assume the dbconnect role.   Lastly, we'll need to specify in the pipeline config itself the arn of the dbconnect role so it knows exactly what you want it to do.

On an EC2 instance, it is much easier since the EC2 instance can have an IAM role attached, but since BYOC & RPCN on BYOC runs in EKS, it is more complicated, involving IRSA among other way in the weeds details.

---

# Walkthrough

1.  either copy the terraform files to a local folder, or clone this repo

2.  Update tfvars with your specifics.

3.  run the terraform

```bash
terraform init
terraform apply --auto-approve
```

This will create a new VPC in the specified AWS acct, along with a public-facing Aurora instance, the IAM role needed to connect into it, and a security group that will allow connectivity on 5432 from your home IP & also the CIDR of either your Redpanda cluster's NAT Gateway (if accessing your database over the public internet) or the CIDR range of your Redpanda cluster.   If using private networking you will need to peer this new VPC to the redpanda VPC, which is not handled by this bit of terraform. 

4.  Create the necessary database objects & privs

```bash
psql "host=$(terraform output -raw db_cluster_endpoint) \
  port=5432 \
  dbname=$(terraform output -raw db_name) \
  user=postgres \
  sslmode=require"
```

It will prompt you for the password, which is postgres (unless you changed it).

Run the SQL in `cdc_setup.sql` which will create several objects & grant privs corresponding to the `iam_demo_user` (again, unless you changed it).

5.  Create the RPCN pipeline

6.  Insert a row into the table created in step 4, and check the topic to see that insert replicate into Redpanda.




---
## IAM roles

This section describes the what & why for the IAM roles needed to make this work.   It boils down to 2 simple things:  an IAM role owned by the Aurora acct that allows connect, and then a policy on the Redpanda side that allows RPCN to assume that database connect role.   

### db connect role 

#### Permissions

In the account that owns the database, you will need an IAM role with permissions to allow it to connect to the database, but the resource for this role isn't the _database_, it's actually a user within the database.   You can find part of this in the console for your Regional Cluster (not the writer instance) under Configuration > Resource ID.   It will look like `cluster-X4BNAQDEZCAUGHTITYK7B6YCAQ`.   You will also specify a database user as part of the resource.  It doesn't have to be created _yet_, but it will be the user RPCN connects as.  Again, this role must live in the same AWS account as where Aurora lives.


Name it `rpcn-demo-xaccount-rds-connect-role`

```json
{
    "Statement": [
        {
            "Action": "rds-db:connect",
            "Effect": "Allow",
            "Resource": "arn:aws:rds-db:us-east-2:<Aurora PG AWS Acct ID>:dbuser:cluster-X4BNAQDEZCAUGHTITYK7B6YCAQ/iam_demo_user"
        }
    ],
    "Version": "2012-10-17"
```

The resource ID of your Aurora instance can also be found via the AWS cli.  Note that if you're using the terraform from this repo, you will need to specify the profile you used to deploy Aurora (se_demo for me).

```bash
aws rds describe-db-clusters \
  --query "DBClusters[?DBClusterIdentifier=='demo-aurora-pg'].[DBClusterIdentifier,DbClusterResourceId,Endpoint]" \
  --output table --profile se_demo
```

#### Trust Policy

The dbconnect role will be assumed by RPCN, so we have to allow it to trust the role that RPCN will be using to assume the dbconnect role.  The principal is the arn of that RPCN role, which was created when the Redpanda Cluster was created and will be owned by the account where Redpanda is deployed.   The role itself is named like `redpanda-<Your Redpanda Cluster ID>-redpanda-connect-pipeline`.

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::<Redpanda AWS Acct ID>:role/redpanda-curl3eo533cmsnt23dv0-redpanda-connect-pipeline"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
```

#### Tagging (important!)

The RPCN role specifies a condition, which requires that the dbconnect role have a specific tag:
key: `redpanda_scope_redpanda_connect"`
value: `true`

If you do not include this tag, the role assumption will fail.


### Redpanda Connect Role

As mentioned above, this role is created when your Redpanda cluster is created.   If your cluster had cluster ID `curl3eo533cmsnt23dv0` then your role would be named `redpanda-curl3eo533cmsnt23dv0-redpanda-connect-pipeline`.  It is vital that we don't change the policies attached to this role.   Out of the box there is a policy that allows it to read AWS secrets, and a trust policy that involves IRSA, OIDC, federated identities...it complex.  The good news is you don't need to worry about this.   There may also be another policy in this role (but there might not be, depends on how the cloud team ends up implementing this), but if we want to be explicit, we can create a new policy for this role.   It is important to understand that if we change the existing policies those changes will be reverted by the Redpanda reconciliation process.   But _adding a policy_ won't be subject to that.   So we will need to create a policy that allows this role to assume the dbconnect role.   It should look very much just like this, and it should be attached to the RPCN role.

Note:  the terraform in this repo will not generate this policy, nor will it attach it to the RPCN role.  It is left as an exercise to the reader (for now).

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
                "arn:aws:iam::<Aurora PG AWS Acct ID>:role/rpcn-demo-xaccount-rds-connect-role"
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



