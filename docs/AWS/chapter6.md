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
# for test environments with just one node or no taint nodes, set to false.
nodeAffinityRequired="[true/false]"

```
To create the external service for your existing infrastructure run:

```
# Load settings
. ~/installsettings.sh

# Create external service cnx-backend
kubectl -n connections create service externalname cnx-backend --external-name $ic_internal

```

### 6.1.2 Create a ingress resource to forward the traffic

The basic ingress resource will proxy all traffic from the public IP to the old infrastructure. The resources to forward some specific paths to Customizer will be added later.

To create the resource run:

```
#Run script to create the cnx_ingress rule
bash beas-cnx-cloud/common/scripts/cnx_ingress_backend.sh

```

### 6.2.2 Create a ingress resource to forward all traffic from the global to the cnx ingress controller

To create the resource run:

```
#Run script to create the cnx_ingress rule
bash beas-cnx-cloud/common/scripts/global_ingress.sh

```

In case everything is configured correctly, the backend infrastructure should not be accessible by using your front door DNS Name.  
OrientMe, AppReg and Borads should also accessible as this services are forwarded per default in the cnx-ingress-controller. 


## 6.2 Configure Redis Traffic

You need to configre your existing backend infratructure to forward redis traffic to your component pack cluster. 
The global-ingress-controller is already configured to accept and forward this traffic.

Follow the instructions to [Manually configuring Redis traffic to Orient Me](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_om_redis_enable.html).  

```
# Load settings
. ~/installsettings.sh

# Get Redis Password from secret redis-secret
redispwd=$(kubectl get secret redis-secret -n connections \
  -o "jsonpath={.data.secret}" | base64 -d)

# run command
bash configureRedis.sh \
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


## 6.4 Configure Customizer

So far customizer is not yet active. All other services are up and running.

Please stay tuned for an update of this documentation on how to enable customizer on this network configuration.

**[Install Component Pack << ](chapter5.html)**