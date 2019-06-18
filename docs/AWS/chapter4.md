# 4 Configure your Network

When you want Customizer, you need to correct the network configuration at this early state. It is important as the installation of the Component Pack requires that all servers are reachable and that the correct host names are set up. Host names and access URLs could be changed later but this is not that simple and requires a lot of testing until everything is finally working as expected.

Please be aware: You need to change the access URL for your existing Connections instance which will prevent your users to access the data until you have configured the Kubernetes infrastructure to forward the traffic correctly which is hopefully the case at the end of this chapter.

This chapter will line out the tasks to get the new Kubernetes infrastructure to forward the traffic to the existing installation. The final Customizer configuration will be done later when everything is running.

## 4.1 Change Service URL for your existing infrastructure

Your existing infrastructure must have a different DNS name than the frontend ingress controller so that traffic can flow from the users through the ingress controller into your existing infrastructure. To avoid that the existing WebSphere servers start to communicate through the ingress controller what will produce a lot of unnecessary load, the DNS Names and service configurations must be adjusted.

### 4.1.1 Create new DNS entry for your existing front end

Create a new DNS entry for your existing HTTP Server or front end load balancer. For simplicity you could append "-backend" to your existing DNS name. e.g. cnx.demo.com will become cnx-backend.demo.com. Create the same type of DNS entry as the existing one. When you have a A record, create a new A record with the same IP. If you have a CNAME, create a new CNAME record with the same value as the existing one.

### 4.1.2 Reconfigure your existing connections instance

**This reconfiguration requires a full restart of the instance**

The process is described by IBM on page [Configuring the NGINX proxy server for Customizer](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_config_customizer_setup_nginx.html).

1. Get new SSL Certificates for your HTTP Server and in case for your Load Balancer where the Service Principal Name also includes the new DNS Name. The old name is only necessary until the new ingress controller is active. In case you do this during the same down time, the old name is not necessary in the SSL certificate.
2. Update your HTTP Server and in case your load balancer to use the new SSL certificate. 
3. Update all service names in the LotusConnections-config.xml from the existing DNS name to the new DNS name. 
4. Place the existing DNS Name in the Dynamic Host configuration so that URLs calculated by the system still have the old DNS name.
5. Restart your infrastructure

After the restart, your old infrastructure should behave normal. If not, you need to debug the configuration change and make sure the DNS entries point to the right systems.


# 4.1 Installing an Ingress Controller

The Customizer requires a reverse proxy in front of the whole infrastructure so that some specific HTTP URLs can be redirected to the Customizer for modification. IBM suggests to use a nginx server. As it is a common problem on kubernetes infrastructures to redirect HTTP(s) traffic to different backend services (internal servers and external endpoints) out of the box solutions exists that can be used.

This chapter uses the nginx-ingress controller from [nginx-ingress](https://kubernetes.github.io/ingress-nginx/).  
Microsoft is has a documentation for their Azure AKS system on page [Create an HTTPS ingress controller on Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/ingress-tls). This instructions work for AWS EKS as well when you adapt the Microsoft specific commands. 

There are different possibilities on how to connect to a Kubernetes cluster. Usually this is done via a load balancer. The load balancer can be set up automatically by Kubernetes or manually. The load balancer ip can be either internal or a public ip address. As Microsoft does not charge for internal load balancer and only one public ip is necessary, the helm hart below will configure a load balancer for the ingress controller.

To install the ingress controller run the helm chart:

```
# Number of replica. Should be less or equal to your nodes customizer nodes.
replica=2

# Run this helm chart to use a public facing load balancer and get a public IP.
helm install stable/nginx-ingress \
  --namespace connections \
  --name connections \
  --set controller.replicaCount=$replica


# Run this helm chart to get a private facing load balanser and get a private IP.
# This is done by annotate the service.
# !!! Currently untested !!!
helm install stable/nginx-ingress \
  --namespace connections \
  --set controller.replicaCount=$replica \
  --set controller.service.annotations='{"service.beta.kubernetes.io/aws-load-balancer-internall": "0.0.0.0/0"}'

# Run this helm chart to start the ingress controller but do not crate the load balancer. (adjust the used ports if necessary)
helm install stable/nginx-ingress \
  --namespace connections \
  --name connections \
  --set controller.replicaCount=$replica \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=32080 \
  --set controller.service.nodePorts.https=32443



```

**When using an internal elb, make sure the security groups are configured correctly to allow traffic forwarding**

# 4.2 Configure the ingress controller

The ingress controller uses a standard ngingx server.

The standard nginx server allows only 1MB of HTTP body to be send to a proxy resource. As the maximum file size in Connections is 512MB or higher when customized, this limit must be adjusted accordingly.

The ingress controller has a config map where all system wide settings are configured. To modify the maximum body size run:

```
# Adjust the limit to your needs!
limit=512m

# create configmap
kubectl -n connections create configmap connections-nginx-ingress-controller

# patch configmap
kubectl -n connections patch configmap connections-nginx-ingress-controller --patch "{\"data\": {\"proxy-body-size\":\"$limit\"}}"

```

# 4.3 Get SSL Certificate

To secure your traffic a ssl certificate is necessary. This certificate must be added to a kubernetes secret.

## 4.3.1 Automatic SSL Certificate retrieval and renewal
When using the ingress controller together with the [cert-manager](https://github.com/jetstack/cert-manager) , the necessary ssl certificates can be retrieved automatically. This setup is currently described here as it is documented by Microsoft on the page [Install cert-manager](https://docs.microsoft.com/en-us/azure/aks/ingress-tls#install-cert-manager).

** The SSL Certificate retrieval only works, when you are using a pulbic Load Balancer (The ingress controller is accessible via http (port 80) from the public internet and your productive DNS entry is already pointing to your load balancer. (see Topic 4.7) **

Setup the certificate manager is simple when your ingress controller has a public IP.  
I recommend trying out the configuration which is copied from Microsoft:

```
# Install the CustomResourceDefinition resources separately
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.8/deploy/manifests/00-crds.yaml

# Create the namespace for cert-manager
kubectl create namespace cert-manager

# Label the cert-manager namespace to disable resource validation
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true

# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io

# Update your local Helm chart repository cache
helm repo update

# Install the cert-manager Helm chart
helm install \
  --name cert-manager \
  --namespace cert-manager \
  --version v0.8.0 \
  jetstack/cert-manager
```

to create the CA cluster issuer configuration update your settings.sh:  
Required parameters:

```
# Let's Encrypt CA Issuer configuration
acme_email=<valid email from your organization>
use_lestencrypt_prod=[true, false]
```

and run:

```
bash beas-cnx-cloud/Azure/scripts/ca_cluster_issuer.sh
```

## 4.3.2 Manual SSL Certificate creation
If you want to use an other CA managed certificate or a self singed certificate create the secret manually.  
For simplicity we use a self singed certificate in this documentation. Example: [TLS certificate termination](https://github.com/kubernetes/contrib/tree/master/ingress/controllers/nginx/examples/tls)

```
# Create a self signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /tmp/tls.key -out /tmp/tls.crt

# Store the certificate inside Kubenetes
kubectl -n connections create secret tls tls-secret --key /tmp/tls.key --cert /tmp/tls.crt

```

# 4.4 Configure your existing infrastructure as external service

External services exist to create a pointer to external systems. This creates a CNAME entry inside the Kubernetes DNS. 

Use the new backend DNS name as external name for this resource.

To create the external service for your existing infrastructure run:

```
# Load settings
. ~/settings.sh

# Create external service cnx-backend
kubectl -n connections create service externalname cnx-backend --external-name $ic_internal

```

# 4.5 Create a ingress resource to forward the traffic

The basic ingress resource will proxy all traffic from the public IP to the old infrastructure. The resources to forward some specific paths to Customizer will be added later.

To create the resource run:

```
#Run script to create the cnx_ingress rule
bash beas-cnx-cloud/Azure/scripts/cnx_ingress.sh

```

# 4.6 Test your forwarding

To test your forwarding, you can use curl or wget. I do not recommend to use a browser as the forwarding is not fully functional yet and with a full browser it is not that easy to see the details.

**Test the access to your ingress loadbalancer by IP**

Your DNS entry may still pointing to the "old" infrastructure. In this case the DNS name can not yet tested.

Access the Load Balancer DNS name e.g. curl -v -k "https://<lb ip>"

* When the forward works as expected, the result of the test should be a "302" redirect to the DNS Name of your old connections instance.
* When the access to the service does not work, you get a connection timeout
* When the access to the service works but the forward fails, you get a 502 Gateway not reachable error.

** Test the access to your ingress loadbalancer by DNS**

To access the load balancer via DNS Name, you need to either reconfigure your DNS Server or create a local hosts entry on your computer.

1. Test `ping <dns name>` to check the correct DNS resolution to your new load balancer.
2. Test `curl -v -k http://<dns name>` to check the correct response.<br>
The results of your test should be a redirect to the DNS name of your old infrastructure.<br>
The error causes are the same as above.

** Test with a browser **

You can now use a browser to test the access.

# 4.7 Point your DNS to the front door

When your can access your old infrastructure through the reverse proxy, you can modify the DNS entry for your connections infrastructure to use the load balancer public IP.

**Before doing so, make sure you have a valid SSL certificate configured in your ingress controller.**

After this step, your new infrastructure is productive as all of your users now access your connections instance through the ingress controller.
