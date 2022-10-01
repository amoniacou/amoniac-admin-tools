#!/bin/bash

if [ $# -lt 1 ]; then
  echo "Usage: k8s-sa-create.sh <service_account_name> [namespace]"
  echo "       If [namespace] is null then cluster-admin will be created."
  exit 1
fi

SERVICE_ACCOUNT_NAME="$1"
NAMESPACE="$2"
if [ -z "${NAMESPACE}" ]; then
  NAMESPACE="default"
  echo "Creating admin ServiceAccount..."
  kubectl create sa "${SERVICE_ACCOUNT_NAME}"

  echo "Creating ClusterRoleBinding:"
  cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ${SERVICE_ACCOUNT_NAME}-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: ${SERVICE_ACCOUNT_NAME}
  namespace: ${NAMESPACE}
EOF
else
  echo "Creating basic ServiceAccount..."
  kubectl create sa "${SERVICE_ACCOUNT_NAME}" --namespace "${NAMESPACE}"

  echo "Creating Role and RoleBinding..."
  cat <<EOF | kubectl apply -f -
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ${SERVICE_ACCOUNT_NAME}-role
  namespace: ${NAMESPACE}
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${SERVICE_ACCOUNT_NAME}-rolebinding
  namespace: ${NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ${SERVICE_ACCOUNT_NAME}-role
subjects:
- namespace: ${NAMESPACE}
  kind: ServiceAccount
  name: ${SERVICE_ACCOUNT_NAME}
EOF
fi

echo "Generating KUBECONFIG_FILE '${SERVICE_ACCOUNT_NAME}_${NAMESPACE}.yaml':"
CONTEXT=`kubectl config current-context`
NEW_CONTEXT="${SERVICE_ACCOUNT_NAME}"
KUBECONFIG_FILE="${SERVICE_ACCOUNT_NAME}_${NAMESPACE}.yaml"
SECRET_NAME=$(kubectl get serviceaccount "${SERVICE_ACCOUNT_NAME}" \
  --context "${CONTEXT}" \
  --namespace "${NAMESPACE}" \
  -o jsonpath='{.secrets[0].name}')
TOKEN_DATA=$(kubectl get secret "${SECRET_NAME}" \
  --context "${CONTEXT}" \
  --namespace "${NAMESPACE}" \
  -o jsonpath='{.data.token}')
TOKEN=$(echo "${TOKEN_DATA}" | base64 -d)
kubectl config view --raw > "${KUBECONFIG_FILE}.full.tmp"
kubectl --kubeconfig "${KUBECONFIG_FILE}.full.tmp" config use-context "${CONTEXT}"
kubectl --kubeconfig "${KUBECONFIG_FILE}.full.tmp" \
  config view --flatten --minify > "${KUBECONFIG_FILE}.tmp"
kubectl config --kubeconfig "${KUBECONFIG_FILE}.tmp" \
  rename-context "${CONTEXT}" "${NEW_CONTEXT}"
kubectl config --kubeconfig "${KUBECONFIG_FILE}.tmp" \
  set-credentials "${CONTEXT}-${NAMESPACE}-token-user" \
  --token "${TOKEN}"
kubectl config --kubeconfig "${KUBECONFIG_FILE}.tmp" \
  set-context "${NEW_CONTEXT}" --user "${CONTEXT}-${NAMESPACE}-token-user"
kubectl config --kubeconfig "${KUBECONFIG_FILE}.tmp" \
  set-context "${NEW_CONTEXT}" --namespace "${NAMESPACE}"
kubectl config --kubeconfig "${KUBECONFIG_FILE}.tmp" \
  view --flatten --minify > "${KUBECONFIG_FILE}"
rm "${KUBECONFIG_FILE}.full.tmp"
rm "${KUBECONFIG_FILE}.tmp"
