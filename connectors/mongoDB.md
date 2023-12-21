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


## Configure Authorization

https://www.mongodb.com/docs/manual/tutorial/configure-scram-client-authentication/#std-label-create-user-admin


### Create an admin user

It will prompt you for a password...

```
use admin
db.createUser(
  {
    user: "myUserAdmin",
    pwd: passwordPrompt(), // or cleartext password
    roles: [
      { role: "userAdminAnyDatabase", db: "admin" },
      { role: "readWriteAnyDatabase", db: "admin" }
    ]
  }
)
```

Then modify `/ect/mongod.conf` to enable authorization

```
security:
  authorization: enabled
```

Again, the service will need to be restarted for this to take effect.   It won't be required to get into the mongo shell, but you won't be able to do much w/o logging in first.

```
use admin
db.auth("myUserAdmin", passwordPrompt()) // or cleartext password
```

And then test by doing something simple like `show users`

### Turn your standalone instance into a replica set

Again, modify your `/etc/mongod.conf` to get it ready to be a replica set:

_(the oplogSizeMB may not be necessary, but it seemed like a good thing to set)_

```
replication:
  #oplogSizeMB: 100
  replSetName: rs0
```


Next grant this role to your admin user:

```
db.grantRolesToUser(
   "admin",
   [ "clusterManager" ]
)
```

NEXT, you'll need to restart the mongo service but you'll discover that if you're running as a replica set with authoriazation enabled you'll need to use a keyfile.   My answer was to disable auth (commenting it out of `/etc/mongod.conf` and then restarting, which may have done the trick.

Once you've successfully got the service back up, get back into mongo shell and authenticate to your admin user and initiate the replica set:

`rs.initiate()`

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

Restarting the connector in the Redpanda UI should put you in a healthy state.

### Insert a document

```
db.sampledata.insertOne( {name: "foo", val: "bar"})
```

That should show up in your Redpanda topic, but only if you were a good little boy or girl this year.




   

