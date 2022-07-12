#/bin/bash

#cleanup resource created by vminstall.sh script

echo "Current directory path is :"
path=$(pwd)
echo $path

if [[ $path == "/var/lib/libvirt/images" ]]
then 
  echo "we are on the correct path"
else
  echo "Moving to correct path"
  cd "/var/lib/libvirt/images"
  pwd
fi  

echo "Cleaning data"
echo "listing before deleting"
names=$(sudo ls)

for name in $names
do
   sudo virsh destroy $name --graceful
   echo "VM $name is destroyed"
   sudo rm -fr $name
   echo "folder deleted $name"
   (i=$i+1)
done
echo "listing AFTER deleting"
sudo ls -a
sudo virsh list
