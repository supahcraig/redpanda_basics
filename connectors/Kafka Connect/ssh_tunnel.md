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


## Validaing the Tunnel is working

### via CLI/psql

from a terminal window on a machine that can reach the bastion host:

`psql --port=5432 --host=bastion.host.ip -c "select * from pg_catalog.pg_tables" -U your_username`


### via Dbeaver

Create a new postgres connection in dbeaver.  It's just like a normal connection to postgres, except that where you would normally put the database host you instead put the hostname/ip address of the bastion host.

---


# Running the SSH Tunnel as a systemd service

Borrowed heavily from this:  https://gist.github.com/drmalex07/c0f9304deea566842490

TODO:  This needs some cleanup to parameterize the hosts & the user security is probably a complete anti-pattern.  But it works.

## Service config

In `/etc/default/secure-tunnel@postgres`:

```
TARGET=postgres
BASTION_ADDR=10.100.11.38
BASTION_PORT=5432
POSTGRES_ADDR=10.100.14.63
POSTGRES_PORT=5432
```

## Service definition
and then in `/etc/systemd/system/secure-tunnel@.service`:

```
[Unit]
Description=Setup a secure tunnel to %I
After=network.target

[Service]
Environment="LOCAL_ADDR=localhost"
EnvironmentFile=/etc/default/secure-tunnel@%i
ExecStart=/usr/bin/ssh -NT -o ServerAliveInterval=60 -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=no -L ${BASTION_ADDR}:${BASTION_PORT}:${POSTGRES_ADDR}:${POSTGRES_PORT} ec2-user@${POSTGRES_ADDR} -i /etc/default/cnelson-kp.pem

# Restart every >2 seconds to avoid StartLimitInterval failure
RestartSec=125
Restart=always

[Install]
WantedBy=multi-user.target
```

## Start/Enable the service

Start the service, then enable it to ensure it starts on reboot.

`systemctl start secure-tunnel@postgres.service`

`systemctl enable secure-tunnel@postgres.service`
