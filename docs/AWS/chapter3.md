# 3 Install your first application

To check that everything runs smoothly, we will install a file browser which can be later used to manage your customizer storage.

## 3.1 Crate the connections namespace

All HCL Connections related services are deployed inside the namespace `connections` per default. See the HCL documentation in case you want to change this default.

To create the namespace run: `kubectl create namespace connections`

 
## 3.2 Create the customizer persistent storage

The persistent storage for Customizer must be a ReadWriteMany storage type. Thats why we created the EFS file system.

To create the persistent volume claim for Customizer with the name `customizernfsclaim` run this command:

```
kubectl apply -f beas-cnx-cloud/AWS/kubernetes/create_pvc_customizer.yaml

```

To check the creation run: `kubectl -n connections get pvc`

Make sure the status of the pvc with the name "customizernfsclaim" is "Bound"

## 3.3 Deploy filebrowser

The documentation for this tool can be found here: <https://github.com/becketalservices/cnx_cp_filebrowser>

To install the tool run: 

```
helm install https://github.com/becketalservices/cnx_cp_filebrowser/releases/download/v2.0.0/filebrowser-2.0.0.tgz \
  --name filebrowser \
  --set storageClassName=aws-efs \
  --namespace connections

```

To test the browser access, a load balancer service must be created.  
Delete the service after testing. The normal HCL Component Pack will be reachable via an ingress controller that gets configured later.

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

**[Create Kubernetes infrastructure on AWS << ](chapter2.html) [ >> Configure your Network](chapter4.html)**