# 5 Install Component Pack

## 5.1 Deploy Component Pack to Cluster

This chapter simply follows the instructions from HCL on page [Installing Component Pack services](https://help.hcltechsw.com/connections/v65/admin/install/cp_install_services_intro.html).

All shown commands use as much default values as possible. Check HCL documentation for more options.

The commands use the configuration file install_cp.yaml created in [3.1 Create configuration files](chapter3.html#31-create-configuration-files).

For more details see HCL Documentation [Sample steps to install or upgrade Component Pack](https://help.hcltechsw.com/connections/v7/admin/install/cp_install_services_tasks.html)

**Load configuration to set enviornment variable namespace**

`. ~/installsettings.sh`

### 5.1.1 Set up pod security policies

[Set up pod security policies](https://help.hcltechsw.com/connections/v7/admin/install/cp_install_services_tasks.html#cp_install_services_tasks__section_yh5_sc5_tnb)

```
helm upgrade k8s-psp ~/microservices_connections/hybridcloud/helmbuilds/k8s-psp-*.tgz -i --namespace $namespace

```

### 5.1.2 Bootstrapping the Kubernetes cluster

[Set up bootstrap charts](https://help.hcltechsw.com/connections/v7/admin/install/cp_install_services_tasks.html#cp_install_services_tasks__section_iqb_24c_qmb)

In case you currently set up only parts of the infrastructure but plan to extend it later, make sure you set the starter\_stack\_list="". The bootstrap process creates certificates and other required artifacts which will be missing when you create the other infrastructure components later. Especially when you plan to have a stand alone Elasticsearch cluster you still need to have the certificates created, otherwise the indexer and retrieval pod will not start independend if the certificates are requred or not. 

**The master_ip is currently set in the installsettings.sh to your internal load balancer. Depending on the status of your existing backend infrastructure, set "skip_configure_redis=false" in the configuration file which will try to configure redis traffic on your existing backend infrastructure.**


```
## Bootstrap
helm upgrade bootstrap ~/microservices_connections/hybridcloud/helmbuilds/bootstrap*.tgz -i -f ~/cp_config/install_cp.yaml --namespace $namespace

```


### 5.1.3 Installing the Component Pack's connections-env

[Set up connections-env charts](https://help.hcltechsw.com/connections/v7/admin/install/cp_install_services_tasks.html#cp_install_services_tasks__section_p2w_spc_qmb)

```
## Connections-Env
helm upgrade connections-env ~/microservices_connections/hybridcloud/helmbuilds/connections-env-*.tgz -i -f ~/cp_config/install_cp.yaml --namespace $namespace

```

To review the generated configmap run:

```
kubectl get configmap connections-env -o yaml -n $namespace

# if msteams is enabled
kubectl get configmap integrations-msteams-env -o yaml -n $namespace
kubectl get secret ms-teams-secret -n $namespace

```


### 5.1.4 Installing the Component Pack infrastructure

[Set up infrastructure charts](https://help.hcltechsw.com/connections/v7/admin/install/cp_install_services_tasks.html#cp_install_services_tasks__section_tcv_5t5_tnb)

**Only relevant for orientme and customizer**

```
## Component Pack infrastructure
helm upgrade infrastructure ~/microservices_connections/hybridcloud/helmbuilds/infrastructure-*.tgz -i -f ~/cp_config/install_cp.yaml --namespace $namespace 

```

Watch the container creation by issuing the command: `watch -n 10 kubectl -n $namespace get pods`  
Wait until the ready state is 1/1 or 2/2 for all running pods. It usually takes 2-3 minutes to complete.

To check that redis cluster is working as expected, run:

```
kubectl exec -it redis-server-0 -n $connections -- bash /usr/bin/runRedisTools.sh --getAllRoles

```

The exected output shows that one server is the master, the others are slave:

```
PodName : Role
--------------
redis-server-0.redis-server.connections.svc.cluster.local: master
redis-server-1.redis-server.connections.svc.cluster.local: slave
redis-server-2.redis-server.connections.svc.cluster.local: slave

```

To check that mongo cluster is working as expected, run:

```
kubectl exec -it mongo-0 -c mongo -n $namespace -- mongo --ssl --sslPEMKeyFile /etc/mongodb/x509/user_admin.pem --sslCAFile /etc/mongodb/x509/mongo-CA-cert.crt \
  --host mongo-1.mongo.$namespace.svc.cluster.local --authenticationMechanism=MONGODB-X509 --authenticationDatabase '$external' \
  -u C=IE,ST=Ireland,L=Dublin,O=IBM,OU=Connections-Middleware-Clients,CN=admin,emailAddress=admin@mongodb --eval "rs.status()"

```

The exected output shows the overall state and that one server is the primary, the others are secondary:

```
MongoDB server version: 3.6.7
{
        "set" : "rs0",
        "date" : ISODate("2021-01-04T09:54:03.881Z"),
        "myState" : 2,
        "term" : NumberLong(1),
        "syncingTo" : "mongo-0.mongo.connections.svc.cluster.local:27017",
        "syncSourceHost" : "mongo-0.mongo.connections.svc.cluster.local:27017",
        "syncSourceId" : 0,
        "heartbeatIntervalMillis" : NumberLong(2000),
....
        "members" : [
.. -> here you see who is primary and who is secondeay.
        ],
        "ok" : 1,
....
}

```


### 5.1.5 Installing Customizer (mw-proxy)

[Set up Customizer](https://help.hcltechsw.com/connections/v7/admin/install/cp_install_services_tasks.html#cp_install_services_tasks__section_erc_3hd_qmb)

**Only relevant for curstomizer**

```
## Customizer (mw-proxy)
helm upgrade mw-proxy ~/microservices_connections/hybridcloud/helmbuilds/mw-proxy-*.tgz -i -f ~/cp_config/install_cp.yaml --namespace $namespace 

```

Check if all pods are running: `watch -n 10 "kubectl -n $namespace get pods | grep '^mw-'"`
Wait until the ready state is 1/1 or 2/2 for all running pods. It usually takes 1 minute to complete.

#### Add Customizer files to persistent storage

HCL delivers 3 files which should be copied onto your customizer persistent storage. 


**CP 6.5**
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

**CP 7**
To upload to customizer files, run:

```
destpod=$(kubectl get pods -n $namespace | grep mw-proxy | awk 'NR==1{print $1}')
for file in ~/microservices_connections/hybridcloud/support/customizer/*; do
  kubectl cp -n $namespace $file $destpod:/mnt;
done

# ms-teams
kubectl cp -n $namespace ~/microservices_connections/hybridcloud/support/ms-teams $destpod:/mnt/ms-teams

```

### 5.1.6 Installing Elasticsearch

[Set up Elasticsearch 7.6.1 charts](https://help.hcltechsw.com/connections/v7/admin/install/cp_install_services_tasks.html#cp_install_services_tasks__section_tvw_xyd_qmb)

**Only relevant for elasitcsearch**

```
## Elasticsearch
if [ -n "$installversion" -a "$installversion" -lt 70 ]; then 
  echo CP6.x
  helm upgrade elasticsearch ~/microservices_connections/hybridcloud/helmbuilds/elasticsearch-*.tgz -i -f ~/cp_config/install_cp.yaml --namespace $namespace
else
  echo CP7
  helm upgrade elasticsearch ~/microservices_connections/hybridcloud/helmbuilds/elasticsearch7-*.tgz -i -f ~/cp_config/install_cp.yaml --namespace $namespace
fi

```

Check if all pods are running: `watch -n 10 "kubectl -n $namespace get pods | grep '^es-'"`
Wait until the ready state is 1/1 or 2/2 for all running pods. It usually takes 3 minutes to complete.


### 5.1.7 Installing the Ingress Controller

[Set up ingress](https://help.hcltechsw.com/connections/v7/admin/install/cp_install_services_tasks.html#cp_install_services_tasks__section_hrm_rqc_qmb)

**Only relevant for orientme and customizer**

**For compatibilty with CP6.x is use the cnx-ingress here. More instructions to use the community ingress with CP7 will follow.**

To save some money, the redis traffic can be exposed through this ingress controller. To do so a appropriate config map needs to be created as the template does not exist in the helm chart.

```
## Create TCP config map
bash beas-cnx-cloud/common/scripts/cnx_ingress_tcp.sh

## CNX Ingress Controller
helm upgrade cnx-ingress ~/microservices_connections/hybridcloud/helmbuilds/cnx-ingress-*.tgz -i -f ~/cp_config/install_cp.yaml --namespace $namespace

```

Watch the container creation by issuing the command: `watch -n 10 "kubectl -n $namespace get pods | grep '^cnx-'"`  
Wait until the ready state is 1/1 or 2/2 for all running pods. It usually takes up to 1 minutes to complete.

To expose the ingress controller though a load balancer run:

```
bash beas-cnx-cloud/AWS/scripts/aws-intenal-lb.sh

```

**Map LB to your master_ip dns resolution**

experimental script:

```
bash beas-cnx-cloud/AWS/scripts/setupDNS4Ingress.sh

```


### 5.1.8 Installing MSTeams integration

[Set up Microsoft Teams integration](https://help.hcltechsw.com/connections/v7/admin/install/cp_install_services_tasks.html#cp_install_services_tasks__section_dvq_wlv_tnb)

**Only relevant for MS Teams integraion**

**Make sure the configmaps are alread created in the step 5.1.3 Installing the Component Pack's connections-env**

```
## MSTeams
helm upgrade teams  ~/microservices_connections/hybridcloud/helmbuilds/teams-*.tgz -i -f ~/cp_config/install_cp.yaml --namespace $namespace

```


### 5.1.9 Installing Tailored Experience features for communities

[Set up Tailored Experience features for communities](https://help.hcltechsw.com/connections/v7/admin/install/cp_install_services_tasks.html#cp_install_services_tasks__section_fwj_l5v_tnb)

```
## Tailored Experience
helm upgrade tailored-exp ~/microservices_connections/hybridcloud/helmbuilds/tailored-exp-*.tgz -i -f ~/cp_config/install_cp.yaml --namespace $namespace

```


### 5.1.10 Installing Orient Me

[Set up Orient Me](https://help.hcltechsw.com/connections/v7/admin/install/cp_install_services_tasks.html#cp_install_services_tasks__section_bny_zxd_qmb)

**Only relevant for orientme**

** The configuration file created in [4.2 Create configuration files](chapter4.html#42-create-configuration-files) `install_cp.yaml` configures Orient Me to use the Elastic Search Cluster for indexing. Therefore the zookeeper and solr services are not necessary and can be shut down. **
 
When you do not use ISAM:

```
## Orient Me
helm upgrade orientme ~/microservices_connections/hybridcloud/helmbuilds/orientme-*.tgz -i -f ~/cp_config/install_cp.yaml --namespace connections

```

Watch the container creation by issuing the command: `watch -n 10 kubectl -n connections get pods`  
Wait until the ready state is 1/1 or 2/2 for all running pods. It usually takes up to 10 minutes to complete.

To shut down the solr and zookeeper services to save resources run:

```
kubectl -n connections scale statefulset solr --replicas=0  
kubectl -n connections scale statefulset zookeeper --replicas=0  

```

### 5.1.11 Installing Activities Plus services

**[ISW](https://www.kudosapps.com/) releases product updates regularily. I recommend to install their latest release.**

To install the latest release see [Activities Plus Install FAQ](https://docs.kudosapps.com/boards/troubleshooting/activities-plus-install/) and Releases[](https://docs.kudosapps.com/boards/cp/releases/)

To install the release published by HCL:

[Set up Activities Plus](https://help.hcltechsw.com/connections/v7/admin/install/cp_install_services_tasks.html#cp_install_services_tasks__section_hvq_xlw_tnb)

The commands use the configuration file boards-cp.yaml created in [4.2 Create configuration files](chapter4.html#42-create-configuration-files).

**Attention: Register kudosboards as OAuth Client first and update the client secret in the boards-cp.yaml {user.env.CONNECTIONS_CLIENT_SECRET}** 

[Registering an OAuth application with a provider](https://help.hcltechsw.com/connections/v7/admin/install/cp_3p_config_ap_oauth.html)


```
# Run all commands in 1 go. The PVC must be recreated before the mini-io pod is running.

# Load configuration
. ~/installsettings

## Kudos Boards
### CNX 6.5
helmchart=$(ls ~/microservices_connections/hybridcloud/helmbuilds/kudos-boards-cp-1*.tgz)

### CNX 6.5.0.1 - the delivered helm chart has a bug. Download the new one:
curl -LO https://docs.kudosapps.com/assets/config/kubernetes/kudos-boards-cp-1.1.1.tgz
helmchart=$(ls kudos-boards-cp-1*.tgz)

### CNX 7.0
helmchart=$(ls ~/microservices_connections/hybridcloud/helmbuilds/kudos-boards-cp-2*.tgz)

### Kudos Helm Chart V2.0 fom ISW
curl -LO https://docs.kudosapps.com/assets/config/kubernetes/kudos-boards-cp-2.0.0.tgz
helmchart=$(ls kudos-boards-cp-2*.tgz)

### For EKS with efs provisioner, the persistent volume must not be created by kudos helm chart.
mkdir ~/helm
tar -C ~/helm -xvf $helmchart

# remove creation of PersistentVolume
sed -i -e '0,/^kind: PersistentVolume\r$/d' -e '0,/^---\r$/{/^---/!{/^\$/!d}}' ~/helm/kudos-boards-cp/charts/kudos-minio/templates/deployment.yaml
# remove creation of PersistentVolumeClaim
sed -i -e '0,/^kind: PersistentVolumeClaim\r$/d' -e '0,/^---\r$/{/^---/!{/^\$/!d}}' ~/helm/kudos-boards-cp/charts/kudos-minio/templates/deployment.yaml

# create Persisten Volume Claim using the efs-provisioner
bash beas-cnx-cloud/AWS/scripts/create_pvc_minio.sh

# fix Persistent Volume reclaim policy
bash beas-cnx-cloud/AWS/scripts/fix_policy_all.sh

# Use modified helm chart to install kudos boards
helm upgrade kudos-boards-cp ~/helm/kudos-boards-cp -i -f ~/cp_config/boards-cp.yaml --namespace $namespace --recreate-pods

```

Check if all pods are running: `watch -n 10 "kubectl -n $namespace get pods | grep '^kudos-'"`
Wait until the ready state is 1/1 or 2/2 for all running pods. It usually takes 3 minute to complete.


### 5.1.12 Installing Connections Add-in for Microsoft Outlook

[Set up Connections Add-in for Microsoft Outlook](https://help.hcltechsw.com/connections/v7/admin/install/cp_install_services_tasks.html#cp_install_services_tasks__section_tvw_cpw_tnb)

**Only relevant for Outlook integraion**

```
## Outlook 
helm upgrade connections-outlook-desktop  ~/microservices_connections/hybridcloud/helmbuilds/connections-outlook-desktop-*.tgz \
  -i -f ~/cp_config/outlook-addin.yml --namespace $namespace

```


### 5.1.13 Installing tools for monitoring and logging

**In CP 7 there is no documentation about this tasks.**

#### 5.1.13.1 Setting up Elastic Stack

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



#### 5.1.13.2 Installing the Kubernetes web-based dashboard

Follow the tutorial [Tutorial: Deploy the Kubernetes Web UI (Dashboard)](https://docs.aws.amazon.com/eks/latest/userguide/dashboard-tutorial.html) to install the dashboard.


#### 5.1.13.3 Installing the Sanity dashboard

[Installing the Sanity dashboard](https://help.hcltechsw.com/connections/v65/admin/install/cp_install_sanity.html)


```
## Sanity dashboard
helmchart=$(ls microservices_connections/hybridcloud/helmbuilds/sanity-[0-9]*)
helm upgrade sanity $helmchart -i -f ~/cp_config/install_cp.yaml --namespace $namespce

helmchart=$(ls microservices_connections/hybridcloud/helmbuilds/sanity-watcher*)
helm upgrade sanity-watcher $helmchart -i -f ~/cp_config/sanity-watcher.yaml --namespace $namespace

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
