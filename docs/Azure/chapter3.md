# 3 Install your first application

To check that everything runs smoothly, we will install a file browser which can be later used to manage your customizer storage.

## 3.1 Crate the connections namespace

All IBM Connections related services are deployed inside the namespace `connections` per default. See the IBM documentation in case you want to change this default.

To create the namespace run: `kubectl create namespace connections`

 
## 3.2 Create the customizer persistent storage

The persistent storage for Customizer must be a ReadWriteMany storage type. Thats why we created the Azure File Service.

To crate the storage, we will crate:

1. StorageClass *azurefile*
2. Grant the storage provisioner appropriate rbac rights
3. Persistent Volume claim *customizerstorage*

**Storage Class**

To create the storage class based on your settings:

```
# run to create yaml file 
bash beas-cnx-cloud/Azure/scripts/create_sc.sh

# run to apply the configuration
kubectl apply -f azure_sc.yaml

```

To check that the storage class has been created run `kubectl get storageclass azurefile`


**RBAC rights**

To grant the correct rights create the necessary cluster roles and bindings

run `kubectl apply -f beas-cnx-cloud/Azure/kubernetes/azure-pvc-roles.yaml`


**Persistent Volume Claim**

To crate the persistent volume claim for Customizer with the name `customizernfsclaim` run this command:

```
kubectl apply -f beas-cnx-cloud/Azure/kubernetes/create_pvc_customizer.yaml

```

To check the creation run: `kubectl -n connections get pvc`

Make sure the status of the pvc with the name "customizernfsclaim" is "Bound"

## 3.3 Deploy filebrowser

The documentation for this tool can be found here: <https://github.com/becketalservices/cnx_cp_filebrowser>

To install the tool run: 

```
helm install https://github.com/becketalservices/cnx_cp_filebrowser/releases/download/v1.0.0/filebrowser-1.0.0.tgz \
  --name filebrowser \
  --set storageClassName=default \
  --namespace connections

```

To test the browser access, a load balancer service must be created.  
Delete the service after testing. The normal IBM Component Pack will be reachable via an ingress controller that gets configured later.

```
kubectl -n connections expose deployment filebrowser \
  --port=8080 \
  --target-port=80 \
  --name=fb-service \
  --type=LoadBalancer

```

Get the external IP Address of the load balancer service. It takes some minutes until the External-IP is available:

```
kubectl -n connections get service fb-service

```

Use your browser to access the service. The default credentials are user: "admin", password: "admin".

```
http://<External-IP>:8080/filebrowser

```

To remove the service run: `kubectl -n connections delete service fb-service`
