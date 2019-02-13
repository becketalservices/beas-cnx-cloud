#!/bin/bash
#Create new PVC on default storage class

storageClass=gp2
storageSize=10Gi

for index in 0 1 2; do
  echo "Create $index"
  cat <<EOF | kubectl -n connections create -f - 
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: es-pvc-es-data-${index}-new
  namespace: connections
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: $storageSize
  storageClassName: $storageClass
EOF

done
