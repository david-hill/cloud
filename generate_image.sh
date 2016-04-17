rpm -qi virt-install
if [ $? -ne 0 ]; then
  sudo yum install virt-install
fi


bootimage=/home/dhill/Downloads/rhel-server-7.2-x86_64-dvd.iso
backingdisk=rhel72.qcow2
name=rhel72

bootimage=/home/dhill/Downloads/isos/Fedora-Workstation-netinst-x86_64-24-20160407.n.2.iso
backingdisk=fc24.qcow2
name=fc24

qemu-img create -f qcow2 /home/$backingdisk 20G
virt-install --virt-type=kvm --name=$name --ram 2048 --cdrom ${bootimage} --disk path=/home/$backingdisk,format=qcow2 --network=bridge:virbr0 --graphics vnc,listen=0.0.0.0 --os-type=linux --os-variant=rhel7
