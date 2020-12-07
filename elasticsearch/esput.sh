#!/bin/bash

SCRIPT_DIR=$(dirname $(readlink -f $0))
if [ -e "${SCRIPT_DIR}/settings.sh" ]; then
  . "${SCRIPT_DIR}/settings.sh"
fi

if [ "$ESKEY" -a "$ESCRT" ]; then
  CERT="-E ${ESCRT} --key ${ESKEY}"
fi

if [ ! -f "$2" ]; then
  echo "ERROR: Input File $2 does not exist."
  exit 1
fi

curl -X "PUT" CURLOPTS -k $CERT -H "Content-Type: application/json" -d @$2 "${ESURL}/$1"

