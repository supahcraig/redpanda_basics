# IAM authentication to RDS cross-account

Repdanda will typically live in a separate account from other customer cloud resources.   So for Redpanda Connect to talk to things like Aurora Postgres in a different account using IAM auth, we have some work to do.


## IAM role

In the account that owns the database, you will need an IAM role with permissions to allow it to connect to the 
