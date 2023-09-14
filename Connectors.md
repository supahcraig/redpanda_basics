# Using Redpanda Managed Connectors

*NOTE* the connectors UI is going to be overhauled in "2-4 weeks", as of 4/25/2023.   We shall see.


Install instructions for Postgres on AL2023:
https://linux.how2shout.com/how-to-install-postgresql-15-amazon-linux-2023/

sudo dnf update
sudo dnf install postgresql15.x86_64 postgresql15-server
sudo postgresql-setup --initdb
sudo systemctl start postgresql
sudo systemctl enable postgresql
sudo systemctl status postgresql.service
sudo passwd postgres


---

## S3 Connector

We have a guide in our docs, it is wildly outdated.
https://docs.redpanda.com/docs/deploy/deployment-option/cloud/managed-connectors/create-s3-sink-connector/#choose-connector-type

### S3 Bucket Policy

For starters, the policy as-written won't work, I had to modify it as follows:

```
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "Statement1",
			"Principal": "*",
			"Effect": "Allow",
			"Action": [
				"s3:GetObject",
				"s3:PutObject",
				"s3:AbortMultipartUpload",
				"s3:ListMultipartUploadParts",
				"s3:ListBucketMultipartUploads"
			],
			"Resource": [
				"arn:aws:s3:::cnelson-bucket/*",
				"arn:aws:s3:::cnelson-bucket"
			]
		}
	]
}
```

Specifically I needed to add the Principal line and the resource line for the bucket by itself (not including the `*/` suffix.   There is probably a way to further restrict that principal.

Then I needed to stop blocking public access.   If there is a subset of permissions, I didn't bother trying to find it.

### Example config

This is the config I went with:

```
{
    "name": "cnelson-s3",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "org.apache.kafka.connect.storage.StringConverter",
    "file.name.prefix": "from_connector/",
    "topics": "s3_topic",
    "aws.s3.bucket.name": "cnelson-bucket",
    "aws.access.key.id": "my_aws_access_key_id",
    "aws.secret.access.key": "my_aws_secret_key",
    "aws.s3.region": "us-east-2",
    "connector.class": "com.redpanda.kafka.connect.s3.S3SinkConnector"
}
```

### Operations

As soon as you start publishing messages to the topic, you should be able to see them in the console.   The connector should start (multipart?) copying them up to s3.  This implies there is consumer....which there is, named `connect-<topic name>`.   

TODO:  need to understand how auth/acl's work with this consumer group.   And why I didn't need to specify any credentials here but I did on the Postgres connector.




# Connect to Postgres via Bastion Host/SSH Tunnel

## Create the Tunnel

From the bastion host:

`ssh -L bastion.ip:5432:postgres.ip:5432 ec2-user@postgres.ip -i keypair.pem`

This opens the SSH tunnel ON the bastion host, through to the postgres server on port 5432.   Relying on localhost may not work here, because localhost may resolve to an IPv6 address
https://serverfault.com/questions/147471/can-not-connect-via-ssh-to-a-remote-postgresql-database/444229#444229?newreg=fbdc2100c9dc464bb747dda830b52c28

## Use the Tunnel

From a different remote host:

`psql --port=5432 --host=10.100.11.38 -c "select * from pg_catalog.pg_tables" -U postgres`

where the host is the IP of the postgres instance, and `-U` is the database user to run the query as.

### Install Postgres client

`sudo apt-get install postgresql-client`


## CONSIDERATIONS

Make sure the firewall is open on the necessary ports to allow traffic from the "local" machine to the "tunnel" (bastion host), and then from the tunnel to the "remote" machine (postgres db).  The connector instances won't have a public IP, so you have options:

There are multiple ways to make the connection.
* They can setup peering and routing to the VPC where the particular data store is.
* In AWS, they can attach the Redpanda VPC to a Transit Gateway
* They can also setup Private Links and create PL attachments in the Redpanda VPC
* If the data store is public, connectors will connect through the NAT Gateway of the Redpanda VPC, the IP to allow list there is the NAT Gateway public IP.
* Cloud VPNs are also possible.



# Use a SSH Tunnel with Debezium

```
{
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "topic.prefix": "crn",
    "database.hostname": "13.59.23.149",
    "database.user": "postgres",
    "database.password": "postgres",
    "database.dbname": "postgres",
    "database.sslmode": "disable",
    "plugin.name": "pgoutput",
    "key.converter": "org.apache.kafka.connect.json.JsonConverter",
    "key.converter.schemas.enable": true,
    "key.converter.json.schemas.enable": true,
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": true,
    "value.converter.json.schemas.enable": true,
    "header.converter": "org.apache.kafka.connect.storage.SimpleHeaderConverter",
    "table.include.list": "test",
    "topic.creation.enable": true,
    "topic.creation.default.partitions": "5",
    "topic.creation.default.replication.factor": "3",
    "name": "debezium-postgresql-connector-dowc"
}
```



## Running the SSH Tunnel as a systemd service

Borrowed heavily from this:  https://gist.github.com/drmalex07/c0f9304deea566842490

TODO:  This needs some cleanup to parameterize the hosts & the user security is probably a complete anti-pattern.  But it works.

In `/etc/default/secure-tunnel@postgres`:

```
TARGET=postgres
LOCAL_ADDR=13.59.23.149
LOCAL_PORT=5432
REMOTE_PORT=5432
```

and then in `/etc/systemd/system/secure-tunnel@.service`:

```
[Unit]
Description=Setup a secure tunnel to %I
After=network.target

[Service]
Environment="LOCAL_ADDR=localhost"
EnvironmentFile=/etc/default/secure-tunnel@%i
ExecStart=/usr/bin/ssh -NT -o ServerAliveInterval=60 -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=no -L 10.100.11.38:${LOCAL_PORT}:10.100.14.63:${REMOTE_PORT} ec2-user@10.100.14.63 -i /etc/default/cnelson-kp.pem

# Restart every >2 seconds to avoid StartLimitInterval failure
RestartSec=125
Restart=always

[Install]
WantedBy=multi-user.target
```
