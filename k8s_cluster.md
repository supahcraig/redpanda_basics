# Creating a Redpanda cluster in EKS

This is taken from the public docs, but slightly modified to make the cluster name dynamic based on the os user env variable `LOGNAME`.   Should take 35 minutes to complete.

May want to change `--name redpanda` to something more personal like `--name $(LOGNAME)-redpanda` but this may cause problems during the helm install.

```
eksctl create cluster --with-oidc --name $(LOGNAME)-redpanda \
    --external-dns-access \
    --nodegroup-name standard-workers \
    --node-type m5.xlarge \
    --nodes 3 \
    --nodes-min 3 \
    --nodes-max 4 \
    --tags "owner=$(LOGNAME)"
```


## Create Service Account

Apparently this deploys a cloudformation stack

```
eksctl create iamserviceaccount \
    --name ebs-csi-controller-sa \
    --namespace kube-system \
    --cluster $(LOGNAME)-redpanda \
    --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
    --approve \
    --role-only \
    --role-name AmazonEKS_EBS_CSI_DriverRole \
    --tags "owner=$(LOGNAME)"
```

But it is throwing an error because this service acct already exists...lets see how far we can get beore it becomes a problem.   Solution would be to either create a new one OR somehow attach the already existing service acct to my new cluster.  Based on the output from the initial eksctl cluster create, this stack is brought up as part of initial stack, that's why it was already there.
ERROR MESSAGE:

```
2023-03-13 13:39:58 [ℹ]  waiting for CloudFormation stack "eksctl-cnelson-redpanda-addon-iamserviceaccount-kube-system-ebs-csi-controller-sa"
2023-03-13 13:39:58 [ℹ]  1 error(s) occurred and IAM Role stacks haven't been created properly, you may wish to check CloudFormation console
2023-03-13 13:39:58 [✖]  waiter state transitioned to Failure
Error: failed to create iamserviceaccount(s)
```



```
eksctl create addon \
    --name aws-ebs-csi-driver \
    --cluster $(LOGNAME)-redpanda \
    --service-account-role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/AmazonEKS_EBS_CSI_DriverRole \
    --force \
```

Next update teh security group.  Our docs are not at all clear about what the inbound IP range or secuity group should be.  `group-id` was found by looking at the EC2 instances in the AWS console.   Could probably sus it out with a desribe & some jq.   Left as a TODO

Find the security group name, then export it to an environment variable.

```
EC2_SG=$(aws ec2 describe-instances --filter "Name=tag:aws:eks:cluster-name,Values=cnelson-redpanda" | jq -r '.Reservations[].Instances[].NetworkInterfaces[].Groups[].GroupId' | uniq -c | tr -s ' ' | cut -d ' ' -f 3)
```


```
aws ec2 authorize-security-group-ingress \
    --group-id $(EC2_SG) \
    --ip-permissions "[ \
                        { \
                          \"IpProtocol\": \"tcp\", \
                          \"FromPort\": 30081, \
                          \"ToPort\": 30082, \
                          \"IpRanges\": [{\"CidrIp\": \"0.0.0.0/0\"}]}]"

```

```
aws ec2 authorize-security-group-ingress \
    --group-id sg-0292989c9cfb2d78b \
    --ip-permissions "[ \
                        { \
                          \"IpProtocol\": \"tcp\", \
                          \"FromPort\": 30081, \
                          \"ToPort\": 30082, \
                          \"IpRanges\": [{\"CidrIp\": \"0.0.0.0/0\"}] \
                        }, \
                        { \
                          \"IpProtocol\": \"tcp\", \
                          \"FromPort\": 31644, \
                          \"ToPort\": 31644, \
                          \"IpRanges\": [{\"CidrIp\": \"0.0.0.0/0\"}] \
                        }, \
                        { \
                          \"IpProtocol\": \"tcp\", \
                          \"FromPort\": 31092, \
                          \"ToPort\": 31092, \
                          \"IpRanges\": [{\"CidrIp\": \"0.0.0.0/0\"}] \
                        } \
                      ]"

```


