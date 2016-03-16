rpm -qi virt-install
if [ $? -ne 0 ]; then
  sudo yum install virt-install
fi

qemu-img create -f qcow2 /home/rhel72.qcow2 20G
virt-install --virt-type=kvm --name=rhel72 --ram 2048 --cdrom /home/dhill/Downloads/rhel-server-7.2-x86_64-dvd.iso --disk path=/home/rhel72.qcow2,format=qcow2 --network=bridge:virbr0 --graphics vnc,listen=0.0.0.0 --os-type=linux --os-variant=rhel7
