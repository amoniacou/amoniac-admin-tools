#!/bin/bash

if [ $# -lt 1 ]; then
  echo "Usage:k8s-google-user-create.sh email"
  exit 1
fi

EMAIL="$1"
SERVICE_ACCOUNT_NAME=$(echo ${1} | awk -F@ '{print $1}' | sed -e 's|\.||')
NAMESPACE="amoniac-${SERVICE_ACCOUNT_NAME}"
kubectl create namespace ${NAMESPACE} || true

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
- kind: User
  name: ${EMAIL}
EOF
