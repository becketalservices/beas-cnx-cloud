# 5. Configure Ingress

IBM uses the Kubernetes Feature that all services using NodePort are accessible through all Nodes with the same port. As the Master Node is a single server or has a Load Balancer in front in case of multiple Master Nodes, the node port can always be reached through the master node or the master load balancer.<br>
When using managed Kubernetes, the master server can not used for this purpose. Microsoft (as all other cloud providers) do not expose the ports on the master node. Therefore other techniques to access the services must be used.<br>

There might also be some more advanced networking techniques involved. Creating a internal Load Balancer will create an IP end point in the same VNet as your Kubernetes Nodes. When your Connections instance is located in a different VNet, you need to enable VNet Peering to be able to reach the Load Balancer IP.
See the Microsoft Documentation about [Virtual network peering](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview). 


## 5.1 Elastic Search

An internal Load Balancer can be used. See the Kubernetes documentation about internal [Load Balancers](https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer).

As I assume that your Connections installation and your Component Pack installation do not communicate via public IP, an internal Load Balancer is created:

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

The expected result of the curl command is the error `curl: (35) NSS: client certificate not found (nickname not specified)` which shows that some HTTPS handshake took place.

Now configure 

* Elastic Search as described by IBM on page [Configuring the Elasticsearch Metrics component](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_config_es_intro.html).
* Type Ahead Search as described by IBM on page [Configuring type-ahead search with Elasticsearch](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/inst_tas_with_es_intro.html).


## 5.2 Configuring the Orient Me component

### 5.2.1 Configuring the HTTP server for Orient Me

Create the appropriate Load Balancer resources for Customizer. Run:

```
# OrientMe Web Client
kubectl apply -f beas-cnx-cloud/Azure/kubernetes/owc_lb.yaml

# itm services
kubectl apply -f beas-cnx-cloud/Azure/kubernetes/is_lb.yaml

# community suggestions
kubectl apply -f beas-cnx-cloud/Azure/kubernetes/cs_lb.yaml

```

Get the external IPs used for the services above and use them in the configuration.

```
# Get OrientMe Web Client External IP
kubectl -n connections get service orient-web-client-lb

# Get itm services External IP
kubectl -n connections get service itm-services-lb

# Get community suggestions External IP
kubectl -n connections get service community-suggestions-lb

```

To configure OrientMe, follow the instructions from IBM on page [Configuring the Orient Me component](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_config_om_intro.html).


### 5.2.2 Enabling and securing Redis traffic to Orient Me

An internal Load Balancer can be used. See the Kubernetes documentation about internal [Load Balancers](https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer).

As I assume that your Connections installation and your Component Pack installation do not communicate via public IP, an internal Load Balancer is created:

```
kubectl apply -f beas-cnx-cloud/Azure/kubernetes/hap_lb.yaml

```

To get the IP of your Load Balancer run: (It takes about 1-2 minutes until the external ip is available)

```
kubectl -n connections get service haproxy-redis-lb

```

To check if the service is available and answers. You can use telnet for this. Just type "auth test". There is no command prompt.

```
telnet <external ip> 30379
> auth test
< -ERR invalid password

```

The expected result of the telnet command is the error `-ERR invalid password` which shows that the redis server answers.

Now configure Elastic Search as described by IBM on page [Manually configuring Redis traffic to Orient Me](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_config_om_redis_enable.html).

I have not tested yet, if you can secure the traffic.


## 5.3 Customizer

Create the appropriate Load Balancer resources for Customizer. Run:

```
# Middleware Proxy
kubectl apply -f beas-cnx-cloud/Azure/kubernetes/mwp_lb.yaml

# AppReg Client
kubectl apply -f beas-cnx-cloud/Azure/kubernetes/ac_lb.yaml

# AppReg Service
kubectl apply -f beas-cnx-cloud/Azure/kubernetes/as_lb.yaml

```

Get the external IPs used for the services above and use them in the configuration.

```
# Get Middleware Proxy External IP
kubectl -n connections get service mw-proxy-lb

# Get AppReg Client External IP
kubectl -n connections get service appregistry-client-lb

# Get AppReg Service External IP
kubectl -n connections get service appregistry-service-lb

```

To configure customizer, follow the instructions from IBM on page [Configuring the Customizer component](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_config_customizer_intro.html).




## 5.4 Filebrowser

Create the appropriate Load Balancer resources for Customizer. Run:

```
# Fielbrowser Service
kubectl apply -f beas-cnx-cloud/Azure/kubernetes/fb_lb.yaml

```

Get the external IPs used for the service above and use them in the configuration.

```
# Get Filebrowser External IP
kubectl -n connections get service filebrowser-lb

```

Create the proxy settings in the HTTP Server configuration.<br>
The settings look like this:

```
ProxyPass "/filebrowser" "http://<external ip>:31675/filebrowser"
ProxyPassReverse "/filebrowser" "http://<external ip>:31675/filebrowser"

```


## 5.5 Sanity Check

You can configure to view the sanity dashboard through the Connections HTTP Server. As the dashboard does not support authentication, the http server should restrict the access to this page.

Create the appropriate Load Balancer resources for Customizer. Run:

```
# Sanity Service
kubectl apply -f beas-cnx-cloud/Azure/kubernetes/sanity_lb.yaml

```

Get the external IPs used for the service above and use them in the configuration.

```
# Get Sanity Service External IP
kubectl -n connections get service sanity-lb

```


In your HTTP Server configuration, add this location entry: The access to this location is allowed only from "source ip".
Adjust the location configuration to your needs.

To access the dashboard, use: `https://<connections url>/sanity/` . The / at the end is important!

```
<Location "/sanity">
  Order Deny,Allow
  Deny from all
  Allow from <Source IP>
  ProxyPass "http://<external ip>:31578"
</Location>

```


#5.6 Reverse Proxy for Customizer

IBM just tells you to install a NGINX Server somewhere.<br>
As we are on Kubernetes, we can use some of the techniques available there.<br>
Feel free to use some different technique if you want.

** Still under investigation **


