# 1 Create your minikube environment

The instructions exist to produce a prove of concept environment so it will scale the deployments to 1 pod of each type to save resources and have the Elastic Search Service hosted as AWS Elastic Search Service to save as much resources as possible.

In case you want to deploy the full stack as lined out by HCL, you need to provide a server with the requirements for an "all on one machine" proof-of-concept deployment which is 16 CPU, 64GB RAM and 100GB HDD.

For my PoC installation I get minikube and HCL Component Pack running on a standard c5.xlarge EC2 instance (4 CPU, 16GB RAM) with CentOS 7.8. It has a 50 GB hard disk attached. 

For both scenarios, you can follow my instructions to get the infrastructure running but for the HCL way of doing it, you do not need to scale down the deployments and you need to follow the HCL instructiosn to install Elastic Search.


## 1.1 Install your OS and required software

Power on your server wiht CentOS 7.8

### 1.1.1 Add the epel repo and update the os:

```
sudo yum -y install epel-release
sudo yum -y update
sudo yum -y install socat vim nano zip unzip bind-utils

```


### 1.1.2 Install git to clone this repository to have the scripts available.


```
sudo yum -y install git
git clone https://github.com/becketalservices/beas-cnx-cloud.git

```

### 1.1.3 Install kubectl

install kubectl:

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

### 1.1.4 Install helm

**Install helm binary**

Download and extract the helm binaries:

```
# CP 6.5.0.1 - use latest availave v2 release
curl -L -O "https://get.helm.sh/helm-v2.17.0-linux-arm64.tar.gz"

tar -zxvf helm*
sudo mv $HOME/linux-amd64/helm /usr/bin/helm

# check that helm is available
helm version --client

```

### 1.1.5 Install Docker

Docker is only necessary to deploy the Docker images into the registry or to build your own Docker images.


**Uses this instructions to install Docker according to HCL**

The instructions about the docker installation are taken from the [Deploying a non-HA Kubernetes platform](https://help.hcltechsw.com/connections/v65/admin/install/cp_prereq_kubernetes_nonha.html).

For the installation run the script:

```
sudo bash $HOME/beas-cnx-cloud/Azure/scripts/install_docker.sh

# to check your docker version run
sudo docker version

# grant current user access to docker daemon (logoff / login required to activate)
sudo usermod -a -G docker $USER

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
sudo usermod -a -G docker $USER

# Log off / Log On to your ssh session to be able to use docker
```

## 1.2 Deploy minikube

### 1.2.1 Download and install minikube


```
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x minikube
sudo mv minikube /usr/bin/

```

### 1.2.2 Run minikube

I want to run kubernetes natively on my server without any hypervisor so I use the option `--vm-driver=none`.
To run the kubernetes version 1.7.6 use the option `--kubernetes-version v1.17.6`.

```
sudo minikube start --vm-driver=none --kubernetes-version v1.17.6

# Enable autostart of minikube
sudo systemctl enable kubelet.service

```

This will also add minikube to the autostart processes as well.

### 1.2.3 Enable dashboard

Enable the dashboard addon:

```
sudo minikube addons enable dashboard

```

### 1.2.4 Make kube config available to centos

To copy over the kube and minikube configuration from root run:

```
sudo cp -r /root/.kube $HOME
sudo cp -r /root/.minikube $HOME
sudo chown -R $USER $HOME/.kube $HOME/.minikube

```

Adjust the configuration files to point to your home directory:

```
sed -i "s@/root@$HOME@" .kube/config
sed -i "s@/root@$HOME@"  .minikube/machines/minikube/config.json

```


### 1.2.5 Verify your installation

```
minikube status
kubectl get nodes
kubectl get svc

```
All 3 commands should give you some output about the minikube cluster and your kubernetes infrastructure. No error message should be shown.

To access your dashboard, run kube-poxy and then use a browser to access the dashboard:

```
kube proxy

http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy

```


**[ >> Create your Kubernetes environment](chapter2.html)**
