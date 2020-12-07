# 4 Install Component Pack

## 4.1 Deploy Component Pack to Cluster

This chapter simply follows the instructions from HCL on page [Installing Component Pack services](https://help.hcltechsw.com/connections/v65/admin/install/cp_install_services_intro.html).

All shown commands use as much default values as possible. Check HCL documentation for more options.

The commands use the configuration file install_cp.yaml created in [3.2 Create configuration files for helm](chapter3.html#31-create-configuration-files-for-helm).

**IMPORTATNT FOR PROVE OF CONCEPT - MINIMAL INSTALL**  
**Make sure you have set "CNXSize=small" in your installsettings.sh so that the replicaCount of all features was set to 1 in the install_cp.yaml file**

Load the common configuration:
```
. ~/installsettings.sh

```

### 4.1.1 Bootstrapping the Kubernetes cluster

[Bootstrapping the Kubernetes Cluster](https://help.hcltechsw.com/connections/v65/admin/install/cp_install_bootstrap.html)

In case you currently set up only parts of the infrastructure but plan to extend it later, make sure you set the full starter\_stack\_list="elasticsearch customizer orientme". The bootstrap process creates certificates and other required artifacts which will be missing when you create the other infrastructure components later.

**The master_ip is currently set in the installsettings.sh to your internal load balancer. The global ingress controller is used to forward traffic for Redis and Elastic Search. Depending on the status of your existing backend infrastructure, set "skip_configure_redis=false" in the configuration file which will try to configure redis traffic on your existing backend infrastructure.**


```
## Bootstrap
helmchart=$(ls microservices_connections/hybridcloud/helmbuilds/bootstrap*)
helm upgrade bootstrap $helmchart -i -f ~/install_cp.yaml --namespace $CNXNS

```


### 4.1.2 Installing the Component Pack's connections-env

[Installing the Component Pack's connections-env](https://help.hcltechsw.com/connections/v65/admin/install/cp_install_connections-env.html)

```
## Connections-Env
helmchart=$(ls microservices_connections/hybridcloud/helmbuilds/connections-env*)
helm upgrade connections-env $helmchart -i -f ~/install_cp.yaml --namespace $CNXNS

```

To review the generated configmap run:

```
kubectl get configmap connections-env -o yaml -n $CNXNS

```


### 4.1.3 Installing the Component Pack infrastructure

[Installing the Component Pack infrastructure](https://help.hcltechsw.com/connections/v65/admin/install/cp_install_infrastructure.html)

**Only relevant for orientme and customizer**

```
## Component Pack infrastructure
helmchart=$(ls microservices_connections/hybridcloud/helmbuilds/infrastructure*)
helm upgrade infrastructure $helmchart -i -f ~/install_cp.yaml --namespace $CNXNS

```

Watch the container creation by issuing the command: `watch -n 10 kubectl -n $CNXNS get pods`  
Wait until the ready state is 1/1 or 2/2 for all running pods. It usually takes 2-3 minutes to complete.

To check that redis cluster is working as expected, run:

```
kubectl exec -it redis-server-0 -n $CNXNS -- bash /usr/bin/runRedisTools.sh --getAllRoles

```

The exected output shows that one server is the master, the others are slave:

```
PodName : Role
--------------
redis-server-0.redis-server.connections.svc.cluster.local: master
redis-server-1.redis-server.connections.svc.cluster.local: slave
redis-server-2.redis-server.connections.svc.cluster.local: slave

```

**On PoC deployment, scale your pods.**


### 4.1.4 Installing Elasticsearch

[Installing Elasticsearch](https://help.hcltechsw.com/connections/v65/admin/install/cp_install_es.html)

**Only relevant for elasitcsearch on kubernetes**

```
## Elasticsearch
helmchart=$(ls microservices_connections/hybridcloud/helmbuilds/elasticsearch*)
helm upgrade elasticsearch $helmchart -i -f ~/install_cp.yaml --namespace $CNXNS

```

Check if all pods are running: `watch -n 10 'kubectl -n $CNXNS get pods | grep "^es-"'`
Wait until the ready state is 1/1 or 2/2 for all running pods. It usually takes 3 minutes to complete.


### 4.1.5 Installing Orient Me

[Installing Orient Me](https://help.hcltechsw.com/connections/v65/admin/install/cp_install_om.html)

**Only relevant for orientme**

** The configuration file created in [4.2 Create configuration files](chapter4.html#42-create-configuration-files) `install_cp.yaml` configures Orient Me to use the Elastic Search Cluster for indexing. Therefore the zookeeper and solr services are not necessary and can be shut down. **
 
When you do not use ISAM:

```
## Orient Me
helmchart=$(ls microservices_connections/hybridcloud/helmbuilds/orientme*)
helm upgrade orientme $helmchart -i -f ~/install_cp.yaml --namespace $CNXNS

```

Watch the container creation by issuing the command: `watch -n 10 kubectl -n $CNXNS get pods`  
Wait until the ready state is 1/1 or 2/2 for all running pods. It usually takes up to 10 minutes to complete.

To shut down the solr and zookeeper services to save resources run:

```
bash beas-cnx-cloud/common/scripts/solr.sh 0

```

**On PoC deployment, scale your pods.**


### 4.1.6 Installing the Installing Ingress Controller

[Installing Ingress Controller](https://help.hcltechsw.com/connections/v65/admin/install/cp_installing_ingress_controller.html)

**Only relevant for orientme and customizer**


```
## CNX Ingress Controller
helmchart=$(ls microservices_connections/hybridcloud/helmbuilds/cnx-ingress-*)
helm upgrade cnx-ingress $helmchart -i -f ~/install_cp.yaml --namespace $CNXNS

```

Watch the container creation by issuing the command: `watch -n 10 'kubectl -n $CNXNS get pods | grep "^cnx-"'`  
Wait until the ready state is 1/1 or 2/2 for all running pods. It usually takes up to 1 minutes to complete.


**On PoC deployment, scale your pods.**


### 4.1.7 Installing Customizer (mw-proxy)

[Installing Customizer (mw-proxy)](https://help.hcltechsw.com/connections/v65/admin/install/cp_install_customizer.html)

**Only relevant for curstomizer**

```
## Customizer (mw-proxy)
helmchart=$(ls microservices_connections/hybridcloud/helmbuilds/mw-proxy*)
helm upgrade mw-proxy $helmchart -i -f ~/install_cp.yaml --namespace $CNXNS

```

Check if all pods are running: `watch -n 10 'kubectl -n $CNXNS get pods | grep "^mw-"'`
Wait until the ready state is 1/1 or 2/2 for all running pods. It usually takes 1 minute to complete.

#### Add Customizer files to persistent storage

HCL delivers 3 files which should be copied onto your customizer persistent storage. 
To do so, run:

```
for file in microservices_connections/hybridcloud/support/customizer/*; do
  kubectl cp -n $CNXNS $file $(kubectl get pods -n $CNXNS | grep mw-proxy | awk 'NR==1{print $1}'):/mnt;
done

```


### 4.1.8 Installing Activities Plus services

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
helm upgrade kudos-boards-cp $helmchart -i -f ./boards-cp.yaml --namespace $CNXNS --recreate-pods

## This commands force the deletion of the standard PVC and creates custom one.
kctl delete pvc kudos-boards-minio-claim
kctl delete pv kudos-boards-minio
kctl apply -f beas-cnx-cloud/AWS/kubernetes/create_pvc_minio.yaml
bash beas-cnx-cloud/AWS/scripts/fix_policy_all.sh

```

Check if all pods are running: `watch -n 10 'kubectl -n $CNXNS get pods | grep "^kudos-"'`
Wait until the ready state is 1/1 or 2/2 for all running pods. It usually takes 3 minute to complete.



### 4.1.9 Installing tools for monitoring and logging

#### 4.1.9.1 Setting up Elastic Stack

** Do not install this when you placed the elastic search on the EFS storage **  
** Do not install this for PoC deployment.**

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



#### 4.1.9.2 Installing the Kubernetes web-based dashboard

** For minikube deployment add the dashboard via minikube addon**

Follow the tutorial [Tutorial: Deploy the Kubernetes Web UI (Dashboard)](https://docs.aws.amazon.com/eks/latest/userguide/dashboard-tutorial.html) to install the dashboard.


#### 4.1.9.3 Installing the Sanity dashboard

[Installing the Sanity dashboard](https://help.hcltechsw.com/connections/v65/admin/install/cp_install_sanity.html)


```
## Sanity dashboard
helmchart=$(ls microservices_connections/hybridcloud/helmbuilds/sanity-[0-9]*)
helm upgrade sanity $helmchart -i -f ~/install_cp.yaml --namespace $CNXNS

helmchart=$(ls microservices_connections/hybridcloud/helmbuilds/sanity-watcher*)
helm upgrade sanity-watcher $helmchart -i -f ~/install_cp.yaml --set replicaCount='1' --namespace $CNXNS 

## scale sanity down to 1 for minimal setup. 
## sanity-watcher makes shure that santy runns always with 3 pods by using helm.
## modification of helm chart does not help in this case.
kubectl -n $CNXNS scale deployment sanity --replicas=1

```

Check if all pods are running: `watch -n 10 'kubectl -n $CNXNS get pods | grep "^sanity-"'`

To access your sanity dashboard, you can use the kubernetes proxy on your local desktop.

1. Make sure you have configured your local kubectl command correctly. See [1.3.5 Install and Configure kubectl for Amazon EKS](chapter1.html#135-install-and-configure-kubectl-for-amazon-eks).
2. Make sure you have run `aws eks update-kubeconfig --name cluster_name`

run `kubectl proxy` on your local computer to start the local proxy service.

Use your browser to access the sanity dashboard via: <http://127.0.0.1:8001/api/v1/namespaces/connections/services/http:sanity:3000/proxy>

In case you get an 401 Unauthorized error, you AWS account might not have sufficient rights on your cluster.


## 4.2 Test

### 4.2.1 Check installed helm packages

To check which helm charts you installed run: `helm list`

### 4.2.2 Check running pods

To check which applications are running, run: `kubectl -n connetions get pods`  
All pods should shown as running.

See HCL Documentation for more commands on page [Troubleshooting Component Pack installation or upgrade](https://help.hcltechsw.com/connections/v65/admin/install/cp_install_troubleshoot_intro.html).


### 4.2.3 Kubernetes Dashboard

Use the installed Kubernetes Dashboard to inspect your infrastructure. See [4.1.9.2 Installing the Kubernetes web-based dashboard](chapter5.html#5192-installing-the-kubernetes-web-based-dashboard)



**[Prepare cluster << ](chapter3.html) [ >> Integration](../integration/index.html)**
