# 5 Install Component Pack

## 5.1 Deploy Component Pack to Cluster

This chapter simply follows the instructions from HCL on page [Installing Component Pack services](https://help.hcltechsw.com/connections/v65/admin/install/cp_install_services_intro.html).

All shown commands use as much default values as possible. Check HCL documentation for more options.

The commands use the configuration file install_cp.yaml created in [3.1 Create configuration files](chapter3.html#31-create-configuration-files).

### 5.1.1 Bootstrapping the Kubernetes cluster

[Bootstrapping the Kubernetes Cluster](https://help.hcltechsw.com/connections/v65/admin/install/cp_install_bootstrap.html)

In case you currently set up only parts of the infrastructure but plan to extend it later, make sure you set the full starter\_stack\_list="elasticsearch customizer orientme". The bootstrap process creates certificates and other required artifacts which will be missing when you create the other infrastructure components later.

**The master_ip is currently set in the installsettings.sh to your internal load balancer. Depending on the status of your existing backend infrastructure, set "skip_configure_redis=false" in the configuration file which will try to configure redis traffic on your existing backend infrastructure.**


```
## Bootstrap
helmchart=$(ls microservices_connections/hybridcloud/helmbuilds/bootstrap*)
helm upgrade bootstrap $helmchart -i -f ./install_cp.yaml --namespace connections

```


### 5.1.2 Installing the Component Pack's connections-env

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


### 5.1.3 Installing the Component Pack infrastructure

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


### 5.1.4 Installing Orient Me

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

### 5.1.5 Installing the Ingress Controller

[Installing Ingress Controller](https://help.hcltechsw.com/connections/v65/admin/install/cp_installing_ingress_controller.html)

**Only relevant for orientme and customizer**

To save some money, the redis traffic can be exposed through this ingress controller. To do so a appropriate config map needs to be created as the template does not exist in the helm chart.

```
## Create TCP config map
bash beas-cnx-cloud/common/scripts/cnx_ingress_tcp.sh

## CNX Ingress Controller
helmchart=$(ls microservices_connections/hybridcloud/helmbuilds/cnx-ingress-*)
helm upgrade cnx-ingress $helmchart -i -f ./install_cp.yaml --namespace connections

```

Watch the container creation by issuing the command: `watch -n 10 'kubectl -n connections get pods | grep "^cnx-"'`  
Wait until the ready state is 1/1 or 2/2 for all running pods. It usually takes up to 1 minutes to complete.

To expose the ingress controller though a load balancer run:

```
kubectl apply -f beas-cnx-cloud/AWS/kubernetes/aws-intenal-lb.yaml

```

**Map LB to your master_ip dns resolution**

experimental script:

```
bash beas-cnx-cloud/AWS/scripts/setupDNS4Ingress.sh

```


### 5.1.6 Installing Elasticsearch

[Installing Elasticsearch](https://help.hcltechsw.com/connections/v65/admin/install/cp_install_es.html)

**Only relevant for elasitcsearch**

```
## Elasticsearch
helmchart=$(ls microservices_connections/hybridcloud/helmbuilds/elasticsearch*)
helm upgrade elasticsearch $helmchart -i -f ./install_cp.yaml --namespace connections

```

Check if all pods are running: `watch -n 10 'kubectl -n connections get pods | grep "^es-"'`
Wait until the ready state is 1/1 or 2/2 for all running pods. It usually takes 3 minutes to complete.


### 5.1.7 Installing Customizer (mw-proxy)

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

Unfortunately, the files in the CP 6.5 CR1 are some html files and not correct JavaScript files.
Download the correct files from: https://github.com/OpenCode4Connections/customizer-utils into directory customizer-utils.

To upload to customizer files, run:

```
curl -L -O https://github.com/OpenCode4Connections/customizer-utils/archive/master.zip
unzip master.zip
for file in customizer-utils-master/*; do
  kubectl cp -n connections $file $(kubectl get pods -n connections | grep mw-proxy | awk 'NR==1{print $1}'):/mnt;
done

```


### 5.1.8 Installing Activities Plus services

[Installing Activities Plus services](https://help.hcltechsw.com/connections/v65/admin/install/cp_3p_install_ap_services.html)

The commands use the configuration file boards-cp.yaml created in [4.2 Create configuration files](chapter4.html#42-create-configuration-files).

**Attention: Register kudosboards as OAuth Client first and update the client secret in the boards-cp.yaml {user.env.CONNECTIONS_CLIENT_SECRET}**  
[Registering an OAuth application with a provider](https://help.hcltechsw.com/connections/v65/admin/install/cp_3p_config_ap_oauth.html)


```
# Run all commands in 1 go. The PVC must be recreated before the mini-io pod is running.

## Kudos Boards
### CNX 6.5
helmchart=$(ls microservices_connections/hybridcloud/helmbuilds/kudos-boards-cp-1*)

### CNX 6.5.0.1 - the delivered helm chart has a bug. Download the new one:
curl -LO https://docs.kudosapps.com/assets/config/kubernetes/kudos-boards-cp-1.1.1.tgz
helmchart=$(ls kudos-boards-cp-1*)
helm upgrade kudos-boards-cp $helmchart -i -f ./boards-cp.yaml --namespace connections --recreate-pods

## This commands force the deletion of the standard PVC and creates custom one.
kctl delete pvc kudos-boards-minio-claim
kctl delete pv kudos-boards-minio
kctl apply -f beas-cnx-cloud/AWS/kubernetes/create_pvc_minio.yaml
bash beas-cnx-cloud/AWS/scripts/fix_policy_all.sh

```

Check if all pods are running: `watch -n 10 'kubectl -n connections get pods | grep "^kudos-"'`
Wait until the ready state is 1/1 or 2/2 for all running pods. It usually takes 3 minute to complete.



### 5.1.9 Installing tools for monitoring and logging

#### 5.1.9.1 Setting up Elastic Stack

** Do not install this when you placed the elastic search on the EFS storage **

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



#### 5.1.9.2 Installing the Kubernetes web-based dashboard

Follow the tutorial [Tutorial: Deploy the Kubernetes Web UI (Dashboard)](https://docs.aws.amazon.com/eks/latest/userguide/dashboard-tutorial.html) to install the dashboard.


#### 5.1.9.3 Installing the Sanity dashboard

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


## 5.2 Test

### 5.2.1 Check installed helm packages

To check which helm charts you installed run: `helm list`

### 5.2.2 Check running pods

To check which applications are running, run: `kubectl -n connetions get pods`  
All pods should shown as running.

See HCL Documentation for more commands on page [Troubleshooting Component Pack installation or upgrade](https://help.hcltechsw.com/connections/v65/admin/install/cp_install_troubleshoot_intro.html).


### 5.2.3 Kubernetes Dashboard

Use the installed Kubernetes Dashboard to inspect your infrastructure. See [5.1.9.2 Installing the Kubernetes web-based dashboard](chapter5.html#5192-installing-the-kubernetes-web-based-dashboard)


## 5.3 Populating the Orient Me home page

The full procedure and more configuration options can be found in [Populating the Orient Me home page](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_om_populate_home_page.html) 

### 5.3.1 Show your migration configuraton

To view your migration configuration run:

```
kubectl exec -n connections -it $(kubectl get pods -n connections | grep people-migrate | awk '{print $1}') cat /usr/src/app/migrationConfig

```

In case something is wrong, check out the [HCL documentation](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_om_prepare_migrate_profiles.html) on how to modify the configuration.

### 5.3.2 Run migration command

In case of a larger infrastructure check out the documentation [Migrating the data for the Orient Me home page](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_om_migrate_profiles.html).

For smaller instances where you can do a full migration with just one command run:

```
kubectl exec -n connections -it $(kubectl get pods -n connections | grep people-migrate | awk '{print $1}') npm run start migrate

```

**[Configure your Network << ](chapter4.html) [ >> Integration](../integration/index.html)**
