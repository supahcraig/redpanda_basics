# Deploying using the deployment-automation tools

https://github.com/redpanda-data/deployment-automation


## Terraform

Basically git clone the repo & navigate to the `aws` folder then do a `terraform init`

`cd deployment-automation`

`terraform init`

`cd aws`

To create the resources you'll do a terraform apply, but it requires a public key.  I had already created a keypair (pem file) but that is the private key.  To create public key from the private key:

`echo ssh-keygen -y -f <your pem file> > whatever.pub`

Then your terraform apply command can reference it:

```
terraform init
```

then actually log in to AWS...

`aws sso login`

Then actually start terraforming...

```
terraform apply -var="public_key_path=~/pem/public.cnelson-kp.pub" -var="aws_region=us-east-2"
```

This will start spinning up EC2 instances, security groups, etc which we will use Ansible to install into.  This will also create the `hosts.ini` file that holds the public & private IP's of the instances.


## Ansible

Then this to do the ansible install steps from the top level of the repo.  Some versions of macos may require this environment variable if you get an error around dead workers, per this link:  https://stackoverflow.com/questions/50168647/multiprocessing-causes-python-to-crash-and-gives-an-error-may-have-been-in-progr


```
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
```

```
ansible-playbook --private-key ~/pem/cnelson-kp.pem \
  -i hosts.ini \
  -e advertise_public_ips=true \
  -v ../ansible/playbooks/provision-node.yml
```

---

## Terraform Teardown 

```
terraform destroy -var="public_key_path=~/pem/public.cnelson-kp.pub" -var="aws_region=us-east-2"
```


---


# New Issues

* it puked on the AZ of `us-west-2a`, likely because I specified `us-east-2` as the region.   Need to try this again specifying the AZ on the terraform apply command.   Interim fix was to edit `main.tf` to reflect an east-2 AZ.
* ansible playbook change:

```
ansible-playbook --private-key ~/pem/cnelson-kp.pem \
  -i ./aws/hosts.ini \
  -e advertise_public_ips=true \
  -v ansible/provision-tiered-storage-cluster.yml
```
....which still didnt' work.   `--fork 1` may be necessary for SSH strict checking


so basically nothing of the ansible instructions I wrote above still works.    I really need to run through this stuff weekly because it appears to be rapidly changing and quite fragile.

New instructions are essentially to follow the actual repo instructions, but this is the distilled version:

From the repo root folder

```
export ANSIBLE_COLLECTIONS_PATHS=${PWD}/artifacts/collections
export ANSIBLE_ROLES_PATH=${PWD}/artifacts/roles
```

then do an ansible deploy

```
ansible-playbook --private-key ~/pem/cnelson-kp.pem \
  -i ./aws/hosts.ini \
  -e advertise_public_ips=true \
  -v ansible/provision-tiered-storage-cluster.yml
```

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
