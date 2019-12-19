#!/bin/bash

. ~/installsettings.sh

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: customizer-ingress
  namespace: connections
  annotations:
    kubernetes.io/ingress.class: global-nginx 
    nginx.ingress.kubernetes.io/use-regex: "true"
spec:
  tls:
  - hosts:
    - $ic_front_door 
    secretName: tls-secret
  rules:
  - host: $ic_front_door
    http:
      paths:
      - path: /files/app|/files/customizer|/communities/service/html|/forums/html|/search/web
        backend:
          serviceName: mw-proxy 
          servicePort: 80
      - path: /homepage/web|/social|/mycontacts|/wikis/home|/dogear/html|/metrics|/moderation/app
        backend:
          serviceName: mw-proxy 
          servicePort: 80
      - path: /blogs|/news|/activities/service/html|/profiles/html|/viewer
        backend:
          serviceName: mw-proxy 
          servicePort: 80
EOF

