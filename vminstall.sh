#/bin/bash

echo "Please enter VM_NAME to be created"
read vm_name

#echo "Create a new user for $vm_name"
#read username

#echo "Create password for user $username"
#read password

echo "Download the Ubuntu 20.04 server cloud image and rename to qcow2"


sudo mkdir /var/lib/libvirt/images/templates
filename=focal-server-cloudimg-amd64.img
file=$(ls |grep focal)

if [[ "$file" == "$filename" ]] 
then
   echo "File focal-server-cloudimg-amd64.img is already on the local device"
else
   wget https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img
fi   

sudo cp -i focal-server-cloudimg-amd64.img /var/lib/libvirt/images/templates/$vm_name.ubuntu-20-server.qcow2

#This command is for ubuntu/Linux mint version

echo "Install cloud-utils and whois packages"
sudo apt update && sudo apt install cloud-utils whois -y


echo "Passing command line argumets VM_NAME, Username, Password"
VM_NAME=$vm_name
USERNAME=ubuntu
PASSWORD=admin

echo "Convert downloaded cloud image to qcow2"

sudo mkdir /var/lib/libvirt/images/$VM_NAME && sudo qemu-img convert -f qcow2 -O qcow2 /var/lib/libvirt/images/templates/$vm_name.ubuntu-20-server.qcow2  /var/lib/libvirt/images/$VM_NAME/$VM_NAME.root-disk.qcow2

echo "Increase disk size for the VM"
sudo qemu-img resize /var/lib/libvirt/images/$VM_NAME/$VM_NAME.root-disk.qcow2 6G

echo "Create a cloud-init configuration"

sudo echo "#cloud-config
system_info:
  default_user:
    name: $USERNAME
    home: /home/$USERNAME

password: $PASSWORD
chpasswd: { expire: False }
hostname: $VM_NAME

# configure sshd to allow users logging in using password
# rather than just keys
ssh_pwauth: True
" | sudo tee /var/lib/libvirt/images/$VM_NAME/$VM_NAME.cloud-init.cfg


echo "Create the ISO file from the cloud config file"
sudo cloud-localds /var/lib/libvirt/images/$VM_NAME/$VM_NAME.cloud-init.iso /var/lib/libvirt/images/$VM_NAME/$VM_NAME.cloud-init.cfg

echo "Install VM"
sudo virt-install --name $VM_NAME --memory 2048 --disk /var/lib/libvirt/images/$VM_NAME/$VM_NAME.root-disk.qcow2,device=disk,bus=virtio --disk /var/lib/libvirt/images/$VM_NAME/$VM_NAME.cloud-init.iso,device=cdrom --os-type linux --os-variant ubuntu19.04 --virt-type kvm --graphics none --network network=default,model=virtio --import --noautoconsole
sleep 30

echo "Make sure Virtual Machine is Running"
sudo virsh list

echo "Get ip address of the system"
sudo virsh domifaddr $VM_NAME

#### Reference Doc :  https://blog.programster.org/create-ubuntu-20-kvm-guest-from-cloud-image

#### To clean up resources created by this script, you can delete the same with below command:
# $ pwd
# /var/lib/libvirt/images
# $ sudo ls -a
# $ sudo rm -fr geeksurf templates
