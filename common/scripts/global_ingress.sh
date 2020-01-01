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
    certmanager.k8s.io/cluster-issuer: letsencrypt
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
          serviceName: cnx-ingress-controller 
          servicePort: 80
EOF

