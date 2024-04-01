#!/bin/bash

set -euxo pipefail


# Container Runtime
# Refer to: https://kubernetes.io/docs/setup/production-environment/container-runtimes/

## 转发 IPv4 并让 iptables 看到桥接流量
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system

## 禁用交换分区，使 kubelet 正常工作
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo swapoff -a

# Install common software
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y
sudo apt-get install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates jq

## Install docker engine
# Refer: https://docs.docker.com/engine/install/ubuntu/
if [ ! "$(command -v docker)" ]; then
    # Add Docker's official GPG key:
    sudo install -m 0755 -d /etc/apt/keyrings

    # Add the containerd official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o/etc/apt/keyrings/containerd-archive-keyring.gpg
    # Set up the repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/containerd-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/containerd.list
    sudo chmod a+r /etc/apt/keyrings/containerd-archive-keyring.gpg

    sudo apt-get update -y
    DOCKER_CE_VERSION_STRING=$(apt-cache madison docker-ce | grep $DOCKER_ENGINE_VERSION | head -1 | awk '{print $3}')
    sudo apt-get install -y docker-ce=$DOCKER_CE_VERSION_STRING docker-ce-cli=$DOCKER_CE_VERSION_STRING containerd.io

    # Refer: https://kubernetes.io/docs/setup/production-environment/container-runtimes/#cgroup-drivers
    sudo mkdir -p /etc/docker
    cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
    sudo systemctl enable docker
    sudo systemctl daemon-reload
    sudo systemctl restart docker
    sudo docker version
    sudo containerd config default > /etc/containerd/config.toml
    sudo systemctl restart containerd
    sudo containerd --v
fi

# Install kubeadm tools 
# Refer: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

## Install kubeadm kubelet kubectl
# command -v kubeadm 会返回 kubeadm 命令的路径如果它已经安装，如果没有安装，则返回空; ! "$()"则表达式的结果为真。
if [ ! "$(command -v kubeadm)" ]; then
    # Refer: https://github.com/kubernetes/k8s.io/pull/4837#issuecomment-1446426585
    sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.24/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.24/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

    sudo apt-get update -y
    KUBE_VERSION_STR=$(apt-cache madison kubelet | grep $KUBE_VERSION | head -1 | awk '{print $3}')
    sudo apt-get install -y kubelet="$KUBE_VERSION_STR" kubeadm="$KUBE_VERSION_STR" kubectl="$KUBE_VERSION_STR"
    sudo apt-mark hold kubelet kubeadm kubectl
fi
kubeadm version