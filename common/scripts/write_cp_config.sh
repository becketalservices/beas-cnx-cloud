#!/bin/bash
#version=202012071630

. ~/installsettings.sh

# Write global ingress controller configuration

if [ "$GlobalIngressPublic" != "1" ]; then
  annotationPrivate="      service.beta.kubernetes.io/aws-load-balancer-internal: 0.0.0.0/0"
fi

cat << EOF1 > global-ingress.yaml
#Global Ingress configuration

controller:
  replicaCount: 3
  ingressClass: global-nginx
  config:
    proxy-body-size: "512m"
  service:
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: "590"
$annotationPrivate
EOF1
# to forward tcp traffic throuh nginx proxy (for global not necessary anmore)
#tcp:
#  "30099": connections/elasticsearch:9200
#  "30379": connections/haproxy-redis:6379

# convert $starter_stack_list from a , separated list to a space separated list and remove kudos-boards in case it is available
stack_list=$(echo $starter_stack_list | sed -e "s/,/ /g" -e "s/kudos-boards//" |xargs)

if [ "$useStandaloneES" == "1" ]; then
  # use standalone ES Server
  ESHost=$standaloneESHost
  ESPort=$standaloneESPort
  ESPVC=false
  if [ "$standaloneESHost" -a "$standaloneESPort" ]; then
    ESIndexing=true
  else
    ESIndexing=false
  fi
else
  # use integrated ES Server - values default from values.yaml in orientme helmchart
  ESHost=elasticsearch
  ESPort=9200
  ESPVC=true
  ESIndexing=true
fi

if [ "$CNXSize" == "small" ]; then
  rCountNormal=1
  rCountSmall=0
  minCount=1
  maxCount=3
else
  rCountNormal=3
  rCountSmall=1
  minCount=3
  maxCount=3
fi

if [ -z "$CNXNS" ]; then
  CNXNS=connections
fi

if [ "$useSolr" == "0" ]; then
  SolrPVC=false
  SolrIndexing=false
  ESRetrieval=true
  SolrRepCount=0
  ZooRepCount=0
else
  SolrPVC=true
  SolrIndexing=true
  ESRetrieval=false
  SolrRepCount=$rCountNormal
  ZooRepCount=$rCountNormal
fi

# Write Component Pack configuration
cat << EOF2 > install_cp.yaml
#Component Pack configuration

#persistent disks & bootstrape & connections-env & elasticsearch & ingress controller & mw-proxy & sanity
namespace: $CNXNS

#Persistent Disks
storageClassName: $storageclass
mongo:
  enabled: true
solr:
  enabled: $SolrPVC
zk:
  enabled: $SolrPVC
es:
  enabled: $ESPVC
customizer:
  enabled: true

#bootstrap
env:
  set_ic_admin_user: "$ic_admin_user"
  set_ic_admin_password: "$ic_admin_password"
  set_ic_internal: "$ic_internal"
  set_master_ip: "$master_ip"
  set_starter_stack_list: "$stack_list"
  skip_configure_redis: true
image:
  repository: ${ECRRegistry}/connections

#connections-env
ic:
  host: $ic_front_door
  internal: $ic_internal
  interserviceOpengraphPort: 443
  interserviceConnectionsPort: 443
  interserviceScheme: https
createSecret: false

#elasticsearch
nodeAffinityRequired: false
deploymentType: hybrid_cloud

client:
  replicas: $rCountNormal

data:
  replicas: $rCountNormal

master:
  replicas: $rCountNormal

#infrastructure
haproxy:
  namespace: $CNXNS
  replicaCount: $rCountNormal

redis:
  namespace: $CNXNS
  replicaCount: $rCountNormal

redis-sentinel:
  env:
    numRedisServerReplicaCount: $rCountNormal
  namespace: $CNXNS
  replicaCount: $rCountNormal

mongodb:
  createSecret: false
  namespace: $CNXNS
  replicaCount: $rCountNormal

appregistry-client:
  namespace: $CNXNS
  replicaCount: $rCountNormal

appregistry-service:
  deploymentType: hybrid_cloud
  namespace: $CNXNS
  replicaCount: $rCountNormal

#orientMe
global:
  onPrem: true
  image:
    repository: ${ECRRegistry}/connections

itm-services:
  service:
    nodePort: 31100
  namespace: $CNXNS
  replicaCount: $rCountNormal

orient-web-client:
  service:
    nodePort: 30001
  namespace: $CNXNS
  replicaCount: $rCountNormal

orient-analysis-service:
  namespace: $CNXNS
  replicaCount: $rCountNormal

orient-indexing-service:
  indexing:
    solr: $SolrIndexing
    elasticsearch: $ESIndexing
  elasticsearch:
    host: $ESHost
    port: $ESPort
  namespace: $CNXNS
  replicaCount: $rCountNormal

solr-basic:
  namespace: $CNXNS
  replicaCount: $SolrRepCount

zookeeper:
  namespace: $CNXNS
  replicaCount: $ZooRepCount

middleware-graphql:
  namespace: $CNXNS
  replicaCount: $rCountNormal

userprefs-service:
  namespace: $CNXNS
  replicaCount: $rCountNormal

orient-retrieval-service:
  retrieval:
    elasticsearch: $ESRetrieval
  elasticsearch:
    host: $ESHost
    port: $ESPort
  namespace: $CNXNS
  replicaCount: $rCountNormal

people-scoring:
  namespace: $CNXNS
  replicaCount: $rCountNormal

people-datamigration:
  namespace: $CNXNS
  replicaCount: 1 #default to 1

people-relationship:
  namespace: $CNXNS
  replicaCount: $rCountNormal

mail-service:
  service:
    nodePort: 32721
  namespace: $CNXNS
  replicaCount: $rCountSmall # default to 1

people-idmapping:
  namespace: $CNXNS
  replicaCount: $rCountNormal

community-suggestions:
  service:
    nodePort: 32200
  namespace: $CNXNS
  replicaCount: $rCountNormal

#ingress controller
controller:
  service:
    enableHttps: false
  ingressClass: nginx
ingress:
  hosts:
    domain: ${GlobalDomainName}

tcp:
  "30099": connections/elasticsearch:9200
  "30379": connections/haproxy-redis:6379

#ingress controller & mw-proxy & sanity & sanity-watcher !!! overwrite by --set replicaCount='1'
replicaCount: $rCountNormal

#mw-proxy
minReplicas: $minCount
maxReplicas: $maxCount

#sanity

EOF2

# Wirite Kudos Boards configuration
if [ $installversion == "65" ]; then
  if [ $installsubversion == "00" ]; then
    valid=1
    tag=20191120-214007
  fi
  if [ $installsubversion == "10" ]; then
    valid=1
    tag=20200306-180701
  fi
fi

if [ "$valid" != "1" ]; then
  echo "Not supported CP Version for Boards."
  exit 1
fi

cat << EOF3 > boards-cp.yaml
# Please read every variable and replace with appropriate value
# For details of variable meanings, please see https://docs.kudosapps.com/boards/cp/

global:
  repository: ${ECRRegistry}/connections 
  imageTag: "$tag"
  imagePullSecret: myregkey
  env:
    APP_URI: https://${ic_front_door}/boards

minio:
  useDockerHub: false
  nfs:
    server: 192.168.0.1
    
webfront:
  env:
    API_GATEWAY: https://${ic_front_door}/api-boards
  ingress:
    # This hostname must match other Ingresses defined in your CP environment
    # If all ingresses start with * you must match the pattern, or all traffic will be routed to Boards and everything will break
    # kubectl get ingresses --all-namespaces
    hosts:
      - "*.${GlobalDomainName}"

core:
  env:
    LOGGER_DEBUG: user
    NOTIFIER_EMAIL_HOST: ${ic_internal}
    NOTIFIER_EMAIL_PORT: 25
    #NOTIFIER_EMAIL_USERNAME: user123
    #NOTIFIER_EMAIL_PASSWORD: passw0rd
    # APP_NAME: Kudos Boards # Used for all notifications, e.g. Orient Me
    # NOTIFIER_EMAIL_FROM_NAME: Kudos Boards
    # NOTIFIER_EMAIL_FROM_EMAIL: boards@connections.example.com
  ingress:
    # This hostname must match other Ingresses defined in your CP environment
    # If all ingresses start with * you must match the pattern, or all traffic will be routed to Boards and everything will break
    # kubectl get ingresses --all-namespaces
    hosts:
      - "*.${GlobalDomainName}"

licence:
  env:
    # Register your Organisation and download your Free 'Activities Plus' licence key from store.kudosapps.com
    LICENCE: ${KudosBoardsLicense} 

# https://docs.kudosapps.com/boards/msgraph/teams-on-prem/
# Uncomment/configure the following 3 lines if you are using this Kudos Boards deployment from Microsoft Teams
# provider:
#   env:
#     MSGRAPH_TEAMS_APP_ID: app-id-shown-in-teams-url

user:
  env:
    LOGGER_DEBUG: auth,client
    CONNECTIONS_NAME: HCL Connections
    CONNECTIONS_URL: https://${ic_front_door}
    CONNECTIONS_CLIENT_ID: kudosboards
    CONNECTIONS_CLIENT_SECRET: ${KudosBoardsClientSecret} 
    CONNECTIONS_ADMINS: "[\"${ic_admin_user}\"]"



migration:
  env:
    API_GATEWAY: https://${ic_front_door}/api-boards
    CONNECTIONS_ACTIVITIES_ADMIN_USERNAME: ${ic_admin_user}
    CONNECTIONS_ACTIVITIES_ADMIN_PASSWORD: ${ic_admin_password}
    CONNECTIONS_DB_HOST: ${db2host}
    CONNECTIONS_DB_USER: ${cnxdbusr}
    CONNECTIONS_DB_PASSWORD: ${cnxdbpwd}

    # -------- DB2 variables ------------
    CONNECTIONS_DB_TYPE: db2
    CONNECTIONS_DB_PORT: "${db2port}"
    # Connection string is built from other variables:
    # CONNECTIONS_DB_CONNECT_STRING: HOSTNAME=\${host};PORT=\${port};PROTOCOL=TCPIP;UID=\${user};PWD=\${password};CHARSET=UTF8;

    # -------- Microsoft variables -------
    # CONNECTIONS_DB_TYPE: mssql
    # CONNECTIONS_DB_PORT: 1433
    # CONNECTIONS_DB_DOMAIN: domain

    # -------- Oracle variables ----------
    # CONNECTIONS_DB_TYPE: oracle
    # CONNECTIONS_DB_PORT: 1531
    # CONNECTIONS_DB_SID: DATABASE
    # Connection string is built from other variables:
    # CONNECTIONS_DB_CONNECT_STRING: \${host}:\${port}/\${sid}

    # -------- Other options -------------
    # PROCESSING_PAGE_SIZE: 10
    # PROCESSING_LOG_EVERY: 50
    # IMMEDIATELY_PROCESS_ALL: false
    # COMPLETE_ACTIVITY_AFTER_MIGRATED: false
    # CREATE_LINK_IN_ACTIVITY_AFTER_MIGRATED: false
EOF3

