Install kubernetes cluster with this BASH script.

Requrement:

- 25GB space on the Machine
- 6GB RAM
- 8 vCPS


1] Execute k8sinstall.sh script with parameter master and worker as 
$ ./k8sinstall.sh master worker

It will create 1 master node and 2 worker Node Virtual Machines(VM)

Once the VMs are installed it will deploy all the required things on the VMs and will join the VMs in k8s cluster.


