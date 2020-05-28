#!/bin/bash

. ~/installsettings.sh

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: gloabal-ingress
  namespace: connections
  annotations:
    kubernetes.io/ingress.class: global-nginx
    cert-manager.io/cluster-issuer: letsencrypt
    nginx.ingress.kubernetes.io/backend-protocol: HTTPS
    nginx.ingress.kubernetes.io/secure-backends: "true"
spec:
  rules:
  - host: $ic_front_door
    http:
      paths:
      - backend:
          serviceName: cnx-backend 
          servicePort: 443
        path: /
  tls:
  - hosts:
    - $ic_front_door 
    secretName: tls-secret
EOF

