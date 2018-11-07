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

>Open the Azure Portal and create a new Resource Group.

**Azure CLI**

>When you have the Azure CLI ready on your computer, you also could use those:

>See the [official documentation](https://docs.microsoft.com/en-us/cli/azure/group?view=azure-cli-latest#az-group-create) for more details.

>```
az group create --location westus --name CPResourceGroup
```

### Crate a Bastion Host in your resource group to administer your cluster

The bastion host will be a small Linux host to upload the docker images to the registry and administer the cluster.
It is recommended that the host is in the same resource group as your kubernetes cluster. This will simplify the access to the cluster resources and the administration.

The host can use a very small server e.g. Standard_B1s or Basic_A1 as no compute power is necessary.

**Azure Portal**

>Open the Azure Portal and create the Bastion Host.
Place the host into the the new Resource Group and in the same region as you will use for your Kubernetes Cluster.

> * Use CentOS as OS for the Bastion Host. Other Linux systems should also be possible as long as you can install Docker CE onto them.
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
git clone https://github.com/xxx/yyy.git
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
* Do not used spaces in the names and the AZStoreAccount must be lower case letters and numbers only.

```
cat > ~/settings.sh <<EOF
AZRegion=westus
AZResourceGroup=CPResourceGroup
AZStoreAccount=cpstorageacct1
AZStoreName=cpshare
EOF
```


### Create a Docker Registry

To store our images, a Docker Registry is necessary.

See the [az acr create](https://docs.microsoft.com/en-us/cli/azure/acr?view=azure-cli-latest#az-acr-create) documentation for more details.

```
. ~/settings.sh
az acr create --resource-group $AZResourceGroup --name CPContainerRegistry --sku Basic
```
When you do not use our current computer to publish images, there is no need to login to the registry yet.


### Create a Azure File Storage

#### Create a storage account

To access your storage, the storage account is necessary.

Create your new storage account: You need to choose a unique name, so do not use mine.

```
. ~/settings.sh
az storage account create --resource-group $AZResourceGroup \
  --name $AZStoreAccount --location $AZRegion \
   --sku Standard_LRS

```

Retrieve your account key:

```
. ~/settings.sh
AZStoreKey=$(az storage account keys list --resource-group $AZResourceGroup \
 --account-name $AZStoreAccount --query "[0].value")
echo Key: $AZStoreKey
```

Make sure you remember this key. It looks like this: `"soh3BvSw895mvxrl0MgeoPw...."`


#### Create an Azure file share

Create the file share using your storage account data.

```
. ~/settings.sh
az storage share create --account-name $AZStoreAccount --account-key "$AZStoreKey" --name "$AZStoreName"
```


## Create your Azure Kubernetes Environment (AKS)

By now, you have a Resource Group to group your environment, a Docker Registry to store the images and a Azure File Share to store your persistent data with ReadWriteMany access.

As next step, we can create 

