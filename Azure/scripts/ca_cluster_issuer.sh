#!/bin/bash

. ~/installsettings.sh
if [ -z "$acme_email" ]; then
  echo "No Registration E-Mail configured. Update your installsettings.sh acme_email="
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
apiVersion: cert-manager.io/v1alpha2
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
    solvers:
    - http01:
        ingress:
          class: global-nginx 
EOF

