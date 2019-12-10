# 2 Create Kubernetes infrastructure on AWS

Choose an AWS region that suits your needs. See [Regions and Availability Zones](https://docs.aws.amazon.com/en_us/AWSEC2/latest/UserGuide/using-regions-availability-zones.html) for more details.  

This chapter follows the documentation from AWS [Getting Started with Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html).

## 2.1 Configure your environment

As some variables like your VPCId is required more often, create a file with this variables.  


```
# Write our environment settings
cat > ~/installsettings.sh <<EOF
# EKS settings
EKSName="cluster name e.g. CNX_Test_EKS" 
EKSNodeType=m5a.xlarge
EKSNodeCount=4
EKSNodeVolumeSize=100
EKSNodePublicKey="Your EC2 Key Name"
AWSRegion="Your AWS Region e.g. eu-west-1"
#VPCId=<VPC Id e.g. vpc-2345abcd>
SUBNETID=<List of Subnet IDs e.g.: subnet-a9189fe2,subnet-50432629>
#SecGroup=<Security Group e.g.: sg-f5c54184>
#IAMRoleName=<IAM Role Name>

# EFS settings
storageclass=aws-efs

# ECR settings
ECRRegistry=<your docker registry>

# Certificte related settings
acme_email=<your enterprise email>
use_lestencrypt_prod=[true/false]

# Component Pack
ic_admin_user=admin_user
ic_admin_password=admin_password
ic_internal=ic_internal
ic_front_door=ic_front_door
master_ip=
# "elasticsearch customizer orientme"
starter_stack_list="elasticsearch customizer orientme"
# for test environments with just one node or no taint nodes, set to false.
nodeAffinityRequired=true
EOF

```

## 2.2 Create the EKS environment

For all options and probably adoptions in your environment see the `eksctl help` and the project [README on GitHub](https://github.com/weaveworks/eksctl/blob/master/README.md).

```
# Load settings file
. ~/installsettings.sh

# Run eksctl
eksctl create cluster \
--name "$EKSName" \
--version 1.12 \
--nodegroup-name standard-workers \
--node-type $EKSNodeType \
--nodes $EKSNodeCount \
--node-ami auto \
--node-volume-size $EKSNodeVolumeSize \
--ssh-public-key $EKSNodePublicKey \
--region $AWSRegion \
--vpc-public-subnets $SUBNETID

```

After deployment which takes 10-15 minutes check that you can successfully communicate with your new cluster:  
Run command:

```
kubectl get svc

```

## 2.3 Configure Helm on your EKS environment
 
**Create a kubernetes service account**

As we have rbac enabled on our cluster, we need to create an service account so that helm can act on our cluster.

The given instructions are based on [Role-based Access Control](https://github.com/helm/helm/blob/master/docs/rbac.md).

To create the service account, allow helm to manage the whole cluster and configure helm to use it, run this commands:

```
# Create rbac configuration for helm
kubectl apply -f beas-cnx-cloud/Azure/helm/rbac-config.yaml

# Initialize helm and deploy server side tiller component
helm init --service-account tiller

```

To check your helm installation and your successful connection to the cluster run `helm version`.

## 2.4 Taint and Label your Nodes

AWS EKS does not support different node groups yet but you can separate the existing nodes as described by IBM.

I found this step not necessary. It makes your configuration more complicate. It is safe to skip this step in a test environment.  
In case you skp this step, make sure that you set the node affinity to false when you deploy the component pack.

Taint and label the infrastructure worker nodes as described in [Labeling and tainting worker nodes for Elasticsearch](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_prereqs_label_es_workers.html).


## 2.5 Create a AWS EFS Storage and Storage Class

### 1.5.1 Create the EFS Storage

Create your EFS Storage by following the AWS documentation [Step 2: Create Your Amazon EFS File System](https://docs.aws.amazon.com/efs/latest/ug/gs-step-two-create-efs-resources.html).

* **Make sure you specify the VPC and all subnets of your EKS Cluster.**  
* **Add the Security groups from your worker and infra node to the Security Group of your EFS File System.**  
  **This security group was created automatically during step 2.2 Create the EKS environment**

The security group is named `eksctl-<EKSName>-cluster-ClusterSharedNodeSecurityGroup-<Random String>`

### 2.5.2 Create Kubernetes resources

**Storage Class**

To create the storage class based on your settings:

```
# Create Storage Class
kubectl apply -f beas-cnx-cloud/AWS/kubernetes/aws-efs-sc.yml

```

To check that the storage class has been created run `kubectl get storageclass aws-efs`

In case you named your storage class differently, update the installsettings.sh file. 


**RBAC rights**

To grant the correct rights create the necessary cluster roles and bindings

run `kubectl apply -f beas-cnx-cloud/AWS/kubernetes/aws-pvc-roles.yaml`

### 2.5.3 Create the efs provisioner

replace the file.system.id with your id and the aws.region by your region.  
run the command:

```
# File System ID:
fsid=fs-xxxxxx

# Region:
region=us-east-1

# Create Configmap
kubectl create configmap efs-provisioner \
--from-literal=file.system.id=$fsid \
--from-literal=aws.region=$region \
--from-literal=provisioner.name=example.com/aws-efs 

# Create efs-provisioner-deployment.yml
sed -e "s/server:.*/server: $fsid.efs.$region.amazonaws.com/" \
 -e "s/path:.*/path: \//" \
 beas-cnx-cloud/AWS/kubernetes/efs-provisioner-deployment.yml > efs-provisioner-deployment.yml

# Apply configuration
kubectl apply -f efs-provisioner-deployment.yml

```

To check that your efs provisioner is deployed and running run `kubectl get pods`.

In case the container is not up and running after 2 minutes, check what went wrong by `kubectl describe pods -l app=efs-provisioner`.

To restart the efs provisioner, delete the pod to get it recreated immediately. `kubectl delete pods -l app=efs-provisioner`

