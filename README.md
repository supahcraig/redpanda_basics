# redpanda_basics
how to do stuff in Redpanda



#Terraform/Ansible automation

Terraform will deploy 3 EC2 instances into AWS, Ansible will install all the software and bring the cluster up.


Working off this:
https://docs.redpanda.com/docs/deploy/deployment-option/self-hosted/manual/production/production-deployment-automation/


## AWS sso login

you'll need to follow the instructions for getting your AWS SSO profile set up.

https://vectorizedio.atlassian.net/wiki/spaces/CS/pages/304709633/Setup+AWS+access+on+MacOS

you may have to do an `aws configure sso` or `aws sso login`

`export AWS_PROFILE=sandbox`
then do an `aws configure sso`

`~/.aws/config` should look like this, but you can modify by hand.  This profile will work with CLI as well as terraform.

```
[profile sandbox]
sso_account_id = <account id>
sso_role_name = AWSAdministratorAccess
sso_start_url = https://redpanda-data.awsapps.com/start
sso_registration_scopes = sso:account:access
sso_region = us-east-2
output = json
region = us-east-2
```

Test with `aws s3 ls` for basic connectivity, and then `aws ec2 describe-instances` for region-centric services.   



## Terraform

Basically git clone the repo & navigate to the `aws` folder then do a `terraform init`

`cd deployment-automation`
`terraform init`

To create the resources you'll do a terraform apply, but it requires a public key.  I had already created a keypair (pem file) but that is the private key.  To create public key from the private key:

`echo ssh-keygen -y -f <your pem file> > whatever.pub`

Then your terraform apply command can reference it:

```
terraform init
```

then....

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
ansible-playbook --private-key ~/pem/cnelson-kp.pem -i hosts.ini -v ansible/playbooks/provision-node.yml
```


## Terraform Teardown 

```
terraform destroy -var="public_key_path=~/pem/public.cnelson-kp.pub" -var="aws_region=us-east-2"
```
