# 2 Configure your Bastion Host as administration workstation

## 2.1 Install helm

**Install helm binary**

Download and extract the helm binaries:

```
sudo curl -L -o helm-v2.11.0-linux-amd64.tar.gz \
  "https://storage.googleapis.com/kubernetes-helm/helm-v2.11.0-linux-amd64.tar.gz"
sudo tar -zxvf helm-v2.11.0-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/bin/helm

```

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

To check your helm installation and your successful connection to the cluster run `helm version`


## 2.2 Install Docker

Docker is only necessary to deploy the Docker images into the registry or to build your own Docker images.


**Uses this instructions to install Docker according to IBM**

The instructions about the docker installation are taken from the [IBM Documentation](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_prereq_kubernetes_nonha.html).

For the installation run the script:

```
bash beas-cnx-cloud/Azure/scripts/install_docker.sh

```

Check the output of the script.

**Use this instructions to install Docker according to AWS**

[Docker Basics for Amazon ECR](https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-basics.html)

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

