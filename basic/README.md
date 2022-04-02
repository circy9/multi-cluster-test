# Two Clusters in one vnet: Can a pod in one cluster reach another pod in another cluster? Yes

Create two clusters in one vnet.
```
cd tools
./setup.sh
```

Deploy pods in cluster1.
```
az aks get-credentials -n liqian-cluster1 -g liqian-rg
kubectl apply -f simple-serivce.yaml

kubectl get svc
NAME             TYPE           CLUSTER-IP   EXTERNAL-IP    PORT(S)        AGE
kubernetes       ClusterIP      10.0.10.1    <none>         443/TCP        13m
nginx            ClusterIP      10.0.10.50   <none>         80/TCP         5m52s
nginx-headless   ClusterIP      None         <none>         80/TCP         35s
nginx-lb         LoadBalancer   10.0.10.5    20.112.49.22   80:31765/TCP   5m52s

kubectl get endpoints
NAME             ENDPOINTS            AGE
kubernetes       52.156.151.175:443   13m
nginx            10.0.1.30:80         5m38s
nginx-headless   10.0.1.30:80         21s
nginx-lb         10.0.1.30:80         5m38s
```

Verify pod2pod connectivity within cluster1.
```
kubectl get nodes -o wide
kubectl debug node/aks-nodepool1-26949044-vmss000000 -it --image=mcr.microsoft.com/aks/fundamental/base-ubuntu:v0.0.11

# Verified: CAN access nginx via service cluster ip.
curl 10.0.10.5
curl 10.0.10.50

# Verified: CAN access nginx via pod ip.
curl 10.0.1.30
```

Verify pod2pod connectivity from cluster2 to cluster1.

```
az aks get-credentials -n liqian-cluster2 -g liqian-rg

kubectl get nodes -o wide
kubectl debug node/aks-nodepool1-17429978-vmss000000 -it --image=mcr.microsoft.com/aks/fundamental/base-ubuntu:v0.0.11

# Verified: CAN NOT access nginx via service cluster ip.
curl 10.0.10.5
curl 10.0.10.50

# Verified: CAN access nginx via pod ip.
curl 10.0.1.30
```
