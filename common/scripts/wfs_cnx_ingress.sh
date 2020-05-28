#!/bin/bash

. ~/installsettings.sh

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: cnx-ingress-wfs
  namespace: connections
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: '*.$GlobalDomainName'
    http:
      paths:
      - backend:
          serviceName: webfilesys 
          servicePort: 8080
        path: /webfilesys
EOF

