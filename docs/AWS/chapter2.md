# 2 Create Kubernetes infrastructure on AWS

Choose an AWS region that suits your needs. See [Regions and Availability Zones](https://docs.aws.amazon.com/en_us/AWSEC2/latest/UserGuide/using-regions-availability-zones.html) for more details.  

This chapter follows the documentation from AWS [Getting Started with Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html).

## 2.1 Create environment configuration file

As some variables like your EKS Name is required more often, create a file with these variables:  
The file is called `installsettings.sh` and is placed in your home directory.  
Most of the scripts and commands reference this file.


```
# Write our environment settings
cat > ~/installsettings.sh <<EOF
# Global
installversion=70

# Network
GlobalIngressPublic=1

# EKS settings
EKSName="cluster name e.g. cnx_test_eks" 
EKSVersion=1.19
EKSNodeType=t3a.xlarge
## Depending on your installation
## Generic Worker: 2; Generic Worker + ES: 4
EKSNodeCount=2
EKSNodeCountMax=10
EKSNodeVolumeSize=100
EKSNodePublicKey="Your EC2 Key Name"
# Set to 1 if you want to use EKS private networking
EKSPrivateNetworking=1
# You can tag all resources created by EKS.
# Format: Key=Vaule,Key=Value
EKSTags=""
AWSRegion="Your AWS Region e.g. eu-west-1"
#VPCId=<VPC Id e.g. vpc-2345abcd>
SUBNETID=<List of Subnet IDs e.g.: subnet-a9189fe2,subnet-50432629>
# Set this to 1 in case you want to use the EKS auto scaling feature.
# If you enable this, choose a small worker node type
EKSAutoscale=0

# Route53
HostedZoneId="HostedZoneId"
HostedZoneIdPublic="HostedZoneIdPublic"

# EFS settings
storageclass=aws-efs

# ES settings
useStandaloneES=1
standaloneESHost=<Hostname of your ES Server end-point>
standaloneESPort=443

# ECR settings
ECRRegistry="your docker registry"

# Certificate related settings
acme_email="your enterprise email"
use_lestencrypt_prod="[true/false]"

# Component Pack
namespace=connections
GlobalDomainName="global domain name"
ic_admin_user="admin_user"
ic_admin_password='admin_password'
ic_internal="ic_internal"
ic_front_door="ic_front_door"
master_ip="master_ip"
# 6: "elasticsearch,customizer,orientme,kudos-boards"
# 7: "orientme,customizer,elasticsearch,elasticsearch7,teams,tailored-exp,cs_lite,ic360,cnx-mso-plugin,kudosboards"
starter_stack_list=""
# for test environments with just one node or no taint nodes, set to false.
nodeAffinityRequired=false
useSolr=0

# MSTeams
MSTeams=0
MSTeams_Tenant_ID=""
MSTeams_Client_ID=""
MSTeams_Client_Secret=""
MSTeams_Auth_Schema=0
MSTeams_Share_Service_Endpoint="/teams-share-service"
MSTeams_Share_UI_Files_API="/files/basic/api"
MSTeams_Redirect_URI=""

MSGraph_Client_ID=""
MSGraph_Client_Secret=""
MSGraph_Secret_Name=""
MSGraph_Auth_Endpoint="https://login.microsoftonline.com/common/"
MSGraph_Meta_Endpoint="v2.0/.well-known/openid-configuration"
MSGraph_Authorize_Endpoint="oauth2/v2.0/authorize"
MSGraph_Token_Endpoint="oauth2/v2.0/token"
MSGraph_Redirect_URI=""

Outlook_Client_Secret=""
Outlook_Support_URL="https://help.hcltechsw.com/connections/v7/connectors/enduser/c_ms_plugins_add_in_outlook.html"

# KUDOS
KudosPublicImages=1
KudosDockerAccount=""
KudosDockerSecret=""
KudosBoardsLicense=""
KudosBoardsClientSecret="this_value_must_be_filled_in_when_connections_is_up_and_running"
db2host="activites db host"
db2port=50000
oracleservice=
oracleconnect=''
cnxdbusr="activites db user"
cnxdbpwd='activites db password'
EOF

```

## 2.2 Create the EKS environment

For all options and probably adoptions in your environment see the `eksctl help` and the project [eksctl on GitHub](https://github.com/weaveworks/eksctl).

```
bash beas-cnx-cloud/AWS/scripts/create_eks_cluster.sh

```

After deployment which takes 10-15 minutes check that you can successfully communicate with your new cluster:  
Run command:

```
kubectl get svc

```

**In case you want to use Autoscaler for your EKS cluster, follow the [Cluster Autoscaler](https://docs.aws.amazon.com/de_de/eks/latest/userguide/cluster-autoscaler.html) instructions.**

## 2.3 Configure Helm on your EKS environment (for Helm v2.x only)
 
**Create a kubernetes service account Helm v2.x only**

As we have rbac enabled on our cluster, we need to create an service account so that helm can act on our cluster.

The given instructions are based on [Role-based Access Control](https://helm.sh/docs/topics/rbac/).

To create the service account, allow helm to manage the whole cluster and configure helm to use it, run this commands:

```
# Create rbac configuration for helm
kubectl apply -f beas-cnx-cloud/Azure/helm/rbac-config.yaml

# Initialize helm and deploy server side tiller component
helm init --service-account tiller

```

To check your helm installation and your successful connection to the cluster run `helm version`.

## 2.4 Taint and Label your Nodes

AWS EKS does not support different node groups yet but you can separate the existing nodes as described by HCL.

I found this step not necessary. It makes your configuration more complicate. It is safe to skip this step in a test environment.  
In case you skp this step, make sure that you set the node affinity to false when you deploy the component pack.

Taint and label the infrastructure worker nodes as described in [Labeling and tainting worker nodes for Elasticsearch](https://help.hcltechsw.com/connections/v65/admin/install/cp_prereqs_label_es_workers.html).


## 2.5 Create a AWS EFS Storage and Storage Class

### 2.5.1 Create the EFS Storage

Create your EFS Storage by following the AWS documentation [Step 2: Create Your Amazon EFS File System](https://docs.aws.amazon.com/efs/latest/ug/gs-step-two-create-efs-resources.html).

* **Make sure you specify the VPC and all subnets of your EKS Cluster.**  
* **Add the Security groups from your worker and infra node to the Security Group of your EFS File System.**  
  **This security group was created automatically during step 2.2 Create the EKS environment**

The security group is named `eksctl-<EKSName>-cluster-ClusterSharedNodeSecurityGroup-<Random String>`

To use aws cli to create the EFS, use this commands:

```
. ~/installsettings.sh

# get the security group name: 
groupid=$(aws ec2 describe-security-groups \
  --region=$AWSRegion \
  --filter "Name=group-name,Values=eksctl-${EKSName}-cluster-ClusterSharedNodeSecurityGroup-*" \
  --query "SecurityGroups[*].{Name:GroupId}" \
  --output text)
echo $groupid

# Create EFS File System
aws efs create-file-system \
  --creation-token $EKSName \
  --performance-mode generalPurpose \
  --throughput-mode bursting \
  --tags Key=Name,Value="$EKSName" \
  --region $AWSRegion \
  --encrypted

# Get FSId
efsid=$(aws efs describe-file-systems \
  --creation-token $EKSName \
  --query "FileSystems[*].FileSystemId" \
  --region $AWSRegion \
  --output text)
echo $efsid

# Create Mount Targets in every subnet
for sid in $(echo $SUBNETID| tr ',' ' ')
do aws efs create-mount-target \
--file-system-id $efsid \
--subnet-id  $sid \
--security-group $groupid \
--region $AWSRegion
done

```

**After EFS creation, wait 2 minutes until DNS is up to date.**

### 2.5.2 Create the efs provisioner

**The helm chart has been depricated but I have not yet found a suitable replacement.**

Replace the file.system.id with your id and the aws.region by your region.  
run the command:

```
. ~/installsettings.sh

# File System ID:
# get id from your AWS Console or used the variable that was set during EFS creation above.
fsid=$efsid


# Use the official helm chart to install:
# !!! command differs on helm version

# Helm v2
helm install stable/efs-provisioner --name efs-provisioner \
  --set efsProvisioner.efsFileSystemId=$fsid \
  --set efsProvisioner.awsRegion=$AWSRegion \
  --set efsProvisioner.storageClass.name=$storageclass

# Helm v3
helm install efs-provisioner stable/efs-provisioner \
  --set efsProvisioner.efsFileSystemId=$fsid \
  --set efsProvisioner.awsRegion=$AWSRegion \
  --set efsProvisioner.storageClass.name=$storageclass

```

To check that your efs provisioner is deployed and running run `kubectl get pods`.

In case the container is not up and running after 2 minutes, check what went wrong by `kubectl describe pods -l app=efs-provisioner`.

To restart the efs provisioner, delete the pod to get it recreated immediately. `kubectl delete pods -l app=efs-provisioner`


**[Create your AWS environment << ](chapter1.html) [ >> Prepare cluster](chapter3.html)**
