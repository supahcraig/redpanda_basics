# Creating a Redpanda cluster in EKS

This is taken from the public docs, but slightly modified to make the cluster name dynamic based on the os user env variable `LOGNAME`.   Should take 35 minutes to complete.


```
eksctl create cluster --with-oidc --name $(LOGNAME)-redpanda \
    --external-dns-access \
    --nodegroup-name standard-workers \
    --node-type m5.xlarge \
    --nodes 3 \
    --nodes-min 3 \
    --nodes-max 4
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
    --role-name AmazonEKS_EBS_CSI_DriverRole
```

But it is throwing an error...lets see how far we can get beore it becomes a problem.
ERROR MESSAGE:

```
2023-03-13 13:39:58 [✖]  waiter state transitioned to Failure
Error: failed to create iamserviceaccount(s)
```



```
eksctl create addon \
    --name aws-ebs-csi-driver \
    --cluster $(LOGNAME)-redpanda \
    --service-account-role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/AmazonEKS_EBS_CSI_DriverRole \
    --force
```

