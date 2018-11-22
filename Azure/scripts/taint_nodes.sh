#!/bin/bash
#version=201811220745

fix=$1
if [ "$fix" != "1" -a "$fix" != "2" ]; then
  fix="0"
fi
echo
if [ "$fix" == "0" ]; then
  echo "Tool will report the current status"
  echo "  Run $0 1 to fix your taints and lables"
  echo "  Run $0 2 to drain your nodes before correcting values"
fi
if [ "$fix" == "1" ]; then
  echo "Tool will correct label and taint."
  echo "  No node drain will happen."
fi

if [ "$fix" == "2" ]; then
  echo "Tool will correct label and taint."
  echo "  Node drain will happen which migth cause some outages."
fi
echo
nodes=$(kubectl get nodes -o "name")
for node in $nodes; do
  # echo "check node $node"
  order=${node##*-}
  values=$(kubectl get ${node} -o jsonpath='label:{.metadata.labels.type} taint:{.spec.taints[?(@.key=="dedicated")].value}')
  #echo "info: $values"
  label=""
  taint=""
  for value in $values; do
    if [ "${value%:*}" == "label" ]; then
      label=${value#*:}
    fi
    if [ "${value%:*}" == "taint" ]; then
      taint=${value#*:}
    fi
  done
  #echo "Label: $label"
  #echo "Taint: $taint"
  if (( $order % 2 )); then
    # odd
    echo "Infrastructure node $node"
    if [ "$fix" == "2" ] && [ "$label" != "infrastructure" -o "$taint" != "infrastructure" ]; then
      echo "  Drain node $node"
      kubectl drain $node --force --delete-local-data --ignore-daemonsets
    fi 
    if [ "$label" != "infrastructure" ]; then
      if [ "$fix" == "1" -o "$fix" == "2" ]; then
        echo "  Set correct label."
        kubectl label $node type=infrastructure --overwrite 
      else
        echo "  Node does not have correct label."
      fi
    fi
    if [ "$taint" != "infrastructure" ]; then
      if [ "$fix" == "1" -o "$fix" == "2" ]; then
        echo "  Set correct taint."
        kubectl taint nodes $node dedicated=infrastructure:NoSchedule --overwrite
      else
        echo "  Node does not have correct taint."
      fi
    fi
    if [ "$fix" == "2" ] && [ "$label" != "infrastructure" -o "$taint" != "infrastructure" ]; then
      echo "  Uncordon node $node"
      kubectl uncordon $node
    fi 
  else
    # even
    echo "Worker node $node"
    if [ "$fix" == "2" ] && [ "$label" == "infrastructure" -o "$taint" == "infrastructure" ]; then
      echo "  Drain node $node"
      kubectl drain $node --force --delete-local-data --ignore-daemonsets
    fi 
    if [ "$label" == "infrastructure" ]; then
      if [ "$fix" == "1" -o "$fix" == "2" ]; then
        echo "  Remove incorrect label."
         kubectl label $node type-
      else
        echo "  Node does not have correct label."
      fi
    fi
    if [ "$taint" == "infrastructure" ]; then
      if [ "$fix" == "1" -o "$fix" == "2" ]; then
        echo "  Remove incorrect taint."
        kubectl taint nodes $node dedicated-
      else
        echo "  Node does not have correct taint."
      fi
    fi
    if [ "$fix" == "2" ] && [ "$label" == "infrastructure" -o "$taint" == "infrastructure" ]; then
      echo "  Uncordon node $node"
      kubectl uncordon $node
    fi 
  fi
  echo
done
