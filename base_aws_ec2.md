
For spinning up a c5.xlarge in us-east-2

```bash
aws ec2 run-instances --image-id "ami-036841078a4b68e14" --instance-type "c5.xlarge" \
--key-name "cnelson-prodse-01-15-2025" \
--block-device-mappings '{"DeviceName":"/dev/sda1","Ebs":{"Encrypted":false,"DeleteOnTermination":true,"Iops":3000,"SnapshotId":"snap-0eaae511237ea4631","VolumeSize":30,"VolumeType":"gp3","Throughput":125}}' \
--network-interfaces '{"SubnetId":"subnet-0850cd9219028a143","AssociatePublicIpAddress":true,"DeviceIndex":0,"Groups":["sg-preview-1"]}' \
--tag-specifications '{"ResourceType":"instance","Tags":[{"Key":"Name","Value":"db2"}]}' \
--metadata-options '{"HttpEndpoint":"enabled","HttpPutResponseHopLimit":2,"HttpTokens":"required"}' \
--private-dns-name-options '{"HostnameType":"ip-name","EnableResourceNameDnsARecord":false,"EnableResourceNameDnsAAAARecord":false}' \
--count "1"
