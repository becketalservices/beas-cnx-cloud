#!/bin/bash

. ~/installsettings.sh

SCRIPT_DIR=$(dirname $(readlink -f $0))
if [ -e "${SCRIPT_DIR}/settings.sh" ]; then
  rm -f "${SCRIPT_DIR}/settings.sh"
fi

touch "${SCRIPT_DIR}/settings.sh"

if [ "$useStandaloneES" != "1" ]; then
  #get es key from secrets
  kubectl get secret elasticsearch-secret -n connections -o "jsonpath={.data.elasticsearch-metrics\.p12}" | base64 -d > elasticsearch-metrics.p12
  kubectl get secret elasticsearch-secret -n connections -o=jsonpath="{.data['chain-ca\.pem']}" | base64 -d > chain-ca.pem

  # get key password from secrets
  export password=$(kubectl get secret elasticsearch-secret -n connections  -o "jsonpath={.data.elasticsearch-key-password\.txt}" |base64 -d)

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

else
  echo "ESURL=https://${standaloneESHost}:${standaloneESPort}" >> "${SCRIPT_DIR}/settings.sh"

  echo
  echo wsadmin command type ahead:
  echo "SearchService.setESQuickResultsBaseUrl(\"https://${standaloneESHost}:${standaloneESPort}\")"
fi

