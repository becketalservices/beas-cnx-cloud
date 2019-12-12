#!/bin/bash

ids=`kubectl -n connections get pv | grep "^pvc" |cut -f1 -d' '`
for id in $ids; do
  echo "Fix $id"
  kubectl -n connections patch pv $id -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
done

