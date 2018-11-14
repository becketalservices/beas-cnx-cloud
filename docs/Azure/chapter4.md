# 4. Install Component Pack

We need the installation files from IBM to continue.

Download the files to your Bastion host and extract them. In case you have your files on a Azure file share or AWS S3, you can use my [s3scripts](https://github.com/MSSputnik/s3scripts) to access your files.

Just extract them: `unzip IC-ComponentPack-6.0.0.6.zip`


## 4.1 Create persistent volumes

IBM provides the relevant documentation here: <https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_prereqs_persist_vols.html>

IBM already created some helper files to create the persistent volumes. As we use Azure File and not  NFS we need a modified version.<br>
Please check the IBM documentation for more details on the available parameters.<br>
The script below will create all storages except customizer with its default sizes on our [azure file store which was created earlier](chapter1.html#16-create-a-azure-file-storage).

The customizer file store was created earlier: [3.2 Create the customizer persistent storage](chapter3.html#32-create-the-customizer-persistent-storage).


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
Use the credentials of the service principal we created earlier in [Create a service principal user to access your Docker Registry](chapter1.html#14-create-a-service-principal-user-to-access-your-docker-registry).

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


## 4.6 Test
