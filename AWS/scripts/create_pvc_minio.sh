#!/bin/bash
. ~/installsettings.sh

cat <<EOF | kubectl apply -n $namespace -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: kudos-boards-minio-claim 
  namespace: $namespace 
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: $storageclass 
EOF

