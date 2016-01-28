image=$( glance image-list | grep cirros | head -1 | awk '{ print $2 }')
neutron=$( neutron net-list | grep test | awk '{ print $2 }')

nova boot --flavor m1.tiny --image $image  --nic $neutron test
