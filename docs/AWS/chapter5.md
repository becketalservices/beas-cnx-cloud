# 5 Install Component Pack

We need the installation files from IBM to continue.

Download the files to your Bastion host and extract them. In case you have your files on a Azure file share or AWS S3, you can use my [s3scripts](https://github.com/MSSputnik/s3scripts) to access your files.

Just extract them: `unzip IC-ComponentPack-6.0.0.6.zip`


## 5.1 Create persistent volumes

IBM provides the relevant documentation on page [Persistent volumes](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_prereqs_persist_vols.html).

The usage of my efs-aws storage class didn't work when using the helm option. Therefore the persitent volumes need to be created first.

IBM already created some helper files to create the persistent volumes. As we use AWS EFS and not NFS we need a modified version.  
Please check the IBM documentation for more details on the available parameters.  
The script below will create all storages except customizer with its default sizes on our [Create a AWS EFS Storage and Storage Class](chapter1.html#15-create-a-aws-efs-sorage-and-storage-class).

The customizer file store was created earlier: [3.2 Create the customizer persistent storage](chapter3.html#32-create-the-customizer-persistent-storage).

In your test environment you could use the AKS default store as persistent storage. This will create additional virtual hard disks that get attached to your worker nodes as required. This attachment process takes up to 1 minute and when a node becomes unresponsive, the disks must be detached manually before they can get attached to a working node. As alternative you can use AWS EFS as persistent storage. This is much more loosely coupled to your infrastructure but much slower.  
The es-pvc-backup persistent volume must be placed on a NFS file share as the local disks do not support "ReadWriteMany" access mode. The helm chart from below plces the pv on the same volume as any other. In case you selected a storage class that does not support "ReadWritMany", you need to delete this pvc and create it manually again on the efs storage.

**Attention: The reclaim policy is currently set to Delete. This will delete your storage and data in case you delete the pvc. This is different from what IBM creates with their helm chart. Do not run `helm delete connections-volumes` when you want to keep your data.**
 
```
# Run the Helm Chart to create the PVCs on our default storage
# Use storageClassName=aws-efs to store your persistent data on AWS EFS.
# The Helm Chart is a modified version from IBM. It supports the same parameters.
# You can specify more parameters if required, especially when you do not want
# all storages or different sizes.

# Load our environment settings
. ~/settings.sh

helm install ./beas-cnx-cloud/Azure/helm/connections-persistent-storage-nfs \
  --name=connections-volumes \
  --set storageClassName=$storageclass \
  --set customizer.enabled=false \
  --set solr.enabled=true \
  --set zk.enabled=true \
  --set es.enabled=true \
  --set mongo.enabled=true
 
```

Create the es-pvc-backup pvc manually in case you selected a storage class that does not support "ReadWriteMany" access:

```
# Delete existing PVC
kubectl delete pvc es-pvc-backup

# Create new PVC
tbd...

```

## 5.2 Upload Docker images to registry

IBM provides a script to upload all necessary images to your registry. Unfortunately it requires that you type in you username and password for the registry. 
Assuming that your account you are working with AWS Cli, has the rights to upload images to the registry, and the account you set up as pull secret has not, you can modify the script to ignore the username and password and just upload the images using your implicit credentials.


** Attension: AWS does not create the repositories for the images automatically. You need to create them first before docker can upload images. **

The IBM instructions are found on page [Pushing Docker images to the Docker registry](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_install_push_docker_images.html).

Modify the -st parameter to your needs. When you omit this parameter, all images are uploaded.  
As we just remove the `docker login` command from the script, the username and password parameters are still mandatory but irrelevant.

Add the URL to our docker registry to the settings.sh file. The URL is necessary later again. [Amazon ECR Registries](https://docs.aws.amazon.com/AmazonECR/latest/userguide/Registries.html)

When the task is finished and you choose to upload all images, 3.5 GB of data were uploaded to your registry.

```
# Create your ECR Repositories
for i in $(grep -Po 'docker push \${DOCKER_REGISTRY}\/\K[^:]+' setupImages.sh); \
 do aws ecr create-repository --repository-name $i; \
done 


# Login with your account to the docker registry
$(aws ecr get-login --no-include-email)

# Load our environment settings
# add ECRRegistry=aws_account_id.dkr.ecr.region.amazonaws.com
. ~/settings.sh

# move into the support directory of the IBM CP installation files
cd microservices_connections/hybridcloud/support

# Modify the installation script to comment out the docker login command.
sed -i "s/^docker login/#docker login/" setupImages.sh

# Push the required images to your registry.
# In case of problems or you need more images, you can rerun this command at any time.
# Docker will upload only what is not yet in the registry.
./setupImages.sh -dr ${ECRRegistry} \
  -u dummy \
  -p dummy \
  -st customizer,elasticsearch,orientme

```

In case you have pushed all images to the registry or you are sure you do not need more, you can remove the "images" directory and the download IC-ComponentPack-6.0.0.6.zip.zip so save disk space.

You can also remove the local docker images as they are also not necessary anymore.

```
docker rmi $(docker images -q)

```

## 5.3 Deploy Component Pack to Cluster

This chapter simply follows the instructions from IBM on page [Installing Component Pack services](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_install_services_intro.html).

All shown commands use as much default values as possible. Check IBM documentation for more options.


### 5.3.1 Bootstrapping the Kubernetes cluster

[Bootstrapping the Kubernetes Cluster](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_install_bootstrap.html)

In case you currently set up only parts of the infrastructure but plan to extend it later, make sure you set the full starter\_stack\_list="elasticsearch customizer orientme". The bootstrap process creates certificates and other required artifacts which will be missing when you create the other infrastructure components later.

**The master_ip is currently not set in the settings.sh as the master can not used to forward traffic. I assume that this configuration is for the automatic redis configuration. Probably creating the load balancer for redis at this point could give you the right IP address. For now I did not set the master_id and set "skip_configure_redis=true"**


```
# Load our environment settings
. ~/settings.sh

helm install \
--name=bootstrap microservices_connections/hybridcloud/helmbuilds/bootstrap-0.1.0-20181008-114142.tgz \
--set \
image.repository=${ECRRegistry}/connections,\
env.set_ic_admin_user=$ic_admin_user,\
env.set_ic_admin_password=$ic_admin_password,\
env.set_ic_internal=$ic_internal,\
env.set_master_ip=$master_ip,\
env.set_starter_stack_list="$starter_stack_list",\
env.skip_configure_redis=true

```


### 5.3.2 Installing the Component Pack's connections-env

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
ic.internal=$ic_internal,\
ic.interserviceOpengraphPort=443,\
ic.interserviceConnectionsPort=443,\
ic.interserviceScheme=https

```


### 5.3.3 Installing the Component Pack infrastructure

[Installing the Component Pack infrastructure](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_install_infrastructure.html)

**Only relevant for orientme and customizer**

```
# Load our environment settings
. ~/settings.sh

helm install \
--name=infrastructure microservices_connections/hybridcloud/helmbuilds/infrastructure-0.1.0-20181014-210242.tgz \
--set \
global.onPrem=true,\
global.image.repository=${ECRRegistry}/connections,\
mongodb.createSecret=false,\
appregistry-service.deploymentType=hybrid_cloud

```

Watch the container creation by issuing the command: `kubectl -n connections get pods`  
Wait until the ready state is 1/1 or 2/2 for all running pods.

### 5.3.4 Installing Orient Me

[Installing Orient Me](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_install_om.html)

**Only relevant for orientme**

When you do not use ISAM:

```
# Load our environment settings
. ~/settings.sh

helm install \
--name=orientme microservices_connections/hybridcloud/helmbuilds/orientme-0.1.0-20181014-210314.tgz \
--set \
global.onPrem=true,\
global.image.repository=${ECRRegistry}/connections,\
orient-web-client.service.nodePort=30001,\
itm-services.service.nodePort=31100,\
mail-service.service.nodePort=32721,\
community-suggestions.service.nodePort=32200

```

Watch the container creation by issuing the command: `kubectl -n connections get pods`  
Wait until the ready state is 1/1 or 2/2 for all running pods.


### 5.3.5 Installing Elasticsearch

[Installing Elasticsearch](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_install_es.html)

**Attention: In case you have only one node or did not taint the nodes for elastic search set `nodeAffinityRequired=false`.**

**Only relevant for elasitcsearch**

```
# Load our environment settings
. ~/settings.sh

helm install \
--name=elasticsearch microservices_connections/hybridcloud/helmbuilds/elasticsearch-0.1.0-20180921-115419.tgz \
--set \
image.repository=${ECRRegistry}/connections,\
nodeAffinityRequired=$nodeAffinityRequired

```

Check if all pods are running: `kubectl get pods -n connections -o wide`


### 5.3.6 Installing Customizer (mw-proxy)

[Installing Customizer (mw-proxy)](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_install_customizer.html)

**Only relevant for curstomizer**

```
# Load our environment settings
. ~/settings.sh

helm install \
--name=mw-proxy microservices_connections/hybridcloud/helmbuilds/mw-proxy-0.1.0-20181012-071823.tgz \
--set \
image.repository=${ECRRegistry}/connections,\
deploymentType=hybrid_cloud

```

Check if all pods are running: `kubectl get pods -n connections`


### 5.3.7 Installing tools for monitoring and logging

#### 5.3.7.1 Setting up Elastic Stack


##### 5.3.7.1.1 Installing Elastic Stack


##### 5.3.7.1.2 Setting up the index patterns in Kibana


##### 5.3.7.1.3 Filtering out logs


##### 5.3.7.1.4 Using the Elasticsearch Curator


#### 5.3.7.2 Installing the Kubernetes web-based dashboard

Follow the tutorial [Tutorial: Deploy the Kubernetes Web UI (Dashboard)](https://docs.aws.amazon.com/eks/latest/userguide/dashboard-tutorial.html) to install the dashboard.



Depending on how you set up your Azrue AKS instance, the dashboard is already installed.

When you used my script from [1.5 Create your Azure Kubernetes Environment](chapter1.html#15-create-your-azure-kubernetes-environment) the monitoring is already installed.<br>
You can see that pods named heapster and kubernetes-dashboard are running when you check the running pods in the kube-system namespace: `kubectl -n kube-system get pods`

As our cluster is rbac enabled, run this command to give the dashboard the required rights:

```
kubectl create clusterrolebinding kubernetes-dashboard \
  --clusterrole=cluster-admin \
  --serviceaccount=kube-system:kubernetes-dashboard

```

Follow the instructions from Microsoft to access your dashboard: <https://docs.microsoft.com/en-us/azure/aks/kubernetes-dashboard>

#### 5.3.7.3 Installing the Sanity dashboard

[Installing the Sanity dashboard](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_install_sanity.html)


```
# Load our environment settings
. ~/settings.sh


# Install Sanity Helm chart
helm install \
--name=sanity microservices_connections/hybridcloud/helmbuilds/sanity-0.1.8-20181010-163810.tgz \
--set \
image.repository=${ECRRegistry}/connections

# Install Sanity Watcher Helm chart
helm install \
--name=sanity-watcher microservices_connections/hybridcloud/helmbuilds/sanity-watcher-0.1.0-20180830-052154.tgz \
--set \
image.repository=${ECRRegistry}/connections

```

Check if all pods are running: `kubectl get pods -n connections`

To access your sanity dashboard, you can use the kubernetes proxy on your local desktop.

1. Make sure you have configured your local kubectl command correctly. See [2.1 Install and configure kubectl](chapter2.html#21-install-and-configure-kubectl).
2. Make sure you have run `aws eks update-kubeconfig --name cluster_name`

run `kubectl proxy --port=8002` on your local computer to start the local proxy service.

Use your browser to access the sanity dashboard via: <http://127.0.0.1:8002/api/v1/namespaces/connections/services/http:sanity:3000/proxy>


## 5.4 Test

### 5.4.1 Check installed helm packages

To check which helm charts you installed run: `helm list`

### 5.4.2 Check running pods

To check which applications are running, run: `kubectl -n connetions get pods`<br>
All pods should shown as running.

See IBM Documentation for more commands on page [Troubleshooting Component Pack installation or upgrade](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_install_troubleshoot_intro.html).


### 5.4.3 Kubernetes Dashboard

Use the installed Kubernetes Dashboard to inspect your infrastructure. See [5.3.7.2 Installing the Kubernetes web-based dashboard](chapter5.html#5372-installing-the-kubernetes-web-based-dashboard)
