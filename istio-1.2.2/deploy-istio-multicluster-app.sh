export KUBECONFIG1=/Users/djannot/Documents/demos/kscli/konvoy_v0.4.0/admin.conf
export KUBECONFIG2=/Users/djannot/Documents/demos/kscli/konvoy_v0.4.0-2/admin.conf

cd $(dirname $0)

# Create sleep on cluster1
kubectl create --kubeconfig=${KUBECONFIG1} namespace foo
kubectl label --kubeconfig=${KUBECONFIG1} namespace foo istio-injection=enabled
kubectl apply --kubeconfig=${KUBECONFIG1} -n foo -f samples/sleep/sleep.yaml
export SLEEP_POD=$(kubectl get --kubeconfig=${KUBECONFIG1} -n foo pod -l app=sleep -o jsonpath={.items..metadata.name})

# Create httpbin on cluster2
kubectl create --kubeconfig=${KUBECONFIG2} namespace bar
kubectl label --kubeconfig=${KUBECONFIG2} namespace bar istio-injection=enabled
kubectl apply --kubeconfig=${KUBECONFIG2} -n bar -f samples/httpbin/httpbin.yaml

export CLUSTER2_GW_HOSTNAME=$(kubectl get --kubeconfig=${KUBECONFIG2} svc --selector=app=istio-ingressgateway \
    -n istio-system -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

# Creating the httpbin.bar.global DNS record on cluster1 and specifying that it is served by cluster2
kubectl apply --kubeconfig=${KUBECONFIG1} -n foo -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: httpbin-bar
spec:
  hosts:
  # must be of form name.namespace.global
  - httpbin.bar.global
  # Treat remote cluster services as part of the service mesh
  # as all clusters in the service mesh share the same root of trust.
  location: MESH_INTERNAL
  ports:
  - name: http1
    number: 8000
    protocol: http
  resolution: DNS
  addresses:
  # the IP address to which httpbin.bar.global will resolve to
  # must be unique for each remote service, within a given cluster.
  # This address need not be routable. Traffic for this IP will be captured
  # by the sidecar and routed appropriately.
  - 127.255.0.2
  endpoints:
  # This is the routable address of the ingress gateway in cluster2 that
  # sits in front of sleep.foo service. Traffic from the sidecar will be
  # routed to this address.
  - address: ${CLUSTER2_GW_HOSTNAME}
    ports:
      http1: 15443 # Do not change this port value
EOF

# Check that httpbin running on cluster2 can be accessed by sleep running on cluster1
kubectl exec --kubeconfig=${KUBECONFIG1} $SLEEP_POD -n foo -c sleep -- curl -I httpbin.bar.global:8000/headers

# Create sleep on cluster2 as well
kubectl create --kubeconfig=${KUBECONFIG2} namespace foo
kubectl label --kubeconfig=${KUBECONFIG2} namespace foo istio-injection=enabled
kubectl apply --kubeconfig=${KUBECONFIG2} -n foo -f samples/sleep/sleep.yaml

export CLUSTER1_GW_HOSTNAME=$(kubectl get --kubeconfig=${KUBECONFIG1} svc --selector=app=istio-ingressgateway \
    -n istio-system -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

# Updating the httpbin.bar.global DNS record on cluster1 and specifying that it is served by both clusters
kubectl apply --kubeconfig=${KUBECONFIG1} -n foo -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: httpbin-bar
spec:
  hosts:
  # must be of form name.namespace.global
  - httpbin.bar.global
  # Treat remote cluster services as part of the service mesh
  # as all clusters in the service mesh share the same root of trust.
  location: MESH_INTERNAL
  ports:
  - name: http1
    number: 8000
    protocol: http
  resolution: DNS
  addresses:
  # the IP address to which httpbin.bar.global will resolve to
  # must be unique for each remote service, within a given cluster.
  # This address need not be routable. Traffic for this IP will be captured
  # by the sidecar and routed appropriately.
  - 127.255.0.2
  endpoints:
  # This is the routable address of the ingress gateway in cluster2 that
  # sits in front of sleep.foo service. Traffic from the sidecar will be
  # routed to this address.
  - address: ${CLUSTER1_GW_HOSTNAME}
    ports:
      http1: 15443 # Do not change this port value
  - address: ${CLUSTER2_GW_HOSTNAME}
    ports:
      http1: 15443 # Do not change this port value
EOF

# If you port of one cluster is not reachable, then Istio will use one that is available.
# But, if the IP of one cluster is not reachable, then Istio will wait 10 seconds before failing back to the other cluster

#export HTTPBIN_POD=$(kubectl get --kubeconfig=${KUBECONFIG2} -n bar pod -l app=httpbin -o jsonpath={.items..metadata.name})
#kubectl exec --kubeconfig=${KUBECONFIG2} $HTTPBIN_POD -n bar -c httpbin -- apt-get -y update
#kubectl exec --kubeconfig=${KUBECONFIG2} $HTTPBIN_POD -n bar -c httpbin -- iputils-ping
#kubectl exec --kubeconfig=${KUBECONFIG2} $HTTPBIN_POD -n bar -c httpbin -- ping sleep.foo.global

# Enable access logs
helm template install/kubernetes/helm/istio --namespace=istio-system -x templates/configmap.yaml --set global.proxy.accessLogFile="/dev/stdout" | kubectl --kubeconfig=${KUBECONFIG1} replace -f -
helm template install/kubernetes/helm/istio --namespace=istio-system -x templates/configmap.yaml --set global.proxy.accessLogFile="/dev/stdout" | kubectl --kubeconfig=${KUBECONFIG2} replace -f -

# Create httpbin on cluster1
kubectl create --kubeconfig=${KUBECONFIG1} namespace bar
kubectl label --kubeconfig=${KUBECONFIG1} namespace bar istio-injection=enabled
kubectl apply --kubeconfig=${KUBECONFIG1} -n bar -f samples/httpbin/httpbin.yaml

# Connect several times to httpbin from sleep running on cluster1 and look at the logs of httpbin on both clusters to check that the requests are distributes accross both clusters
kubectl exec --kubeconfig=${KUBECONFIG1} $SLEEP_POD -n foo -c sleep -- curl -I httpbin.bar.global:8000/headers
kubectl exec --kubeconfig=${KUBECONFIG1} $SLEEP_POD -n foo -c sleep -- curl -I httpbin.bar.global:8000/headers
kubectl exec --kubeconfig=${KUBECONFIG1} $SLEEP_POD -n foo -c sleep -- curl -I httpbin.bar.global:8000/headers
kubectl exec --kubeconfig=${KUBECONFIG1} $SLEEP_POD -n foo -c sleep -- curl -I httpbin.bar.global:8000/headers
kubectl --kubeconfig=${KUBECONFIG1} -n bar logs $(kubectl --kubeconfig=${KUBECONFIG1} -n bar get pods -o jsonpath='{.items[0].metadata.name}') -c istio-proxy
kubectl --kubeconfig=${KUBECONFIG2} -n bar logs $(kubectl --kubeconfig=${KUBECONFIG2} -n bar get pods -o jsonpath='{.items[0].metadata.name}') -c istio-proxy

# On AWS remove the port 15443 from the security group associated to the ELB to isolate cluster1 (10s timeout on some requests).
# On AWS remove the port 15443 from the ELB to isolate cluster1 (no timeout).

# Connect several times to httpbin from sleep running on cluster1 and look at the logs of httpbin on both clusters to check that the requests are all served by cluster1
kubectl exec --kubeconfig=${KUBECONFIG1} $SLEEP_POD -n foo -c sleep -- curl -I httpbin.bar.global:8000/headers
kubectl exec --kubeconfig=${KUBECONFIG1} $SLEEP_POD -n foo -c sleep -- curl -I httpbin.bar.global:8000/headers
kubectl exec --kubeconfig=${KUBECONFIG1} $SLEEP_POD -n foo -c sleep -- curl -I httpbin.bar.global:8000/headers
kubectl exec --kubeconfig=${KUBECONFIG1} $SLEEP_POD -n foo -c sleep -- curl -I httpbin.bar.global:8000/headers
kubectl --kubeconfig=${KUBECONFIG1} -n bar logs $(kubectl --kubeconfig=${KUBECONFIG1} -n bar get pods -o jsonpath='{.items[0].metadata.name}') -c istio-proxy
kubectl --kubeconfig=${KUBECONFIG2} -n bar logs $(kubectl --kubeconfig=${KUBECONFIG2} -n bar get pods -o jsonpath='{.items[0].metadata.name}') -c istio-proxy

# On AWS remove the port 15443 from the security group associated to the ELB to allow cluster1 to communicate again with cluster2 (10s timeout on some requests).
# On AWS remove the port 15443 from the ELB to allow cluster1 to communicate again with cluster2 (no timeout).

# Connect several times to httpbin from sleep running on cluster1 and look at the logs of httpbin on both clusters to check that the requests are distributes accross both clusters
kubectl exec --kubeconfig=${KUBECONFIG1} $SLEEP_POD -n foo -c sleep -- curl -I httpbin.bar.global:8000/headers
kubectl exec --kubeconfig=${KUBECONFIG1} $SLEEP_POD -n foo -c sleep -- curl -I httpbin.bar.global:8000/headers
kubectl exec --kubeconfig=${KUBECONFIG1} $SLEEP_POD -n foo -c sleep -- curl -I httpbin.bar.global:8000/headers
kubectl exec --kubeconfig=${KUBECONFIG1} $SLEEP_POD -n foo -c sleep -- curl -I httpbin.bar.global:8000/headers
kubectl --kubeconfig=${KUBECONFIG1} -n bar logs $(kubectl --kubeconfig=${KUBECONFIG1} -n bar get pods -o jsonpath='{.items[0].metadata.name}') -c istio-proxy
kubectl --kubeconfig=${KUBECONFIG2} -n bar logs $(kubectl --kubeconfig=${KUBECONFIG2} -n bar get pods -o jsonpath='{.items[0].metadata.name}') -c istio-proxy

# But it can be even smarter: https://istio.io/docs/reference/config/networking/v1alpha3/service-entry/#ServiceEntry-Endpoint

# Updating the httpbin.bar.global DNS record on cluster1 to use different weights
kubectl apply --kubeconfig=${KUBECONFIG1} -n foo -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: httpbin-bar
spec:
  hosts:
  # must be of form name.namespace.global
  - httpbin.bar.global
  # Treat remote cluster services as part of the service mesh
  # as all clusters in the service mesh share the same root of trust.
  location: MESH_INTERNAL
  ports:
  - name: http1
    number: 8000
    protocol: http
  resolution: DNS
  addresses:
  # the IP address to which httpbin.bar.global will resolve to
  # must be unique for each remote service, within a given cluster.
  # This address need not be routable. Traffic for this IP will be captured
  # by the sidecar and routed appropriately.
  - 127.255.0.2
  endpoints:
  # This is the routable address of the ingress gateway in cluster2 that
  # sits in front of sleep.foo service. Traffic from the sidecar will be
  # routed to this address.
  - address: ${CLUSTER1_GW_HOSTNAME}
    ports:
      http1: 15443 # Do not change this port value
    weight: 3
  - address: ${CLUSTER2_GW_HOSTNAME}
    ports:
      http1: 15443 # Do not change this port value
    weight: 1
EOF

# Connect several times to httpbin from sleep running on cluster1 and look at the logs of httpbin on both clusters to check that more requests are sent to cluster1.
kubectl exec --kubeconfig=${KUBECONFIG1} $SLEEP_POD -n foo -c sleep -- curl -I httpbin.bar.global:8000/headers
kubectl exec --kubeconfig=${KUBECONFIG1} $SLEEP_POD -n foo -c sleep -- curl -I httpbin.bar.global:8000/headers
kubectl exec --kubeconfig=${KUBECONFIG1} $SLEEP_POD -n foo -c sleep -- curl -I httpbin.bar.global:8000/headers
kubectl exec --kubeconfig=${KUBECONFIG1} $SLEEP_POD -n foo -c sleep -- curl -I httpbin.bar.global:8000/headers
kubectl --kubeconfig=${KUBECONFIG1} -n bar logs $(kubectl --kubeconfig=${KUBECONFIG1} -n bar get pods -o jsonpath='{.items[0].metadata.name}') -c istio-proxy
kubectl --kubeconfig=${KUBECONFIG2} -n bar logs $(kubectl --kubeconfig=${KUBECONFIG2} -n bar get pods -o jsonpath='{.items[0].metadata.name}') -c istio-proxy

# Updating the httpbin.bar.global DNS record on cluster2 to have an active/active deployment
kubectl apply --kubeconfig=${KUBECONFIG2} -n foo -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: httpbin-bar
spec:
  hosts:
  # must be of form name.namespace.global
  - httpbin.bar.global
  # Treat remote cluster services as part of the service mesh
  # as all clusters in the service mesh share the same root of trust.
  location: MESH_INTERNAL
  ports:
  - name: http1
    number: 8000
    protocol: http
  resolution: DNS
  addresses:
  # the IP address to which httpbin.bar.global will resolve to
  # must be unique for each remote service, within a given cluster.
  # This address need not be routable. Traffic for this IP will be captured
  # by the sidecar and routed appropriately.
  - 127.255.0.2
  endpoints:
  # This is the routable address of the ingress gateway in cluster2 that
  # sits in front of sleep.foo service. Traffic from the sidecar will be
  # routed to this address.
  - address: ${CLUSTER1_GW_HOSTNAME}
    ports:
      http1: 15443 # Do not change this port value
  - address: ${CLUSTER2_GW_HOSTNAME}
    ports:
      http1: 15443 # Do not change this port value
EOF

# Connect several times to httpbin from sleep running on cluster2 and look at the logs of httpbin on both clusters to check that the requests are distributes accross both clusters
export SLEEP_POD=$(kubectl get --kubeconfig=${KUBECONFIG2} -n foo pod -l app=sleep -o jsonpath={.items..metadata.name})
kubectl exec --kubeconfig=${KUBECONFIG2} $SLEEP_POD -n foo -c sleep -- curl -I httpbin.bar.global:8000/headers
kubectl exec --kubeconfig=${KUBECONFIG2} $SLEEP_POD -n foo -c sleep -- curl -I httpbin.bar.global:8000/headers
kubectl exec --kubeconfig=${KUBECONFIG2} $SLEEP_POD -n foo -c sleep -- curl -I httpbin.bar.global:8000/headers
kubectl exec --kubeconfig=${KUBECONFIG2} $SLEEP_POD -n foo -c sleep -- curl -I httpbin.bar.global:8000/headers
kubectl --kubeconfig=${KUBECONFIG1} -n bar logs $(kubectl --kubeconfig=${KUBECONFIG1} -n bar get pods -o jsonpath='{.items[0].metadata.name}') -c istio-proxy
kubectl --kubeconfig=${KUBECONFIG2} -n bar logs $(kubectl --kubeconfig=${KUBECONFIG2} -n bar get pods -o jsonpath='{.items[0].metadata.name}') -c istio-proxy

export CLUSTER1_SVC_CLUSTERIP=$(kubectl get --kubeconfig=${KUBECONFIG1} svc --selector=app=istio-ingressgateway \
    -n istio-system -o jsonpath='{.items[0].spec.clusterIP}')
export CLUSTER1_SVC_PORT=$(kubectl get --kubeconfig=${KUBECONFIG1} svc --selector=app=istio-ingressgateway \
    -n istio-system -o jsonpath='{.items[0].spec.ports[?(@.name=="tls")].port}')

# Updating the httpbin.bar.global DNS record on cluster1 to use the NodePort locally
kubectl apply --kubeconfig=${KUBECONFIG1} -n foo -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: httpbin-bar
spec:
  hosts:
  # must be of form name.namespace.global
  - httpbin.bar.global
  # Treat remote cluster services as part of the service mesh
  # as all clusters in the service mesh share the same root of trust.
  location: MESH_INTERNAL
  ports:
  - name: http1
    number: 8000
    protocol: http
  resolution: DNS
  addresses:
  # the IP address to which httpbin.bar.global will resolve to
  # must be unique for each remote service, within a given cluster.
  # This address need not be routable. Traffic for this IP will be captured
  # by the sidecar and routed appropriately.
  - 127.255.0.2
  endpoints:
  # This is the routable address of the ingress gateway in cluster2 that
  # sits in front of sleep.foo service. Traffic from the sidecar will be
  # routed to this address.
  - address: ${CLUSTER1_SVC_CLUSTERIP}
    ports:
      http1: ${CLUSTER1_SVC_PORT}
  - address: ${CLUSTER2_GW_HOSTNAME}
    ports:
      http1: 15443 # Do not change this port value
EOF

# Connect several times to httpbin from sleep running on cluster1 and look at the logs of httpbin on both clusters to check that the requests are distributes accross both clusters
export SLEEP_POD=$(kubectl get --kubeconfig=${KUBECONFIG1} -n foo pod -l app=sleep -o jsonpath={.items..metadata.name})
kubectl exec --kubeconfig=${KUBECONFIG1} $SLEEP_POD -n foo -c sleep -- curl -I httpbin.bar.global:8000/headers
kubectl exec --kubeconfig=${KUBECONFIG1} $SLEEP_POD -n foo -c sleep -- curl -I httpbin.bar.global:8000/headers
kubectl exec --kubeconfig=${KUBECONFIG1} $SLEEP_POD -n foo -c sleep -- curl -I httpbin.bar.global:8000/headers
kubectl exec --kubeconfig=${KUBECONFIG1} $SLEEP_POD -n foo -c sleep -- curl -I httpbin.bar.global:8000/headers
kubectl --kubeconfig=${KUBECONFIG1} -n bar logs $(kubectl --kubeconfig=${KUBECONFIG1} -n bar get pods -o jsonpath='{.items[0].metadata.name}') -c istio-proxy
kubectl --kubeconfig=${KUBECONFIG2} -n bar logs $(kubectl --kubeconfig=${KUBECONFIG2} -n bar get pods -o jsonpath='{.items[0].metadata.name}') -c istio-proxy
