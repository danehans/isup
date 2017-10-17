# isup
Deploy Istio+Kubernetes in Containers to GCE for Testing. `isup` is a tool for deploying [Istio](https://istio.io) to [Google Compute Engine](https://cloud.google.com/compute/) (GCE) using [kubeadm-dind-cluster](https://github.com/Mirantis/kubeadm-dind-cluster) (dind).

## Requirements
- A GCE account: Follow the [quick-start](https://cloud.google.com/sdk/docs/quickstart-mac-os-x) guide to get your GCE developer environment setup.
- GCE [application default credentials](https://developers.google.com/identity/protocols/application-default-credentials?hl=en_US): Export your GCE application default credentials:
```
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/my/gce/default/application/credentials.json
```
- kubectl: If `kubectl` client is not installed or not at least v1.8.x, then install the kubectl [client](https://kubernetes.io/docs/tasks/tools/install-kubectl/).
- [Docker Machine](https://docs.docker.com/machine/install-machine/).

## Deployment
Until dind supports Kubernetes 1.8.x, isup will only deploy Kubernetes from source. Set environment variables to customize your Istio deployment:
```
export ISTIO_BOOKINFO=y
export ISTIO_ADDONS=y
```

Download and run `isup`:
```
curl -O https://raw.githubusercontent.com/danehans/isup/master/isup.sh
chmod +x isup.sh
./isup.sh
```

Building the Kubernetes binaries and images takes roughly 10 minutes on a 4 vCPU GCE compute instance. The Kubernetes deployment should complete with the following:
```
<SNIP>
Access dashboard at: http://localhost:8899/ui
```

## Verify Kubernetes Deployment
Test access to the UI:
```
curl http://localhost:8899/ui
<a href="/api/v1/namespaces/kube-system/services/kubernetes-dashboard/proxy">Temporary Redirect</a>.
```

Test access to the API using kubectl:
```
kubectl cluster-info
Kubernetes master is running at http://localhost:8899
KubeDNS is running at http://localhost:8899/api/v1/namespaces/kube-system/services/kube-dns/proxy
```

## Verify Istio Deployment
Verify the Istio svc's and pods are running:
```
kubectl get po,svc -n istio-system
NAME                               READY     STATUS    RESTARTS   AGE
po/istio-ca-7d55f54c97-p6nj6       1/1       Running   0          1m
po/istio-egress-d45bf8cd5-xtvj4    1/1       Running   0          1m
po/istio-ingress-64559cc97-7vczs   1/1       Running   0          1m
po/istio-mixer-6bc46fb49d-z6pwc    2/2       Running   0          1m
po/istio-pilot-54f4b4d9d4-lclt7    1/1       Running   0          1m

NAME                CLUSTER-IP       EXTERNAL-IP   PORT(S)                                                  AGE
svc/istio-egress    10.108.252.107   <none>        80/TCP                                                   1m
svc/istio-ingress   10.101.195.149   <nodes>       80:32000/TCP,443:31924/TCP                               1m
svc/istio-mixer     10.106.177.185   <none>        9091/TCP,9093/TCP,9094/TCP,9102/TCP,9125/UDP,42422/TCP   1m
svc/istio-pilot     10.111.78.218    <none>        8080/TCP,443/TCP
```

## Verify Bookinfo Deployment
Generate some traffic:
```
curl http://localhost:32000/productpage
```

View values for the new metric via the [Prometheus UI](http://localhost:9090/graph#%5B%7B%22range_input%22%3A%221h%22%2C%22expr%22%3A%22double_request_count%22%2C%22tab%22%3A1%7D%5D).

Refer to the [Collecting Metrics and Logs documentation](https://istio.io/docs/tasks/telemetry/metrics-logs.html) for additional details.

Access the [Zipkin UI](http://localhost:9411/)

Reference the [Distributed Tracing documentation](https://istio.io/docs/tasks/telemetry/distributed-tracing.html#generating-traces-using-the-bookinfo-sample) for details on how to generate tyraces using the bookinfo application.

Open the Dashboard [Web UI](http://localhost:3000/dashboard/db/istio-dashboard).

Generate some traffic:
```
curl http://localhost:32000/productpage
```

Return to the dashboard to view activity.

Reference the [Istio Dashboard documentation]https://istio.io/docs/tasks/telemetry/using-istio-dashboard.html) for additional details.

## Uninstall
```
docker-machine rm -f $KUBE_DIND_VM
```