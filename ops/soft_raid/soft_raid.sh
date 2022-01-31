nodes="control-0-rhosp16 control-1-rhosp16 control-2-rhosp16 compute-0-rhosp16 compute-1-rhosp16"

function wait_for_active {
  inc=$1
  tnode=$2
  openstack baremetal node list | grep -q "$tnode.*manage"
  if [ $? -ne 0 ] && [ $inc -lt 30 ]; then
    openstack baremetal node list | grep -q "$tnode.*avail"
    if [ $? -ne 0 ]; then
      sleep 10
      inc=$(( $inc + 1 ))
      wait_for_active $inc $tnode
    fi
  fi
}

for node in $nodes; do
 inc=0
 openstack baremetal node set --raid-interface agent $node
 
 openstack baremetal node manage $node
 
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
 wait_for_active $inc $node
 openstack overcloud node provide $node
done
