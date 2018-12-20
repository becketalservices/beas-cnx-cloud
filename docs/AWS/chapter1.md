# 1 Create Kubernetes infrastructure on AWS

Choose an AWS region that suits your needs. See [Regions and Availability Zones](https://docs.aws.amazon.com/en_us/AWSEC2/latest/UserGuide/using-regions-availability-zones.html) for more details.  

This chapter follows the documentation from AWS [Getting Started with Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html).

## 1.1 Amazon EKS Prerequisites

### 1.1.1 Create your Amazon EKS service role in the IAM console

Create a IAM Role for your cluster.  
Choose EKS as your service.  
Choose a unique role name.  

### 1.1.2 Create your Amazon EKS Cluster VPC

Follow the instructions in the [getting started guide](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html) from AWS to create your VPC for the EKS cluster.

Make sure you record the Security Groups value and the VPCId and the SubnetIds of the created resources. 


### 1.1.2 Create a Bastion Host in your VPC to administer your cluster

The bastion host will be a small Linux host to upload the docker images to the registry and administer the cluster.
It is recommended that the host is in the same VPC as your kubernetes cluster. This will simplify the access to the cluster resources and the administration.

The host can use a very small server e.g. t2.medium as no compute power is necessary.

**AWS Console**

Open the AWS Console and create the Bastion Host.
Place the host into the the new VPC as you will use it for your Kubernetes Cluster.

* Use CentOS as OS for the Bastion Host. Other Linux systems should also be possible as long as you can install Docker CE onto them.
All provided scripts are created on CentOS or RHEL Server. They are not tested with other Linux distributions. 
* Open port 22 (SSH) to access your Bastion Host from everywhere.
* Make sure a public IP is assinged. Either assign an Elastic IP afterwards or make sure "Auto-assign Public IP" is set to enable.
* Make sure you assign 30GB of Hard Disk space to your new instance. You need this disk space to extract the Component Pack.


## 1.2 Make the Bastion Host your administration console

Use SSH (Putty) to connect to your new Bastion Host.
For login use the username for your used image (use centos when you choose the official CentOS image from the AWS Marketplace) and the ssh key you configured when you created your host.

### 1.2.1 Install git to clone this repository to have the scripts available.

```
sudo -i
yum -y update
yum -y install git
git clone https://github.com/becketalservices/beas-cnx-cloud.git

```

### 1.2.2 Install AWS CLI

Install AWS CLI on your Bastion Host.

```
sudo -i
yum -y install epel-release
yum -y install python-pip
pip install --upgrade pip
pip install awscli --upgrade

```

### 1.2.3 Install and Configure kubectl for Amazon EKS

run as root to install kubectl:

```
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
yum install -y kubectl

```

### 1.2.4 Install _aws-iam-authenticator_ for Amazon EKS

run as root:

```
curl -o aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.11.5/2018-12-06/bin/linux/amd64/aws-iam-authenticator
chmod 755 aws-iam-authenticator
mv aws-iam-authenticator /usr/bin/

```

### 1.2.5 Schedule bastion host shutdown

On Azure you can configure your server to shut down on a certain time each day. This is quite handy so save some mony.

run this command as root to add the shutdown your bastion host a 7pm.

```
echo "0 19 * * * /usr/sbin/shutdown -h 10 Power Off in 10 minutes"| crontab -

```

### 1.2.6 Configure your environment

As some variables like your VPCId is required more often, create a file with this variables.  


```
# Write our environment settings
cat > ~/settings.sh <<EOF
EKSName=<cluster name>
VPCId=<VPC Id>
SUBNETID=<List of Subnet IDs>
SecGroup=<Security Group>
IAMRoleName=<IAM Role Name>

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


## 1.3 Create your AWS Kubernetes Environment (EKS)

To create your cluster, make sure your settings.sh is filled with the right values.  
Run this command:

```
# Load settings.sh
. ~/settings.sh

# get IAM Role ARN
IAMRoleArn=$(aws iam get-role  --role-name $IAMRoleName --query 'Role.Arn'| sed 's/"//g')

# run AWS cli command to create the cluser:
aws eks create-cluster --name $EKSName --role-arn $IAMRoleArn --resources-vpc-config subnetIds=$SUBNETID,securityGroupIds=$SecGroup

```

Check the output of the command. 

To check the current status of your cluster and wait until it is created:

```
watch -n10 -g aws eks describe-cluster --name $EKSName --query cluster.status

```

When your cluster was created successfully, update your kubectl configuration to use the new Kubernetes Cluster:  
Run command:

```
aws eks update-kubeconfig --name $EKSName

```

Check that you can succsessfully communicate with your new cluster:  
Run command:

```
kubectl get svc

```

## 1.4 Launch and Configure Amazon EKS Worker Nodes

Up to now, only your Kubernetes Master is created. Now we need to create the required worker nodes.

Follow the instructions in the [Launching Amazon EKS Worker Nodes](https://docs.aws.amazon.com/eks/latest/userguide/launch-workers.html).

We need 2 different node groups:

1. Worker Nodes  
choose a name like "worker-nodes"  
create at least 2 Nodes m5.xlarge (4 CPU, 16 GB RAM) with 100GB Hard Disk
2. Infrastructure Nodes  
choose a name like "infra-nodes"  
create at least 2 Nodes m5.xlarge (4 CPU, 16 GB RAM) with 100GB Hard Disk
 

When the nodes were created successfully, enable worker nodes to join your cluster.

For this download the _aws-auth-cm.yaml_ from AWS and extend it to have both node groups to join your cluster:

```
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: <ARN of instance role (not instance profile) worker nodes>
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: <ARN of instance role (not instance profile) infra nodes>
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes

```

Taint and label the infrastructure worker nodes as described in [Labeling and tainting worker nodes for Elasticsearch](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_prereqs_label_es_workers.html).



## 1.5 Create a AWS EFS Storage and Storage Class

### 1.5.1 Create the EFS Storage

Create your EFS Storage by following the AWS documentation [Step 2: Create Your Amazon EFS File System](https://docs.aws.amazon.com/efs/latest/ug/gs-step-two-create-efs-resources.html).

Make sure you specify the VPC and all subnets of your EKS Cluster.  
As security groups add the Security groups from your worker and infra node.

### 1.5.2 Create Kubernetes resources

**Storage Class**

To create the storage class based on your settings:

```
# Create Storage Class
kubectl apply -f beas-cnx-cloud/AWS/kubernetes/aws-efs-sc.yml

```

To check that the storage class has been created run `kubectl get storageclass aws-efs`


**RBAC rights**

To grant the correct rights create the necessary cluster roles and bindings

run `kubectl apply -f beas-cnx-cloud/AWS/kubernetes/aws-pvc-roles.yaml`

### 1.5.3 Create the efs provisioner

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


