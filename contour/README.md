# Contour

## Background

Repo: https://github.com/projectcontour/contour

## Test Contour

### Install Contour

https://projectcontour.io/getting-started/#option-1-yaml

```bash
# Set subscription
az login

# Use personal subscription.
# az account set -s "Visual Studio Enterprise Subscription"

# Use shared subscription.
az account set -s "Arc-Validation-Conformance"

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

curl http://52.190.192.246
````

### Test gateway
https://projectcontour.io/guides/gateway-api/

```
az aks get-credentials -n liqian-cluster1 -g liqian-rg
kubectl apply -f https://projectcontour.io/quickstart/contour-gateway.yaml
kubectl apply -f https://projectcontour.io/quickstart/kuard.yaml

kubectl get po,svc,httproute -n projectcontour -l app=kuard
NAME                         READY   STATUS    RESTARTS   AGE
pod/kuard-798585497b-hn76q   1/1     Running   0          102s
pod/kuard-798585497b-hsjsp   1/1     Running   0          102s
pod/kuard-798585497b-x55d9   1/1     Running   0          102s

NAME            TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kuard   ClusterIP   10.0.20.9    <none>        80/TCP    102s

kubectl get gateway --namespace projectcontour
NAME      CLASS     ADDRESS        READY   AGE
contour   example   20.112.49.13   True    16h

kubectl describe gateway/contour --namespace projectcontour

kubectl get httproutes --namespace projectcontour
NAME          HOSTNAMES                     AGE
kuard         ["local.projectcontour.io"]   35s

kubectl describe httproutes --namespace projectcontour
Status:
  Parents:
    Conditions:
      Last Transition Time:  2022-04-02T17:13:23Z
      Message:               Valid HTTPRoute
      Observed Generation:   1
      Reason:                Valid
      Status:                True
      Type:                  Accepted
    Controller Name:         projectcontour.io/projectcontour/contour
    Parent Ref:
      Group:      gateway.networking.k8s.io
      Kind:       Gateway
      Name:       contour
      Namespace:  projectcontour
Events:           <none>

export GATEWAY=$(kubectl -n projectcontour get svc/envoy -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Verified: Can access the app: 200.
curl -H "Host: local.projectcontour.io" -s -o /dev/null -w "%{http_code}" "http://$GATEWAY/"
200%

kubectl delete -f https://projectcontour.io/quickstart/kuard.yaml

```

### Test gateway to another cluster
Follow https://github.com/circy9/multi-cluster-test/blob/first/basic/README.md to set up two clusters.
Follow "Test gateway" to deploy gateway to cluster1.

```
az aks get-credentials -n liqian-cluster2 -g liqian-rg
kubectl apply -f simple-service.yaml
kubectl describe po nginx
...
IP:           10.0.2.31
...

# Change dummy-service.yaml to use the IP above.

az aks get-credentials -n liqian-cluster1 -g liqian-rg
kubectl apply -f dummy-service.yaml

kubectl get service

NAME             TYPE           CLUSTER-IP    EXTERNAL-IP     PORT(S)        AGE
kubernetes       ClusterIP      10.0.20.1     <none>          443/TCP        85m
nginx-dummy      LoadBalancer   10.0.20.31    20.72.249.170   80:30125/TCP   9m44s

# Verified: Can access nginx.
curl 20.72.249.170
<!DOCTYPE html>
<html>
<head>
...

kubectl describe gateway/contour --namespace projectcontour
Status:
  Addresses:
    Type:   IPAddress
    Value:  20.112.49.13
  Conditions:
    Last Transition Time:  2022-04-02T17:26:44Z
    Message:               Valid Gateway
    Observed Generation:   1
    Reason:                Valid
    Status:                True
    Type:                  Ready

kubectl describe httproute
Status:
  Parents:
    Conditions:
      Last Transition Time:  2022-04-02T17:30:56Z
      Message:               Valid HTTPRoute
      Observed Generation:   2
      Reason:                Valid
      Status:                True
      Type:                  Accepted
    Controller Name:         projectcontour.io/projectcontour/contour
    Parent Ref:
      Group:      gateway.networking.k8s.io
      Kind:       Gateway
      Name:       contour
      Namespace:  projectcontour

kubectl get gateway --namespace projectcontour
NAME      CLASS     ADDRESS        READY   AGE
contour   example   20.112.49.13   True    17h

# Verified: No output if dummer-service.yaml contains:
#  hostnames:
#    - "local.projectcontour.io"
# It is because the IP we used doesn't match the give host names.
curl 20.112.49.13

# Verified: Works if dummer-service.yaml comments out:
#  hostnames:
#    - "local.projectcontour.io"
curl 20.112.49.13
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...

```

#### Inspect envoy logs

##### Happy Path
```
# tab 1: apply service change to comment out "hostnames".
kubectl apply -f dummy-service.yaml

# tab 2: inspect envoy logs. Note that 10.0.1.34 is the pod IP of nginx in another cluster.
kubectl get nodes -o wide
kubectl debug node/aks-nodepool1-17429978-vmss000000 -it --image=mcr.microsoft.com/aks/fundamental/base-ubuntu:v0.0.11
root@aks-nodepool1-17429978-vmss000001:/host/var/log/pods/projectcontour_envoy-bpvlx_10359dc6-dae5-443f-85c8-b23a77f9ebfe/envoy# tail 0.log
2022-04-02T18:29:55.867979448Z stderr F [2022-04-02 18:29:55.867][1][info][upstream] [source/common/upstream/cds_api_helper.cc:30] cds: add 1 cluster(s), remove 2 cluster(s)
2022-04-02T18:29:55.867996748Z stderr F [2022-04-02 18:29:55.867][1][info][upstream] [source/common/upstream/cds_api_helper.cc:67] cds: added/updated 0 cluster(s), skipped 1 unmodified cluster(s)
2022-04-02T18:29:55.979860299Z stderr F [2022-04-02 18:29:55.979][1][info][upstream] [source/common/upstream/cds_api_helper.cc:30] cds: add 1 cluster(s), remove 2 cluster(s)
2022-04-02T18:29:55.979915598Z stderr F [2022-04-02 18:29:55.979][1][info][upstream] [source/common/upstream/cds_api_helper.cc:67] cds: added/updated 0 cluster(s), skipped 1 unmodified cluster(s)
2022-04-02T18:30:26.739957561Z stdout F [2022-04-02T18:30:24.964Z] "GET / HTTP/1.1" 200 - 0 400 1 1 "192.241.213.226" "Mozilla/5.0 zgrab/0.x" "b7b8259c-d31a-45a3-ac70-79c0d24255bf" "20.112.49.13" "10.0.1.34:80"
# The last message is probably probing.

# tab 1: curl the gateway IP.
kubectl get gateway --namespace projectcontour
NAME      CLASS     ADDRESS        READY   AGE
contour   example   20.112.49.13   True    17h

curl 20.112.49.13
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...

# tab 2: inspect envoy logs
root@aks-nodepool1-17429978-vmss000001:/host/var/log/pods/projectcontour_envoy-bpvlx_10359dc6-dae5-443f-85c8-b23a77f9ebfe/envoy# tail 0.log
2022-04-02T18:33:46.819358723Z stdout F [2022-04-02T18:33:44.093Z] "GET / HTTP/1.1" 200 - 0 615 2 1 "50.47.114.118" "curl/7.79.1" "249a182f-e947-42bd-b66b-033d1bb5a7d3" "20.112.49.13" "10.0.1.34:80"

# Chrome: visit http://20.112.49.13

# tab 2: inspect envoy logs
root@aks-nodepool1-17429978-vmss000001:/host/var/log/pods/projectcontour_envoy-bpvlx_10359dc6-dae5-443f-85c8-b23a77f9ebfe/envoy# tail 0.log
2022-04-02T18:36:06.876270353Z stdout F [2022-04-02T18:36:01.334Z] "GET / HTTP/1.1" 304 - 0 0 1 1 "50.47.114.118" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.60 Safari/537.36" "3362da12-63a3-4f3c-a5df-5df7d7a31316" "20.112.49.13" "10.0.1.34:80"
```

#### Unhappy Path
```
# tab 1: apply service change to uncomment  "hostnames".
kubectl apply -f dummy-service.yaml

# tab 2: inspect envoy logs.
root@aks-nodepool1-17429978-vmss000001:/host/var/log/pods/projectcontour_envoy-bpvlx_10359dc6-dae5-443f-85c8-b23a77f9ebfe/envoy# tail 0.log
2022-04-02T18:37:33.646553019Z stderr F [2022-04-02 18:37:33.646][1][info][upstream] [source/common/upstream/cds_api_helper.cc:30] cds: add 1 cluster(s), remove 2 cluster(s)
2022-04-02T18:37:33.646674718Z stderr F [2022-04-02 18:37:33.646][1][info][upstream] [source/common/upstream/cds_api_helper.cc:67] cds: added/updated 0 cluster(s), skipped 1 unmodified cluster(s)
2022-04-02T18:37:33.773912792Z stderr F [2022-04-02 18:37:33.773][1][info][upstream] [source/common/upstream/cds_api_helper.cc:30] cds: add 1 cluster(s), remove 2 cluster(s)
2022-04-02T18:37:33.773946892Z stderr F [2022-04-02 18:37:33.773][1][info][upstream] [source/common/upstream/cds_api_helper.cc:67] cds: added/updated 0 cluster(s), skipped 1 unmodified cluster(s)

# tab 1: curl the gateway IP.
curl 20.112.49.13

# tab 2: inspect envoy logs. Note that "-" means it failed to route to a target IP.
root@aks-nodepool1-17429978-vmss000001:/host/var/log/pods/projectcontour_envoy-bpvlx_10359dc6-dae5-443f-85c8-b23a77f9ebfe/envoy# tail 0.log
2022-04-02T18:38:46.947721702Z stdout F [2022-04-02T18:38:44.413Z] "GET / HTTP/1.1" 404 NR 0 0 0 - "50.47.114.118" "curl/7.79.1" "7b4405f4-fa58-47a9-864c-e5df1eb60fe6" "20.112.49.13" "-"
```

### Install Monitoring
https://projectcontour.io/guides/prometheus/

❯ git clone https://github.com/projectcontour/contour
cd contour
kubectl apply -f examples/prometheus

kubectl -n projectcontour-monitoring port-forward $(kubectl -n projectcontour-monitoring get pods -l app=prometheus -l component=server -o jsonpath='{.items[0].metadata.name}') 9090:9090
http://localhost:9090

kubectl -n projectcontour-monitoring port-forward $(kubectl -n projectcontour-monitoring get pods -l app=prometheus -l component=alertmanager -o jsonpath='{.items[0].metadata.name}') 9093:9093
http://localhost:9093

❯ kubectl apply -f examples/grafana/
namespace/projectcontour-monitoring unchanged
configmap/grafana-dashs created
configmap/grafana-config created
configmap/grafana-dash-provider created
configmap/grafana-datasources-provider created
deployment.apps/grafana created
service/grafana created

❯ kubectl create secret generic grafana -n projectcontour-monitoring \
--from-literal=grafana-admin-password=admin \
--from-literal=grafana-admin-user=admin
secret/grafana created

❯ kubectl port-forward $(kubectl get pods -l app=grafana -n projectcontour-monitoring -o jsonpath='{.items[0].metadata.name}') 3000 -n projectcontour-monitoring

http://localhost:3000

## Debug

### Access service from local machine

```
kubectl port-forward service/envoy -n projectcontour 8080:80
http://localhost:8080

kubectl port-forward service/envoy -n projectcontour 8443:443
# This doesn't work.
https://localhost:8443

kubectl port-forward service/httpbin 8080:80
http://localhost:8080
```

### Inspect processes, configs, and logs

Find processes:
```
kubectl get nodes -o wide
kubectl debug node/aks-nodepool1-76974163-vmss000000 -it --image=mcr.microsoft.com/aks/fundamental/base-ubuntu:v0.0.11

ps aux | grep envoy
nobody    7978  0.0  0.5 748920 38776 ?        Ssl  01:39   0:08 /bin/contour envoy shutdown-manager
nobody    9322  0.2  0.7 2274816 55804 ?       Ssl  01:39   2:52 envoy -c /config/envoy.json --service-cluster projectcontour --service-node envoy-rh8p2 --log-level info

ps aux | grep contour
nobody    7917  0.2  0.8 749944 58536 ?        Ssl  01:39   2:14 contour serve --incluster --xds-address=0.0.0.0 --xds-port=8001 --contour-cafile=/certs/ca.crt --contour-cert-file=/certs/tls.crt --contour-key-file=/certs/tls.key --config-path=/config/contour.yaml
nobody    7978  0.0  0.5 748920 38776 ?        Ssl  01:39   0:08 /bin/contour envoy shutdown-manager
nobody    8071  0.0  0.7 749688 53296 ?        Ssl  01:39   0:48 contour serve --incluster --xds-address=0.0.0.0 --xds-port=8001 --contour-cafile=/certs/ca.crt --contour-cert-file=/certs/tls.crt --contour-key-file=/certs/tls.key --config-path=/config/contour.yaml
nobody    9322  0.2  0.7 2274816 55804 ?       Ssl  01:39   2:52 envoy -c /config/envoy.json --service-cluster projectcontour --service-node envoy-rh8p2 --log-level info
```

Find configs:
```
cd host/var

/host/var# find . -name contour.yaml
./lib/kubelet/pods/8c241277-802c-4bd5-a4a1-6cb18be7efb1/volumes/kubernetes.io~configmap/contour-config/..2022_03_20_01_39_19.925934757/contour.yaml
./lib/kubelet/pods/8c241277-802c-4bd5-a4a1-6cb18be7efb1/volumes/kubernetes.io~configmap/contour-config/contour.yaml
./lib/kubelet/pods/ec5d91c7-bb91-4e08-8146-05a6ef91360c/volumes/kubernetes.io~configmap/contour-config/..2022_03_20_01_39_19.2144141347/contour.yaml
./lib/kubelet/pods/ec5d91c7-bb91-4e08-8146-05a6ef91360c/volumes/kubernetes.io~configmap/contour-config/contour.yaml

/host/var# find . -name envoy.json
./lib/kubelet/pods/04664334-6edc-4e1b-80be-06a52eade2c2/volumes/kubernetes.io~empty-dir/envoy-config/envoy.json
```

Find logs
```
/host/var/log/pods# more projectcontour_envoy-rh8p2_04664334-6edc-4e1b-80be-06a52eade2c2/envoy/0.log
```

### Inspect Envoy
https://projectcontour.io/docs/v1.20.1/troubleshooting/envoy-admin-interface/

```
❯ ENVOY_POD=$(kubectl -n projectcontour get pod -l app=envoy -o name | head -1)
❯ echo $ENVOY_POD
pod/envoy-qxkrc
❯ kubectl -n projectcontour port-forward $ENVOY_POD 9001
```

http://localhost:9001/server_info
More endpoints: https://projectcontour.io/docs/v1.20.1/troubleshooting/envoy-admin-interface/

### Inspect xDS resources
https://projectcontour.io/docs/v1.20.1/troubleshooting/contour-xds-resources/

```
❯ CONTOUR_POD=$(kubectl -n projectcontour get pod -l app=contour -o jsonpath='{.items[0].metadata.name}')
❯ kubectl -n projectcontour exec $CONTOUR_POD -c contour -- contour cli eds --cafile=/certs/ca.crt --cert-file=/certs/tls.crt --key-file=/certs/tls.key
```

### Inspect Envoy metrics

https://projectcontour.io/guides/prometheus/

```
❯ kubectl get po -n projectcontour
NAME                       READY   STATUS    RESTARTS   AGE
contour-697d45c475-ccp2f   1/1     Running   0          18h
contour-697d45c475-gr8j7   1/1     Running   0          18h
envoy-rh8p2                2/2     Running   0          18h

❯ kubectl -n projectcontour port-forward envoy-rh8p2 8002:8002
Forwarding from 127.0.0.1:8002 -> 8002
Forwarding from [::1]:8002 -> 8002
Handling connection for 8002
Handling connection for 8002
```

http://localhost:8002/stats/prometheus

### Inspect Contour metrics

https://projectcontour.io/guides/prometheus/

```
❯ kubectl get po -n projectcontour -o wide
NAME                       READY   STATUS    RESTARTS   AGE   IP           NODE                                NOMINATED NODE   READINESS GATES
contour-697d45c475-ccp2f   1/1     Running   0          18h   10.244.0.5   aks-nodepool1-85539412-vmss000002   <none>           <none>
contour-697d45c475-gr8j7   1/1     Running   0          18h   10.244.0.4   aks-nodepool1-85539412-vmss000002   <none>           <none>
envoy-rh8p2                2/2     Running   0          18h   10.244.0.2   aks-nodepool1-85539412-vmss000002   <none>           <none>
❯ kubectl -n projectcontour port-forward contour-697d45c475-ccp2f 8000:8000
Forwarding from 127.0.0.1:8000 -> 8000
Forwarding from [::1]:8000 -> 8000
Handling connection for 8000
Handling connection for 8000
```

http://localhost:8000/metrics

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