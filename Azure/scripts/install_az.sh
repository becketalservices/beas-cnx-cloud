#!/bin/bash
set -x
if [ $UID -ne 0 ]; then
  echo "ERROR: You must be root to run this script."
  exit 1
fi

rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[azure-cli]\nname=Azure CLI\nbaseurl=https://packages.microsoft.com/yumrepos/azure-cli\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/azure-cli.repo
yum -y install azure-cli
erg=$?
echo
if [ $erg -eq 0 ]; then
  echo "SUCCESS. AZ cli was installed."
else
  echo "ERROR ERROR"
  echo "ERROR. AZ cli installation failed."
fi
echo
exit $erg

