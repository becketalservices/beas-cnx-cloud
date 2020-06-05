#!/bin/bash
if [ "$1" ]; then
  number=$1
else
  number=1
fi

namespace=connections
echo Scale to $number
echo
for x in $(kubectl get deployment --no-headers -o custom-columns=":metadata.name" -n $namespace); do
  scale=$number
  if [ $number -gt 0 ]; then
    if [ "$x" == "mail-service" -o "$x" == "sanity-watcher" ]; then
      scale=1
    fi
    if [ "${x:0:2}" == "es" ]; then
      scale=3
    fi
  fi
  #echo -- scale $x to $scale
  kubectl -n $namespace scale deployment $x --replicas=$scale
done
