#!/bin/bash
# This script uses default helm chart from IBM and creates a version for Azure
# This script to document the implemented changes.
# Users can use the resulting template.

# Remove the automatic binding to NFS by removing the template from the helm chart
rm -f connections-persistent-storage-nfs/templates/fullPVs_NFS.yaml

# Remove the selectors as they are not supported by dynamic provisioning
# Remove the existing storageClassName that does not exist everywhere so it can easily added everywhere again.
sed -i -e "/  selector/d" \
  -e "/    matchLabels/d" \
  -e "/      component/d" \
  -e "/      role/d" \
  -e "/        app/d" \
  -e "/  storageClassName/d" \
  connections-persistent-storage-nfs/templates/fullPVCs.yaml

# Add the storage class to every pvc
sed -i '/ resources/i \
  storageClassName: {{ .Values.storageClassName }}' \
  connections-persistent-storage-nfs/templates/fullPVCs.yaml

# Fix the intents
sed -i -e "s/^ \([a-z-].*\)/  \1/" \
  -e "s/^   \([a-z-].*\)/    \1/" \
  -e "s/^     \([a-z-].*\)/      \1/" \
  connections-persistent-storage-nfs/templates/fullPVCs.yaml

