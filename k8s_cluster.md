# Creating a Redpanda cluster in EKS



```
eksctl create cluster --name $(LOGNAME)-redpanda \
    --external-dns-access \
    --nodegroup-name standard-workers \
    --node-type m5.xlarge \
    --nodes 3 \
    --nodes-min 3 \
    --nodes-max 4
```
