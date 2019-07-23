export KUBECONFIG1=/Users/djannot/Documents/demos/kscli/konvoy_v0.4.0/admin.conf
export KUBECONFIG2=/Users/djannot/Documents/demos/kscli/konvoy_v0.4.0-2/admin.conf

cd $(dirname $0)

export PATH=$PWD/bin:$PATH
kubectl --kubeconfig=${KUBECONFIG1} create namespace istio-system
kubectl --kubeconfig=${KUBECONFIG1} create secret generic cacerts -n istio-system \
    --from-file=samples/certs/ca-cert.pem \
    --from-file=samples/certs/ca-key.pem \
    --from-file=samples/certs/root-cert.pem \
    --from-file=samples/certs/cert-chain.pem
helm template install/kubernetes/helm/istio-init --name istio-init --namespace istio-system | kubectl --kubeconfig=${KUBECONFIG1} apply -f -
until kubectl --kubeconfig=${KUBECONFIG1} get crds | grep 'istio.io\|certmanager.k8s.io' | wc -l | grep 23
do
  sleep 1
done
helm template install/kubernetes/helm/istio --name istio --namespace istio-system \
    -f install/kubernetes/helm/istio/example-values/values-istio-multicluster-gateways.yaml > template-multicluster1.yaml
kubectl --kubeconfig=${KUBECONFIG1} apply -f template-multicluster1.yaml
kubectl --kubeconfig=${KUBECONFIG1} -n istio-system get pods

kubectl --kubeconfig=${KUBECONFIG2} create namespace istio-system
kubectl --kubeconfig=${KUBECONFIG2} create secret generic cacerts -n istio-system \
    --from-file=samples/certs/ca-cert.pem \
    --from-file=samples/certs/ca-key.pem \
    --from-file=samples/certs/root-cert.pem \
    --from-file=samples/certs/cert-chain.pem
helm template install/kubernetes/helm/istio-init --name istio-init --namespace istio-system | kubectl --kubeconfig=${KUBECONFIG2} apply -f -
until kubectl --kubeconfig=${KUBECONFIG2} get crds | grep 'istio.io\|certmanager.k8s.io' | wc -l | grep 23
do
  sleep 1
done
helm template install/kubernetes/helm/istio --name istio --namespace istio-system \
    -f install/kubernetes/helm/istio/example-values/values-istio-multicluster-gateways.yaml > template-multicluster2.yaml
kubectl --kubeconfig=${KUBECONFIG2} apply -f template-multicluster2.yaml
kubectl --kubeconfig=${KUBECONFIG2} -n istio-system get pods

kubectl --kubeconfig=${KUBECONFIG1} apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           upstream
           fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        proxy . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
    global:53 {
        errors
        cache 30
        proxy . $(kubectl --kubeconfig=${KUBECONFIG1} get svc -n istio-system istiocoredns -o jsonpath={.spec.clusterIP})
    }
EOF

kubectl --kubeconfig=${KUBECONFIG2} apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           upstream
           fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        proxy . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
    global:53 {
        errors
        cache 30
        proxy . $(kubectl --kubeconfig=${KUBECONFIG2} get svc -n istio-system istiocoredns -o jsonpath={.spec.clusterIP})
    }
EOF
