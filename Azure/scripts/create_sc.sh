. ~/settings.sh

cat > azure_sc.yaml << EOF
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: azurefile
provisioner: kubernetes.io/azure-file
mountOptions:
- dir_mode=0777
- file_mode=0777
- uid=100
- gid=65533
parameters:
  storageAccount: $AZStoreAccount
reclaimPolicy: $AZStoreReclaim 
EOF
