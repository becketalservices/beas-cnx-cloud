Create a IBM Component Pack installation on Azure
=================================================

This instructions are like a cook book. You can follow them and you will get the desired result when you environment is the same as mine. This instructions were build using a payed account without any restrictions. When you are in a corporate environment there might some restrictions apply. Please check with your entitlement administrator.

The infrastructure requires quite a lot of resources. A Free Tier or Trial Account is not sufficient to install the whole Component Pack
components. Please use a payed account.

# 1. Create Kubernetes infrastructure on Azure

Choose an Azure region that suits your needs. See [Quotas and region availability for Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/container-service-quotas) for more details.

## 1.1 Prepare Azure Environment and Administrative Console

The first three steps are executed using the Azure portal. 
Experienced users could also use the Azure CLI.


### 1.1.1 Create Resource Group

To group our infrastructure, I recommend to create an own resource group.

**Azure Portal**

Open the Azure Portal and create a new Resource Group.

**Azure CLI**

When you have the Azure CLI ready on your computer, you also could use those:

See the [official documentation](https://docs.microsoft.com/en-us/cli/azure/group?view=azure-cli-latest#az-group-create) for more details.

```
az group create --location westus --name CPResourceGroup

```

### 1.1.2 Create a Bastion Host in your resource group to administer your cluster

The bastion host will be a small Linux host to upload the docker images to the registry and administer the cluster.
It is recommended that the host is in the same resource group as your kubernetes cluster. This will simplify the access to the cluster resources and the administration.

The host can use a very small server e.g. Standard\_B1s or Basic\_A1 as no compute power is necessary.

**Azure Portal**

Open the Azure Portal and create the Bastion Host.
Place the host into the the new Resource Group and in the same region as you will use for your Kubernetes Cluster.

* Use CentOS as OS for the Bastion Host. Other Linux systems should also be possible as long as you can install Docker CE onto them.
All provided scripts are created on CentOS or RHEL Server. They are not tested with other Linux distributions. 
* Open port 22 (SSH) to access your Bastion Host from everywhere.
* Place your SSH Public Key into the configuration so you can use SSH Key authentication. When you use Putty, use PuttyGen to generate a new private key and to display the RSA public key.
* Shutdown the Host automatically. It does not need to run 24/7.


## 1.2 Make the Bastion Host your administration console

Use SSH (Putty) to connect to your new Bastion Host.
For login use the username and the ssh key you configured when you created your host.

### 1.2.1 Install git to clone this repository to have the scripts available.

```
sudo -i
yum -y update
yum -y install git
git clone https://github.com/becketalservices/beas-cnx-cloud.git

```

### 1.2.2 Install Azure CLI

Install Azure CLI on your Bastion Host.

The instructions of Microsoft: <https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest>

Use the provided script and check the output.

```
bash beas-cnx-cloud/Azure/scripts/install_az.sh

```


After installation make sure, you can authorized yourself using `az login`.

### 1.2.3 Configure your environment

As some variables like your resource group name or the region is queries more often, create a file with this variables.

* Make sure you use your own `AZStoreAccount` name as this need to be unique.
* Make sure you use your own `AZDNSPrefix`. It needs to be unique.
* Do not used spaces in the names and the AZStoreAccount must be lower case letters and numbers only.
* Use only lower case letters for your Docker registry name. This is a Docker requirement.
* Choose the right Server for the cluster. I choose Standard_B4ms as this has enough RAM and CPU but is cheaper than then the Standard_D4_v3.

```
# Write our environment settings
cat > ~/settings.sh <<EOF
AZRegion=westus
AZResourceGroup=CPResourceGroup
AZStoreAccount=cpstorageacct1
AZStoreName=cpshare
AZRegistryName=cpcontainerregistry
AZRegistryPrincipal=CP_Registry_Reader
AZClusterName=CPCluster
AZDNSPrefix=CP1
AZCluserNodes=6
AZClusterServer=Standard_B4ms
ic_admin_user=admin_user
ic_admin_password=admin_password
ic_internal=ic_internal
ic_front_door=ic_front_door
ic_http_server=ic_http_server
master_ip=
# "elasticsearch customizer orientme"
starter_stack_list="elasticsearch"
# for test environments with just one node set to false.
nodeAffinityRequired=true
EOF
```


## 1.3 Create a Docker Registry

To store our images, a Docker Registry is necessary.

See the [az acr create](https://docs.microsoft.com/en-us/cli/azure/acr?view=azure-cli-latest#az-acr-create) documentation for more details.

```
# Load our environment settings
. ~/settings.sh

# Create our Docker Registry
az acr create --resource-group $AZResourceGroup --name $AZRegistryName --sku Basic

```
When you do not use our current computer to publish images, there is no need to login to the registry yet.

## 1.4 Create a service principal user to access your Docker Registry 

We need this service principal to autorize the kubernetes services to pull the images from the registry. IBM Component pack creates a secret named "myregkey" which needs the user id and password of this service principal.

The instructions on how to creates this account are taken from this [Microsoft documentation](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-auth-service-principal).

I slightly modified the script to use our settings.sh file:

```
bash beas-cnx-cloud/Azure/scripts/create_service_principal.sh

```

Write down the ID and password. We need this information later to create the kubernetes secret.


## 1.5 Create your Azure Kubernetes Environment (AKS)

By now, you have a Resource Group to group your environment, a Docker Registry to store the images and a Azure File Share to store your persistent data with ReadOnlyMany access.

As next step, we can create the Kubernetes Cluster.

* Make shure you have filled in the settings.sh from above when you want to use the script.
You can modify the script to your needs.
* The script will instruct the command to create ssh keys to access the VMs for you. If you want to use your already existing ssh keys, modify the script accordingly.
* The script will instruct the command to crate a service principal account for you. If you want to use your already existing service principal account, modify the script accordingly.

To start the generation process run:

```
bash scripts/install_az.sh

```

Check the Azure Portal for the current status. It will take a while (10-20minutes) until the cluster is created.
When you have not enough resources available in your Azure subscription, the process will fail.

Check the output of the command for details or errors.


## 1.6 Create a Azure File Storage

### 1.6.1 Create a storage account

To access your storage, the storage account is necessary.

Create your new storage account: 

* The account must be in the same resource group of Kubernetes.
* You need to choose a unique name, so do not use mine.

```
# Load our environment settings
. ~/settings.sh

# Get RG
AZNodeRG=$(az aks show --resource-group $AZResourceGroup --name $AZClusterName  --query "nodeResourceGroup"  | sed "s/\"//g")

# Create account
az storage account create --resource-group $AZNodeRG \
  --name $AZStoreAccount --location $AZRegion \
   --sku Standard_LRS

```

Retrieve your account key. You need it to create an Azure file share.

```
# Load our environment settings
. ~/settings.sh

# Get storage account key
AZStoreKey=$(az storage account keys list --resource-group $AZNodeRG \
 --account-name $AZStoreAccount --query "[0].value" | sed "s/\"//g")
echo Key: $AZStoreKey

```

Make sure you remember this key. It looks like this: `"soh3BvSw895mvxrl0MgeoPw...."`


### 1.6.2 Create an Azure file share

Create the file share using your storage account data.

```
# Load our environment settings
. ~/settings.sh

# Create Azure file share
az storage share create --account-name $AZStoreAccount --account-key "$AZStoreKey" --name "$AZStoreName"

```



# 2. Configure your Bastion Host as administration workstation

## 2.1 Install and configure kubectl

Microsoft already provided the tools for you. The default install location is not part of the PATH of the root user. 

```
# Load our environment settings
. ~/settings.sh

# Install kubectl command
az aks install-cli --install-location /usr/bin/kubectl

# Store access credentials in kubectl configuration
az aks get-credentials --resource-group $AZResourceGroup --name $AZClusterName

```

To test your connections to your cluster and check your nodes run: `kubectl get nodes`


## 2.2 Install helm

**Install helm binary**

Download and extract the helm binaries:

```
curl -L -o helm-v2.11.0-linux-amd64.tar.gz "https://storage.googleapis.com/kubernetes-helm/helm-v2.11.0-linux-amd64.tar.gz"
tar -zxvf helm-v2.11.0-linux-amd64.tar.gz
mv linux-amd64/helm /usr/bin/helm

```

**Create a kubernetes service account**

As we have rbac enabled on our cluster, we need to create an service account so that helm can act on our cluster.

The given instructions are based on this instructions: <https://github.com/helm/helm/blob/master/docs/rbac.md>

To create the service account, allow helm to manage the whole cluster and configure helm to use it, run this commands:

```
kubectl apply -f helm/rbac-config.yaml
helm init --service-account tiller

```

To check your helm installation and your successful connection to the cluster run `helm version`


## 2.3 Install Docker

Docker is only necessary to deploy the Docker images into the registry or to build your own Docker images.

The instructions about the docker installation are taken from the [IBM Documentation](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_prereq_kubernetes_nonha.html).

For the installation run the script:

```
bash scripts/install_docker.sh

```

Check the output of the script.

To verify that docker is installed correctly run: `docker version`


# 3. Install your first application

To check that everything runs smoothly, we will install a file browser which can be later used to manage your customizer storage.

## 3.1 Crate the connections namespace

All IBM Connections related services are deployed inside the namespace `connections` per default. See the IBM documentation in case you want to change this default.

To create the namespace run: `kubectl create namespace connections`

 
## 3.2 Create the customizer persistent storage

The persistent storage for Customizer must be a ReadOnlyMany storage type. Thats why we created the Azure File Service.

To crate the storage, we will crate:

1. StorageClass `azurefile`
2. Grant the storage provisioner appropriate rbac rights
3. Persistent Volume claim `customizerstorage`

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

To crate the persistent volume claim for Customizier with the name `customizernfsclaim` run this command:

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
Delete the service afterwarer testing. The normal IBM Component Pack will be reachable via an ingress controller that gets configured later.

```
kubectl -n connections expose deployment filebrowser --port=8080 --target-port=80 --name=fb-service --type=LoadBalancer

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


# 4. Install Component Pack

We need the installation files from IBM to continue.

Download the files to your Bastion host and extract them. In case you have your files on a Azure file share or AWS S3, you can use my [s3scripts](https://github.com/MSSputnik/s3scripts) to access your files.

Just extract them: `unzip IC-ComponentPack-6.0.0.6.zip`


## 4.1 Create persistent volumes

IBM provides the relevant documentation here: <https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_prereqs_persist_vols.html>

IBM already created some helper files to create the persistent volumes. As we use Azure File and not  NFS we need a modified version.<br>
Please check the IBM documentation for more details on the available parameters.<br>
The script below will create all storages except customizer with its default sizes on our [azure file store which was created earlier](#1-6-create-a-azure-file-storage).

The customizer file store was created earlier: [3.2 Create the customizer persistent storage](#3-2-create-the-customizer-persistent-storage).


**Attention: The reclaim policy is currently set to Delete. This will delete your storage and data in case you delete the pvc. This is different from what IBM creates with their helm chart. Do not run `helm delete connections-volumes` when you want to keep your data.**
 
```
# Run the Helm Chart to create the PVCs on our azurefile storage
# The Helm Chart is a modified version from IBM. It supports the same parameters.
# You can specify more parameters if required, especially when you do not want all storages or different sizes.
helm install ./beas-cnx-cloud/Azure/helm/connections-persistent-storage-nfs \
  --name=connections-volumes \
  --set storageClassName=azurefile \
  --set customizer.enabled=false \
  --set solr.enabled=true \
  --set zk.enabled=true \
  --set es.enabled=true \
  --set mongo.enabled=true
 
```



## 4.2 Create Docker Registry pull secret

IBM Component Pack uses a kubernetes secret to store the access credentials for the docker registry.
Use the credentials of the service principal we created earlier in [Create a service principal user to access your Docker Registry](#1-4-create-a-service-principal-user-to-access-your-docker-registry).

More details can be found in the [IBM Knowledge Center](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_prereqs.html).

```
# Load our environment settings
. ~/settings.sh

# Create kubernetes secret myregkey
kubectl -n connections create secret docker-registry myregkey \
  --docker-server=${AZRegistryName}.azurecr.io \
  --docker-username=<Service principal ID> \
  --docker-password=<Service principal password>

```

## 4.3 Upload Docker images to registry

IBM provides a script to upload all necessary images to your registry. Unfortunately it requires that you type in you username and password for the registry. 
Assuming that your account you are working with Azure Cli, has the rights to upload images to the registry, you can modify the script to ignore the username password and just upload the images using your implicit credentials.

The IBM instructions are found here: <https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_install_push_docker_images.html>

Modify the -st parameter to your needs. When you omit this parameter, all images are uploaded. <br>As we just remove the `docker login` command from the script, the username and password parameters are still mandatory but irrelevant.

```
# Load our environment settings
. ~/settings.sh

# Login with your account to the docker registry
az acr login --resource-group $AZResourceGroup --name $AZRegistryName

# move into the support directory of the IBM CP installation files
cd microservices_connections/hybridcloud/support

# Modify the installation script to comment out the docker login command.
sed -i "s/^docker login/#docker login/" setupImages.sh

# Push the required images to your registry.
# In case of problems or you need more images, you can rerun this command at any time.
# Docker will upload only what is not yet in the registry.
./setupImages.sh -dr ${AZRegistryName}.azurecr.io -u dummy -p dummy -st customizer,elasticsearch,orientme

```

In case you have pushed all images to the registry or you are shure you do not need more, you can remove the "images" directory and the download IC-ComponentPack-6.0.0.6.zip.zip so save disk space.

## 4.4 Taint nodes for Elastic Search

When you want to have dedicated nodes for Elastic Search you need to taint and label them.<br>
When you just have 1 node, skip this step.

For details instructions from IBM see here: <https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_prereqs_label_es_workers.html>

```
# Get the available nodes
kubectl get nodes

# For each node, you want to taint run:
kubectl label nodes <node> type=infrastructure --overwrite 
kubectl taint nodes <node> dedicated=infrastructure:NoSchedule --overwrite 

```

## 4.5 Deploy Component Pack to Cluster

This chapter simply follows the instructions from IBM: <https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_install_services_intro.html>

All shown commands use as much default values as possible. Check IBM documentation for more options.


### 4.5.1 Bootstrapping the Kubernetes cluster

[Bootstrapping the Kubernetes Cluster](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_install_bootstrap.html)


```
# Load our environment settings
. ~/settings.sh

helm install \
--name=bootstrap microservices_connections/hybridcloud/helmbuilds/bootstrap-0.1.0-20181008-114142.tgz \
--set \
image.repository=${AZRegistryName}.azurecr.io/connections,\
env.set_ic_admin_user=$ic_admin_user,\
env.set_ic_admin_password=$ic_admin_password,\
env.set_ic_internal=$ic_internal,\
env.set_master_ip=$master_ip,\
env.set_starter_stack_list="$starter_stack_list",\
env.skip_configure_redis=true

```


### 4.5.2 Installing the Component Pack's connections-env

[Installing the Component Pack's connections-env](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_install_connections-env.html)

```
# Load our environment settings
. ~/settings.sh

helm install \
--name=connections-env microservices_connections/hybridcloud/helmbuilds/connections-env-0.1.40-20181011-103145.tgz \
--set \
onPrem=true,\
createSecret=false,\
ic.host=$ic_front_door,\
ic.internal=$ic_http_server,\
ic.interserviceOpengraphPort=443,\
ic.interserviceConnectionsPort=443,\
ic.interserviceScheme=https

```


### 4.5.3 Installing the Component Pack infrastructure

[Installing the Component Pack infrastructure](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_install_infrastructure.html)

```
# Load our environment settings
. ~/settings.sh

helm install \
--name=infrastructure microservices_connections/hybridcloud/helmbuilds/infrastructure-0.1.0-20181014-210242.tgz \
--set \
global.onPrem=true,\
global.image.repository=${AZRegistryName}.azurecr.io/connections,\
mongodb.createSecret=false,\
appregistry-service.deploymentType=hybrid_cloud

```


### 4.5.4 Installing Orient Me

[Installing Orient Me](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_install_om.html)

### 4.5.5 Installing Elasticsearch

[Installing Elasticsearch](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_install_es.html)

**Attention: In case you have only one node or did not taint the nodes for elastic search set `nodeAffinityRequired=false`.

```
# Load our environment settings
. ~/settings.sh

helm install \
--name=elasticsearch microservices_connections/hybridcloud/helmbuilds/elasticsearch-0.1.0-20180921-115419.tgz \
--set \
image.repository=${AZRegistryName}.azurecr.io/connections,\
nodeAffinityRequired=$nodeAffinityRequired

```

### 4.5.6 Installing Customizer (mw-proxy)

[Installing Customizer (mw-proxy)](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_install_customizer.html)

### 4.5.7 Installing tools for monitoring and logging

This chapter needs more attension....


## Test

# Configure Ingress

## Elastic Search

## Redis Traffic

## HTTP Services

### Orient Me

### Filebrowser

### Customizer


