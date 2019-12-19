#!/bin/bash

. ~/installsettings.sh

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: cnx-ingress-filebrowser
  namespace: connections
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: "*.$GlobalDomainName"
    http:
      paths:
      - path: /filebrowser
        backend:
          serviceName: filebrowser 
          servicePort: "80" 
EOF

