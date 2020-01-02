#!/bin/bash

. ~/installsettings.sh

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: push-global-ingress
  namespace: connections
  annotations:
    kubernetes.io/ingress.class: global-nginx
    certmanager.k8s.io/cluster-issuer: letsencrypt
    nginx.ingress.kubernetes.io/secure-backends: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
spec:
  tls:
  - hosts:
    - $ic_front_door 
    secretName: tls-secret
  rules:
  - host: $ic_front_door
    http:
      paths:
      - path: /push
        backend:
          serviceName: cnx-backend 
          servicePort: 443
EOF

