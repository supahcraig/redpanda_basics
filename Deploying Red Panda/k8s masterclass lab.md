
https://play.instruqt.com/redpanda/invite/kxlyqjegnypd


helm repo add redpanda https://charts.redpanda.com

kubectl create namespace redpanda

kubectl auth can-i create CustomResourceDefinition --all-namespaces

* should return Yes


kubectl kustomize "https://github.com/redpanda-data/redpanda-operator//src/go/k8s/config/crd?ref=v2.1.20-24.1.2" | kubectl apply --server-side -f -

helm upgrade --install redpanda-controller redpanda/operator \
  --namespace redpanda \
  --set image.repository=docker.redpanda.com/redpandadata/redpanda-operator \
  --set image.tag=v2.1.20-24.1.2 \
  --create-namespace \
  --timeout 10m

kubectl --namespace redpanda rollout status --watch deployment/redpanda-controller-operator

* should return "deployment "redpanda-controller-operator" successfully rolled out"

kubectl get pod -n redpanda



```
cat <<EOF | kubectl -n redpanda apply -f -
apiVersion: cluster.redpanda.com/v1alpha1
kind: Redpanda
metadata:
  name: redpanda
spec:
  chartRef:
    chartVersion: 5.8.6
  clusterSpec:
    statefulset:
      replicas: 1
    tls:
      enabled: false
    resources:
      cpu:
        overprovisioned: true
        cores: 300m
      memory:
        container:
          max: 3G
          min: 2G
        enable_memory_locking: false
    auth:
      sasl:
        enabled: false
    storage:
      persistentVolume:
        enabled: true
        size: 2Gi
    console:
      enabled: false
EOF
```


kubectl get redpanda --namespace redpanda --watch


then ctrl+C once you see `Redpanda reconciliation succeeded`

kubectl -n redpanda get pod

