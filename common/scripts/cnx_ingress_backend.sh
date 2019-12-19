#!/bin/bash

. ~/installsettings.sh

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: cnx-ingress
  namespace: connections
  annotations:
    kubernetes.io/ingress.class: nginx
    #certmanager.k8s.io/cluster-issuer: letsencrypt
    nginx.ingress.kubernetes.io/secure-backends: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  rules:
  - host: *.$GlobalDomainName
    http:
      paths:
      - path: /
        backend:
          serviceName: cnx-backend 
          servicePort: 443
EOF

