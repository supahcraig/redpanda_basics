# Writing to S3

https://www.benthos.dev/docs/components/outputs/aws_s3

---

Basic config, assumes aws sso session is active.

```yaml
output:
  label: ""
  aws_s3:
    bucket: cnelson-benthos
    path: ${!timestamp_unix_nano()}.txt
```



To specificy credntials:

```yaml
  credentials:
        id: "your aws access id"
        secret: "your aws secret"
```

_See the dynamodb example for how to use hashicorp vault to protect the AWS credentials._
