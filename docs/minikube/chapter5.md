# 5 Integration

## 5.1 Integrate Elastic Search

There are 2 possibilities on how you have installed Elastic Search.

To simplify the interaction with the Elastic Search service, I provide some simple scripts to interact with your Elastic Search instance.

These scripts can be found in the directory `elasticsearch` within this git repository.

To configure the scripts, run `bash getcerts.sh`.  
This will create a settings.sh file with the necessary parameters in the same directory.  
In case of a Elastic Search on Kubernetes it will also download and setup the necessary certificates to interact with the ES Service.

### 5.1.1 Elastic Search on Kubernetes

You have installed Elastic Search together with the other HCL Services.  
In this case follow the instructions provided by HCL to configure the integration. 

- [Configuring the Elasticsearch Metrics component](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_es_intro.html)  
- [Setting up type-ahead search](https://help.hcltechsw.com/connections/v65/admin/install/inst_tasearch_intro.html)

When you run `getcerts.sh`, the necessary files `elasticsearch-metrics.p12` and `chain-ca.pem` is extracted four you.  
To view the password, run `kubectl get secret elasticsearch-secret -n connections  -o "jsonpath={.data.elasticsearch-key-password\.txt}" |base64 -d`.

**Configure ES on CNX**  
run:

```
. ~/installsettings.sh
pushd microservices_connections/hybridcloud/support
python config_blue_metrics.py --skipSslCertCheck true --pinkhost $master_ip
popd

```

On the Connections Dmgr:

1. Stop and Start application MetricsUI and MetricsEventCapture
2. Copy files `elasticsearch-metrics.p12` and `chain-ca.pem` from your kubernetes host to your _data shared_/elasticsearch directory.
3. Run wsadmin commands: (the 2nd line was already shown to you by the `getcerts.sh` command.)

```
execfile('esSecurityAdmin.py')
enableSslForMetrics('/opt/IBM/data/shared/elasticsearch/elasticsearch-metrics.p12', '<password>', '/opt/IBM/data/shared/elasticsearch/chain-ca.pem', '30099')

```

**Configure Type Ahead Search**

1. Update type ahead settings in search-config.xml
    
    ```
    <property name="quickResults">
        <propertyField name="quick.results.connections" value=""/>
        <!-- disable solr for indexing -->
        <propertyField name="quick.results.solr.indexing.enabled" value="false"/>
        <!-- disable solr for queries -->
        <propertyField name="quick.results.use.solr.for.queries" value="false"/>
        <!-- enable elastic search for indexing -->
        <propertyField name="quick.results.elasticsearch.indexing.enabled" value="true"/>
        <!-- reduce the number of replica to 1 -->
        <propertyField name="quick.results.elasticsearch.replicas.count" value="1"/>
        <!-- reduce the number of shards to 4 -->
        <propertyField name="quick.results.elasticsearch.shards.count" value="4"/>
        <propertyField name="quick.results.elasticsearch.index.name" value="quickresults"/>
    </property>
    ```
    
2. Update LC-config.xml
    
    ```
    <genericProperty name="quickResultsEnabled">true</genericProperty>
    
    ```
    
3. Synchronize the nodes and then restart the servers or clusters that are running the Search and Common applications
4. Run wsadmin command: (the 2nd line was already shown to you be the `getcerts.sh` command.)
    
    ```
    execfile('searchAdmin.py')
    SearchService.setESQuickResultsBaseUrl("https://<master-ip>:30099")
    ```
    
5. Create the index
    
    ```
    SearchService.createESQuickResultsIndex()
    ```

On Kubernetes host verify that the index was created:  
`bash beas-cnx-cloud/elasticsearch/esget.sh "_cat/indices?v"`


### 5.1.2 Stand alone Elastic Search

When you want to use a stand alone Elastic Search service follow the instructions [Setting up stand-alone Elasticsearch](https://help.hcltechsw.com/connections/v65/admin/install/es_install_standalone_intro.html).

When you want to use the AWS Elastic Search service, you can do so. Configure it with IP based access restrictions as the other options for authentication provided by AWS are not compatible with HCL Connections. In this case, you do not need to import any certificated for authentication but you need to trust the signer certificate of AWS.


### 5.1.3 Enable new MetricsUI

Depending of your existing metrics data follow one of this procedures:

* [Deploying Elasticsearch Metrics as your first use of metrics](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_es_metrics_no_cognos.html)
* [Deploying Elasticsearch Metrics with the data migrated from the metrics relational database](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_es_migrate_cognos_data.html)



## 5.2 Integrate Redis Traffic

Follow the instructions to [Manually configuring Redis traffic to Orient Me](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_om_redis_enable.html). 

In case you use EKS, your kubernetes cluster does not provide a SSH endpoint that can be used to secure the redis traffic. In this case you can either power up a special service to provide this endpoint or you don't encapsulate your Redis traffic in SSH. 
 

```
# Load settings
. ~/installsettings.sh

# Get Redis Password from secret redis-secret
redispwd=$(kubectl get secret redis-secret -n connections \
  -o "jsonpath={.data.secret}" | base64 -d)

# run command
bash microservices_connections/hybridcloud/support/redis/configureRedis.sh \
  -m  $master_ip\
  -po 30379 \
  -ic https://$ic_internal \
  -pw "$redispwd" \
  -ic_u "$ic_admin_user" -ic_p "$ic_admin_password"

```

Check the command output. When the command completed successfully, restart common and news application.

To check if redis is working as expected use [Verifying Redis server traffic](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_om_redis_verify.html).

To view your Redis password run:

```
kubectl get secret redis-secret -n connections   -o "jsonpath={.data.secret}" | base64 -d

```

To run redsi-cli run:

```
kubectl exec -it -n connections redis-server-0 -- redis-cli

```

Commands to verify traffic:

```
auth <redis-password>
subscribe connections.events

```

## 5.3 Integrate Orient Me

Follow the instructions [Configuring the Orient Me component](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_om_intro.html).

### 5.3.1 Configuring the HTTP server for Orient Me

Update your HTTP Server configuration: <https://help.hcltechsw.com/connections/v65/admin/install/cp_config_om_http_server.html>

### 5.3.2 Enabling profiles events for Orient Me

Update your TDI and LC-config: <https://help.hcltechsw.com/connections/v65/admin/install/cp_config_om_enable_profiles_events.html>

### 5.3.3 Configuring the Orient Me home page

Update your search and LC-config: <https://help.hcltechsw.com/connections/v65/admin/install/cp_config_om_enable_notifications.html>

### 5.3.4 Populating the Orient Me home page

The full procedure and more configuration options can be found in [Populating the Orient Me home page](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_om_populate_home_page.html) 


**Show your migration configuraton**

To view your migration configuration run:

```
kubectl exec -n connections -it $(kubectl get pods -n connections | grep people-migrate | awk '{print $1}') -- cat /usr/src/app/migrationConfig

```

In case something is wrong, check out the [HCL documentation](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_om_prepare_migrate_profiles.html) on how to modify the configuration.


**Run migration command**

In case of a larger infrastructure check out the documentation [Migrating the data for the Orient Me home page](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_om_migrate_profiles.html).

For smaller instances where you can do a full migration with just one command run:

```
kubectl exec -n connections -it $(kubectl get pods -n connections | grep people-migrate | awk '{print $1}') -- npm run start migrate

```


## 5.4 Integrate Customizer

This is the most complex task as it requires some reconfiguration of your network.  
The entry point for your connections system is no longer the IBM HTTP Servers or Load Balancers in front of your WebSphere infrastructure. It is moved to a Reverse Proxy Server in front of the Kubernetes Cluster or the Global Ingress Controller on the Kubernets Cluster.

### 5.4.1 Use a ingress controller with Load Balancer as entry point


### 5.4.2 Use a 2nd IBM HTTP Server configuration as entry point

This scenario is for small deployments where you want to save resources, especially when you have only 1 HTTP Server and no Load Balancer.

The exiting IBM HTTP Server is moved to different ports but is still used as the internal entry point for the WebSphere Connections environment.  
The new IBM HTTP Server is listening on port 80 an 443 and is used as reverse proxy or the customizer.

#### 5.4.2.1 Move server to different ports

1. Modify the httpd.conf of your HTTP Server to use port 81 and 444 as ports
2. Modify the LC-config.xml and change the services configurations by specifiying the new ports in the href and ssl_href entries.
3. Modify in the WAS console the http server configuration to use port 81.
4. Modify in the WAS console the environment - virtual hosts - default_host and add port 81 and 444.
5. Generate and propagate the HTTP Server Plug-in configuration, Restart HTTP Server.
3. Full Synchronize and restart the instance
4. Test. Your HCL Connections WebSphere environment should no react as normal but on different ports.

#### 5.4.2.2 Create 2nd HTTP Server as ingress HTTP Server

1. Install a 2nd IBH HTTP Server
2. Make sure it has a valid SSL Certificate and listen on port 80 and 443
3. Add the proxy rules to forward all traffic to the internal HTTP server
4. Change your LC-config.xml to used the standard ports in the dynamicHosts configuration.
5. Full Synchronize and restart the instance
6. Test. Your HCL Connections WebSphere environment should no react as normal on the standard ports.

#### 5.4.2.3 add proxy rules for customizer

1. Update your httpd.conf file of your ingress HTTP server to redirect traffic via customizer.
    Replace ${master_ip} with your hostname or ip of your master or k8s load balancer.

    ```
    SSLProxyEngine on
    ProxyPreserveHost On
    ProxyPass "/files/customizer" "http://${master_ip}:30301/files/customizer"
    ProxyPassReverse "/files/customizer" "http://${master_ip}:30301/files/customizer"
    ProxyPass "/files/app" "http://${master_ip}:30301/files/app"
    ProxyPassReverse "/files/app" "http://${master_ip}:30301/files/app"
    ProxyPass "/moderation/app" "http://${master_ip}:30301/moderation/app"
    ProxyPassReverse "/moderation/app" "http://${master_ip}:30301/moderation/app"
    ProxyPass "/metrics/orgapp" "http://${master_ip}:30301/metrics/orgapp"
    ProxyPassReverse "/metrics/orgapp" "http://${master_ip}:30301/metrics/orgapp"
    ProxyPass "/communities/service/html" "http://${master_ip}:30301/communities/service/html"
    ProxyPassReverse "/communities/service/html" "http://${master_ip}:30301/communities/service/html"
    ProxyPass "/forums/html" "http://${master_ip}:30301/forums/html"
    ProxyPassReverse "/forums/html" "http://${master_ip}:30301/forums/html"
    ProxyPass "/dogear/html" "http://${master_ip}:30301/dogear/html"
    ProxyPassReverse "/dogear/html" "http://${master_ip}:30301/dogear/html"
    ProxyPass "/search/web" "http://${master_ip}:30301/search/web"
    ProxyPassReverse "/search/web" "http://${master_ip}:30301/search/web"
    ProxyPass "/homepage/web" "http://${master_ip}:30301/homepage/web"
    ProxyPassReverse "/homepage/web" "http://${master_ip}:30301/homepage/web"
    ProxyPass "/social/home" "http://${master_ip}:30301/social/home"
    ProxyPassReverse "/social/home" "http://${master_ip}:30301/social/home"
    ProxyPass "/mycontacts" "http://${master_ip}:30301/mycontacts"
    ProxyPassReverse "/mycontacts" "http://${master_ip}:30301/mycontacts"
    ProxyPass "/wikis/home" "http://${master_ip}:30301/wikis/home"
    ProxyPassReverse "/wikis/home" "http://${master_ip}:30301/wikis/home"
    ProxyPass "/blogs" "http://${master_ip}:30301/blogs"
    ProxyPassReverse "/blogs" "http://${master_ip}:30301/blogs"
    ProxyPass "/news" "http://${master_ip}:30301/news"
    ProxyPassReverse "/news" "http://${master_ip}:30301/news"
    ProxyPass "/activities/service/html" "http://${master_ip}:30301/activities/service/html"
    ProxyPassReverse "/activities/service/html" "http://${master_ip}:30301/activities/service/html"
    ProxyPass "/profiles/html" "http://${master_ip}:30301/profiles/html"
    ProxyPassReverse "/profiles/html" "http://${master_ip}:30301/profiles/html"
    ProxyPass "/viewer" "http://${master_ip}:30301/viewer"
    ProxyPassReverse "/viewer" "http://${master_ip}:30301/viewer"
    ProxyPass "/" "https://${ic_internal}:445/"
    ProxyPassReverse "/" "https://${ic_internal}:445/"
    ```    

## 5.5 Integrate Activities Plus / Boards

Just follow the instructions to provide the links to the new Activities Plus / Boards application.



**[Install Component Pack << ](chapter4.html) [ >> Deploy additional features](chapter6.html)**
