#!/bin/bash

. ~/settings.sh
if [ -z "$acme_email" ]; then
  echo "No Registration E-Mail configured. Update your settings.sh acme_email="
  exti 1
fi

if [ "$use_lestencrypt_prod" == "true" ]; then
  echo "Using Let's Encrypt Productive"
  ds_server=https://acme-v02.api.letsencrypt.org/directory
  service_ref=letsencrypt-prod
else
  echo "Using Let's Encrypt Staging"
  ds_server=https://acme-staging-v02.api.letsencrypt.org/directory
  service_ref=letsencrypt-staging
fi

cat <<EOF | kubectl apply -f -
apiVersion: certmanager.k8s.io/v1alpha1
kind: ClusterIssuer
metadata:
  name: letsencrypt
  namespace: cert-manager 
spec:
  acme:
    server: $ds_server 
    email: $acme_email
    privateKeySecretRef:
      name: $service_ref
    http01: {}
EOF

