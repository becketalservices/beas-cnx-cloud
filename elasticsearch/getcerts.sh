#!/bin/bash

. ~/installsettings.sh

SCRIPT_DIR=$(dirname $(readlink -f $0))
if [ -e "${SCRIPT_DIR}/settings.sh" ]; then
  rm -f "${SCRIPT_DIR}/settings.sh"
fi

touch "${SCRIPT_DIR}/settings.sh"

if [ -z "$CNXNS" ]; then
  CNXNS=connections
fi

if [ "$useStandaloneES" != "1" ]; then
  command -p openssl version > /dev/null 2>&1
  if [ $? -gt 0 ]; then
    echo "ERROR ERROR ERROR"
    echo "openssl command found. Can not convert certificates."
    exit 1
  fi
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
  #get es key from secrets
  $kubecmd get secret elasticsearch-secret -n $CNXNS -o "jsonpath={.data.elasticsearch-metrics\.p12}" | base64 -d > elasticsearch-metrics.p12
  $kubecmd get secret elasticsearch-secret -n $CNXNS -o=jsonpath="{.data['chain-ca\.pem']}" | base64 -d > chain-ca.pem

  # get key password from secrets
  export password=$($kubecmd get secret elasticsearch-secret -n $CNXNS  -o "jsonpath={.data.elasticsearch-key-password\.txt}" |base64 -d)

  openssl pkcs12 -passin env:password -in elasticsearch-metrics.p12 -out elasticsearch-metrics.key.pem -nocerts -nodes
  openssl pkcs12 -passin env:password -in elasticsearch-metrics.p12 -out elasticsearch-metrics.crt.pem -clcerts -nokeys

  echo
  echo wsadmin command elastic search:
  echo "enableSslForMetrics('/opt/IBM/data/shared/elasticsearch/elasticsearch-metrics.p12', '$password', '/opt/IBM/data/shared/elasticsearch/chain-ca.pem', '30099')"
  echo
  echo wsadmin command type ahead:
  echo "SearchService.setESQuickResultsBaseUrl(\"https://${master_ip}:30099\")"

  export password=

  echo "ESURL=https://${master_ip}:30099" >> "${SCRIPT_DIR}/settings.sh"
  echo "ESKEY='${SCRIPT_DIR}/elasticsearch-metrics.key.pem'" >> "${SCRIPT_DIR}/settings.sh"
  echo "ESCRT='${SCRIPT_DIR}/elasticsearch-metrics.crt.pem'" >> "${SCRIPT_DIR}/settings.sh"
  echo "CURLOPTS='--ipv4'" >> "${SCRIPT_DIR}/settings.sh"

else
  echo "ESURL=https://${standaloneESHost}:${standaloneESPort}" >> "${SCRIPT_DIR}/settings.sh"
  echo "CURLOPTS='--ipv4'" >> "${SCRIPT_DIR}/settings.sh"

  echo
  echo wsadmin command type ahead:
  echo "SearchService.setESQuickResultsBaseUrl(\"https://${standaloneESHost}:${standaloneESPort}\")"
fi

echo
echo List All Indexes
echo "${SCRIPT_DIR}/esget.sh \"_cat/indices?v\""

