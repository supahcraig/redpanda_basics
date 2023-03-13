# Creating a Redpanda cluster in EKS

This is taken from the public docs, but slightly modified to make the cluster name dynamic based on the os user env variable `LOGNAME`

```
eksctl create cluster --name $(LOGNAME)-redpanda \
    --external-dns-access \
    --nodegroup-name standard-workers \
    --node-type m5.xlarge \
    --nodes 3 \
    --nodes-min 3 \
    --nodes-max 4
```

This will take about 15 minutes.  Progress can be tracked in the AWS console by looking at CloudFormation stacks.

```
eksctl create iamserviceaccount \
    `# Do not change the name. It is required by EKS.` \
    --name ebs-csi-controller-sa \
    `# Do not change the namespace. It is required by EKS.` \
    --namespace kube-system \
    --cluster $(LOGNAME)-redpanda \
    --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
    --approve \
    --role-only \
    --role-name AmazonEKS_EBS_CSI_DriverRole
```

