Prometheus und Grafana
======================

The basic instructions to deploy Prometheus and Grafana are taken from the AWS EKS Workshop 
[MONITORING USING PROMETHEUS AND GRAFANA](https://www.eksworkshop.com/intermediate/240_monitoring/).

The instructions are modified in that way that they match our infrastructure.


## 4.1 Register Helm repo

```
# add prometheus Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# add grafana Helm repo
helm repo add grafana https://grafana.github.io/helm-charts

```

## 4.2 Deploy Prometheus

```
# load environment configuration
. ./installsettings.sh

# register new namespace for prometheus
kubectl create namespace prometheus


helm install prometheus prometheus-community/prometheus \
    --namespace prometheus \
    --set alertmanager.persistentVolume.storageClass="$storageclass" \
    --set server.persistentVolume.storageClass="$storageclass"

```

To check what has been created run: `kubectl get all -n prometheus`


## 4.3 Deploy Grafana

In opposition to the workshop instructions, we will access  Grafana through our internal ingress controller.

**Grafana Helm Chart currently does not support ingress hosts like *.example.com which is used in the internal cnx ingress controller**

To fix this, download, extract, and modify the helm chart:  

```
mkdir helm
helm pull grafana/grafana --untar --untardir helm

# Edit file : helm/grafana/templates/ingress.yaml
# In line 41 add quotation marks around the value:     - host: "{{ tpl . $}}"
sed -i "s/\- host: {{ tpl . \\$}}/- host: '{{ tpl . $}}'/" helm/grafana/templates/ingress.yaml

```


```
# set admin password
adminpwd="passw0rd"

# crate gafana configuration file
cat << EoF > ${HOME}/cp_config/grafana.yaml
adminPassword: "$adminpwd"
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus-server.prometheus.svc.cluster.local
      access: proxy
      isDefault: true
persistence:
  enabled: true
  storageClassName: "$storageclass"
ingress:
  enabled: true
  path: /grafana
  annotations:
    kubernetes.io/ingress.class: nginx
  hosts:
    - "*.$GlobalDomainName"
grafana.ini:
  server:
    domain: "*.$GlobalDomainName"
    root_url: "%(protocol)s://%(domain)s:%(http_port)s/grafana/"
    serve_from_sub_path: true

EoF

# register new namespace for grafana
kubectl create namespace grafana


# Install grafana (original version)
helm upgrade grafana grafana/grafana -i -f ${HOME}/cp_config/grafana.yaml --namespace grafana

# Install grafana (modified helm chart)
helm upgrade grafana ./helm/grafana -i -f ${HOME}/cp_config/grafana.yaml --namespace grafana

```

## 4.4 Import first dashboards

To do this, follow the instructions from the AWS EKS Workshop [DASHBOARDS](https://www.eksworkshop.com/intermediate/240_monitoring/dashboards/).

- 3119 : Kubernetes cluster monitoring (via Prometheus)
- 6417 : Kubernetes Cluster (Prometheus)
- 9614 : NGINX Ingress controller


## 4.5 Add Linux Hosts


### 4.5.1 Install and Configure node_exporter

This description was taken from [Step 4 - Install and Configure node_exporter](https://www.howtoforge.com/tutorial/how-to-install-prometheus-and-node-exporter-on-centos-7/).

```
# create user (as root)
useradd -m -s /bin/bash prometheus

```

```
# download and extract package
su - prometheus
wget https://github.com/prometheus/node_exporter/releases/download/v1.1.2/node_exporter-1.1.2.linux-amd64.tar.gz
tar -xzvf node_exporter*
mv node_exporter-1.1.2.linux-amd64 node_exporter

```

```
# create service file (as root)
cat << EoF > /etc/systemd/system/node_exporter.service 
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
ExecStart=/home/prometheus/node_exporter/node_exporter

[Install]
WantedBy=default.target
EoF

# reoload systemd configuration
systemctl daemon-reload


# enable and start the daemon
systemctl start node_exporter
systemctl enable node_exporter

```

### 4.5.2 configure Prometeus to scarp our Linux Targets

