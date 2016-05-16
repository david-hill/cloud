#!/bin/bash

source functions
source_rc setup.cfg

function delete_vms {
  type=$1
  inc=0
  output=$(sudo virsh list --all | grep "$type-$inc-$releasever")
  ssh stack@$undercloudip 'sudo subscription-manager unregister'
  for snap in $(sudo virsh snapshot-list $type-$inc-$releasever | egrep "shut off|running" | awk '{ print $1 }'); do
    sudo virsh snapshot-delete $type-$inc-$releasever $snap 2>$stderr 1>$stdout
  done
  sudo virsh destroy $type-$inc-$releasever 2>$stderr 1>$stdout
  sudo virsh undefine $type-$inc-$releasever 2>$stderr 1>$stdout
}

function cleanup {
  if [ -e /home/stack/instackenv.json-$releasever ]; then
    sudo rm -rf /home/stack/instackenv.json-$releasever
  fi
}
delete_vms undercloud
cleanup
