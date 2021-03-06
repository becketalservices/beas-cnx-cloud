#!/bin/bash
. ~/installsettings.sh

cat <<EOF | kubectl apply -n $namespace -f -
apiVersion: v1
kind: Service
metadata:
  labels:
    app: cnx-ingress 
    component: controller
    release: cnx-ingress 
  name: connections-nginx-ingress-controller-intern
  namespace: $NAMESPACE
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-internal: 0.0.0.0/0
spec:
  externalTrafficPolicy: Cluster
  ports:
  - name: http
    port: 80
    protocol: TCP
    targetPort: http
  - name: redis 
    port: 30379
    protocol: TCP
    targetPort: 30379
  - name: es
    port: 30099
    protocol: TCP
    targetPort: 30099
  selector:
    app: cnx-ingress
    component: controller
    release: cnx-ingress 
  sessionAffinity: None
  type: LoadBalancer
EOF

