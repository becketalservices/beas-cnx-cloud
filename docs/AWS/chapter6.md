# 6 Configure Ingress

HCL uses the Kubernetes Feature that all services using NodePort are accessible through all Nodes with the same port. As the Master Node is a single server or has a Load Balancer in front in case of multiple Master Nodes, the node port can always be reached through the master node or the master load balancer.  
When using managed Kubernetes, the master server can not used for this purpose. AWS (as all other cloud providers) do not expose the ports on the master node. Therefore other techniques to access the services must be used.

There might also be some more advanced networking techniques involved. Creating a internal Load Balancer will create an IP end point in the same VPC as your Kubernetes Nodes. When your Connections instance is located in a different VPC, you need to enable VPC Peering to be able to reach the Load Balancer IP.

During the last chapters all relevant Load Balancer, Ingress Controller and DNS entries were already created but not fully configured.  

## 6.1 Forward all traffic through all ingress controller to the backend infrastructure

To forward all traffic to the backend infrastructure, the cnx-ingress-controller must forward all traffic using an exteranl service to the backend infrastructure and the global-ingress-controller must forward all traffic to the cnx-ingress-controller.

### 6.1.1 Setup external service to allow traffic forward 

External services exist to create a pointer to external systems. This creates a CNAME entry inside the Kubernetes DNS. 

Use the new backend DNS name as external name for this resource.

Update your component pack configuration in your installsettings.sh:  

```
# Component Pack
ic_admin_user=admin_user
ic_admin_password=admin_password
ic_internal="IC Classic FQDN"
ic_front_door="IC FQDN for users"
master_ip=
# "elasticsearch customizer orientme"
starter_stack_list="elasticsearch customizer orientme"
# for test environments with just one node or no taint nodes, 
# set to false.
nodeAffinityRequired="[true/false]"

```
To create the external service for your existing infrastructure run:

```
# Load settings
. ~/installsettings.sh

# Create external service cnx-backend
kubectl -n connections create service externalname cnx-backend \
  --external-name $ic_internal

```

### 6.1.2 Create a ingress resource to forward the traffic

The basic ingress resource will proxy all traffic from the public IP to the old infrastructure. The resources to forward some specific paths to Customizer will be added later.

To create the resource run:

```
#Run script to create the cnx_ingress rule
bash beas-cnx-cloud/common/scripts/cnx_ingress_backend.sh

```

### 6.2.2 Create an ingress resource to forward all traffic from the global to the cnx ingress controller

To create the resource run:

```
#Run script to create the cnx_ingress rule
bash beas-cnx-cloud/common/scripts/global_ingress.sh

```

In case everything is configured correctly, the backend infrastructure should not be accessible by using your front door DNS Name.  
OrientMe, AppReg and Borads should also accessible as this services are forwarded per default in the cnx-ingress-controller. 

### 6.2.3 Create an ingress resource to forward all push traffic directly to the backend

HCL has implemented push notifications by using long polling request. Depending on the used client, the duration of this requests is between 100sec and 550sec.

HCL documents multiple possibilities to handle this traffic on the backend infrastructure. The assumption is, that these configurations are already in place. 
see: 
1. [Configuring an NGINX server for long polling](https://help.hcltechsw.com/connections/v65/admin/install/inst_post_nginx.html)
2. [Setting up and configuring a WAS proxy server for long poll testing](https://help.hcltechsw.com/connections/v65/admin/secure/t_admin_config_was_proxy.html)

As the ingress controller on kubernetes is already an nginx server, the best option would be to configure it using option 1. Unfortunately I found no configuration option to do so.
Therefore the command just forwards the /push traffic to the backend infrastructure. Maybe there are better options available. In case you know one, please inform me about this.

The created loadbalancer are also configured to support this long running requests by adding the annotation `service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: "590"`.

```
# Separate /puth traffic to the backend service
bash beas-cnx-cloud/common/scripts/push_global_ingress.sh

```


## 6.2 Configure Redis Traffic

You need to configure your existing backend infratructure to forward redis traffic to your component pack cluster. 
The global-ingress-controller is already configured to accept and forward this traffic.

Follow the instructions to [Manually configuring Redis traffic to Orient Me](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_om_redis_enable.html).  

```
# Load settings
. ~/installsettings.sh

# Get Redis Password from secret redis-secret
redispwd=$(kubectl get secret redis-secret -n connections \
  -o "jsonpath={.data.secret}" | base64 -d)

# run command
bash microservices_connections/hybridcloud/support/redis/configureRedis.sh \
  -m  $master_ip\
  -po 30379 \
  -ic https://$ic_internal \
  -pw "$redispwd" \
  -ic_u "$ic_admin_user" -ic_p "$ic_admin_password"

```

Check the command output. When the command completed successfully, restart common and news application.

Securing redis traffic does not work as no ssh endpoint currently exists.

To check if redis is working as expected use [Verifying Redis server traffic](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_om_redis_verify.html).


## 6.3 Configure Elastic Search

Use this documentation [Configuring the Elasticsearch Metrics component](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_es_intro.html) to configure the backend infrastructure to use the Elastic Search component. 
Use the internal load balancer hostname (ic_front_door) as pink host.

To retrieve the key and password, you can use this commands.

```
## Get Key Password:
# Get ES Key Password from secret elasticsearch-secret
echo $(kubectl get secret elasticsearch-secret -n connections \
  -o 'jsonpath={.data.elasticsearch-key-password\.txt}' | base64 -d)

  
## Get Key in .p12 format. Copy the output of the last command to 
## the backend instance and execute it. It will create the
## P12 key store in the current directory.
# Get ES Key from secret elasticsearch-secret
p12key=$(kubectl get secret elasticsearch-secret -n connections \
  -o 'jsonpath={.data.elasticsearch-metrics\.p12}')
echo
echo "echo $p12key | base64 -d > lasticsearch-metrics.p12"

```



## 6.4 Configure Customizer

Here, my configuration differs from the one of HCL. HCL use the first ingress controller to separate traffic between standard and customizer traffic. This traffic is then send either directly to the backend or via the mw-proxy pod. In the HTTP Server of the backend, the traffic is then separated again between classic connections traffic and kubernetes traffic by using proxy rules. The kubernetes traffic is then send back to the kubernetes infrastructure into the cnx-ingress controller for further processing.   

In my network setup, the traffic is not forwarded to the external HTTP Server, it is directly send to the internal services mw-proxy or cnx-ingress-contrller. 

**Advantages**
- No proxy configuration on existing HTTP Server
- No load balancer for the cnx-ingress-controller necessary.

**Disadvantage**
- The mw-proxy pod needs to be customized to support http as protocol to the cnx-ingress-controller service
- All classic network traffic is routed through 2 ingress controller before reaching the HTTP Server.

To support this scenario, the mw-proxy must be patched to support http traffic as upstream protocol to forward the traffic not to the https enabled backend HTTP Server but to the internal cnx-ingress-controller only supporting http.

### 6.4.1 Path mw-proxy image to support http traffic

HCL has not enabled to configure the protocol to be used for the backend service.

To patch the mw-proxy image, you need docker installed on your management host.
[How to edit files within docker containers](https://ligerlearn.com/how-to-edit-files-within-docker-containers/)


```
# Load our environment settings
. ~/installsettings.sh

# Set version specific TAG
# 6500: 20191122-024351
TAG="20191122-024351"

# Authorizes docker with ECR
$(aws ecr get-login --no-include-email --region ${AWSRegion})

# Patch Image
docker run --name mw-patch \
  ${ECRRegistry}/connections/mw-proxy:${TAG} \
  sed -i "s/protocol: 'https'/protocol: 'http'/" src/server/config.production.js

# Commit Image (append c to tag)
docker commit mw-patch ${ECRRegistry}/connections/mw-proxy:${TAG}c

# Check patch. 
docker run --name mw-test \
  ${ECRRegistry}/connections/mw-proxy:${TAG}c \
  cat src/server/config.production.js | grep protocol

# if "protocol: http" -> push to registry
docker push ${ECRRegistry}/connections/mw-proxy:${TAG}c

# Clean up
docker rm mw-patch
docker rm mw-test
docker rmi ${ECRRegistry}/connections/mw-proxy:${TAG}
docker rmi ${ECRRegistry}/connections/mw-proxy:${TAG}c

```


### 6.4.2 Update configmap connections-env to redirect traffic to cnx-ingress-controller

During the creation of the connections-env configmap, the 2 parameters customizer-interservice-host and customizer-interservice-port are set to the hostname and port of you backend http server. This needs to be changed to the cnx-ingress-controller.

```
kubectl patch configmap connections-env \
  -n connections \
  --type merge \
  -p '{"data":{"customizer-interservice-host":"cnx-ingress-controller","customizer-interservice-port":"80"}}'
  
```

### 6.4.3 Update mw-proxy deployment to use patched image

To use the updated image from 6.4.1, the deployment descriptor must be changed.

```
# get current image name
currentimage=$(kubectl get deployment mw-proxy \
  -n connections \
  -o 'jsonpath={.spec.template.spec.containers[0].image}')

#modify image tag by adding a 'c' at the end. (depends on the tag of 6.4.1) 
newimage=${currentimage}c

# patch deployment to use new image
kubectl patch deployment mw-proxy \
  -n connections \
  --type json \
  -p "[{\"op\" : \"replace\" ,\"path\" : \"/spec/template/spec/containers/0/image\" , \"value\" : \"$newimage\"}]"

```

### 6.4.4 Activate customizer rules

To forward traffic to the customizer, activate the forward rules as lined out by HCL [Configuring the NGINX proxy server for Customizer](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_customizer_setup_nginx.html).

To activate the configuration run command:

```
# Activate ingress for customizer on global-ingress
bash beas-cnx-cloud/common/scripts/customizer_ingress_frontend.sh

```

**[Install Component Pack << ](chapter5.html)**
