# Contour

## Background

Repo: https://github.com/projectcontour/contour

## Test Contour

### Create cluster

```bash
# Set subscription
az login
az account set -s "Visual Studio Enterprise Subscription"

# Create a AKS cluster.
./tools/azure-cluster.sh create

# Install Contour: https://projectcontour.io/getting-started/#option-1-yaml
kubectl apply -f https://projectcontour.io/quickstart/contour.yaml

kubectl get pods -n projectcontour -o wide
NAME                            READY   STATUS      RESTARTS   AGE     IP            NODE                                NOMINATED NODE   READINESS GATES
contour-697d45c475-7hv6m        1/1     Running     0          2m29s   10.244.0.10   aks-nodepool1-76974163-vmss000000   <none>           <none>
contour-697d45c475-9tbm9        1/1     Running     0          2m29s   10.244.0.9    aks-nodepool1-76974163-vmss000000   <none>           <none>
contour-certgen-v1.20.1-w2d84   0/1     Completed   0          2m29s   10.244.0.8    aks-nodepool1-76974163-vmss000000   <none>           <none>
envoy-zbzj8                     2/2     Running     0          2m29s   10.244.0.11   aks-nodepool1-76974163-vmss000000   <none>           <none>

# Install app: https://projectcontour.io/getting-started/#test-it-out
kubectl apply -f https://projectcontour.io/examples/httpbin.yaml
deployment.apps/httpbin created
service/httpbin created
ingress.networking.k8s.io/httpbin created

kubectl get po,svc,ing -l app=httpbin
NAME                           READY   STATUS    RESTARTS   AGE
pod/httpbin-84fc76f6f6-7j759   1/1     Running   0          45s
pod/httpbin-84fc76f6f6-l67qf   1/1     Running   0          45s
pod/httpbin-84fc76f6f6-q6lc9   1/1     Running   0          45s

NAME              TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
service/httpbin   ClusterIP   10.0.55.246   <none>        80/TCP    45s

NAME                                CLASS    HOSTS   ADDRESS          PORTS   AGE
ingress.networking.k8s.io/httpbin   <none>   *       52.190.192.246   80      44s

kubectl -n projectcontour get svc/envoy -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
52.190.192.246

# Test app: didn't work.
curl http://52.190.192.246
````
## Debug

### Error: Readiness probe failed: Get "http://10.244.0.11:8002/ready"
```
kubectl logs po/envoy-zbzj8 envoy -n projectcontour

kubectl describe po/envoy-zbzj8 -n projectcontour
Events:
Type     Reason       Age                From               Message
  ----     ------       ----               ----               -------
Normal   Scheduled    55m                default-scheduler  Successfully assigned projectcontour/envoy-zbzj8 to aks-nodepool1-76974163-vmss000000
Warning  FailedMount  55m (x4 over 55m)  kubelet            MountVolume.SetUp failed for volume "envoycert" : secret "envoycert" not found
Normal   Pulled       55m                kubelet            Container image "ghcr.io/projectcontour/contour:v1.20.1" already present on machine
Normal   Created      55m                kubelet            Created container envoy-initconfig
Normal   Started      55m                kubelet            Started container envoy-initconfig
Normal   Created      55m                kubelet            Created container shutdown-manager
Normal   Pulled       55m                kubelet            Container image "ghcr.io/projectcontour/contour:v1.20.1" already present on machine
Normal   Started      55m                kubelet            Started container shutdown-manager
Normal   Pulling      55m                kubelet            Pulling image "docker.io/envoyproxy/envoy:v1.21.1"
Normal   Pulled       55m                kubelet            Successfully pulled image "docker.io/envoyproxy/envoy:v1.21.1" in 5.012505429s
Normal   Created      55m                kubelet            Created container envoy
Normal   Started      55m                kubelet            Started container envoy
Warning  Unhealthy    55m (x4 over 55m)  kubelet            Readiness probe failed: Get "http://10.244.0.11:8002/ready": dial tcp 10.244.0.11:8002: connect: connection refused
```

Use the AKS debug image. But it doesn't have curl.
```
kubectl get nodes -o wide
kubectl debug node/aks-nodepool1-76974163-vmss000000 -it --image=mcr.microsoft.com/dotnet/runtime-deps:6.0
chroot /host
cd /var/log/pods
# Browsed logs. Logs look fine.
```

Just use Ubuntu. "http://10.244.0.11:8002/ready" is reachable. "http://52.190.192.246" is reachable.
```
kubectl debug node/aks-nodepool1-76974163-vmss000000 -it --image=mcr.microsoft.com/aks/fundamental/base-ubuntu:v0.0.11
chroot /host

curl http://10.244.0.11:8002/ready
LIVE

curl http://52.190.192.246
Works!
```

But http://52.190.192.246 from outside the vnet still doesn't work.
It is possible that Azure internal subscriptions block http traffic. Decided to try personal sub. It worked!