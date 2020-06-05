# 6 Deploy additional features

## 6.1 Deploy filebrowser

The documentation for this tool can be found here: <https://github.com/becketalservices/cnx_cp_filebrowser>

**In the meanwhile, the project is not developed any further and has been archived. [https://github.com/filebrowser/filebrowser](https://github.com/filebrowser/filebrowser)**

To install the tool run: 

```
helm install https://github.com/becketalservices/cnx_cp_filebrowser/releases/download/v1.0.0/filebrowser-1.0.0.tgz \
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


## 6.2 Deploy webfilesys

The documentation for this tool can be found here: <https://github.com/becketalservices/cnx_cp_filebrowser/tree/webfilesys>

Unfortunately there is no ready Docker image available. You need to build it by yourself. Just follow the instructions in the the documentation on github.


To test the browser access, a load balancer service must be created.  
Delete the service after testing. The normal HCL Component Pack will be reachable via an ingress controller that gets configured later.

```
kubectl -n connections expose deployment webfilesys \
  --port=8080 \
  --target-port=8080 \
  --name=wfs-service \
  --type=LoadBalancer

```

Get the external IP Address of the load balancer service. It takes some minutes until the External-IP is available:

```
kubectl -n connections get service wfs-service

```

Use your browser to access the service. The default credentials are user: "admin", password: "admin".

```
http://<External-IP>:8080/webfilesys

```

To remove the service run: `kubectl -n connections delete service wfs-service`



**[Integration << ](chapter5.html)**