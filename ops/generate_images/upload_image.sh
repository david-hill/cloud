openstack overcloud image upload --image-path /home/stack/cloud/ops/generate_images --whole-disk --update-existing

for node in $( openstack baremetal node list -c UUID -f value ); do
  openstack overcloud node configure $node
done
