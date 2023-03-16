The docs have some troubleshooting steps but here are some more detailed troubleshooting:

# Error:  INSTALLATION FAILED:  timed out waiting for the condition

You may see this during the helm install.   It is related to the `AmazonEKS_EBS_CSI_DriverRole`.   If a role already exists with that name, the role create step will fail, but the error message will make you believe that it already exists so you're ok.  And it may already exist, but you're not ok.

Here is the error in CloudFormation:

```
AmazonEKS_EBS_CSI_DriverRole already exists in stack arn:aws:cloudformation:us-east-2:569527441423:stack/eksctl-redpanda-addon-iamserviceaccount-kube-system-ebs-csi-controller-sa/9eec4e20-53eb-11ed-9a86-068643113df4
```

The thing is, this role _doesn't_ exist in the stack, at least as far as I can tell.   But I'm also not sure what it means exactly for a role to exist within a stack.


Anyway, onto the troubleshooting steps we took.

## Events

`kubectl -n redpanda get events`

```
LAST SEEN   TYPE      REASON                 OBJECT                                     MESSAGE
4m50s       Normal    ExternalProvisioning   persistentvolumeclaim/datadir-redpanda-0   waiting for a volume to be created, either by external provisioner "ebs.csi.aws.com" or manually created by system administrator
78s         Normal    Provisioning           persistentvolumeclaim/datadir-redpanda-0   External provisioner is provisioning volume for claim "redpanda/datadir-redpanda-0"
78s         Normal    Provisioning           persistentvolumeclaim/datadir-redpanda-1   External provisioner is provisioning volume for claim "redpanda/datadir-redpanda-1"
4m50s       Normal    ExternalProvisioning   persistentvolumeclaim/datadir-redpanda-1   waiting for a volume to be created, either by external provisioner "ebs.csi.aws.com" or manually created by system administrator
78s         Normal    Provisioning           persistentvolumeclaim/datadir-redpanda-2   External provisioner is provisioning volume for claim "redpanda/datadir-redpanda-2"
4m50s       Normal    ExternalProvisioning   persistentvolumeclaim/datadir-redpanda-2   waiting for a volume to be created, either by external provisioner "ebs.csi.aws.com" or manually created by system administrator
25s         Warning   FailedScheduling       pod/redpanda-0                             running PreBind plugin "VolumeBinding": binding volumes: timed out waiting for the condition
25s         Warning   FailedScheduling       pod/redpanda-1                             running PreBind plugin "VolumeBinding": binding volumes: timed out waiting for the condition
25s         Warning   FailedScheduling       pod/redpanda-2                             running PreBind plugin "VolumeBinding": binding volumes: timed out waiting for the condition
19m         Warning   Unhealthy              pod/redpanda-console-76ccfbfffb-drkd8      Liveness probe failed: Get "http://192.168.95.71:8080/admin/health": dial tcp 192.168.95.71:8080: connect: connection refused
4m48s       Warning   BackOff                pod/redpanda-console-76ccfbfffb-drkd8      Back-off restarting failed container
```

We can see that there seems to be a problem binding the volumes to the worker nodes.  So lets find the pods for the EBS controller:

`kubectl -n kube-system get pods`

```
NAME                                 READY   STATUS    RESTARTS   AGE
aws-node-8kh8k                       1/1     Running   0          10h
aws-node-npx7w                       1/1     Running   0          10h
aws-node-q94c4                       1/1     Running   0          10h
coredns-5c5677bc78-26d97             1/1     Running   0          10h
coredns-5c5677bc78-8bgqw             1/1     Running   0          10h
ebs-csi-controller-967469fb9-2xrcc   6/6     Running   0          9h
ebs-csi-controller-967469fb9-twwzh   6/6     Running   0          9h
ebs-csi-node-2vxrw                   3/3     Running   0          9h
ebs-csi-node-jfdgx                   3/3     Running   0          9h
ebs-csi-node-n4tnw                   3/3     Running   0          9h
kube-proxy-9bshw                     1/1     Running   0          10h
kube-proxy-qw8s2                     1/1     Running   0          10h
kube-proxy-slh4f                     1/1     Running   0          10h
```

The two ebs-csi-controller pods are the two we're interested in.  Let's look at these logs.

`kubectl -n kube-system logs -f ebs-csi-controller-967469fb9-2xrcc`

and we find tons of entries that look just like this:

```
E0316 14:56:48.899494       1 driver.go:120] "GRPC error" err=<
	rpc error: code = Internal desc = Could not create volume "pvc-47ed5bd3-9ab2-47c3-9a24-a3d4ce19e2f2": could not create volume in EC2: WebIdentityErr: failed to retrieve credentials
	caused by: AccessDenied: Not authorized to perform sts:AssumeRoleWithWebIdentity
		status code: 403, request id: 57eb198c-8229-49aa-bcc5-0ac6bb9c5948
 >
```

So we have some sort of authentication or IAM role/policy issue.


## Service Account

`kubectl -n kube-system get sa ebs-csi-controller-sa -o yaml`

shows us which IAM role is being used, and in this case it's the EBS CSI role that already existed.
```
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::569527441423:role/AmazonEKS_EBS_CSI_DriverRole
  creationTimestamp: "2023-03-16T05:01:24Z"
  labels:
    app.kubernetes.io/component: csi-driver
    app.kubernetes.io/managed-by: EKS
    app.kubernetes.io/name: aws-ebs-csi-driver
    app.kubernetes.io/version: 1.16.1
  name: ebs-csi-controller-sa
  namespace: kube-system
  resourceVersion: "3408"
  uid: 2efd8406-89e1-4fbc-bd64-8ba8b2a556ca
  ```
  
  ## IAM Role
  
  `aws iam list-role-tags --role-name AmazonEKS_EBS_CSI_DriverRole`
  
  ```
  {
    "Tags": [
        {
            "Key": "alpha.eksctl.io/cluster-name",
            "Value": "redpanda"
        },
        {
            "Key": "eksctl.cluster.k8s.io/v1alpha1/cluster-name",
            "Value": "redpanda"
        },
        {
            "Key": "alpha.eksctl.io/iamserviceaccount-name",
            "Value": "kube-system/ebs-csi-controller-sa"
        },
        {
            "Key": "alpha.eksctl.io/eksctl-version",
            "Value": "0.115.0"
        }
    ],
    "IsTruncated": false
}
```

Here you can see that the role has tags associated to a cluster named `redpanda` but our cluster is named `cnelson-redpanda` so possibly there is some magic in these tags?


  
