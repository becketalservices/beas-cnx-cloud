Start / Stop infrastructure
===========================

# Stop

## Stop App Registry

kubectl -n connections scale deployment -l app=appregistry-client --replicas=0 
kubectl -n connections scale deployment -l app=appregistry-service --replicas=0

kubectl -n connections scale deployment -l app=community-suggestions --replicas=0 
kubectl -n connections scale deployment -l app=itm-services --replicas=0 
kubectl -n connections scale deployment -l app=middleware-graphql --replicas=0 
kubectl -n connections scale deployment -l app=orient-web-client --replicas=0 
kubectl -n connections scale deployment -l app=people-migrate --replicas=0 


kubectl -n connections scale deployment mw-proxy --replicas=0

kubectl -n connections scale deployment -l app=sanity --replicas=0


# Start

## Start App Registry

kubectl -n connections scale deployment -l app=appregistry-service --replicas=3
kubectl -n connections scale deployment -l app=appregistry-client --replicas=3
 
kubectl -n connections scale deployment -l app=community-suggestions --replicas=3 
kubectl -n connections scale deployment -l app=itm-services --replicas=3 
kubectl -n connections scale deployment -l app=middleware-graphql --replicas=3 
kubectl -n connections scale deployment -l app=orient-web-client --replicas=3 
kubectl -n connections scale deployment -l app=people-migrate --replicas=1 


kubectl -n connections scale deployment mw-proxy --replicas=3

kubectl -n connections scale deployment -l app=sanity --replicas=3