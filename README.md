# redpanda_basics
how to do stuff in Redpanda



##Terraform/Ansible automation

Working off this:
https://docs.redpanda.com/docs/deploy/deployment-option/self-hosted/manual/production/production-deployment-automation/

Basically git clone the repo & do `terraform init`

To create the resources you'll do a terraform apply, but it requires a public key.  I had already created a keypair (pem file) but that is the private key.  To create public key from the private key:

`echo ssh-keygen -y -f <your pem file> > whatever.pub`

Then your terraform apply command can reference it:

terraform apply -var="public_key_path=~/pem/public.cnelson-kp.pub" -var="aws_region=us-east-2"

This will start spinning up EC2 instances, security groups, etc which we will use Ansible to install into.  This will also create the `hosts.ini` file that holds the public & private IP's of the instances.


