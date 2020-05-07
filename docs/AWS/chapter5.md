# 5 Install Component Pack

We need the installation files from IBM to continue.

Download the files to your Bastion host and extract them. In case you have your files on a Azure file share or AWS S3, you can use my [s3scripts](https://github.com/MSSputnik/s3scripts) to access your files.

To fully extract the component pack archive: `unzip ComponentPack*.zip`

In case your Container Registry already contains the docker images, you can just extract the scripts and heml charts:

```
unzip ComponentPack*.zip \
  -x microservices_connections/hybridcloud/images/*

```

The commands use the configuration file created in [4.2 Create configuration files](chapter4.html#42-create-configuration-files).


## 5.1 Create persistent volumes

HCL provides the relevant documentation on page [Persistent volumes](https://help.hcltechsw.com/connections/v65/admin/install/cp_prereqs_persist_vols.html).

The usage of my efs-aws storage class didn´t work when using the helm option. Therefore the persistent volumes need to be created first.

HCL already created some helper files to create the persistent volumes. As we use AWS EFS and EBS and not native NFS we need a modified version.  
Please check the HCL documentation for more details on the available parameters.  
The script below will create all storages except customizer with its default sizes on our [Create a AWS EFS Storage and Storage Class](chapter2.html#25-create-a-aws-efs-storage-and-storage-class).

The customizer file store was created earlier: [3.2 Create the customizer persistent storage](chapter3.html#32-create-the-customizer-persistent-storage).

**Attention: When you plan to use the monitoring stack (ELK) which comes with the component pack, do not place the ElasitcSearch data volumes on EFS. EFS has a limit of 256 open files per process which will be exceeded every night causing ElasticSearch to hang.**

In your test environment you could use the EKS default store as persistent storage. This will create additional virtual hard disks that get attached to your worker nodes as required. This attachment process takes up to 1 minute and when a node becomes unresponsive, the disks must be detached manually before they can get attached to a working node. As alternative you can use AWS EFS as persistent storage. This is much more loosely coupled to your infrastructure but probably slower.  
The es-pvc-backup persistent volume must be placed on a NFS file share as the local disks do not support "ReadWriteMany" access mode. The helm chart from below places the persistent volume on the same volume as any other. In case you selected a storage class that does not support "ReadWritMany", you need to delete this persistent volume and create it manually again on the efs storage.

**Attention: The reclaim policy is currently set to Delete. This will delete your storage and data in case you delete the pvc. This is different from what HCL creates with their helm chart. Do not run `helm delete connections-volumes` when you want to keep your data. See the fix script at the end of this chapter.**
 
```
# Run the Helm Chart to create the PVCs for ElasticSearch on 
# our default storage.
# The install_cp.yaml file uses storageClassName=aws-efs to 
# store your persistent data on AWS EFS for all services.
# The Helm Chart is a modified version from HCL. 
# It supports the same parameters.
# You can specify more parameters if required, especially 
# when you do not want all storages or different sizes.


# To create all volumes on efs, you can use the generated
# install_cp.yaml configuration file:
# in case filebrowser is already up and running, you get an 
# error about customizernfsclaim which can be ignored.

helm upgrade connections-volumes \
  ./beas-cnx-cloud/Azure/helm/connections-persistent-storage-nfs \
  -i -f ./install_cp.yaml --namespace connections



# To use an EBS volume for Elastic Search use theses commands:

# Load our environment settings
. ~/installsettings.sh

# Create ElasticSearch Volumes on the default storage (gp2)
helm install ./beas-cnx-cloud/Azure/helm/connections-persistent-storage-nfs \
  --name=connections-volumes \
  --set customizer.enabled=false \
  --set solr.enabled=false \
  --set zk.enabled=false \
  --set es.enabled=true \
  --set mongo.enabled=false

# Create Solr, Zookeeper and MongoDB Volumes on the custom storage (aws-efs) 
helm install ./beas-cnx-cloud/Azure/helm/connections-persistent-storage-nfs \
  --name=connections-volumes \
  --set storageClassName=$storageclass \
  --set customizer.enabled=false \
  --set solr.enabled=true \
  --set zk.enabled=true \
  --set es.enabled=false \
  --set mongo.enabled=true
 
```

As the ElasticSearch was installed on the default storage class which does not support "ReadWireMany" we need to create the es-pvc-backup pvc manually:

```
# Delete existing PVC
kubectl -n connections delete pvc es-pvc-backup

# Create new PVC
cat << EOF > create_es_backup.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: es-pvc-backup2
  namespace: connections
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
  storageClassName: $storageclass
EOF

kubectl create -f create_es_backup.yaml

```

In case you want to move your ElasticSearch data from EFS to EBS, you can use the process [Migrate ES Data from EFS to EBS](migrate_es_data.html).

To fix the reclaim policy run: `bash beas-cnx-cloud/AWS/scripts/fix_policy_all.sh`


## 5.2 Upload Docker images to registry

HCL provides a script to upload all necessary images to your registry. Unfortunately it requires that you type in you username and password for the registry. 
Assuming that your account you are working with AWS Cli, has the rights to upload images to the registry, and the account you set up as pull secret has not, you can modify the script to ignore the username and password and just upload the images using your implicit credentials.


** Attension: AWS does not create the repositories for the images automatically. You need to create them first before docker can upload images. **

The HCL instructions are found on page [Pushing Docker images to the Docker registry](https://help.hcltechsw.com/connections/v65/admin/install/cp_install_push_docker_images.html).

Modify the -st parameter to your needs. When you omit this parameter, all images are uploaded.  
As we just remove the `docker login` command from the script, the username and password parameters are still mandatory but irrelevant.

Add the URL to our docker registry to the installsettings.sh file. The URL is necessary later again. [Amazon ECR Registries](https://docs.aws.amazon.com/AmazonECR/latest/userguide/Registries.html)

When the task is finished and you choose to upload all images, 3.5 GB of data were uploaded to your registry.

```
# Load our environment settings
# add ECRRegistry=aws_account_id.dkr.ecr.region.amazonaws.com
# add AWSRegion= - your AWS Region - 
# add starter_stack_list= - the stack list to install -
. ~/installsettings.sh

# move into the support directory of the IBM CP installation files
cd microservices_connections/hybridcloud/support

# Create your ECR Repositories
for i in $(grep -Po 'docker push \${DOCKER_REGISTRY}\/\K[^:]+' setupImages.sh); \
 do aws ecr create-repository --repository-name $i --region ${AWSRegion}; \
done 

# Login with your account to the docker registry
$(aws ecr get-login --no-include-email --region ${AWSRegion})

# Modify the installation script to comment out the docker login command.
sed -i "s/^docker login/#docker login/" setupImages.sh

# Push the required images to your registry.
# In case of problems or you need more images, you can rerun this command at any time.
# Docker will upload only what is not yet in the registry.
./setupImages.sh -dr ${ECRRegistry} \
  -u dummy \
  -p dummy \
  -st ${starter_stack_list} 

```

In case your login times out, you can always rerun the login command and the last setupImages.sh command.

In case you have pushed all images to the registry or you are sure you do not need more, you can remove the "images" directory and the download IC-ComponentPack-6.0.0.*.zip so save disk space.

You can also remove the local docker images as they are also not necessary anymore. **This command removes all locally stored docker images**

```
docker rmi $(docker images -q)

```

## 5.3 Deploy Component Pack to Cluster

This chapter simply follows the instructions from HCL on page [Installing Component Pack services](https://help.hcltechsw.com/connections/v65/admin/install/cp_install_services_intro.html).

All shown commands use as much default values as possible. Check HCL documentation for more options.

The commands use the configuration file install_cp.yaml created in [4.2 Create configuration files](chapter4.html#42-create-configuration-files).

### 5.3.1 Bootstrapping the Kubernetes cluster

[Bootstrapping the Kubernetes Cluster](https://help.hcltechsw.com/connections/v65/admin/install/cp_install_bootstrap.html)

In case you currently set up only parts of the infrastructure but plan to extend it later, make sure you set the full starter\_stack\_list="elasticsearch customizer orientme". The bootstrap process creates certificates and other required artifacts which will be missing when you create the other infrastructure components later.

**The master_ip is currently set in the installsettings.sh to your internal load balancer. The global ingress controller is used to forward traffic for Redis and Elastic Search. Depending on the status of your existing backend infrastructure, set "skip_configure_redis=false" in the configuration file which will try to configure redis traffic on your existing backend infrastructure.**


```
## Bootstrap
helmchart=$(ls microservices_connections/hybridcloud/helmbuilds/bootstrap*)
helm upgrade bootstrap $helmchart -i -f ./install_cp.yaml --namespace connections

```


### 5.3.2 Installing the Component Pack's connections-env

[Installing the Component Pack's connections-env](https://help.hcltechsw.com/connections/v65/admin/install/cp_install_connections-env.html)

```
## Connections-Env
helmchart=$(ls microservices_connections/hybridcloud/helmbuilds/connections-env*)
helm upgrade connections-env $helmchart -i -f ./install_cp.yaml --namespace connections

```

To review the generated configmap run:

```
kubectl get configmap connections-env -o yaml -n connections

```


### 5.3.3 Installing the Component Pack infrastructure

[Installing the Component Pack infrastructure](https://help.hcltechsw.com/connections/v65/admin/install/cp_install_infrastructure.html)

**Only relevant for orientme and customizer**

```
## Component Pack infrastructure
helmchart=$(ls microservices_connections/hybridcloud/helmbuilds/infrastructure*)
helm upgrade infrastructure $helmchart -i -f ./install_cp.yaml --namespace connections

```

Watch the container creation by issuing the command: `watch -n 10 kubectl -n connections get pods`  
Wait until the ready state is 1/1 or 2/2 for all running pods. It usually takes 2-3 minutes to complete.

To check that redis cluster is working as expected, run:

```
kubectl exec -it redis-server-0 -n connections -- bash /usr/bin/runRedisTools.sh --getAllRoles

```

The exected output shows that one server is the master, the others are slave:

```
PodName : Role
--------------
redis-server-0.redis-server.connections.svc.cluster.local: master
redis-server-1.redis-server.connections.svc.cluster.local: slave
redis-server-2.redis-server.connections.svc.cluster.local: slave

```


### 5.3.4 Installing Orient Me

[Installing Orient Me](https://help.hcltechsw.com/connections/v65/admin/install/cp_install_om.html)

**Only relevant for orientme**

** The configuration file created in [4.2 Create configuration files](chapter4.html#42-create-configuration-files) `install_cp.yaml` configures Orient Me to use the Elastic Search Cluster for indexing. Therefore the zookeeper and solr services are not necessary and can be shut down. **
 
When you do not use ISAM:

```
## Orient Me
helmchart=$(ls microservices_connections/hybridcloud/helmbuilds/orientme*)
helm upgrade orientme $helmchart -i -f ./install_cp.yaml --namespace connections

```

Watch the container creation by issuing the command: `watch -n 10 kubectl -n connections get pods`  
Wait until the ready state is 1/1 or 2/2 for all running pods. It usually takes up to 10 minutes to complete.

To shut down the solr and zookeeper services to save resources run:

```
kubectl -n connections scale statefulset solr --replicas=0  
kubectl -n connections scale statefulset zookeeper --replicas=0  

```

### 5.3.5 Installing the Installing Ingress Controller

[Installing Ingress Controller](https://help.hcltechsw.com/connections/v65/admin/install/cp_installing_ingress_controller.html)

**Only relevant for orientme and customizer**


```
## CNX Ingress Controller
helmchart=$(ls microservices_connections/hybridcloud/helmbuilds/cnx-ingress-*)
helm upgrade cnx-ingress $helmchart -i -f ./install_cp.yaml --namespace connections


```

Watch the container creation by issuing the command: `watch -n 10 'kubectl -n connections get pods | grep "^cnx-"'`  
Wait until the ready state is 1/1 or 2/2 for all running pods. It usually takes up to 1 minutes to complete.



### 5.3.6 Installing Elasticsearch

[Installing Elasticsearch](https://help.hcltechsw.com/connections/v65/admin/install/cp_install_es.html)

**Only relevant for elasitcsearch**

```
## Elasticsearch
helmchart=$(ls microservices_connections/hybridcloud/helmbuilds/elasticsearch*)
helm upgrade elasticsearch $helmchart -i -f ./install_cp.yaml --namespace connections

```

Check if all pods are running: `watch -n 10 'kubectl -n connections get pods | grep "^es-"'`
Wait until the ready state is 1/1 or 2/2 for all running pods. It usually takes 3 minutes to complete.


### 5.3.7 Installing Customizer (mw-proxy)

[Installing Customizer (mw-proxy)](https://help.hcltechsw.com/connections/v65/admin/install/cp_install_customizer.html)

**Only relevant for curstomizer**

```
## Customizer (mw-proxy)
helmchart=$(ls microservices_connections/hybridcloud/helmbuilds/mw-proxy*)
helm upgrade mw-proxy $helmchart -i -f ./install_cp.yaml --namespace connections

```

Check if all pods are running: `watch -n 10 'kubectl -n connections get pods | grep "^mw-"'`
Wait until the ready state is 1/1 or 2/2 for all running pods. It usually takes 1 minute to complete.

#### Add Customizer files to persistent storage

HCL delivers 3 files which should be copied onto your customizer persistent storage. 
To do so, run:

```
for file in microservices_connections/hybridcloud/support/customizer/*; do
  kubectl cp -n connections $file $(kubectl get pods -n connections | grep mw-proxy | awk 'NR==1{print $1}'):/mnt;
done

```


### 5.3.8 Installing Activities Plus services

[Installing Activities Plus services](https://help.hcltechsw.com/connections/v65/admin/install/cp_3p_install_ap_services.html)

The commands use the configuration file boards-cp.yaml created in [4.2 Create configuration files](chapter4.html#42-create-configuration-files).

**Attention: Register kudosboards as OAuth Client first and update the client secret in the boards-cp.yaml {user.env.CONNECTIONS_CLIENT_SECRET}**  
[Registering an OAuth application with a provider](https://help.hcltechsw.com/connections/v65/admin/install/cp_3p_config_ap_oauth.html)


```
# Run all commands in 1 go. The PVC must be recreated before the mini-io pod is running.

## Kudos Boards
helmchart=$(ls microservices_connections/hybridcloud/helmbuilds/kudos-boards-cp-1*)
helm upgrade kudos-boards-cp $helmchart -i -f ./boards-cp.yaml --namespace connections --recreate-pods

kctl delete pvc kudos-boards-minio-claim
kctl delete pv kudos-boards-minio
kctl apply -f beas-cnx-cloud/AWS/kubernetes/create_pvc_minio.yaml
bash beas-cnx-cloud/AWS/scripts/fix_policy_all.sh

```

Check if all pods are running: `watch -n 10 'kubectl -n connections get pods | grep "^kudos-"'`
Wait until the ready state is 1/1 or 2/2 for all running pods. It usually takes 3 minute to complete.



### 5.3.9 Installing tools for monitoring and logging

** Do not install this when you placed the elastic search on the EFS storage **

#### 5.3.9.1 Setting up Elastic Stack

[Setting up Elastic Stack](https://help.hcltechsw.com/connections/v65/admin/install/cp_prereqs_dashboards_elasticstack.html)

```
# Load our environment settings
. ~/installsettings.sh

helmchart=$(ls microservices_connections/hybridcloud/helmbuilds/elasticstack*)

helm install \
--name=elasticstack $helmchart \
--set \
global.onPrem=true,\
global.image.repository=${ECRRegistry}/connections,\
nodeAffinityRequired=$nodeAffinityRequired

```



#### 5.3.9.2 Installing the Kubernetes web-based dashboard

Follow the tutorial [Tutorial: Deploy the Kubernetes Web UI (Dashboard)](https://docs.aws.amazon.com/eks/latest/userguide/dashboard-tutorial.html) to install the dashboard.


#### 5.3.9.3 Installing the Sanity dashboard

[Installing the Sanity dashboard](https://help.hcltechsw.com/connections/v65/admin/install/cp_install_sanity.html)


```
## Sanity dashboard
helmchart=$(ls microservices_connections/hybridcloud/helmbuilds/sanity-[0-9]*)
helm upgrade sanity $helmchart -i -f ./install_cp.yaml --namespace connections

helmchart=$(ls microservices_connections/hybridcloud/helmbuilds/sanity-watcher*)
helm upgrade sanity-watcher $helmchart -i -f ./install_cp.yaml --namespace connections

```

Check if all pods are running: `watch -n 10 'kubectl -n connections get pods | grep "^sanity-"'`

To access your sanity dashboard, you can use the kubernetes proxy on your local desktop.

1. Make sure you have configured your local kubectl command correctly. See [1.3.5 Install and Configure kubectl for Amazon EKS](chapter1.html#135-install-and-configure-kubectl-for-amazon-eks).
2. Make sure you have run `aws eks update-kubeconfig --name cluster_name`

run `kubectl proxy` on your local computer to start the local proxy service.

Use your browser to access the sanity dashboard via: <http://127.0.0.1:8001/api/v1/namespaces/connections/services/http:sanity:3000/proxy>

In case you get an 401 Unauthorized error, you AWS account might not have sufficient rights on your cluster.


## 5.4 Test

### 5.4.1 Check installed helm packages

To check which helm charts you installed run: `helm list`

### 5.4.2 Check running pods

To check which applications are running, run: `kubectl -n connetions get pods`  
All pods should shown as running.

See HCL Documentation for more commands on page [Troubleshooting Component Pack installation or upgrade](https://help.hcltechsw.com/connections/v65/admin/install/cp_install_troubleshoot_intro.html).


### 5.4.3 Kubernetes Dashboard

Use the installed Kubernetes Dashboard to inspect your infrastructure. See [5.3.9.2 Installing the Kubernetes web-based dashboard](chapter5.html#5392-installing-the-kubernetes-web-based-dashboard)


## 5.5 Populating the Orient Me home page

The full procedure and more configuration options can be found in [Populating the Orient Me home page](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_om_populate_home_page.html) 

### 5.5.1 Show your migration configuraton

To view your migration configuration run:

```
kubectl exec -n connections -it $(kubectl get pods -n connections | grep people-migrate | awk '{print $1}') cat /usr/src/app/migrationConfig

```

In case something is wrong, check out the [HCL documentation](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_om_prepare_migrate_profiles.html) on how to modify the configuration.

### 5.5.2 Run migration command

In case of a larger infrastructure check out the documentation [Migrating the data for the Orient Me home page](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_om_migrate_profiles.html).

For smaller instances where you can do a full migration with just one command run:

```
kubectl exec -n connections -it $(kubectl get pods -n connections | grep people-migrate | awk '{print $1}') npm run start migrate

```

**[Configure your Network << ](chapter4.html) [ >> Configure Ingress](chapter6.html)**
