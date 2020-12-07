#!/bin/bash
. ~/installsettings.sh

command -p kubectl version > /dev/null 2>&1
if [ $? -eq 0 ]; then
  kubecmd=kubectl
else
  command -p minikube version > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    kubecmd="minikube kubectl --"
  else
    echo "ERROR ERROR ERROR"
    echo "No suitable kubectl command found. Can not extract certificates."
    exit 1
  fi
fi

ids=`$kubecmd -n $CNXNS get pv | grep "^pvc" |cut -f1 -d' '`
for id in $ids; do
  echo "Fix $id"
  $kubecmd -n $CNXNS patch pv $id -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
done

