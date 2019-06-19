# 6 Configure Ingress

IBM uses the Kubernetes Feature that all services using NodePort are accessible through all Nodes with the same port. As the Master Node is a single server or has a Load Balancer in front in case of multiple Master Nodes, the node port can always be reached through the master node or the master load balancer.  
When using managed Kubernetes, the master server can not used for this purpose. AWS (as all other cloud providers) do not expose the ports on the master node. Therefore other techniques to access the services must be used.

There might also be some more advanced networking techniques involved. Creating a internal Load Balancer will create an IP end point in the same VPC as your Kubernetes Nodes. When your Connections instance is located in a different VPC, you need to enable VPC Peering to be able to reach the Load Balancer IP.

## 6.1 Classic Load Balancer creation

As AWS charges for every Load Balancer you create, it is a bad idea to create a Load Balancer for every service.

All services will be routed through one Classic Load Balancer.

### 6.6.1 Create private subnetworks

Internal Load Balancer require the creation of private subnetworks for each used availability zone. When you already created your Kubernetes Cluster in a private subnet you do not need to create new ones.

### 6.6.2 Create Classic Load Balancer

Create a Classic Load Balancer.  
For the Health Check I used TCP with port 22. This checks the native node. Probably any other port will do. In case you want to check every real port, you need to create multiple Load Balancer as every LB can check only one port.  
Choose internal load balancer. Select your private subnet. It ook about 5 minutes until the new created subnet were visible in the console.  
Choose your cluster nodes as destinations.

### 6.6.3 Assign Security Groups

Make sure all devices see each other. 

* **Add the Security groups from your worker and infra nodes to the Security Group of your elb.**
* **Add the Security groups from your elb to the Security Group of your worker and infra node.**  


When everything is set up correctly, the LB shows your nodes as "InService".


## 6.2 Elastic Search

Check if the service is available and listen to port 30099.

```
kubectl -n connections get ep  elasticsearch
kubectl -n connections get service elasticsearch

```

Add the port 30099 to your LB listener configuration to forward this traffic as TCP.

To check if the service is available and answers:

```
curl -k -v https://<lb hostname>:30099

```

The expected result of the curl command is the error `curl: (35) NSS: client certificate not found (nickname not specified)` which shows that some HTTPS handshake took place.

Now configure 


* Elastic Search as described by IBM on page [Configuring the Elasticsearch Metrics component](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_config_es_intro.html).
* Type Ahead Search as described by IBM on page [Configuring type-ahead search with Elasticsearch](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/inst_tas_with_es_intro.html).


## 6.2 Configuring the Orient Me component

### 6.2.1 Configuring the HTTP server for Orient Me

Check if the services are available and listen to ports 30001, 31100, 32200, 30285, 32212.

```
kubectl -n connections get ep  orient-web-client
kubectl -n connections get ep  itm-services
kubectl -n connections get ep  community-suggestions
kubectl -n connections get ep  appregistry-client
kubectl -n connections get ep  appregistry-service

kubectl -n connections get service orient-web-client
kubectl -n connections get service itm-services
kubectl -n connections get service community-suggestions
kubectl -n connections get service appregistry-client
kubectl -n connections get service appregistry-service

```

Add the ports 30001, 31100, 32200, 30285, 32212 to your LB listener configuration to forward this traffic as TCP. (Do no use HTTP. At least for /appreg, this setting caused troubles.)

To check if the service is available and answers from your connections instance. You can use curl for this. It is important that the response is a HTTP response. The actual content is not relevant.

```
curl -v "http://<lb hostname>:30001/social"
curl -v "http://<lb hostname>:31100/itm"
curl -v "http://<lb hostname>:32200/community_suggestions/api/recommend/communities"
curl -v "http://<lb hostname>:30285"
curl -v "http://<lb hostname>:32212/appregistry"

```

To configure OrientMe, follow the instructions from IBM on page [Configuring the Orient Me component](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_config_om_intro.html).


### 6.2.2 Enabling and securing Redis traffic to Orient Me

Check if the services are available and listen to port 30379.

```
kubectl -n connections get ep  haproxy-redis

kubectl -n connections get service haproxy-redis


```

Add the port 30379 to your LB listener configuration to forward this traffic as TCP.

To check if the service is available and answers from your connections instance. You can use telnet for this. Just type "auth test". There is no command prompt.

```
telnet <lb hostname> 30379
> auth test
< -ERR invalid password
quit

```

The expected result of the telnet command is the error `-ERR invalid password` which shows that the redis server answers.

Now configure Orient Me as described by IBM on page [Manually configuring Redis traffic to Orient Me](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_config_om_redis_enable.html).

I have not tested yet, if you can secure the traffic.


## 6.3 Customizer

In case you already checked OrientMe. Your configuration already exists.

Check if the services are available and listen to ports 30285, 32212.

```
kubectl -n connections get ep  appregistry-client
kubectl -n connections get ep  appregistry-service

kubectl -n connections get service appregistry-client
kubectl -n connections get service appregistry-service

```

Add the ports 30001, 31100, 32200, 30285, 32212 to your LB listener configuration to forward this traffic as TCP. (Do no use HTTP. At least for /appreg, this setting caused troubles.)

To check if the service is available and answers from your connections instance. You can use curl for this. It is important that the response is a HTTP response. The actual content is not relevant.

```
curl -v "http://<lb hostname>:30285"
curl -v "http://<lb hostname>:32212/appregistry"

```

To configure customizer, follow the instructions from IBM on page [Configuring the Customizer component](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_config_customizer_intro.html).




## 6.4 Filebrowser

Check if the services are available and listen to port 31675.

```
kubectl -n connections get ep  filebrowser

kubectl -n connections get service filebrowser

```

Add the port 31675 to your LB listener configuration to forward this traffic as TCP. (Do no use HTTP. At least for /appreg, this setting caused troubles.)

To check if the service is available and answers from your connections instance. You can use curl for this. It is important that the response is a HTTP response. The actual content is not relevant.

```
curl -v "http://<lb hostname>:31675/filebrowser"

```

Create the proxy settings in the HTTP Server configuration.  
The settings look like this:

```
ProxyPass "/filebrowser" "http://<lb hostname>:31675/filebrowser"
ProxyPassReverse "/filebrowser" "http://<lb hostname>:31675/filebrowser"

```


## 6.5 Sanity Check

You can configure to view the sanity dashboard through the Connections HTTP Server. As the dashboard does not support authentication, the http server should restrict the access to this page.

The better way is to use the kubectl proxy access.

Check if the services are available and listen to port 31856. (Port could be different on your installation!)

```
kubectl -n connections get ep  sanity

kubectl -n connections get service sanity

```

Add the port 31856 to your LB listener configuration to forward this traffic as TCP. (Do no use HTTP. At least for /appreg, this setting caused troubles.)

To check if the service is available and answers from your connections instance. You can use curl for this. It is important that the response is a HTTP response. The actual content is not relevant.

```
curl -v "http://<lb hostname>:31856/sanity/"

```

In your HTTP Server configuration, add this location entry: The access to this location is allowed only from "source ip".
Adjust the location configuration to your needs.

To access the dashboard, use: `https://<lb hostname>/sanity/` . The / at the end is important!

```
<Location "/sanity">
  Order Deny,Allow
  Deny from all
  Allow from <Source IP>
  ProxyPass "http://<lb hostname>:31856"
</Location>

```


# 6.6 Reverse Proxy for Customizer

The reverse proxy is already up and running when you followed the instructions in [Chapter 4](chapter4.html).

To forward all relevant path to customizer as described in [Configuring the NGINX proxy server for Customizer](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_config_customizer_setup_nginx.html) load the appropriate ingress resource:

```
#Run script to create the customizer_ingress rule
bash beas-cnx-cloud/Azure/scripts/customizer_ingress.sh

```
