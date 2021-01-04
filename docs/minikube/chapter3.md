# 3 Prepare cluster

We need the installation files from HCL as well to continue.

Download the files to your Bastion host and extract them. In case you have your files on a Azure file share or AWS S3, you can use my [s3scripts](https://github.com/MSSputnik/s3scripts) to access your files.

To fully extract the component pack archive: `unzip ComponentPack*.zip`

In case your Container Registry already contains the docker images, you can just extract the scripts and helm charts:

```
unzip ComponentPack*.zip \
  -x microservices_connections/hybridcloud/images/*

```

The commands use the configuration file created in [4.2 Create configuration files](chapter4.html#42-create-configuration-files).

## 3.1 Create environment configuration file

As some variables like your Docker Registry or your Elastic Search Service is required more often, create a file with these variables:  
The file must be called `installsettings.sh` and is placed in your home directory.  
Most of the scripts and commands reference this file.


```
# Write our environment settings
cat > ~/installsettings.sh <<EOF
# used connections version
installversion=65
installsubversion=10

# Connections namespace and install size
namespace=connnections
CNXSize=small  # small -> run only 1 replica per pod

# Storage settings (minikube uses 'standard' by default)
storageclass=standard

# ES settings
useStandaloneES=0
standaloneESHost="Hostname of your ES Server endpoint"
standaloneESPort=443
useSolr=0

# Docker Registry 
# hostname:port (when you have an external registry update this values)
ECRRegistry=control-plane.minikube.internal:31456

# Certificte related settings (when you want to use certbot for certificate retrieval)
acme_email="your enterprise email"
use_lestencrypt_prod="[true/false]"

# Component Pack
GlobalDomainName="$(hostname -d)"
ic_admin_user="admin_user"
ic_admin_password='admin_password'
ic_internal="ic_internal"
ic_front_door="ic_front_door"
master_ip="$HOSTNAME"
# "elasticsearch,customizer,orientme,kudos-boards"
starter_stack_list="customizer,orientme,kudos-boards"
# for test environments with just one node or no taint nodes, set to false.
nodeAffinityRequired=false

# KUDOS
KudosBoardsLicense=""
KudosBoardsClientSecret=""
db2host="activites db host"
db2port=50000
oracleservice=
oracleconnect=''
cnxdbusr="activites db user"
cnxdbpwd='activites db password'
EOF

```


# 3.2 Create configuration files for helm

To simplify the resource creation, many settings can be placed into yaml files. Theses files will then be referenced by the various installation commands.  
Currently 3 different configuration files can be created automatically.  

**Currently the script create the single domain configuration as I have not yet understood what mutlti domain means.**

**Starting with CP7.0 the configuration files are placed into $HOME/cp_config**

1. global-ingress.yaml - Used by the creation of the global-ingress-controller
2. install_cp.yaml - Used by the creations of the component pack helm charts
3. sanity_watcher.yaml - Used for the sanity watcher so that the replica count is always 1. (CP 6.x only)
4. boards-cp.yaml - Used by the creation of the activities plus helm chart

To create these files make sure, your `installsettings.sh` file is up to date, then run:

```
# Write Config Files
bash beas-cnx-cloud/common/scripts/write_cp_config.sh

```


## 3.3 Crate the connections namespace

All HCL Connections related services are deployed inside the namespace `connections` per default. See the HCL documentation in case you want to change this default.

To create the namespace run: 

```
. ~/installsettings.sh
kubectl create namespace $namespace

```

 
## 3.4 Create persistent volumes

HCL provides the relevant documentation on page [Persistent volumes](https://help.hcltechsw.com/connections/v65/admin/install/cp_prereqs_persist_vols.html).

The usage of a custom storage class didn`t work when using the helm option. Therefore the persistent volumes need to be created first.

HCL already created some helper files to create the persistent volumes. As we use AWS EFS and EBS and not native NFS we need a modified version.  
Please check the HCL documentation for more details on the available parameters.  
The script below will create all storages except customizer with its default sizes on our [Create a AWS EFS Storage and Storage Class](chapter2.html#25-create-a-aws-efs-storage-and-storage-class).

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

helm upgrade connections-volumes \
  ~/beas-cnx-cloud/Azure/helm/connections-persistent-storage-nfs \
  -i -f ~/cp_config/install_cp.yaml --namespace $namespace



## To use an EBS volume for Elastic Search use theses commands: ##

# Load our environment settings
. ~/installsettings.sh

# Create ElasticSearch Volumes on the default storage (gp2)
helm upgrade connections-volumes \
  ~/beas-cnx-cloud/Azure/helm/connections-persistent-storage-nfs \
  --set customizer.enabled=true \
  --set solr.enabled=false \
  --set zk.enabled=false \
  --set es.enabled=true \
  --set mongo.enabled=false

# Create Solr, Zookeeper and MongoDB Volumes on the custom storage (aws-efs) 
helm upgrade connections-volumes \ 
  ~/beas-cnx-cloud/Azure/helm/connections-persistent-storage-nfs \
  --set storageClassName=$storageclass \
  --set customizer.enabled=true \
  --set solr.enabled=true \
  --set zk.enabled=true \
  --set es.enabled=false \
  --set mongo.enabled=true
 
```

As the ElasticSearch was installed on the default storage class which does not support "ReadWireMany" we need to create the es-pvc-backup pvc manually:

```
# Delete existing PVC
kubectl -n $namespace delete pvc es-pvc-backup

# Create new PVC
cat << EOF > create_es_backup.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: es-pvc-backup2
  namespace: $namespace
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


To check the creation run: `kubectl -n $namespace get pvc`

Make sure the status of the created pvc is "Bound"

To fix the reclaim policy run: `bash beas-cnx-cloud/AWS/scripts/fix_policy_all.sh`


## 3.4 Upload Docker images to registry

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

# move into the support directory of the HCL CP installation files
cd microservices_connections/hybridcloud/support

# Only for ECR on AWS
 ## Create your AWS ECR Repositories 
  for i in $(grep -Po 'docker push \${DOCKER_REGISTRY}\/\K[^:]+' setupImages.sh); \
    do aws ecr create-repository --repository-name $i --region ${AWSRegion}; \
  done 

 ## Login with your account to the docker registry
 $(aws ecr get-login --no-include-email --region ${AWSRegion})

 ## Modify the installation script to comment out the docker login command.
 sed -i "s/^docker login/#docker login/" setupImages.sh

# Push the required images to your registry.
# In case of problems or you need more images, you can rerun this command at any time.
# Docker will upload only what is not yet in the registry.
./setupImages.sh -dr ${ECRRegistry} \
  -u dummy \
  -p dummy \
  -st "${starter_stack_list}"

```

In case your login times out, you can always rerun the login command and the last setupImages.sh command.

In case you have pushed all images to the registry or you are sure you do not need more, you can remove the "images" directory and the download IC-ComponentPack-6.0.0.*.zip so save disk space.

You can also remove the local docker images as they are also not necessary anymore. **This command removes all locally stored docker images**

```
docker rmi $(docker images -q)

# to force the deletion of the sanity images run
docker rmi -f $(docker images ${ECRRegistry}/connections/sanity -q)

```


**[Create your Kubernetes environment << ](chapter2.html) [ >> Install Component Pack](chapter4.html)**
