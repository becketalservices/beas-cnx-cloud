#!/bin/bash
set +x

yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum-config-manager --disable docker*
yum-config-manager --enable docker-ce-stable
yum install -y --setopt=obsoletes=0 docker-ce-18.06*
yum makecache fast
sudo systemctl start docker
sudo systemctl enable docker.service
yum-config-manager --disable docker*

# Only for docker 17.03. set by default wiht docker 18.06
#echo 1 > /proc/sys/fs/may_detach_mounts
#echo fs.may_detach_mounts=1 > /usr/lib/sysctl.d/99-docker.conf

