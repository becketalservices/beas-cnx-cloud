# 5. Configure Ingress

IBM uses the Kubernetes Feature that all services using NodePort are accessible through all Nodes with the same port. As the Master Node is a single server or has a Load Balancer in front in case of multiple Master Nodes, the node port can always be reached through the master node or the master load balancer.<br>
When using managed Kubernetes, the master server can not used for this purpose. Microsoft (as all other cloud providers) do not expose the ports on the master node. Therefore other techniques to access the services must be used.<br>
Kubernetes has two service types that can be used for this purpose:
1. LoadBalancer - This type of service can be used for all types of traffic.
2. HTTP Ingress Controller - This type of service can be used for HTTP/HTTPS traffic only and requires some more services.
   
LoadBalancer could also be used for HTTP / HTTPS traffic but usually the cloud provides charge per used Load Balancer. Therefore it reduces costs, when some services use one common Load Balancer which is done when using a [Ingress Controller](https://kubernetes.io/docs/concepts/services-networking/ingress/). 

There might also be some more advanced networking techniques involved. Creating a internal Load Balancer will create an IP end point in the same VNet as your Kubernetes Nodes. When your Connections instance is located in a different VNet, you need to enable VNet Peering to be able to reach the Load Balancer IP.
See the Microsoft Documentation about [Virtual network peering](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview). 


## 5.1 Elastic Search

The elastic search component uses a native IP Port with HTTPS traffic but with some ceriticate based authentication. As I did not found out how this service works with an ingress controller a Load Balancer service is set up for this service.

Depending on your network layout an internal Load Balancer can be used. See the Kubernetes documentation about internal [Load Balancers](https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer).

As I assume that your Connections installation and your Component Pack installation do no communicate via public IP, an internal Load Balancer is created:

```
kubectl apply -f beas-cnx-cloud/Azure/kubernetes/es_lb.yaml

```

To get the IP of your Load Balancer run: (It takes about 1-2 minutes until the external ip is available)

```
kubectl -n connections get service elasticsearch-lb

```

To check if the service is available and answers:

```
curl -k -v https://<external ip>:30099

```

The expected error is this error: `curl: (35) NSS: client certificate not found (nickname not specified)` which shows that some HTTPS handshake took place.

Now configure Elastic Search as described by IBM on page [Configuring the Elasticsearch Metrics component](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_config_es_intro.html).



## 5.2 Redis Traffic

## 5.3 HTTP Services

### 5.3.1 Orient Me

### 5.3.2 Filebrowser

### 5.3.3 Customizer

