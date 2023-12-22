# Mongo Source Connector

(see below for Mongo sink connector notes)

----

## Install MongoDB on Amazon Linux 2023

https://linux.how2shout.com/how-to-install-mongodb-on-amazon-linux-2023/

sudo -i
dnf update

```
tee /etc/yum.repos.d/mongodb-org-7.0.repo<<EOL
[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/amazon/2023/mongodb-org/7.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-7.0.asc
EOL
```

Actually install mongodb

`dnf install mongodb-org`


## Start the Service

This actually install & start mongodb:

```
systemctl enable --now mongodb
systemctl enable --now mongod
systemctl status mongod
```

### OpenSSL Error?
if you get an OpenSSL error when opening `mongosh` try this:

```
sudo yum remove mongodb-mongosh
sudo yum install mongodb-mongosh-shared-openssl3
sudo yum install mongodb-mongosh
```

(from this link:  https://www.mongodb.com/community/forums/t/openssl-error-when-starting-mongosh/243323/3 )


---

## Install MongoDB on Ubuntu

https://www.mongodb.com/docs/manual/tutorial/install-mongodb-on-ubuntu/

```
curl -fsSL https://pgp.mongodb.com/server-7.0.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg \
   --dearmor

echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

sudo apt-get update

sudo apt-get install -y mongodb-org

sudo systemctl start mongod
sudo systemctl enable mongod
```

-----

## Configure to allow external connections

You need to modify the `net` section of `/etc/mongod.conf`
By default the `bindIp` is set to 127.0.0.1, but that will only allow local connections.   Changing to 0.0.0.0 will allow ALL traffic, so you'll need to tighten up your firewall rules.  Use Linux IPtables to control access to the box itself, _unsure how this is different from the AWS security group_

Starting with Mongo 6, use semicolons (no spaces) to list multiple IP's in the `bindIp` section.

```
# network interfaces
net:
  port: 27017
  bindIp: 0.0.0.0
```

You can test this from a remote machine via `mongosh remote.ip.address/database` but it requires the service to be restarted first.

```
sudo systemctl restart mongod.service
sudo systemctl status mongod.service
```


## Configure Authorization (almost)

https://www.mongodb.com/docs/manual/tutorial/configure-scram-client-authentication/#std-label-create-user-admin


### Create an admin user

It will prompt you for a password...

```
use admin
db.createUser(
  {
    user: "admin",
    pwd: passwordPrompt(), // or cleartext password
    roles: [
      { role: "userAdminAnyDatabase", db: "admin" },
      { role: "readWriteAnyDatabase", db: "admin" }
    ]
  }
)
```

And grant this additional role which you will need later on to allow you to initiate the replication piece.

```
db.grantRolesToUser(
   "admin",
   [ "clusterManager" ]
)
```







### Turn your standalone instance into a replica set

https://www.mongodb.com/docs/manual/tutorial/convert-standalone-to-replica-set/

Again, modify your `/etc/mongod.conf` to get it ready to be a replica set:

_(the oplogSizeMB may not be necessary, but it seemed like a good thing to set)_

```
replication:
  #oplogSizeMB: 100
  replSetName: rs0
```

```
sudo systemctl restart mongod.service
sudo systemctl status mongod.service
```


NEXT, you'll need to restart the mongo service but you'll discover that if you're running as a replica set with authoriazation enabled you'll need to use a keyfile.   My answer was to disable auth (commenting it out of `/etc/mongod.conf` and then restarting).  Note that some of this is a relic of early versions of the walkthrough, but may be useful in troubleshooting later.

Once you've successfully got the service back up, get back into mongo shell and authenticate to your admin user and initiate the replica set:

```
use admin
rs.initiate()
```

which will give you output like this:

```
admin> rs.initiate()
{
  info2: 'no configuration specified. Using a default configuration for the set',
  me: 'ip-10-100-14-5:27017',
  ok: 1,
  '$clusterTime': {
    clusterTime: Timestamp({ t: 1703113134, i: 1 }),
    signature: {
      hash: Binary.createFromBase64('AAAAAAAAAAAAAAAAAAAAAAAAAAA=', 0),
      keyId: Long('0')
    }
  },
  operationTime: Timestamp({ t: 1703113134, i: 1 })
}
rs0 [direct: secondary] admin>
```

If you already had a connector created, restarting the connector in the Redpanda UI should put you in a healthy state.


## Create the Mongo Source Connector

Very few config items are actually required...

* Mongodb connection URL:  `mongodb://10.100.14.5:27017`  --> `_mongodb://<host>:<port>_`
  * In the generated json config you'll see a stubbed out entry for `connection.uri` but Redpanda will complete this behind the scenes.
* Mongodb username:  _username you created above_
* Mongodb password:  _password for that user_
  * this will be stored in an AWS secret, but as of 12/21/2023 there is a bug whereby modifying the JSON will expose the secret
* Database to watch:  the name of the db you want to track changes on
* Collection to watch:  the name of the collection you want to track changes on
* Message key/value format:
  * Looks like any selection will work here, but the challenge comes in later sinking the data
    * String is the default, so for a MVP demo, use String for both.
    * Bytes appears to work just as well as String, unsure what the gotchas might be
    * _either String or Bytes is required if you're planning to use the MongoCDC option in the sink connector
    * Avro/Json - have not touched yet
* Startup behavior:  Copy Existing works well, but could generate a ton of traffic on an existing large db?

### Troubleshooting

Username/password are required even if you don't want/have authorization enabled.   Redpanda can't build the `connection.uri` without it.

Your mongo instance needs to accept external connections (see `bindIp`), and needs to be open on port 27017 (default mongo port).

The security group for mongo needs to allow inbound traffic from any/all of the primary/secondary IP's of the Connector instance(s).   This is most easily done by opening the firewall to the cidr range of your Redpanda VPC.
* it MAY instead/also require accepting traffic from the NAT gateway, but that will be included in that same cidr range as your Redpanda VPC.   CIDR is going to be the most resilient way to manage this as components fail/replace over time.

The VPC hosting your mongo needs to be peered (with proper routing) to the Redpanda VPC (or go over the public internet).  


----

## Insert a document

```
db.sampledata.insertOne( {name: "foo", val: "bar"})
```

That should show up in your Redpanda topic, where the topic name is of the form `<database>.<collection>`


---

# Mongo Sink Connector

In short, you can consume messages produced by the Mongo source, and stick them right back into that same mongo instance.   Use the same key/value format as you did in the source, use the Mongo CDC handler (haven't tried the debezium one), and route it to a NEW database & collection.




# Appendix
### Commands we learned along the way but maybe aren't all that useful for an MVP

## Enable authorization

Then modify `/ect/mongod.conf` to enable authorization.  _NOTE:  Later on we're going to disable this so it's probably not even necessary._

```
security:
  authorization: enabled
```

Again, the service will need to be restarted for this to take effect.   It won't be required to get into the mongo shell, but you won't be able to do much w/o logging in first.

If you want to authenticate within the mongo shell, use this:

Back in the mongo shell, grant this role to your admin user by logging in first.

```
use admin
db.auth("admin", passwordPrompt()) // or cleartext password
```


