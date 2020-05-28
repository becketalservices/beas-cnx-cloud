#!/bin/bash

. ~/installsettings.sh

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: fb-gloabal-ingress
  namespace: connections
  annotations:
    kubernetes.io/ingress.class: global-nginx
    cert-manager.io/cluster-issuer: letsencrypt
spec:
  tls:
  - hosts:
    - $ic_front_door 
    secretName: tls-secret
  rules:
  - host: $ic_front_door
    http:
      paths:
      - path: /filebrowser
        backend:
          serviceName: filebrowser 
          servicePort: 80
EOF

