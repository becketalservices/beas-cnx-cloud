#!/bin/bash
scale=0
if [ "$1" ]; then
  if [ $1 -gt 0 ]; then
    scale=3
  fi
fi

namespace=connections
echo Scale to $scale
echo
for x in solr zookeeper; do
  kubectl -n $namespace scale statefulset $x --replicas=$scale
done
