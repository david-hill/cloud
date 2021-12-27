nodes="control-0-rhosp16 control-1-rhosp16 control-2-rhosp16 compute-0-rhosp16 compute-1-rhosp16"

for node in $nodes; do
 openstack baremetal node set --raid-interface agent $node
 
 openstack baremetal node manage $node
 
 openstack baremetal node set $node --property root_device='{"name": "/dev/md127"}'
 
 echo '{
   "logical_disks": [
     {
       "size_gb": "MAX",
       "raid_level": "1",
       "controller": "software",
       "is_root_volume": true,
       "disk_type": "ssd"
     }
   ]
 }' | openstack baremetal node set $node --target-raid-config -
 
 echo '[{
   "interface": "raid",
   "step": "delete_configuration"
 },
 {
   "interface": "deploy",
   "step": "erase_devices_metadata"
 },
 {
   "interface": "raid",
   "step": "create_configuration"
 }]' | openstack baremetal node clean $node --clean-steps -
done

for node in $nodes; do
 openstack overcloud node provide $node
done

