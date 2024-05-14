# AWS sso login

you'll need to follow the instructions for getting your AWS SSO profile set up.

https://vectorizedio.atlassian.net/wiki/spaces/CS/pages/304709633/Setup+AWS+access+on+MacOS

you may have to do an aws configure sso or aws sso login

`export AWS_PROFILE=sandbox` then do an aws configure sso

`~/.aws/config` should look like this, but you can modify by hand. This profile will work with CLI as well as terraform.

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

Test with `aws s3 ls` for basic connectivity, and then aws ec2 describe-instances for region-centric services.
