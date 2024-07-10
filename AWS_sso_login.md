# AWS sso login

you'll need to follow the instructions for getting your AWS SSO profile set up.

https://vectorizedio.atlassian.net/wiki/spaces/CS/pages/304709633/Setup+AWS+access+on+MacOS

you may have to do an aws configure sso or aws sso login

`export AWS_PROFILE=sandbox` then do an aws configure sso

`~/.aws/config` should look like this, but you can modify by hand. This profile will work with CLI as well as terraform.

It's unclear how this first profile works, exactly.  But this is how my profile is set up and it works to sso into the 2nd profile.

```
[profile AWSAdministratorAccess-721484753854]
sso_session = redpanda
sso_account_id = 721484753854
sso_role_name = AWSAdministratorAccess
region = us-east-2
output = json
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

I'm sure it's possible to have multiple profiles & using the environment variable to switch between them, but I've never used this at Redpanda.
