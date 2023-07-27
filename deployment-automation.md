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
  -i hosts.ini \
  -e advertise_public_ips=true \
  -v ../ansible/playbooks/provision-tiered-storage-cluster.yml
```
....which still didnt' work.
