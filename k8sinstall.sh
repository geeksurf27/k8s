#!/bin/bash

source vminstallfunc.sh

MASTERNAME=$(sudo virsh -q list | awk '{print $2}' |grep master)
MASTERIP=$(sudo virsh -q domifaddr $MASTERNAME | awk '{print $4}' |grep -o -P "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}")
function get_master_node_ready()
{
	echo -e "\n\e[1;32m Login to Master server $MASTERNAME \e[0m\n"

	echo -e "\n\e[1;32m enable_Modules on Master \e[0m\n"
        sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no $USERNAME@$MASTERIP sudo bash -c "'$(declare -f enable_modules); enable_modules'" 2>&1
        
	echo -e "\n\e[1;32m Deploy Docker on Master Node \e[0m\n"
        sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no  $USERNAME@$MASTERIP "echo '${PASSWORD}' | sudo --stdin bash -c '$(declare -f install_docker); install_docker'" 2>&1
        
	echo -e "\n\e[1;32m Install k8s packages \e[0m\n"
        sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no  $USERNAME@$MASTERIP "echo '${PASSWORD}' | sudo --stdin bash -c '$(declare -f install_kube_package); install_kube_package'" 2>&1
	
	echo -e "\n\e[1;32m Enable Ports on Master server \e[0m\n"
        sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no  $USERNAME@$MASTERIP "echo '${PASSWORD}' | sudo --stdin bash -c '$(declare -f enable_ports_on_master); enable_ports_on_master'" 2>&1
	
	echo -e "\n\e[1;32m Initialize Control Plane \e[0m\n"
        sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no  $USERNAME@$MASTERIP "echo '${PASSWORD}' | sudo --stdin bash -c '$(declare -f initialize_controlplane_node); initialize_controlplane_node'" 2>&1
}

function get_worker_node_ready()
{	
	for worker in $(sudo virsh -q list | awk '{print $2}' |grep worker)
do
	WORKERIP=$(sudo virsh -q domifaddr "$worker" | awk '{print $4}' |grep -o -P "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}")
        
	echo -e "\n\e[1;32m Here is the WORKERIP $WORKERIP \e[0m\n"
	
	echo -e "\n\e[1;32m Login to Worker Node $VM_NAME\e[0m\n"

        echo -e "\n\e[1;32m enable_Modules on Worker Node $VM_NAME \e[0m\n"
        sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no  $USERNAME@$WORKERIP "echo '${PASSWORD}' | sudo --stdin bash -c '$(declare -f enable_modules); enable_modules'" 2>&1
        
	echo -e "\n\e[1;32m Deploy Docker on Worker Node $VM_NAME \e[0m\n"
        sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no  $USERNAME@$WORKERIP "echo '${PASSWORD}' | sudo --stdin bash -c '$(declare -f install_docker); install_docker'" 2>&1
        
	echo -e "\n\e[1;32m Install k8s packages on Worker Node $VM_NAME\e[0m\n"
        sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no  $USERNAME@$WORKERIP "echo '${PASSWORD}' | sudo --stdin bash -c '$(declare -f install_kube_package); install_kube_package'" 2>&1
	
        echo -e "\n\e[1;32m Enable Ports on Worker node $VM_NAME\e[0m\n"
        sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no  $USERNAME@$WORKERIP "echo '${PASSWORD}' | sudo --stdin bash -c '$(declare -f enable_ports_on_worker); enable_ports_on_worker'" 2>&1

	echo -e "\n\e[1;32m Login to Worker node $VM_NAME to join cluster\e[0m\n"
        sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no  $USERNAME@$MASTERIP "sshpass -p $PASSWORD scp -o StrictHostKeyChecking=no output.txt $USERNAME@$WORKERIP:output.txt"

	sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no  $USERNAME@$WORKERIP "echo '${PASSWORD}' | sudo --stdin bash -c '$(declare -f join_cluster); join_cluster'" 2>&1

done
sleep 60s
}

function join_cluster()
{
	echo -e "\n\e[1;32m ## Joining WORKERNODE $VM_NAME node to kubernetes cluster...!\e[0m\n"
        sudo rm /etc/containerd/config.toml
        sudo systemctl restart containerd
        
	grep "kubeadm\|hash" $PWD/output.txt |grep "token">join.sh
	chmod +x join.sh
	./join.sh
	sleep 60s
}

function verifiy_cluster_details()
{

	echo -e "\n\e[1;32m Verify Cluster Details from Master \e[0m\n"
        sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no  $USERNAME@$MASTERIP "echo '${PASSWORD}' | sudo --stdin bash -c '$(declare -f cluster_details); cluster_details'" 2>&1
}

function cluster_details()
{
	export KUBECONFIG=$HOME/.kube/config
	echo -e "\n\e[1;32m ## Check cluster-info...!\e[0m\n"
	kubectl cluster-info

	echo -e "\n\e[1;32m ## Verifying all node status...!\e[0m\n"
	echo -e "\n"
	kubectl get nodes

        echo -e "\n\e[1;32m ## Check all pod status...!\e[0m\n"
        echo -e "\n"
        kubectl get pods --all-namespaces
}

function enable_ports_on_master()
{
	echo -e "\n\e[1;32m Opening required ports on the Master server \e[0m\n"
	sudo ufw --force enable
	m_ports=(21,22,6443,2379,2380,10248,10250,10257,10259)
	for port in "${m_ports[@]}"
	do
		sudo ufw allow $port/tcp
	        echo "Port $port Allowed"
	done
	sudo ufw reload
	sudo ufw status verbose
}

function enable_ports_on_worker()
{
        echo -e "\n\e[1;32m Opening required ports on the worker Node $VM_NAME \e[0m\n"
        sudo ufw --force enable
        w_ports=(21,22,10250,30000:32767)
        for port in "${w_ports[@]}"
        do
                sudo ufw allow $port/tcp
                echo "Port $port Allowed"
        done
        sudo ufw reload
	sudo ufw status verbose
}

function install_docker()
{
	# Add repo and Install packages
	sudo apt update
	sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	sudo apt update
	sudo apt install -y containerd.io docker-ce docker-ce-cli

	# Create required directories
	sudo mkdir -p /etc/systemd/system/docker.service.d

	# Create daemon json config file
sudo tee /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

	# Start and enable Services
	sudo systemctl daemon-reload 
	sudo systemctl restart docker
	sudo systemctl enable docker

}

function enable_modules()
{
        module_k8s="/etc/modules-load.d/kubernetes.conf"
        sysctl_k8s="/etc/sysctl.d/99-kubernetes.conf"
        touch "$module_k8s"
        echo "br_netfilter" >> "$module_k8s"
        echo "overlay" >> "$module_k8s"
        modprobe br_netfilter
        modprobe overlay
        touch "$sysctl_k8s"
        echo "net.bridge.bridge-nf-call-ip6tables = 1" >> "$sysctl_k8s"
        echo "net.bridge.bridge-nf-call-iptables = 1" >> "$sysctl_k8s"
        echo "net.ipv4.ip_forward                 = 1" >> "$sysctl_k8s"
        sysctl --system
}

function install_kube_package()
{
  	sudo apt install sshpass -y
	sudo apt-get install -y apt-transport-https ca-certificates curl
	sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
	sudo echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
	sudo apt-get update -y
	sudo apt-get install -y kubelet kubeadm kubectl
	sudo apt-mark hold kubelet kubeadm kubectl
}

function initialize_controlplane_node()
{
	sudo rm /etc/containerd/config.toml
	sudo systemctl restart containerd
	api_server_ip=$MASTERIP
        sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address="$api_server_ip" | tee -a output.txt

	mkdir -p $HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config
	sleep 60s
	kubectl get nodes
	JOIN_CMD=$(grep "kubeadm\|hash" $PWD/output.txt |grep "token")

        echo -e "\n\e[1;32m ## Installing pod network add-on 'flannel' for cluster...!\e[0m\n"
	kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
	sleep 30s
	kubectl get nodes
}

echo -e "\n\e[1;32m ## The kubernetes installation started...!\e[0m\n"
get_master_node_ready
echo -e "\n\e[1;32m ## The kubernetes initialized successfully on master node...!\e[0m\n"
echo -e "\n\e[1;32m ## Get Worker Node details\e[0m\n"
get_worker_node_ready
echo -e "\n\e[1;32m ##  cluster details\e[0m\n"
verifiy_cluster_details

