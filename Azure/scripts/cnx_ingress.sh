#!/bin/bash

. ~/settings.sh

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: cnx-ingress
  namespace: connections
  annotations:
    kubernetes.io/ingress.class: nginx
    certmanager.k8s.io/cluster-issuer: letsencrypt
    nginx.ingress.kubernetes.io/secure-backends: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  tls:
  - hosts:
    - $ic_front_door 
    secretName: tls-secret
  rules:
  - host: $ic_front_door
    http:
      paths:
      - path: /
        backend:
          serviceName: cnx-backend 
          servicePort: 443
EOF

