#!/bin/bash
#

ISTIO_VERSION="0.2.7"
ISTIO_ADDONS="${ISTIO_ADDONS:-}"
ISTIO_BOOKINFO="${ISTIO_BOOKINFO:-}"
export KUBE_DIND_VM="${KUBE_DIND_VM:-k8s-dind}"
export ISTIO_INGRESS_PORT=32000
# TODO: Remove when dind supports 1.8.
export BUILD_KUBEADM=y
export BUILD_HYPERKUBE=y

if [ $(uname) = Darwin ]; then
  readlinkf(){ perl -MCwd -e 'print Cwd::abs_path shift' "$1";}
else
  readlinkf(){ readlink -f "$1"; }
fi

OS="$(uname)"
if [ "x${OS}" = "xDarwin" ] ; then
  OSEXT="osx"
else
  OSEXT="linux"
fi

INSTALL_DIR="$(cd $(dirname "$(readlinkf "${BASH_SOURCE}")"); pwd)"

set -x

# Download the dind scripts
GCE_URL="https://raw.githubusercontent.com/danehans/kubeadm-dind-cluster/istio/gce-setup.sh"
DIND_URL="https://raw.githubusercontent.com/danehans/kubeadm-dind-cluster/istio/dind-cluster.sh"
DIND_CONFIG_URL="https://raw.githubusercontent.com/danehans/kubeadm-dind-cluster/istio/config.sh"
rm -rf "${INSTALL_DIR}/dind"
mkdir -p "${INSTALL_DIR}/dind"
echo "Downloading dind scripts..."
curl -SLo "${INSTALL_DIR}/dind/gce-setup.sh" "${GCE_URL}"
curl -SLo "${INSTALL_DIR}/dind/dind-cluster.sh" "${DIND_URL}"
curl -SLo "${INSTALL_DIR}/dind/config.sh" "${DIND_CONFIG_URL}"
chmod +x "${INSTALL_DIR}/dind/gce-setup.sh"
chmod +x "${INSTALL_DIR}/dind/dind-cluster.sh"
chmod +x "${INSTALL_DIR}/dind/config.sh"

# Clone the k8s repo and run the dind gce script.
echo "Downloading Kubernetes..."
rm -rf "${INSTALL_DIR}/kubernetes"
git clone "https://github.com/kubernetes/kubernetes.git" "${INSTALL_DIR}/kubernetes"
cd "${INSTALL_DIR}/kubernetes"
time "${INSTALL_DIR}"/dind/gce-setup.sh

# Forward the Istio Ingress port.
docker-machine ssh ${KUBE_DIND_VM} \
               -L ${ISTIO_INGRESS_PORT}:localhost:${ISTIO_INGRESS_PORT} \
               -N&

# Install Istio client binary
ISTIO_URL="https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-${OSEXT}.tar.gz"
echo "Downloading ${ISTIO_VERSION} from ${ISTIO_URL}..."
curl -SLo "${INSTALL_DIR}/istio-${ISTIO_VERSION}-${OSEXT}.tar.gz" "${ISTIO_URL}"
echo "Downloaded into ${INSTALL_DIR}/istio-${ISTIO_VERSION}"
echo "Extracting Istio client binary"
tar -xvf "${INSTALL_DIR}/istio-${ISTIO_VERSION}-${OSEXT}.tar.gz" -C "${INSTALL_DIR}"
export PATH="${INSTALL_DIR}/istio-${ISTIO_VERSION}/bin:$PATH"

# Deploy Istio
echo "Deploying Istio..."
ISTIO_AUTH_URL="https://raw.githubusercontent.com/danehans/istio/test_nodeport/install/kubernetes/istio-auth.yaml"
# Update the manifests to use NodePorts for Istio Ingress.
mv "${INSTALL_DIR}/istio-${ISTIO_VERSION}/install/kubernetes/istio-auth.yaml" "${INSTALL_DIR}/istio-${ISTIO_VERSION}/install/kubernetes/istio-auth.yaml.bak"
# Deploy the istio contol plane and proxy initializer.
kubectl apply -f "${ISTIO_AUTH_URL}"
kubectl apply -f "${INSTALL_DIR}/istio-${ISTIO_VERSION}/install/kubernetes/istio-initializer.yaml"
echo "Istio deployment complete!"

if [[ ${ISTIO_ADDONS} ]]; then
  echo "Deploying Istio Addons..."
  PROMETHEUS_URL="https://raw.githubusercontent.com/istio/istio/master/install/kubernetes/addons/prometheus.yaml"
  METRICS_URL="https://goo.gl/kTX9ut"
  ZIPKIN_URL="https://raw.githubusercontent.com/istio/istio/master/install/kubernetes/addons/zipkin.yaml"
  GRAFANA_URL="https://raw.githubusercontent.com/istio/istio/master/install/kubernetes/addons/grafana.yaml"
  #Prometheus Addon
  kubectl apply -f "${PROMETHEUS_URL}"
  # Apply the manifest containing the metric and log stream configuration.
  kubectl apply -f "${METRICS_URL}"
  # wait for the prometheus pods to enter a running state, then port-forward.
  sleep 20
  prometheus_pod=$(kubectl -n istio-system get pod -l app=prometheus -o jsonpath='{.items[0].metadata.name}')
  kubectl -n istio-system port-forward ${prometheus_pod} 9090:9090 &
  # Zipkin Addon
  kubectl apply -f "${ZIPKIN_URL}"
  sleep 15
  zipkin_pod=$(kubectl get pod -n istio-system -l app=zipkin -o jsonpath='{.items[0].metadata.name}')
  kubectl port-forward -n istio-system ${zipkin_pod} 9411:9411 &
  # Grafana Addon
  kubectl apply -f "${GRAFANA_URL}"
  sleep 15
  grafana_pod=$(kubectl -n istio-system get pod -l app=grafana -o jsonpath='{.items[0].metadata.name}')
  kubectl -n istio-system port-forward ${grafana_pod} 3000:3000 &
  echo "Addons deployment complete!"
fi

if [[ ${ISTIO_BOOKINFO} ]]; then
  echo "Deploying Istio Bookino Application..."
  BOOKINFO_URL="https://raw.githubusercontent.com/danehans/istio/test_nodeport/samples/bookinfo/kube/bookinfo.yaml"
  mv "${INSTALL_DIR}/istio-${ISTIO_VERSION}/samples/bookinfo/kube/bookinfo.yaml" "${INSTALL_DIR}/istio-${ISTIO_VERSION}/samples/bookinfo/kube/bookinfo.yaml.bak"
  kubectl apply -f "${BOOKINFO_URL}"
  echo "Bookinfo Deployment complete!"
  echo "Test: curl http://localhost:32000/productpage"
fi

set +x
