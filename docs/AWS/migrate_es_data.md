# Migrate ES Data from EFS to EBS
This document is only necessary when you created your ElasticSerch Volumes on EFS but now want to migrate your data to EBS volumes.

## Create new Persistent Volumes
Create new Persistent Volumes and Volume Claims on the default storage (gp2)

```
# Run script to create the replacement es volumes
bash beas-cnx-cloud/AWS/scripts/create_replacement_pvc.sh

```

## Change reclaim policy for the persistent volumes
To make sure the volume which contains the data is not deleted, when the associated volume claim is deleted, the reclaim policy needs to be changed.

```
# Run script to change the reclaim policy from Delete to Retain
bash beas-cnx-cloud/AWS/scripts/fix_policy.sh

```

## Stop the ElasticSearch Components 
To be able to migrate the content to the new volues, the ElasticSearch components that use this storage must be stopped.  
The commands can also be found on [Start / Stop infrastructure](../kubernetes/Start_Stop.html)

```
kubectl -n connections scale deployment es-client --replicas=0  
kubectl -n connections scale statefulset es-data --replicas=0  
kubectl -n connections scale deployment es-master --replicas=0  

# Check the result with command. When no pods are running anymore everything is stopped.
kubectl -n connections get pods |grep ^es

```

## Migrate Data from old to new volumes
We can use a pod to mount the data volumes and to migrate the data.

```
# Start migration via script
bash beas-cnx-cloud/AWS/scripts/migrate.sh

# Watch the pods to complete the job:
watch -n 10 "kubectl -n connections get pods |grep datamigrate"

```

After completion, check the rsync log and on success delete the pods

```
#to show the logs
kubectl -n connections logs datamigrate0
kubectl -n connections logs datamigrate1
kubectl -n connections logs datamigrate2

#delete the migration pods
kubectl -n connections delete pods datamigrate0 datamigrate1 datamigrate2

```

## Change the PV - PVC Association
The ElasticSearch service uses the pvc connections/es-pvc-data-X to mount the volume. Therefore the new persistent volumes must be assigned to the correct persistent volume claim names.

**Make sure your reclaim policy is set to Retain, otherwise your data will be lost.**

```
# Change the pvc by running
bash beas-cnx-cloud/AWS/scripts/update_pvc.sh

# check the result. The 3 pvc es-pvc-es-data-X must be on stroageclass gp2
kubectl -n connections get pvc

```

## Start ElasticSearch and test
When the storage is migrated, the ElasticSearch components can be started again.

```
# Start es-master
kubectl -n connections scale deployment es-master --replicas=3  

# wait until 3 pods are running
watch -n 5 "kubectl -n connections get pods |grep ^es"

# Start es-data
kubectl -n connections scale statefulset es-data --replicas=3 

# wait until 6 pods are running
watch -n 10 "kubectl -n connections get pods |grep ^es"

# Start es-client
kubectl -n connections scale deployment es-client --replicas=3  

# wait until 9 pods are running
watch -n 5 "kubectl -n connections get pods |grep ^es"

```
