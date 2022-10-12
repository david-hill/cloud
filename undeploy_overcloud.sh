source functions
source_rc setup.cfg
source_rc /home/stack/stackrc

openstack overcloud node unprovision -y --all --stack overcloud --network-ports /home/stack/$releasever/baremetal.yaml

subnet=$(openstack subnet list | grep ctlplane | awk '{ print $2 }')
skipid=$(openstack port list | grep -v virtual_ip | grep $subnet | awk '{ print $2 }')

for port in $( openstack port list -f value -c ID | grep -v $skipid ); do
  openstack port delete $port;
done



rm -rf ~/$releasever/*deployed*
