Deploy webfilesys
=================

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

