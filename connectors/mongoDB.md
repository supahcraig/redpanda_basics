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



