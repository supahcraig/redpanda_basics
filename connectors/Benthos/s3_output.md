# Writing to S3

https://www.benthos.dev/docs/components/outputs/aws_s3

---

Basic config, assumes aws sso session is active.

```
output:
  label: ""
  aws_s3:
    bucket: cnelson-benthos
    path: ${!timestamp_unix_nano()}.txt
```



To specificy credntials:

```
  credentials:
        id: "your aws access id"
        secret: "your aws secret"
```
