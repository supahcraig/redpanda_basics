# Deploying using the deployment-automation tools

https://github.com/redpanda-data/deployment-automation

Basically git clone the repo & navigate to the `aws` folder then do a `terraform init`

```
git clone https://github.com/redpanda-data/deployment-automation.git
cd deployment-automation
```

Then set some environment variables which ansible-galaxy will use to install roles, etc.

```
export ANSIBLE_COLLECTIONS_PATHS=${PWD}/artifacts/collections
export ANSIBLE_ROLES_PATH=${PWD}/artifacts/roles
```


## Terraform

Next, get ready to terraform.

`cd aws`

`terraform init`


### Generating the public key

If you don't already have one, you can easily create one.   Navigate to `~/.ssh` and run this simple command:

```
ssh-keygen -o
```

You can just hit enter for the default filename (`id_rsa.pub`) and enter twice if you don't want a password.  Now you can use this in your terraform apply step.  It will also create a private key in the same path which you can use to ssh into the instances that get created.

I had already created a keypair (pem file) but that is the private key.  To create public key from the private key.   (this may or may not still work)

```
echo ssh-keygen -y -f <your pem file> > whatever.pub
```




Then your terraform apply command can reference it:

```
terraform init
```

then actually log in to AWS...

`aws sso login`

Then actually start terraforming...

```
terraform apply \
-var='aws_region=us-east-2' \
-var='availability_zone=["us-east-2a"]' \
-var='public_key_path=~/.ssh/id_rsa.pub' \
-var='deployment_prefix=cn-test-2'
```

This will start spinning up EC2 instances, security groups, etc which we will use Ansible to install into.  This will also create the `hosts.ini` file that holds the public & private IP's of the instances.




---

## Ansible

Then this to do the ansible install steps _from the top level of the repo_.  

`cd ..`


Some versions of macos may require this environment variable if you get an error around dead workers, per this link:  https://stackoverflow.com/questions/50168647/multiprocessing-causes-python-to-crash-and-gives-an-error-may-have-been-in-progr

```
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
```

Install the ansible roles

(assumes you are still in the aws folder.

```
# Install collections and roles
ansible-galaxy install -r ../requirements.yml
```

Spin up Redpanda!

```
ansible-playbook --private-key ~/.ssh/id_rsa \
  -i hosts.ini \
  -e advertise_public_ips=true \
  -v ../ansible/provision-basic-cluster.yml \
  --ssh-common-args='-o StrictHostKeyChecking=no'
```


## rpk

You will probably want to use an rpk profile to actually talk to the cluster.   We have lots of docs on this, but from the ground up the process looks like this:

### Create profile

You can name your profile whatever you like.

```
rpk profile create via-deployment-automation
```

### Edit your profile

You can edit the file directly using rpk profile edit.

```
rpk profile edit via-deployment-automation
```

At a minimum, your rpk config needs to look like this.  If TLS is in use, then it will be more complex.

```
name: via-deployment-automation
description: deployment-automation
kafka_api:
    brokers:
        - <ip of broker #1>:9092
        - <ip of broker #2>:9092
        - <ip of broker #3>:9092

admin_api:
    addresses:
        - <ip of broker #1>:9644
        - <ip of broker #2>:9644
        - <ip of broker #3>:9644

```

#### Working Example:

```
name: via-deployment-automation
description: deployment-automation
prompt: hi-red, "[%n]"
kafka_api:
    brokers:
        - 18.191.240.43:9092
        - 18.117.165.211:9092
        - 18.188.99.199:9092
admin_api:
    addresses:
        - 18.191.240.43:9644
        - 18.117.165.211:9092
        - 18.188.99.199:9092
```

## Testing connectivity

`rpk use profile via-deployment-automation`

Then test the kafka api:

```
rpk topic list
```

Then test the admin api:

```
rpk cluster info
```



---

## Terraform Teardown 

It's basically the same command used to terraform apply, only replace `apply` with `destroy`.

```
terraform destroy \
-var='aws_region=us-east-2' \
-var='availability_zone=["us-east-2a"]' \
-var='public_key_path=~/.ssh/id_rsa.pub' \
-var='deployment_prefix=cn-test'
```


---


# New Issues

## Warn/fatal on jinja2 being used in a conditional statment


The "fix" seems to be to modify this file `deployment-automation/artifacts/collections/ansible_collections/redpanda/cluster/roles/redpanda_broker/tasks/start-redpanda.yml`
And specifically this line, which should be around line #150 (subject to change)

```
cat start-redpanda.yml | grep -n "{{ config_version.stdout|int() }}"
```

you need to remove the jinja2 stuff to make this:

```
changed_when: '"New configuration version is {{ config_version.stdout|int() }}." not in result.stdout'
```

look like this:

```
changed_when: '"New configuration version is (jinja2 removed)." not in result.stdout'
```

This was fixed in 0.4.20 but if you still have problems make sure that your environment variables are correct such that the ansible-galaxy install step puts everything in the correct location, which is off the root deployment-automation folder, NOT off the aws or other sub folders.



Sample commands need a whole lot of TLS help:

```
rpk cluster status --tls-key ansible/tls/ca/ca.key --tls-cert ansible/tls/ca/ca.crt --tls-truststore ansible/tls/ca/ca.crt
```

but you probably don't want to type all that every time, so create a file called `redpanda.yaml` in your working directory.   You will set the brokers to the IP's of your brokers, obviously

This blog post may help:  https://redpanda.com/blog/tls-config

```
rpk:

  kafka_api:
    brokers:
    - 3.144.124.82:9092
    - 18.217.34.238:9092
    - 3.133.120.186:9092

    tls:
      key_file: /Users/cnelson/sandbox/deployment-automation/ansible/tls/ca/ca.key
      cert_file: /Users/cnelson/sandbox/deployment-automation/ansible/tls/ca/ca.crt
      truststore_file: /Users/cnelson/sandbox/deployment-automation/ansible/tls/ca/ca.crt

  admin_api:
    brokers:
    - 3.144.124.82:9644
    - 18.217.34.238:9644
    - 3.133.120.186:9644

    tls:
      key_file: /Users/cnelson/sandbox/deployment-automation/ansible/tls/ca/ca.key
      cert_file: /Users/cnelson/sandbox/deployment-automation/ansible/tls/ca/ca.crt
      truststore_file: /Users/cnelson/sandbox/deployment-automation/ansible/tls/ca/ca.crt
```


and then test with something simple:

`rpk cluster status`

`rpk topic list`


```
rpk cluster config edit \
--tls-key ansible/tls/ca/ca.key \
--tls-cert ansible/tls/ca/ca.crt \
--tls-truststore ansible/tls/ca/ca.crt
```
