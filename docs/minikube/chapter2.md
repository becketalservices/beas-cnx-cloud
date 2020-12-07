# 2 Create your Kubernetes environment

## 2.1 Configure Helm

**Create a kubernetes service account**

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

In case you see errors, make sure you have the os package `socat` installed.

## 2.2 Create your docker registry

To run the HCL Component Pack, you need to publish packages in a private docker registry. 
- In case you already have a docker registry, you can used this.
- IN cae you do not have one, you can deploy one on your kubernetes insfratructure.

To get a private docker registry, run this commands:

```
# 1. Create a self signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /tmp/tls.key -out /tmp/tls.crt \
  -subj "/CN=$HOSTNAME/O=DockerRegistry/C=XX"

# 2. Trust your new certificate 
sudo cp /tmp/tls.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust

# 3. Restart Docker daemon to pick up this trust
sudo systemctl restart docker
sleep 60 # just to wait until docker and kubernetes is available again


# 4. Store the certificate inside Kubenetes
kubectl create secret tls dr-secret --key /tmp/tls.key --cert /tmp/tls.crt

# 5. Deploy Docker Registry
helm install stable/docker-registry \
  --set tlsSecretName=dr-secret \
  --set service.type=NodePort \
  --set service.nodePort=31456 \
  --set persistence.enabled=true \
  --set persistence.size=10G \
  --set persistence.storageClass=standard 

# 6. Check that you can access your Registry via curl
# !! curl shoud trust the certificate. No -k option necessary.
curl --ipv4 -v https://$HOSTNAME:31456

```


**[Create your minikube environment << ](chapter1.html) [ >> Prepare cluster](chapter3.html)**
