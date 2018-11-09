# Create Kubernetes infrastructure on Azure

The infrastructure requires quite a lot of resources. A Free Tier or Trial Account is not sufficient to install the whole Component Pack
components. Please use a payed account.

Choose an Azure region that suits your needs. See [Quotas and region availability for Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/container-service-quotas) for more details.


## Prepare Azure Environment and Administrative Console

The first three steps are executed using the Azure portal. 
Experienced users could also use the Azure CLI.


### Create Resource Group

To group our infrastructure, I recommend to create an own resource group.

**Azure Portal**

Open the Azure Portal and create a new Resource Group.

**Azure CLI**

When you have the Azure CLI ready on your computer, you also could use those:

See the [official documentation](https://docs.microsoft.com/en-us/cli/azure/group?view=azure-cli-latest#az-group-create) for more details.

```
az group create --location westus --name CPResourceGroup
```

### Crate a Bastion Host in your resource group to administer your cluster

The bastion host will be a small Linux host to upload the docker images to the registry and administer the cluster.
It is recommended that the host is in the same resource group as your kubernetes cluster. This will simplify the access to the cluster resources and the administration.

The host can use a very small server e.g. Standard_B1s or Basic_A1 as no compute power is necessary.

**Azure Portal**

Open the Azure Portal and create the Bastion Host.
Place the host into the the new Resource Group and in the same region as you will use for your Kubernetes Cluster.

* Use CentOS as OS for the Bastion Host. Other Linux systems should also be possible as long as you can install Docker CE onto them.
All provided scripts are created on CentOS or RHEL Server. They are not tested with other Linux distributions. 
* Open port 22 (SSH) to access your Bastion Host from everywhere.
* Place your SSH Public Key into the configuration so you can use SSH Key authentication. When you use Putty, use PuttyGen to generate a new private key and to display the RSA public key.
* Shutdown the Host automatically. It does not need to run 24/7.


## Make the Bastion Host your administration console

Use SSH (Putty) to connect to your new Bastion Host.
For login use the username and the ssh key you configured when you created your host.

### Install git to clone this repository to have the scripts available.

```
sudo -i
yum -y update
yum -y install git
git clone https://github.com/becketalservices/beas-cnx-cloud.git

```

### Install Azure CLI

Install Azure CLI on your Bastion Host.

The instructions of Microsoft: <https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest>

Use the provided script and check the output.

```
bash scripts/install_az.sh

```


After installation make sure, you can authorized yourself using `az login`.

### Configure your environment

As some variables like your resource group name or the region is queries more often, create a file with this variables.

* Make sure you use your own `AZStoreAccount` name as this need to be unique.
* Make sure you use your own `AZDNSPrefix`. It needs to be unique.
* Do not used spaces in the names and the AZStoreAccount must be lower case letters and numbers only.
* Choose the right Server for the cluster. I choose Standard_B4ms as this has enough RAM and CPU but is cheaper than then the Standard_D4_v3.

```
cat > ~/settings.sh <<EOF
AZRegion=westus
AZResourceGroup=CPResourceGroup
AZStoreAccount=cpstorageacct1
AZStoreName=cpshare
AZRegisryName=CPContainerRegistry
AZClusterName=CPCluster
AZDNSPrefix=CP1
AZCluserNodes=6
AZClusterServer=Standard_B4ms
EOF
```


## Create a Docker Registry

To store our images, a Docker Registry is necessary.

See the [az acr create](https://docs.microsoft.com/en-us/cli/azure/acr?view=azure-cli-latest#az-acr-create) documentation for more details.

```
. ~/settings.sh
az acr create --resource-group $AZResourceGroup --name $AZRegisryName --sku Basic

```
When you do not use our current computer to publish images, there is no need to login to the registry yet.



## Create your Azure Kubernetes Environment (AKS)

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


## Create a Azure File Storage

### Create a storage account

To access your storage, the storage account is necessary.

Create your new storage account: 

* The account must be in the same resource group of Kubernetes.
* You need to choose a unique name, so do not use mine.

```
. ~/settings.sh
# Get RG
AZNodeRG=$(az aks show --resource-group $AZResourceGroup --name $AZClusterName  --query "nodeResourceGroup"  | sed "s/\"//g")

# Create account
az storage account create --resource-group $AZNodeRG \
  --name $AZStoreAccount --location $AZRegion \
   --sku Standard_LRS

```

Retrieve your account key: *WHY ????*

```
. ~/settings.sh
AZStoreKey=$(az storage account keys list --resource-group $AZNodeRG \
 --account-name $AZStoreAccount --query "[0].value" | sed "s/\"//g")
echo Key: $AZStoreKey

```

Make sure you remember this key. It looks like this: `"soh3BvSw895mvxrl0MgeoPw...."`


### Create an Azure file share

Create the file share using your storage account data.

```
. ~/settings.sh
az storage share create --account-name $AZStoreAccount --account-key "$AZStoreKey" --name "$AZStoreName"

```



# Configure your Bastion Host as administration workstation

## Install and configure kubectl

Microsoft already provided the tools for you. The default install location is not part of the PATH of the root user. 

```
. ~/settings.sh
az aks install-cli --install-location /usr/bin/kubectl
az aks get-credentials --resource-group $AZResourceGroup --name $AZClusterName

```

To test your connections to your cluster and check your nodes run: `kubectl get nodes`


## Install helm

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


## Install Docker

Docker is only necessary to deploy the Docker images into the registry or to build your own Docker images.

The instructions about the docker installation are taken from the [IBM Documentation](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_prereq_kubernetes_nonha.html).

For the installation run the script:

```
  bash scripts/install_docker.sh
  
```

Check the output of the script.

To verify that docker is installed correctly run: `docker version`


# Install your first application

To check that everything runs smoothly, we will install a file browser which can be later used to manage your customizer storage.

## Crate the connections namespace

All IBM Connections related services are deployed inside the namespace `connections` per default. See the IBM documentation in case you want to change this default.

To create the namespace run: `kubectl create namespace connections`

 
## Create the customizer persistent storage

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

Make sure the status of the pvc with the name "customizernfsclaim" is "Running"

## Deploy filebrowser

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


