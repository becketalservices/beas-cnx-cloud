Start / Stop infrastructure
===========================

# Stop

## Stop Ingress Controller

```
kubectl -n connections  scale deployment -l app=nginx-ingress --replicas=0
```  

## Stop Custom

```
kubectl -n connections scale deployment webfilesys --replicas=0  
kubectl -n connections scale deployment filebrowser --replicas=0  
```

## Stop MW-Proxy

```
kubectl -n connections scale deployment mw-proxy --replicas=0  
```
 
## Stop OrientMe

```
kubectl -n connections scale deployment analysisservice --replicas=0  
kubectl -n connections scale deployment indexingservice --replicas=0  
kubectl -n connections scale deployment retrievalservice --replicas=0  
kubectl -n connections scale deployment orient-web-client --replicas=0  
kubectl -n connections scale deployment people-migrate --replicas=0  
kubectl -n connections scale deployment people-idmapping --replicas=0  
kubectl -n connections scale deployment people-scoring --replicas=0  
kubectl -n connections scale deployment people-relation --replicas=0  
kubectl -n connections scale deployment userprefs-service --replicas=0  
kubectl -n connections scale deployment middleware-graphql --replicas=0  
kubectl -n connections scale deployment community-suggestions --replicas=0   
kubectl -n connections scale deployment itm-services --replicas=0  
kubectl -n connections scale deployment mail-service --replicas=0  
kubectl -n connections scale statefulset solr --replicas=0  
kubectl -n connections scale statefulset zookeeper --replicas=0  
```

## Stop Infrastructure

```
kubectl -n connections scale deployment haproxy --replicas=0  
kubectl -n connections scale deployment appregistry-client --replicas=0   
kubectl -n connections scale deployment appregistry-service --replicas=0  
kubectl -n connections scale deployment redis-sentinel --replicas=0  
kubectl -n connections scale statefulset redis-server --replicas=0  
kubectl -n connections scale statefulset mongo --replicas=0  
```

## Stop Monitoring

```
kubectl -n connections scale deployment kibana --replicas=0  
kubectl -n connections scale statefulset logstash --replicas=0  
```

## Stop Elastic Search

```
kubectl -n connections scale deployment es-client --replicas=0  
kubectl -n connections scale statefulset es-data --replicas=0  
kubectl -n connections scale deployment es-master --replicas=0  
```

## Stop Sanity

```
kubectl -n connections scale deployment sanity-watcher --replicas=0  
kubectl -n connections scale deployment sanity --replicas=0  
```


# Start

## Start Sanity

```
kubectl -n connections scale deployment sanity --replicas=3  
kubectl -n connections scale deployment sanity-watcher --replicas=1  
```

## Start Elastic Search

```
kubectl -n connections scale deployment es-master --replicas=3  
kubectl -n connections scale statefulset es-data --replicas=3  
kubectl -n connections scale deployment es-client --replicas=3  
```

## Start Monitoring

```
kubectl -n connections scale statefulset logstash --replicas=3  
kubectl -n connections scale deployment kibana --replicas=3  
```

## Start Infrastructure

```
kubectl -n connections scale statefulset redis-server --replicas=3  
kubectl -n connections scale statefulset mongo --replicas=3  
kubectl -n connections scale deployment redis-sentinel --replicas=3  
kubectl -n connections scale deployment appregistry-service --replicas=3  
kubectl -n connections scale deployment appregistry-client --replicas=3  
kubectl -n connections scale deployment haproxy --replicas=3  
```
 
## Start OrientMe

```
kubectl -n connections scale statefulset zookeeper --replicas=3  
kubectl -n connections scale statefulset solr --replicas=3  
kubectl -n connections scale deployment mail-service --replicas=1  
kubectl -n connections scale deployment middleware-graphql --replicas=3   
kubectl -n connections scale deployment itm-services --replicas=3  
kubectl -n connections scale deployment community-suggestions --replicas=3   
kubectl -n connections scale deployment analysisservice --replicas=3  
kubectl -n connections scale deployment indexingservice --replicas=3  
kubectl -n connections scale deployment retrievalservice --replicas=3  
kubectl -n connections scale deployment orient-web-client --replicas=3  
kubectl -n connections scale deployment people-migrate --replicas=1  
kubectl -n connections scale deployment people-idmapping --replicas=3  
kubectl -n connections scale deployment people-scoring --replicas=3  
kubectl -n connections scale deployment people-relation --replicas=3  
kubectl -n connections scale deployment userprefs-service --replicas=3  
```

## Start MW-Proxy

```
kubectl -n connections scale deployment mw-proxy --replicas=3  
```

## Start Custom

```
kubectl -n connections scale deployment webfilesys --replicas=1  
kubectl -n connections scale deployment filebrowser --replicas=1  
```

## Start Ingress Controller

```
kubectl -n connections  scale deployment -l app=nginx-ingress --replicas=1  
```