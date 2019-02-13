#!/bin/bash

for index in 0 1 2; do
  echo "Fix PVC $index"
  echo "#1 remove existing pv es-pvc-es-data-$index and es-pvc-es-data-${index}-new"
  kubectl -n connections delete pvc es-pvc-es-data-$index es-pvc-es-data-${index}-new

  echo
  echo "#2 change new pv from released to available"
  pvnew=`kubectl -n connections get pv |grep es-pvc-es-data-${index}-new | cut -f1 -d' '`
  echo "PV ID: $pvnew" 
  kubectl -n connections patch pv $pvnew --type='json' -p='[{"op": "remove", "path": "/spec/claimRef"}]'

  echo
  echo "#3 Add new pv to pvc with old name"
  cat <<EOF | kubectl -n connections create -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: es-pvc-es-data-$index
  namespace: connections
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: gp2
  volumeName: $pvnew 
EOF

done

