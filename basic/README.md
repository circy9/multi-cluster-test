# Two clusters in one vnet: Can we create an SLB to talk to pods in two clusters?
Create two clusters in one vnet.
```
cd tools
./setup.sh
```

Change account.
```
# Use sub: Arc-Validation-Conformance
export SUBSCRIPTION_ID=3959ec86-5353-4b0c-b5d7-3877122861a0
az account set -s ${SUBSCRIPTION_ID}
```

Deploy service in cluster1 and cluster2
```
az aks get-credentials -n liqian-cluster1 -g liqian-rg
kubectl apply -f kuar-blue.yaml

❯ kubectl get endpoints
NAME         ENDPOINTS                                AGE
kuar-blue      10.0.1.41:8080                           8m

az aks get-credentials -n liqian-cluster2 -g liqian-rg
kubectl apply -f kuar-green.yaml

❯ kubectl get endpoints
NAME         ENDPOINTS           AGE
kuar-green   10.0.2.54:8080      2m36s
```

Change tools/kuar-dummy.yaml to add the pod ips above
```
  - addresses:
      - ip: 10.0.1.41
      - ip: 10.0.2.54
```

Deploy dummy service.
```
kubectl apply -f kuar-dummy.yaml

❯ kubectl get svc
NAME         TYPE           CLUSTER-IP    EXTERNAL-IP      PORT(S)          AGE
kuar-dummy   LoadBalancer   10.0.20.242   51.143.120.174   8080:31599/TCP   3m2s
kuar-green   LoadBalancer   10.0.20.127   40.91.122.82     8080:30290/TCP   8m19s

❯ kubectl get endpoints
NAME          ENDPOINTS                       AGE
kuar-dummy    10.0.1.41:8080,10.0.2.54:8080   10s
kuar-green    10.0.2.54:8080                  8m25s
```

Test dummy service. Note that it can hit both pods.
```
❯ for i in `seq 1 5`; do curl 51.143.120.174:8080 | grep addrs; done
var pageContext = {"urlBase":"","hostname":"kuar","addrs":["10.0.1.41"],"version":"v0.10.0-blue","versionColor":"hsl(339,100%,50%)","requestDump":"GET / HTTP/1.1\r\nHost: 51.143.120.174:8080\r\nAccept: */*\r\nUser-Agent: curl/7.79.1","requestProto":"HTTP/1.1","requestAddr":"10.0.2.35:12483"}
var pageContext = {"urlBase":"","hostname":"kuar","addrs":["10.0.2.54"],"version":"v0.10.0-dirty-green","versionColor":"hsl(3,100%,50%)","requestDump":"GET / HTTP/1.1\r\nHost: 51.143.120.174:8080\r\nAccept: */*\r\nUser-Agent: curl/7.79.1","requestProto":"HTTP/1.1","requestAddr":"10.0.2.4:20693"}
var pageContext = {"urlBase":"","hostname":"kuar","addrs":["10.0.2.54"],"version":"v0.10.0-dirty-green","versionColor":"hsl(3,100%,50%)","requestDump":"GET / HTTP/1.1\r\nHost: 51.143.120.174:8080\r\nAccept: */*\r\nUser-Agent: curl/7.79.1","requestProto":"HTTP/1.1","requestAddr":"10.0.2.66:48135"}
var pageContext = {"urlBase":"","hostname":"kuar","addrs":["10.0.1.41"],"version":"v0.10.0-blue","versionColor":"hsl(339,100%,50%)","requestDump":"GET / HTTP/1.1\r\nHost: 51.143.120.174:8080\r\nAccept: */*\r\nUser-Agent: curl/7.79.1","requestProto":"HTTP/1.1","requestAddr":"10.0.2.35:61349"}
var pageContext = {"urlBase":"","hostname":"kuar","addrs":["10.0.2.54"],"version":"v0.10.0-dirty-green","versionColor":"hsl(3,100%,50%)","requestDump":"GET / HTTP/1.1\r\nHost: 51.143.120.174:8080\r\nAccept: */*\r\nUser-Agent: curl/7.79.1","requestProto":"HTTP/1.1","requestAddr":"10.0.2.4:48895"}
```

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

Verify connectivity within cluster1.
```
kubectl get nodes -o wide
kubectl debug node/aks-nodepool1-26949044-vmss000000 -it --image=mcr.microsoft.com/aks/fundamental/base-ubuntu:v0.0.11

# Verified: CAN access nginx via service cluster ip.
curl 10.0.10.5
curl 10.0.10.50

# Verified: CAN access nginx via pod ip.
curl 10.0.1.30
```

Verify connectivity from cluster2 to cluster1.

```
az aks get-credentials -n liqian-cluster2 -g liqian-rg

kubectl get nodes -o wide
kubectl debug node/aks-nodepool1-17429978-vmss000000 -it --image=mcr.microsoft.com/aks/fundamental/base-ubuntu:v0.0.11

# Verified: CAN NOT access nginx via service cluster ip.
curl 10.0.10.5
curl 10.0.10.50

# Verified: CAN access nginx via pod ip.
curl 10.0.1.30
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...

```

# Two Clusters in two vnet: Can a pod in one cluster reach another pod in another cluster? Yes

Create cluster3 in vnet 2.
```
cd tools
./setup-vnet2.sh
```

Deploy pods in cluster1 (same as above)
```
az aks get-credentials -n liqian-cluster1 -g liqian-rg
kubectl get nodes -o wide
NAME                                STATUS   ROLES   AGE     VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
aks-nodepool1-26949044-vmss000002   Ready    agent   2m56s   v1.21.9   10.0.1.4      <none>        Ubuntu 18.04.6 LTS   5.4.0-1072-azure   containerd://1.4.12+azure-3

kubectl get pods -o wide
NAME    READY   STATUS    RESTARTS   AGE     IP         NODE                                NOMINATED NODE   READINESS GATES
nginx   1/1     Running   0          4m17s   10.0.1.6   aks-nodepool1-26949044-vmss000002   <none>           <none>

kubectl get services
NAME             TYPE           CLUSTER-IP   EXTERNAL-IP    PORT(S)        AGE
kubernetes       ClusterIP      10.0.10.1    <none>         443/TCP        20h
nginx            ClusterIP      10.0.10.50   <none>         80/TCP         19h
nginx-headless   ClusterIP      None         <none>         80/TCP         19h
nginx-lb         LoadBalancer   10.0.10.5    20.112.49.22   80:31765/TCP   19h


```

Get IPs in cluster2
```
az aks get-credentials -n liqian-cluster2 -g liqian-rg
kubectl get node -o wide
NAME                                STATUS   ROLES   AGE     VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
aks-nodepool1-17429978-vmss000002   Ready    agent   7m13s   v1.21.9   10.0.2.4      <none>        Ubuntu 18.04.6 LTS   5.4.0-1072-azure   containerd://1.4.12+azure-3

kubectl get pods --namespace projectcontour -o wide
NAME                       READY   STATUS    RESTARTS   AGE     IP          NODE                                NOMINATED NODE   READINESS GATES
contour-76cbc54fbf-gw9pr   1/1     Running   0          34m     10.0.2.5    aks-nodepool1-17429978-vmss000002   <none>           <none>
contour-76cbc54fbf-sdtdn   1/1     Running   0          34m     10.0.2.28   aks-nodepool1-17429978-vmss000002   <none>           <none>
envoy-zx9vw                2/2     Running   0          8m19s   10.0.2.7    aks-nodepool1-17429978-vmss000002   <none>           <none>

kubectl get services
NAME          TYPE           CLUSTER-IP   EXTERNAL-IP    PORT(S)        AGE
kubernetes    ClusterIP      10.0.20.1    <none>         443/TCP        20h
nginx-dummy   LoadBalancer   10.0.20.56   20.64.136.46   80:30703/TCP   130m
```

Get IPs in cluster3
```
kubectl get node -o wide
NAME                                STATUS   ROLES   AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
aks-nodepool1-17318001-vmss000001   Ready    agent   11m   v1.21.9   10.2.3.4      <none>        Ubuntu 18.04.6 LTS   5.4.0-1072-azure   containerd://1.4.12+azure-3

kubectl get pods -o wide --all-namespaces
NAMESPACE     NAME                                                    READY   STATUS    RESTARTS   AGE     IP          NODE                                NOMINATED NODE   READINESS GATES
kube-system   azure-ip-masq-agent-5dkc8                               1/1     Running   0          18m     10.2.3.4    aks-nodepool1-17318001-vmss000001   <none>           <none>
kube-system   coredns-845757d86-7p9nv                                 1/1     Running   0          44m     10.2.3.15   aks-nodepool1-17318001-vmss000001   <none>           <none>
kube-system   coredns-845757d86-dpnlj                                 1/1     Running   0          44m     10.2.3.32   aks-nodepool1-17318001-vmss000001   <none>           <none>
kube-system   coredns-autoscaler-5f85dc856b-gplzz                     1/1     Running   0          44m     10.2.3.23   aks-nodepool1-17318001-vmss000001   <none>           <none>
kube-system   csi-azuredisk-node-zz5zt                                3/3     Running   0          18m     10.2.3.4    aks-nodepool1-17318001-vmss000001   <none>           <none>
kube-system   csi-azurefile-node-t2phw                                3/3     Running   0          18m     10.2.3.4    aks-nodepool1-17318001-vmss000001   <none>           <none>
kube-system   kube-proxy-29qt9                                        1/1     Running   0          18m     10.2.3.4    aks-nodepool1-17318001-vmss000001   <none>           <none>
kube-system   metrics-server-774f99dbf4-gw4vd                         1/1     Running   0          44m     10.2.3.10   aks-nodepool1-17318001-vmss000001   <none>           <none>
kube-system   tunnelfront-d578ddc97-24jvv                             1/1     Running   0          44m     10.2.3.28   aks-nodepool1-17318001-vmss000001   <none>           <none>

kubectl get services
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.2.30.1    <none>        443/TCP   49m
```

Verify connectivity from cluster3 to cluster1/2/3.
```
az aks get-credentials -n liqian-cluster3 -g liqian-rg
kubectl get nodes -o wide
kubectl debug node/aks-nodepool1-17318001-vmss000001 -it --image=mcr.microsoft.com/aks/fundamental/base-ubuntu:v0.0.11

# Verified: Node IP is reachable.
root@aks-nodepool1-17318001-vmss000001:/# curl 10.0.1.4
curl: (7) Failed to connect to 10.0.1.4 port 80: Connection refused

root@aks-nodepool1-17318001-vmss000001:/# curl 10.0.2.4

root@aks-nodepool1-17318001-vmss000001:/# curl 10.2.3.4
curl: (7) Failed to connect to 10.2.3.4 port 80: Connection refused

# Verified: pod IP is reachable.
root@aks-nodepool1-17318001-vmss000001:/# curl 10.0.1.6
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...

root@aks-nodepool1-17318001-vmss000001:/# curl 10.0.2.5
curl: (7) Failed to connect to 10.0.2.5 port 80: Connection refused
root@aks-nodepool1-17318001-vmss000001:/# curl 10.0.2.7
curl: (7) Failed to connect to 10.0.2.7 port 80: Connection refused
root@aks-nodepool1-17318001-vmss000001:/# curl 10.0.2.28
curl: (7) Failed to connect to 10.0.2.28 port 80: Connection refused

# Verified: Service IPs are unreachable.
# This is working as expected: https://docs.microsoft.com/en-us/azure/aks/configure-azure-cni#frequently-asked-questions
root@aks-nodepool1-17318001-vmss000001:/# curl 10.0.10.5
^C
root@aks-nodepool1-17318001-vmss000001:/# curl 10.0.10.50
^C

root@aks-nodepool1-17318001-vmss000001:/# curl 10.0.20.1
^C
root@aks-nodepool1-17318001-vmss000001:/# curl 10.0.20.56
^C

root@aks-nodepool1-17318001-vmss000001:/# curl 10.2.30.1
^C
```

Verify connectivity from cluster2 to cluster1/2/3.
```
❯ az aks get-credentials -n liqian-cluster2 -g liqian-rg

❯ kubectl get nodes -o wide
NAME                                STATUS   ROLES   AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
aks-nodepool1-17429978-vmss000002   Ready    agent   15m   v1.21.9   10.0.2.4      <none>        Ubuntu 18.04.6 LTS   5.4.0-1072-azure   containerd://1.4.12+azure-3

kubectl debug node/aks-nodepool1-17429978-vmss000002 -it --image=mcr.microsoft.com/aks/fundamental/base-ubuntu:v0.0.11

# Verified: Node IP is reachable.
root@aks-nodepool1-17429978-vmss000002:/# curl 10.2.3.4
curl: (7) Failed to connect to 10.2.3.4 port 80: Connection refused

# Verified: pod IP is reachable.
root@aks-nodepool1-17429978-vmss000002:/# curl 10.0.1.6
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
root@aks-nodepool1-17429978-vmss000002:/# curl 10.0.2.5
curl: (7) Failed to connect to 10.0.2.5 port 80: Connection refused
root@aks-nodepool1-17429978-vmss000002:/# curl 10.2.3.10
curl: (7) Failed to connect to 10.2.3.10 port 80: Connection refused

# Verified: Service IPs are unreachable.
root@aks-nodepool1-17429978-vmss000002:/# curl 10.0.10.5
^C
root@aks-nodepool1-17429978-vmss000002:/# curl 10.0.10.50
^C
root@aks-nodepool1-17429978-vmss000002:/# curl 10.0.20.56
^C
root@aks-nodepool1-17429978-vmss000002:/# curl 10.2.30.1
^C
```

# Two Clusters in two vnets in two regions: Can a pod in one cluster reach another pod in another cluster? Yes

Create cluster4 in vnet 3.
```
cd tools
./setup-vnet3.sh
```

Deploy pods in cluster1 (same as above)
```
az aks get-credentials -n liqian-cluster1 -g liqian-rg
kubectl apply -f simple-serivce.yaml

❯ kubectl get pods -o wide
NAME    READY   STATUS    RESTARTS   AGE   IP          NODE                                NOMINATED NODE   READINESS GATES
nginx   1/1     Running   0          44s   10.0.1.22   aks-nodepool1-26949044-vmss000004   <none>           <none>

❯ kubectl get nodes -o wide
NAME                                STATUS   ROLES   AGE     VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
aks-nodepool1-26949044-vmss000004   Ready    agent   2m12s   v1.21.9   10.0.1.4      <none>        Ubuntu 18.04.6 LTS   5.4.0-1072-azure   containerd://1.4.12+azure-3
```

Verify connectivity from cluster4 to cluster1.
```
❯ az aks get-credentials -n liqian-cluster4 -g liqian-eastus2-rg

❯ kubectl get nodes -o wide

kubectl debug node/aks-nodepool1-27206661-vmss000000 -it --image=mcr.microsoft.com/aks/fundamental/base-ubuntu:v0.0.11

# Verified: Node IP is reachable.
root@aks-nodepool1-27206661-vmss000000:/# curl 10.0.1.4
curl: (7) Failed to connect to 10.0.1.4 port 80: Connection refused

# Verified: pod IP is reachable.
root@aks-nodepool1-27206661-vmss000000:/# curl 10.0.1.22
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...

root@aks-nodepool1-27206661-vmss000000:/# route
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
default         10.3.4.1        0.0.0.0         UG    100    0        0 eth0
10.3.4.0        0.0.0.0         255.255.255.0   U     0      0        0 eth0
10.3.4.11       0.0.0.0         255.255.255.255 UH    0      0        0 azv9f8c0c51685
10.3.4.14       0.0.0.0         255.255.255.255 UH    0      0        0 azva1cfb8297b1
10.3.4.17       0.0.0.0         255.255.255.255 UH    0      0        0 azv1623c868318
10.3.4.19       0.0.0.0         255.255.255.255 UH    0      0        0 azvc0a7fa39812
10.3.4.28       0.0.0.0         255.255.255.255 UH    0      0        0 azvb9172c0835f
168.63.129.16   10.3.4.1        255.255.255.255 UGH   100    0        0 eth0
169.254.169.254 10.3.4.1        255.255.255.255 UGH   100    0        0 eth0

```


