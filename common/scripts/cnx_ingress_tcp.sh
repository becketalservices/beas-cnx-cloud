#!/bin/bash

. ~/installsettings.sh

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: cnx-ingress-tcp 
  namespace: $namespace 
data:
  "30099": $namespace/elasticsearch:9200
  "30379": $namespace/haproxy-redis:6379
EOF

