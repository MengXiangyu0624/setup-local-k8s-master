# Load settings from settings.yaml
require "yaml"
settings = YAML.load_file "settings.yaml"

WORKER_COUNT = settings["vm"]["workers"]["count"]
VM_IP_PREFIX = settings["vm"]["ip_prefix"]
VM_IP_START = settings["vm"]["ip_start"]
KUBE_VERSION = settings["kubernetes"]["version"]
CLUSTER_NAME = settings["kubernetes"]["cluster_name"]
POD_CIDR = settings["kubernetes"]["pod_cidr"]
SERVICE_CIDR = settings["kubernetes"]["service_cidr"]
CALICO_VERSION = settings["components"]["calico"]
DOCKER_ENGINE_VERSION = settings["components"]["docker_engine"]

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
# 定义 Vagrant 配置，"2" 表示使用的是 Vagrantfile API 版本 2。
Vagrant.configure("2") do |config|
    # 设置虚拟机的镜像 
    config.vm.box = settings["vm"]["box_image"]
    config.vm.box_check_update = false 

    # Set hosts file
    config.vm.provision "shell",
    env: {
      "VM_IP_PREFIX" => VM_IP_PREFIX,
      "VM_IP_START" => VM_IP_START,
      "WORKER_COUNT" => WORKER_COUNT,
      "CLUSTER_NAME" => CLUSTER_NAME
    },
    inline: <<-SHELL
      # master IP - hostname mapping
      sudo echo "$VM_IP_PREFIX$((VM_IP_START)) $CLUSTER_NAME-master" >> /etc/hosts
      # worker IP - hostname mapping
      for i in `seq 1 ${WORKER_COUNT}`; do
        echo "$VM_IP_PREFIX$((VM_IP_START+i)) $CLUSTER_NAME-worker0${i}" >> /etc/hosts
      done
    SHELL

    # 安装通用工具, 如 Container Runtime, kubeadm, kubelet 等
    config.vm.provision "install_common", type: "shell",
    # env: 环境变量只在 provision 时有效，而不是在虚拟机的整个生命周期中有效。
    # ./scripts/common.sh: 写入环境配置文件中，如 .bashrc 或 .profile才会长期生效。echo "export KUBE_VERSION=${KUBE_VERSION}" >> /home/vagrant/.bashrc
    env: {
      "KUBE_VERSION" => KUBE_VERSION,
      "DOCKER_ENGINE_VERSION" => DOCKER_ENGINE_VERSION
    },
    path: "./scripts/common.sh" 

    # Master 节点配置
    # 定义 k8s-master 虚拟机配置。此名称为 vagrant status 显示的名称
    # #{CLUSTER_NAME}-master 为虚拟机的名称: local-k8s-master
    # do |master| 是一个 Ruby 的块（block），用于对这个虚拟机实例进行详细的配置。
    # master 是块变量，表示当前定义的虚拟机实例，**在这个块内，可以使用 master 变量来访问和设置虚拟机的各种属性**

    config.vm.define "#{CLUSTER_NAME}-master" do |master|
      master.vm.provider "virtualbox" do |vb|
        vb.cpus = settings["vm"]["master"]["cpu"]
        vb.memory = settings["vm"]["master"]["memory"] 
        # 此名称为在 virtualbox 显示的名称
        vb.name = "#{CLUSTER_NAME}-master"
      end
      master.vm.hostname = "#{CLUSTER_NAME}-master"
      master.vm.network :private_network, ip: "#{VM_IP_PREFIX}#{VM_IP_START}"
      master.vm.provision "setup_master", type: "shell", privileged: true, 
      env: {
        "MASTER_IP" => "#{VM_IP_PREFIX}#{VM_IP_START}",
        "POD_CIDR" => POD_CIDR,
        "SERVICE_CIDR" => SERVICE_CIDR,
        "CALICO_VERSION" => CALICO_VERSION
      },
      path: "./scripts/master.sh" 
    end

    # Worker 节点配置
    # (1..WORKER_COUNT): 这是一个 Ruby 的范围表达式，表示从 1 到 WORKER_COUNT（一个在之前定义的变量，表示 Worker 节点的数量）的序列。
    # .each do |i|: 这是一个迭代器，它遍历上面定义的范围中的每一个数字。对于范围内的每个数字，迭代器会执行 do 和 end 之间的块（block），其中 i 是当前迭代的值。
    (1..WORKER_COUNT).each do |i| 
      config.vm.define "#{CLUSTER_NAME}-worker0#{i}" do |worker|
        worker.vm.hostname = "#{CLUSTER_NAME}-worker0#{i}" 
        worker.vm.network :private_network, ip: "#{VM_IP_PREFIX}#{i + VM_IP_START}"
        worker.vm.provider "virtualbox" do |vb|
          vb.cpus = settings["vm"]["workers"]["cpu"]
          vb.memory = settings["vm"]["workers"]["memory"] 
          vb.name = "#{CLUSTER_NAME}-worker0#{i}"
        end

        worker.vm.provision "setup_node", type: "shell",  path: "./scripts/node.sh" 
      end
    end
end