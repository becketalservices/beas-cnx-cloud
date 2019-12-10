# 1 Create Kubernetes infrastructure on Azure

Choose an Azure region that suits your needs. See [Quotas and region availability for Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/container-service-quotas) for more details.<br>
Make sure your region has enough resources available. When you create a cluster with 6 nodes, using Standard_B4ms servers, you need 24 free regional vCPUs and 24 free Standard BS vCPUs available.

Take care about the necessary network configuration. There are 2 options available.
1. Create the Kubernetes Cluster in a separate VNet. <br>When choosing this option, the services are reachable via public IP only or you need to create VNet Peering to be able to reach the internal IPs. 
2. Create the Kubernetes Cluster in an existing VNet. <br>When choosing this option, some planning is necessary.


## 1.1 Prepare Azure Environment and Administrative Console

The first three steps are executed using the Azure portal. 
Experienced users could also use the Azure CLI.


### 1.1.1 Create Resource Group

To group our infrastructure, I recommend to create a separate resource group.

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

As some variables like your resource group name or the region is required more often, create a file with this variables.

* Make sure you use your own `AZStoreAccount` name as this need to be unique.
* Make sure you use your own `AZDNSPrefix`. It needs to be unique.
* Do not used spaces in the names and the AZStoreAccount must be lower case letters and numbers only.
* Use only lower case letters for your Docker registry name. This is a Docker requirement.
* Choose the right Server for the cluster. I choose Standard_B4ms as this has enough RAM and CPU but is cheaper than then the Standard_D4_v3.
* To create a non HA environment 4 Nodes are enough. When you require that you have enough resources available when one node fails, you need 6 nodes.

```
# Write our environment settings
cat > ~/installsettings.sh <<EOF
AZRegion=westus
AZResourceGroup=CPResourceGroup
AZStoreAccount=cpstorageacct1
AZStoreName=cpshare
AZRegistryName=cpcontainerregistry
AZRegistryPrincipal=CP_Registry_Reader
AZClusterName=CPCluster
AZDNSPrefix=CP1
AZCluserNodes=4
AZClusterServer=Standard_B4ms
ic_admin_user=admin_user
ic_admin_password=admin_password
ic_internal=ic_internal
ic_front_door=ic_front_door
master_ip=
# "elasticsearch customizer orientme"
starter_stack_list="elasticsearch customizer orientme"
# for test environments with just one node or no taint nodes, set to false.
nodeAffinityRequired=true
EOF
```


## 1.3 Create a Docker Registry

To store our images, a Docker Registry is necessary.

See the [az acr create](https://docs.microsoft.com/en-us/cli/azure/acr?view=azure-cli-latest#az-acr-create) documentation for more details.

```
# Load our environment settings
. ~/installsettings.sh

# Create our Docker Registry
az acr create --resource-group $AZResourceGroup \
  --name $AZRegistryName \
  --location $AZRegion \
  --sku Basic

```
When you do not use your current computer to publish images, there is no need to login to the registry yet.

## 1.4 Create a service principal user to access your Docker Registry 

We need this service principal to autorize the kubernetes services to pull the images from the registry. IBM Component pack creates a secret named "myregkey" which needs the user id and password of this service principal.

The instructions on how to creates this account are taken from this [Microsoft documentation](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-auth-service-principal).

I slightly modified the script to use our installsettings.sh file:

```
bash beas-cnx-cloud/Azure/scripts/create_service_principal.sh

```

Write down the ID and password. We need this information later to create the kubernetes secret.


## 1.5 Create your Azure Kubernetes Environment (AKS)

By now, you have a Resource Group to group your environment and a Docker Registry to store the images. The Azure File Share to store your persistent data with ReadWriteMany access will be crated later.

** The given script creates the cluster in a separate VNet. In case you want to use other network settings, see the Microsoft Documentation first.**

As next step, we can create the Kubernetes Cluster.

* Make sure you have filled in the installsettings.sh from above when you want to use the script.
You can modify the script to your needs.
* The script will instruct the command to create ssh keys to access the VMs for you. If you want to use your already existing ssh keys, modify the script accordingly.
* The script will instruct the command to crate a service principal account for you. If you want to use your already existing service principal account, modify the script accordingly.

To start the generation process run:

```
bash beas-cnx-cloud/Azure/scripts/create_aks.sh

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
. ~/installsettings.sh

# Get RG
AZNodeRG=$(az aks show --resource-group $AZResourceGroup \
  --name $AZClusterName \
  --query "nodeResourceGroup"  | sed "s/\"//g")

# Create account
az storage account create --resource-group $AZNodeRG \
  --name $AZStoreAccount --location $AZRegion \
   --sku Standard_LRS

```

Retrieve your account key. You need it to create an Azure file share.

```
# Load our environment settings
. ~/installsettings.sh

# Get storage account key
AZStoreKey=$(az storage account keys list --resource-group $AZNodeRG \
 --account-name $AZStoreAccount --query "[0].value" | sed "s/\"//g")
echo Key: $AZStoreKey

```

Make sure you remember this key. It looks like this: `"soh3BvSw895mvxrl0MgeoPw...."`

