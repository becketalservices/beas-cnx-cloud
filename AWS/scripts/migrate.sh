#!/bin/bash

for index in 0 1 2; do
  echo "Migrate $index"
cat <<EOF | kubectl -n connections create -f -
apiVersion: v1
kind: Pod
metadata:
  name: datamigrate$index
  namespace: connections
spec:
  containers:
    - name: centos
      image: centos
      volumeMounts:
      - name: source
        mountPath: /mnt/source
      - name: dest
        mountPath: /mnt/dest
      # install rsync and run migration 
      command: [ "/bin/bash", "-c", "--" ]
      args: [ "yum -y install rsync; rsync --progress --stats --archive /mnt/source/ /mnt/dest/;" ]
  volumes:
  - name: source
    persistentVolumeClaim:
      claimName: es-pvc-es-data-$index
  - name: dest
    persistentVolumeClaim:
      claimName: es-pvc-es-data-$index-new
  restartPolicy: Never
EOF

done

