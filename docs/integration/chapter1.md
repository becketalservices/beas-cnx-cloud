Integrate Elastic Search
========================

There are 2 possibilities on how you have installed Elastic Search.

To simplify the interaction with the Elastic Search service, I provide some simple scripts to interact with your Elastic Search instance.

These scripts can be found in the directory `elasticsearch` within this git repository.

To configure the scripts, run `bash getcerts.sh`.  
This will create a settings.sh file with the necessary parameters in the same directory.  
In case of a Elastic Search on Kubernetes it will also download and setup the necessary certificates to interact with the ES Service.

Elastic Search on Kubernetes
----------------------------

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


Stand alone Elastic Search
--------------------------

When you want to use a stand alone Elastic Search service follow the instructions [Setting up stand-alone Elasticsearch](https://help.hcltechsw.com/connections/v65/admin/install/es_install_standalone_intro.html).

When you want to use the AWS Elastic Search service, you can do so. Configure it with IP based access restrictions as the other options for authentication provided by AWS are not compatible with HCL Connections. In this case, you do not need to import any certificated for authentication but you need to trust the signer certificate of AWS.


### 5.1.3 Enable new MetricsUI

Depending of your existing metrics data follow one of this procedures:

* [Deploying Elasticsearch Metrics as your first use of metrics](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_es_metrics_no_cognos.html)
* [Deploying Elasticsearch Metrics with the data migrated from the metrics relational database](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_es_migrate_cognos_data.html)


