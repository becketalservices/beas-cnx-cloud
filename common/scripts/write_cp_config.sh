#!/bin/bash
. ~/installsettings.sh

# Write global ingress controller configuration

cat << EOF1 > global-ingress.yaml
#Global Ingress configuration

controller:
  replicaCount: 3
  ingressClass: global-nginx
  config:
    proxy-body-size: "512m"
  service:
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-internal: 0.0.0.0/0
      service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: "590"

tcp:
  "30001": connections/orient-web-client:8000
  "30099": connections/elasticsearch:9200
  "30379": connections/haproxy-redis:6379
EOF1

# Write Component Pack configuration
cat << EOF2 > install_cp.yaml
#Component Pack configuration

global:
  onPrem: true
  image:
    repository: ${ECRRegistry}/connections

image:
  repository: ${ECRRegistry}/connections

onPrem: true
createSecret: false
ic:
  host: $ic_front_door
  internal: $ic_internal
  interserviceOpengraphPort: 443
  interserviceConnectionsPort: 443
  interserviceScheme: https

controller:
  service:
    enableHttps: false

ingress:
  hosts:
    domain: ${GlobalDomainName}

storageClassName: $storageclass

customizer:
  enabled: true

solr:
  enabled: true

zk:
  enabled: true

es:
  enabled: true

mongo:
  enabled: true

env:
  set_ic_admin_user: "$ic_admin_user"
  set_ic_admin_password: "$ic_admin_password"
  set_ic_internal: "$ic_internal"
  set_master_ip: "$master_ip"
  set_starter_stack_list: "$starter_stack_list"
  skip_configure_redis: true

mongodb:
  createSecret: false

appregistry-service:
  deploymentType: hybrid_cloud

orient-web-client:
  service:
    nodePort: 30001

itm-services:
  service:
    nodePort: 31100

mail-service:
  service:
    nodePort: 32721

community-suggestions:
  service:
    nodePort: 32200

nodeAffinityRequired: $nodeAffinityRequired
deploymentType: hybrid_cloud

EOF2

# Wirite Kudos Boards configuration
cat << EOF3 > boards-cp.yaml
# Please read every variable and replace with appropriate value
# For details of variable meanings, please see https://docs.kudosapps.com/boards/cp/

global:
  repository: ${ECRRegistry}/connections 
  imageTag: "20191120-214007"
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
    API_GATEWAY: https://cnx63.ic4.beaslabs.com/api-boards
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

