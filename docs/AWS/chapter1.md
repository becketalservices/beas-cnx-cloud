# 1 Create your AWS environment

## 1.1 VPC and Security Groups

Make sure you have a VPC with 2 or 3 subnets in a EKS Supported region.
The subnets should be in one in each availability zone and have at least 128 free IP Addresses.

Make sure you tagged your subnets properly to have the load balancer created properly. [tag the Amazon VPC subnets](https://aws.amazon.com/premiumsupport/knowledge-center/eks-vpc-subnet-discovery/)

![AWS VPC Setup](../images/AWS_VPC_Setup.png "AWS VPC Setup")
## 1.2 IAM Roles and Policies

Create an IAM Policy to allow your EKS Management Host access to manage the required resources on your behalf.  
It is possible to restrict the Policy further but for the test, this will do:

Create a new IAM Policy and name it "EKSFullAccess"

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "iam:CreateInstanceProfile",
                "iam:UntagRole",
                "iam:TagRole",
                "iam:RemoveRoleFromInstanceProfile",
                "iam:CreateRole",
                "iam:AttachRolePolicy",
                "iam:PutRolePolicy",
                "iam:AddRoleToInstanceProfile",
                "iam:ListInstanceProfilesForRole",
                "iam:PassRole",
                "iam:DetachRolePolicy",
                "iam:ListAttachedRolePolicies",
                "iam:DeleteRolePolicy",
                "iam:DeleteInstanceProfile",
                "iam:GetRole",
                "iam:GetInstanceProfile",
                "iam:DeleteRole",
                "iam:ListInstanceProfiles",
                "iam:TagUser",
                "iam:UntagUser",
                "iam:CreateServiceLinkedRole",
                "iam:DeleteServiceLinkedRole",
                "iam:GetOpenIDConnectProvider",
                "iam:GetRolePolicy"
                "cloudformation:*",
                "eks:*"
            ],
            "Resource": "*"
        }
    ]
}
```

In case you want to manage your Route53 DNS zones from your EKS Management Host, create a new IAM Policy and name it "DNSAccess".

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "route53:ListHostedZones",
                "route53:GetChange"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "route53:ChangeResourceRecordSets"
            ],
            "Resource": [
                "arn:aws:route53:::hostedzone/<ID of public Route53 zone>",
                "arn:aws:route53:::hostedzone/<ID of private Route53 zone>"
            ]
        }
    ]
}
```

Create a new IAM Role and name it "EKSManager".

Assign this policies to your new IAM Role:
* AmazonEC2FullAccess
* AmazonEKSWorkerNodePolicy
* AmazonEC2ContainerRegistryFullAccess
* AmazonElasticFileSystemFullAccess
* AmazonEKS_CNI_Policy
* EKSFullAccess
* DNSAccess  (optional)


## 1.2 Create an EKS Management Host in your VPC to administer your cluster

To administer your EKS cluster easily, create a administrative host, called the EKS Admin Host.

The admin host will be a small Linux host to upload the docker images to the registry and administer the cluster.
It is recommended that the host is in the same VPC as your Kubernetes cluster. This will simplify the access to the cluster resources and the administration.

The host can use a very small server e.g. t3a.medium as no compute power is necessary.

**AWS Console**

Open the AWS Console and create the Management Host.
You can use a small instance type like t3a.medium.
Place the host into the the new VPC as you will use it for your Kubernetes Cluster.
Attach the EKSManager Role you created in 1.1 to the instance.

* Use CentOS or AWS Linux as OS for the Management Host. Other Linux systems should also be possible as long as you can install Docker CE onto them.
All provided scripts are created on CentOS or RHEL Server. They are not tested with other Linux distributions. 
* Open port 22 (SSH) to access your Management Host from everywhere.
* Make sure a public IP is assigned. Either assign an Elastic IP afterwards or make sure "Auto-assign Public IP" is set to enable.
* Make sure you assign 60GB of Hard Disk space to your new instance. You need this disk space to extract the Component Pack.


## 1.3 Add the required software to your Management Host

Connect to your new host and install this software:

### 1.3.1 Add the epel repo and update the os:

```
sudo yum -y install epel-release
sudo yum update
sudo yum -y install vim nano unzip bind-utils

```

### 1.3.2 Install AWS CLI

Login to your new admin host using SSH and install the required tools:

```
# Install AWS CLI
sudo yum -y install epel-release
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Check AWS CLI Version
aws --version

# Check AWS IAM Role that it contains the EKSManager role you created and assigned to your Management Host.
aws sts get-caller-identity
```

### 1.3.3 Install eksctl

download and install:

```
# Download and extract the latest release of eksctl with the following command.
curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/latest_release/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp

# Move the extracted binary to /usr/bin.
sudo mv /tmp/eksctl /usr/bin

# Test that your installation was successful with the following command.
eksctl version

```

### 1.3.4 Install git to clone this repository to have the scripts available.

```
sudo yum -y update
sudo yum -y install git
git clone https://github.com/becketalservices/beas-cnx-cloud.git

```

### 1.3.5 Install and Configure kubectl for Amazon EKS

To install kubectl:

```
cat <<EOF > /tmp/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
sudo mv /tmp/kubernetes.repo /etc/yum.repos.d/
sudo yum install -y kubectl

```

### 1.3.6 Install _aws-iam-authenticator_ for Amazon EKS

```
curl -o aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.16.8/2020-04-16/bin/linux/amd64/aws-iam-authenticator
chmod 755 aws-iam-authenticator
sudo mv aws-iam-authenticator /usr/bin/

```

### 1.3.7 Install helm

**Install helm binary**

Download and extract the helm binaries:

```
# CP 6.0 - 6.5
curl -L -O "https://storage.googleapis.com/kubernetes-helm/helm-v2.11.0-linux-amd64.tar.gz"

# CP 6.5.0.1 - use latest available v2 release
curl -L -O "https://get.helm.sh/helm-v2.16.6-linux-amd64.tar.gz"

# CP 7.0 - use latest available v3 release (3.4.2 by time of writing)
curl -L -O "https://get.helm.sh/helm-v3.4.2-linux-amd64.tar.gz"

tar -zxvf helm*
sudo mv $HOME/linux-amd64/helm /usr/bin/helm

# check that helm is available
helm version --client

# add stable helm repo
helm repo add stable https://charts.helm.sh/stable

```

### 1.3.7 Install Docker

Docker is only necessary to deploy the Docker images into the registry or to build your own Docker images.


**Uses this instructions to install Docker according to HCL / Kubernetes**

The instructions about the docker installation for CP 6.5 or lower are taken from the [Deploying a non-HA Kubernetes platform](https://help.hcltechsw.com/connections/v65/admin/install/cp_prereq_kubernetes_nonha.html).

The instructions about the docker installation for CP 7.0 are taken from the [Kubernetes Documentation - Getting started - Production environment - Container runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#docker).

For the installation run the script:

```
sudo bash $HOME/beas-cnx-cloud/Azure/scripts/install_docker.sh

# to check your docker version run
sudo docker version

```

Check the output of the script.

**Use this instructions to install Docker according to AWS**

[Docker Basics for Amazon ECR](https://docs.aws.amazon.com/AmazonECR/latest/userguide/getting-started-cli.html)

```
sudo yum update -y
sudo amazon-linux-extras install -y docker
sudo yum -y install docker
sudo systemctl enable docker
sudo systemctl start docker 
sudo usermod -a -G docker ec2-user

# Log off / Log On to your ssh session to be able to use docker
```

To verify that docker is installed correctly run: `docker version`

## 1.4 Schedule management host shutdown

On Azure you can configure your server to shut down on a certain time each day. This is quite handy so save some mony.

run this command as root to add the shutdown your management host a 7pm.

```
echo "0 19 * * * /usr/sbin/shutdown -h 10 'Power Off in 10 minutes'"| sudo crontab -

```


**[ >> Create Kubernetes infrastructure on AWS](chapter2.html)**
