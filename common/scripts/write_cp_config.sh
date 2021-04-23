#!/bin/bash
#version=202101041040

. ~/installsettings.sh

# create subdirecoty
if [ ! -d "$HOME/cp_config" ]; then
  mkdir -p "$HOME/cp_config"
fi

if [ ! -d "$HOME/cp_config" ]; then
  echo "ERROR: Configuration directory "$HOME/cp_config" was not created."
  exit 1
fi

if [ -z "$namespace" ]; then
  $namespace=connections
fi

if [ "$CNXSize" == "small" ]; then
  rCountNormal=1
  rCountSmall=0
  minCount=1
  maxCount=3
  bCountNormal=1
else
  rCountNormal=3
  rCountSmall=1
  minCount=3
  maxCount=3
  bCountNormal=2
fi

# Write global ingress controller configuration

if [ "$GlobalIngressPublic" != "1" ]; then
  annotationPrivate="      service.beta.kubernetes.io/aws-load-balancer-internal: 0.0.0.0/0"
fi

cat << EOF1 > "$HOME/cp_config/global-ingress.yaml"
#Global Ingress configuration

controller:
  replicaCount: $rCountNormal 
  ingressClass: global-nginx
  config:
    proxy-body-size: "512m"
  service:
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: nlb
      service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: "590"
$annotationPrivate
  metrics:
    enabled: true
    service:
      annotations:
        prometheus.io/port: "10254"
        prometheus.io/scrape: "true"
EOF1
# to forward tcp traffic throuh nginx proxy (for global not necessary anmore)
#tcp:
#  "30099": connections/elasticsearch:9200
#  "30379": connections/haproxy-redis:6379


# Write internal ingress controller configuration
if [ ]; then
  forwardES="  \"30099\": $namespace/elasticsearch:9200"
fi

cat << EOF1 > "$HOME/cp_config/internal-ingress.yaml"
#Global Ingress configuration

controller:
  replicaCount: $rCountNormal 
  ingressClass: nginx
  config:
  service:
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: nlb
      service.beta.kubernetes.io/aws-load-balancer-internal: "true"
  metrics:
    enabled: true
    service:
      annotations:
        prometheus.io/port: "10254"
        prometheus.io/scrape: "true"
# to forward tcp traffic throuh nginx proxy (for global not necessary anmore)
tcp:
  "30379": $namepsace/haproxy-redis:6379
$forwardES
EOF1



# convert $starter_stack_list from a , separated list to a space separated list and remove kudos-boards in case it is available
stack_list=$(echo $starter_stack_list | sed -e "s/,/ /g" -e "s/kudos-boards//" |xargs)

if [ "$useStandaloneES" == "1" ]; then
  # use standalone ES Server
  if [ "$ESVersion" == "7" ]; then
    ESHost7=$standaloneESHost
    ESPort7=$standaloneESPort
  else
    ESHost=$standaloneESHost
    ESPort=$standaloneESPort
  fi
  ESPVC=false
  ESPVC7=false
  if [ "$standaloneESHost" -a "$standaloneESPort" ]; then
    ESIndexing=true
  else
    ESIndexing=false
  fi
else
  # use integrated ES Server - values default from values.yaml in orientme helmchart
  ESHost=elasticsearch
  ESPort=9200
  ESHost7=elasticsearch7
  ESPort7=9200
  if [ $installversion -ge 70 ]; then
    ESPVC=false
    ESPVC7=true
  else 
    ESPVC=true
    ESPVC7=false
  fi
  ESIndexing=true
fi

if [ "$useSolr" == "0" -o "$installversion" -ge 70 ]; then
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

if [ "$MSTeams" == "1" ]; then
  MSTeamsEnabled="true"
else
  MSTeamsEnabled="false"
fi

# Write Component Pack configuration
cat << EOF2 > "$HOME/cp_config/install_cp.yaml"
#Component Pack configuration

#persistent disks & bootstrape & connections-env & elasticsearch & ingress controller & mw-proxy & sanity
namespace: $namespace

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
es7:
  enabled: $ESPVC7
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
integrations:
  msgraph:
    auth:
      endpoint: '$MSGraph_Auth_Endpoint'
    authorize:
      endpoint: '$MSGraph_Authorize_Endpoint'
    client:
      id: '$MSGraph_Client_ID'
      secret: '$MSGraph_Client_Secret'
    meta:
      endpoint: '$MSGraph_Meta_Endpoint'
    redirect:
      uri: '$MSGraph_Redirect_URI'
    secret:
      name: '$MSGraph_Secret_Name'
    token:
      endpoint: '$MSGraph_Token_Endpoint'
  msteams:
    auth:
      schema: '$MSTeams_Auth_Schema'
    client:
      id: '$MSTeams_Client_ID'
      secret: '$MSTeams_Client_Secret'
    enabled: $MSTeamsEnabled 
    redirect:
      uri: '$MSTeams_Redirect_URI'
    tenant:
      id: '$MSTeams_Tenant_ID'
    share:
      service:
        endpoint: '$MSTeams_Share_Service_Endpoint'
      ui:
        files:
          api: '$MSTeams_Share_UI_Files_API'

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
  namespace: $namespace
  replicaCount: $rCountNormal

redis:
  namespace: $namespace
  replicaCount: $rCountNormal

redis-sentinel:
  env:
    numRedisServerReplicaCount: $rCountNormal
  namespace: $namespace
  replicaCount: $rCountNormal

mongodb:
  createSecret: false
  namespace: $namespace
  replicaCount: $rCountNormal

appregistry-client:
  namespace: $namespace
  replicaCount: $rCountNormal

appregistry-service:
  deploymentType: hybrid_cloud
  namespace: $namespace
  replicaCount: $rCountNormal

#msteams
teams-share-ui :
  namespace: $namespace
  maxReplicas: $maxCount
  minReplicas: $minCount 
  replicaCount: $rCountNormal

teams-share-service :
  namespace: $namespace
  maxReplicas: $maxCount 
  minReplicas: $minCount
  replicaCount: $rCountNormal

teams-tab-api :
  namespace: $namespace
  scaler:
    maxReplicas: $maxCount 
    minReplicas: $minCount

teams-tab-ui :
  namespace: $namespace
  scaler:
    maxReplicas: $maxCount
    minReplicas: $minCount


#tailored-exp
admin-portal :
  namespace: $namespace
  maxReplicas: $maxCount 
  minReplicas: $minCount 
  replicaCount: $rCountNormal

te-creation-wizard :
  namespace: $namespace
  maxReplicas: $maxCount 
  minReplicas: $minCount
  replicaCount: $rCountNormal

community-template-service :
  namespace: $namespace
  maxReplicas: $maxCount 
  minReplicas: $minCount
  replicaCount: 1

#orientMe
global:
  onPrem: true
  image:
    repository: ${ECRRegistry}/connections

itm-services:
  service:
    nodePort: 31100
  namespace: $namespace
  replicaCount: $rCountNormal

orient-web-client:
  service:
    nodePort: 30001
  namespace: $namespace
  replicaCount: $rCountNormal

orient-analysis-service:
  namespace: $namespace
  replicaCount: $rCountNormal

orient-indexing-service:
  indexing:
    solr: $SolrIndexing
    elasticsearch: $ESIndexing
  elasticsearch:
    host: $ESHost
    port: $ESPort
  elasticsearch7:
    host: $ESHost7
    port: $ESPort7
  namespace: $namespace
  replicaCount: $rCountNormal

solr-basic:
  namespace: $namespace
  replicaCount: $SolrRepCount

zookeeper:
  namespace: $namespace
  replicaCount: $ZooRepCount

middleware-graphql:
  namespace: $namespace
  replicaCount: $rCountNormal

userprefs-service:
  namespace: $namespace
  replicaCount: $rCountNormal

orient-retrieval-service:
  retrieval:
    elasticsearch: $ESRetrieval
  elasticsearch:
    host: $ESHost
    port: $ESPort
  elasticsearch7:
    host: $ESHost7
    port: $ESPort7
  namespace: $namespace
  replicaCount: $rCountNormal

people-scoring:
  namespace: $namespace
  replicaCount: $rCountNormal

people-datamigration:
  namespace: $namespace
  replicaCount: 1 #default to 1

people-relationship:
  namespace: $namespace
  replicaCount: $rCountNormal

mail-service:
  service:
    nodePort: 32721
  namespace: $namespace
  replicaCount: $rCountSmall # default to 1

people-idmapping:
  namespace: $namespace
  replicaCount: $rCountNormal

community-suggestions:
  service:
    nodePort: 32200
  namespace: $namespace
  replicaCount: $rCountNormal

#ingress controller
controller:
  service:
    enableHttps: false
  ingressClass: nginx
ingress:
  hosts:
    domain: ${GlobalDomainName}
multiDomainEnabled: false

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

# Write santiy_watcher.yaml
cat << EOF4 > "$HOME/cp_config/sanity_watcher.yaml"
#Component Pack configuration - sanity watcher

#sanity-watcher
namespace: $namespace

image:
  repository: ${ECRRegistry}/connections

#sanity-watcher
replicaCount: 1
EOF4

# Write outlook-addin.yml
cat << EOF5 > "$HOME/cp_config/outlook-addin.yml"
#Component Pack configuration - outlook-addin

namespace: $namespace

image:
  repository: ${ECRRegistry}/connections

env:
  # The URL of your Connections envrionment without a trailing slash. Do NOT end with '/' 
  CONNECTIONS_URL: https://$ic_front_door
  # The path to where the addin app is being served, relative to the CONNECTIONS_URL. Do NOT start or end with '/'
  CONTEXT_ROOT: outlook-addin
  # A URL that a user can go to for support of the addin.
  SUPPORT_URL: "$Outlook_Support_URL" 
  # Client ID (aka. app ID) used when registering oauth app in Connections
  CONNECTIONS_CLIENT_ID: connections-outlook-desktop
  # Client secret generated by Connections when registering oauth app
  CONNECTIONS_CLIENT_SECRET: "$Outlook_Client_Secret"
  # A custom name for the add-in.
  CONNECTIONS_NAME: $name
ingress:
  hosts:
    - host: "*.${GlobalDomainName}" 
      paths: []

EOF5


# Wirite Kudos Boards configuration
if [ $installversion == "70" ]; then
  if [ $installsubversion == "00" ]; then
    valid=1
    tag=20201113-192158
  fi
fi
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

if [ ! "$KudosPublicImages" == 1 -a "$installversion" -eq 70 ]; then
  kudosImage="  image:"
  kudosMinio="    name: kudosboards-minio"
  kudosWebfront="    name: kudosboards-webfront"
  kudosCore="    name: kudosboards-core"
  kudosLicence="    name: kudosboards-licence"
  kudosUser="    name: kudosboards-user"
  kudosApp="    name: kudosboards-boards"
  kudosProvider="    name: kudosboards-provider"
  kudosNotification="    name: kudosboards-notification"
fi

cat << EOF3 > "$HOME/cp_config/boards-cp.yaml"
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
$kudosImage
$kudosMinio
    
webfront:
  replicaCount: $bCountNormal
  env:
    API_GATEWAY: https://${ic_front_door}/api-boards
  ingress:
    # This hostname must match other Ingresses defined in your CP environment
    # If all ingresses start with * you must match the pattern, or all traffic will be routed to Boards and everything will break
    # kubectl get ingresses --all-namespaces
    hosts:
      - "*.${GlobalDomainName}"
$kudosImage
$kudosWebfront

core:
  replicaCount: $bCountNormal
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
$kudosImage
$kudosCore

licence:
  replicaCount: $bCountNormal
  env:
    # Register your Organisation and download your Free 'Activities Plus' licence key from store.kudosapps.com
    LICENCE: ${KudosBoardsLicense} 
$kudosImage
$kudosLicence

# https://docs.kudosapps.com/boards/msgraph/teams-on-prem/
# Uncomment/configure the following 3 lines if you are using this Kudos Boards deployment from Microsoft Teams
# provider:
#   env:
#     MSGRAPH_TEAMS_APP_ID: app-id-shown-in-teams-url

user:
  replicaCount: $bCountNormal
  env:
    LOGGER_DEBUG: auth,client
    CONNECTIONS_NAME: HCL Connections
    CONNECTIONS_URL: https://${ic_front_door}
    CONNECTIONS_CLIENT_ID: kudosboards
    CONNECTIONS_CLIENT_SECRET: ${KudosBoardsClientSecret} 
    CONNECTIONS_ADMINS: "[\"${ic_admin_user}\"]"
$kudosImage
$kudosUser

app:
  replicaCount: $bCountNormal
$kudosImage
$kudosApp

provider:
  replicaCount: $bCountNormal
$kudosImage
$kudosProvider

notification:
  replicaCount: $bCountNormal
$kudosImage
$kudosNotification

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

