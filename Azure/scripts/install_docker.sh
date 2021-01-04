#!/bin/bash
set +x

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

if [ -e ~/installsettings.sh ]; then
  . ~/installsettings.sh
else
  echo "installsettings.sh not found. Assuming latest CP Version 7.0"
  installversion=70
fi

yum install -y yum-utils device-mapper-persistent-data lvm2
grep "Red Hat" /etc/redhat-release
if [ $? -eq 0 ]; then
  yum install -y http://mirror.centos.org/centos/7/extras/x86_64/Packages/container-selinux-2.107-3.el7.noarch.rpm
fi
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum update -y
if [ $installversion -le 65 ]; then
  echo
  echo "Installing Docker for CP 65 or lower"
  echo "####################################"
  echo
  yum install -y docker-ce-18.06.3.ce containerd.io
else
  echo
  echo "Installing Docker for CP 70 or newer"
  echo "####################################"
  echo
  yum install -y \
    containerd.io-1.2.13 \
    docker-ce-19.03.11 \
    docker-ce-cli-19.03.11
  mkdir /etc/docker
  cat <<EOF | tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF
  mkdir -p /etc/systemd/system/docker.service.d
fi

systemctl daemon-reload
systemctl enable docker
systemctl restart docker

echo
echo "----------------------------------------------------------------------------------"
echo
echo 'run "sudo usermod -a -G docker $USER" to grant your current user docker rights.'
echo
echo "----------------------------------------------------------------------------------"
echo

