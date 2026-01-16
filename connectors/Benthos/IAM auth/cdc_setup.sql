-- Example replication user that will authenticate via IAM token (no password needed)
CREATE USER iam_demo_user;

-- Allow IAM token auth for this user
GRANT rds_iam TO iam_demo_user;

-- Allow logical replication privileges
GRANT rds_replication TO iam_demo_user;

-- (Optional but common) allow connecting to your DB
GRANT CONNECT, CREATE ON DATABASE demo_db TO iam_demo_user;

-- Create a basic table to replicate
CREATE TABLE iamuser_test(x int);

INSERT INTO iamuser_test VALUES (1);

-- Create the publication as the table owner
CREATE PUBLICATION pglog_stream_rpcn_iam_test FOR TABLE public.iamuser_test;



