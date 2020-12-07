#!/bin/bash

SCRIPT_DIR=$(dirname $(readlink -f $0))
if [ -e "${SCRIPT_DIR}/settings.sh" ]; then
  . "${SCRIPT_DIR}/settings.sh"
fi

if [ "$ESKEY" -a "$ESCRT" ]; then
  CERT="-E ${ESCRT} --key ${ESKEY}"
fi

curl $CURLOPTS -k $CERT "${ESURL}/$1"

