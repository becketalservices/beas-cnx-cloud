#!/bin/bash

. ~/installsettings.sh

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: cnx-ingress-tcp 
  namespace: connections
data:
  "30099": connections/elasticsearch:9200
  "30379": connections/haproxy-redis:6379
EOF

