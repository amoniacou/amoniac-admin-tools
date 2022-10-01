#!/bin/bash

if [ $# -lt 1 ]; then
  echo "Usage: k8s-createadmin.sh <admin_name>"
  echo "       Creates a cluster administrator with auth by certificate"
  exit 1
fi

USERNAME=${1}
CONTEXT=`kubectl config current-context`
NEW_CONTEXT="${USERNAME}-${CONTEXT}"
KEYPATH="${NEW_CONTEXT}.key"
CSRPATH="${NEW_CONTEXT}.csr"
CRTPATH="${NEW_CONTEXT}.crt"

echo + Creating private key: ${USERNAME}.key
openssl genrsa -out $KEYPATH 4096

echo + Creating signing request: ${USERNAME}.csr
openssl req -new -key ${KEYPATH} -out ${CSRPATH} -subj "/CN=${USERNAME}/O=${ORG_NAME:-amoniac}:${ORG_TEAM:-deployment}"

echo + Sending signing request: ${USERNAME}.csr
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${USERNAME}-authentication
spec:
  groups:
    - system:authenticated
  request: $(cat ${CSRPATH} | base64 | tr -d '\n' | tr -d '\r')
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - digital signature
  - key encipherment
  - client auth
EOF

echo + Create cluster admin role
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ${ORG_NAME_NAME:-amoniac}-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: ${ORG_NAME:-amoniac}:${ORG_TEAM:-deployment}
EOF

echo + Approve request: ${USERNAME}-authentication
kubectl certificate approve "${USERNAME}-authentication"
kubectl get csr ${USERNAME}-authentication -o jsonpath='{.status.certificate}' | base64 -d > $CRTPATH
KUBECONFIG_FILE="${NEW_CONTEXT}-kubeconfig.yaml"

# get current config
kubectl config view --flatten --minify > "${KUBECONFIG_FILE}.tmp"
kubectl config --kubeconfig "${KUBECONFIG_FILE}.tmp" rename-context "${CONTEXT}" "${NEW_CONTEXT}"
kubectl config --kubeconfig "${KUBECONFIG_FILE}.tmp" set-credentials "${USERNAME}" --embed-certs --client-key ${KEYPATH}
kubectl config --kubeconfig "${KUBECONFIG_FILE}.tmp" set-credentials "${USERNAME}" --embed-certs --client-certificate ${CRTPATH} 
kubectl config --kubeconfig "${KUBECONFIG_FILE}.tmp" set-context "${NEW_CONTEXT}" --user "${USERNAME}"
kubectl config --kubeconfig "${KUBECONFIG_FILE}.tmp" view --flatten --minify > "${KUBECONFIG_FILE}"
rm "${KUBECONFIG_FILE}.tmp"
