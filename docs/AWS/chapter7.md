# 7 Update Component Pack
This process does the update to Component Pack 6.0.0.8

We need the installation files from IBM to continue.

Download the files to your Bastion host and extract them. In case you have your files on a Azure file share or AWS S3, you can use my [s3scripts](https://github.com/MSSputnik/s3scripts) to access your files.

Just extract them: `unzip IC-ComponentPack-6.0.0.8.zip`


## 7.1 Upload Docker images to registry
IBM provides a script to upload all necessary images to your registry. Unfortunately it requires that you type in you username and password for the registry. 
Assuming that your account you are working with AWS Cli, has the rights to upload images to the registry, and the account you set up as pull secret has not, you can modify the script to ignore the username and password and just upload the images using your implicit credentials.


** Attension: AWS does not create the repositories for the images automatically. You need to create them first before docker can upload images. **

The IBM instructions are found on page [Pushing Docker images to the Docker registry](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_install_push_docker_images.html).

Modify the -st parameter to your needs. When you omit this parameter, all images are uploaded.  
As we just remove the `docker login` command from the script, the username and password parameters are still mandatory but irrelevant.

Add the URL to our docker registry to the settings.sh file. The URL is necessary later again. [Amazon ECR Registries](https://docs.aws.amazon.com/AmazonECR/latest/userguide/Registries.html)

When the task is finished and you choose to upload all images, 3.5 GB of data were uploaded to your registry.

```
## Depending on your docker installation, this commands must be executed as root.

# move into the support directory of the IBM CP installation files
cd microservices_connections/hybridcloud/support

# Create your ECR Repositories
for i in $(grep -Po 'docker push \${DOCKER_REGISTRY}\/\K[^:]+' setupImages.sh); \
 do aws ecr create-repository --repository-name $i; \
done 

# Login with your account to the docker registry
$(aws ecr get-login --no-include-email)

# Load our environment settings
# add ECRRegistry=aws_account_id.dkr.ecr.region.amazonaws.com
. ~/settings.sh

# Modify the installation script to comment out the docker login command.
sed -i "s/^docker login/#docker login/" setupImages.sh

# Push the required images to your registry.
# In case of problems or you need more images, you can rerun this command at any time.
# Docker will upload only what is not yet in the registry.
./setupImages.sh -dr ${ECRRegistry} \
  -u dummy \
  -p dummy \
  -st customizer,elasticsearch,orientme

# back to the root directory
cd 

```

In case your login times out, you can always rerun the login command and the last setupImages.sh command.

In case you have pushed all images to the registry or you are sure you do not need more, you can remove the "images" directory and the download IC-ComponentPack-6.0.0.*.zip so save disk space.

You can also remove the local docker images as they are also not necessary anymore. **This command removes all locally stored docker images**

```
docker rmi $(docker images -q)

```

## 7.2 Deploy Component Pack Updates to Cluster

This chapter simply follows the instructions from IBM on page [Upgrading Component Pack to the latest version](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_install_upgrade_latest_versions.html).

All shown commands use as much default values as possible. Check IBM documentation for more options.

### 7.2.1 Updating the Component Pack's connections-env

```
# Load our environment settings
. ~/settings.sh

helm upgrade \
  connections-env microservices_connections/hybridcloud/helmbuilds/connections-env-0.1.40-20190122-110818.tgz \
--set \
onPrem=true,\
createSecret=false,\
ic.host=$ic_front_door,\
ic.internal=$ic_internal,\
ic.interserviceOpengraphPort=443,\
ic.interserviceConnectionsPort=443,\
ic.interserviceScheme=https

```

### 7.2.2 Updating the Component Pack infrastructure

**Only relevant for orientme and customizer**

```
# Load our environment settings
. ~/settings.sh

helm upgrade \
  infrastructure microservices_connections/hybridcloud/helmbuilds/infrastructure-0.1.0-20190329-081444.tgz \
--set \
global.onPrem=true,\
global.image.repository=${ECRRegistry}/connections,\
mongodb.createSecret=false,\
appregistry-service.deploymentType=hybrid_cloud

```

Watch the container creation by issuing the command: `watch -n 10 "kubectl -n connections get pods"`  
Wait until the ready state is 1/1 or 2/2 for all running pods.

### 7.2.3 Updating OrientMe

**Only relevant for orientme**

When you do not use ISAM:

```
# Load our environment settings
. ~/settings.sh

helm upgrade \
  orientme microservices_connections/hybridcloud/helmbuilds/orientme-0.1.0-20190329-081601.tgz \
--set \
global.onPrem=true,\
global.image.repository=${ECRRegistry}/connections,\
orient-web-client.service.nodePort=30001,\
itm-services.service.nodePort=31100,\
mail-service.service.nodePort=32721,\
community-suggestions.service.nodePort=32200

```

Watch the container creation by issuing the command: `watch -n 10 "kubectl -n connections get pods"`  
Wait until the ready state is 1/1 or 2/2 for all running pods.


### 7.2.4 Updating Elasticsearch

**Attention: In case you have only one node or did not taint the nodes for elastic search set `nodeAffinityRequired=false`.**

**Only relevant for elasitcsearch**

```
# Load our environment settings
. ~/settings.sh

helm upgrade \
  elasticsearch microservices_connections/hybridcloud/helmbuilds/elasticsearch-0.1.0-20190314-020037.tgz \
--set \
image.repository=${ECRRegistry}/connections,\
nodeAffinityRequired=$nodeAffinityRequired

```

Check if all pods are running: `watch -n 10 "kubectl get pods -n connections -o wide"`

### 7.2.5 Upgrading Customizer (mw-proxy)

**Only relevant for curstomizer**

```
# Load our environment settings
. ~/settings.sh

helm upgrade \
  mw-proxy microservices_connections/hybridcloud/helmbuilds/mw-proxy-0.1.0-20190328-020041.tgz \
--set \
image.repository=${ECRRegistry}/connections,\
deploymentType=hybrid_cloud

```

Check if all pods are running: `watch -n 10 "kubectl get pods -n connections"`

#### 7.2.6 Upgrading the Sanity dashboard

```
# Load our environment settings
. ~/settings.sh


# Upgrade Sanity Helm chart
helm upgrade \
  sanity microservices_connections/hybridcloud/helmbuilds/sanity-0.1.8-20190321-150210.tgz \
--set \
image.repository=${ECRRegistry}/connections

# Upgrade Sanity Watcher Helm chart
helm upgrade \
  sanity-watcher microservices_connections/hybridcloud/helmbuilds/sanity-watcher-0.1.0-20190328-022032.tgz \
--set \
image.repository=${ECRRegistry}/connections

```

#### 7.2.7 Upgrade Elastic Stack

```
# Load our environment settings
. ~/settings.sh


helm upgrade \
  elasticstack microservices_connections/hybridcloud/helmbuilds/elasticstack-0.1.0-20190205-020155.tgz \
--set \
global.onPrem=true,\
global.image.repository=${ECRRegistry}/connections,\
nodeAffinityRequired=$nodeAffinityRequired

```

## 7.3 Installing cnx-ingress
The installation of the new ingress controller was not yet tested. 
Need to check if this solution is better than the already deployed ingress controller.

