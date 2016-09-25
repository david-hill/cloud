#!/bin/bash

source functions
source_rc setup.cfg

if [ ! -z $1 ]; then
  installtype=$1
  if [ ! -z $2 ]; then
    releasever=$2
  fi
fi

if [[ "$installtype" =~ all ]]; then
  releasever='*'
fi

function delete_vms {
  type=$1
  inc=0
  output=$(sudo virsh list --all | grep -q "$type-$inc-$releasever" | awk '{ print $2 }')
  if [ $? -eq 0 ]; then
    ssh stack@$undercloudip 'sudo subscription-manager unregister' 2>$stderr 1>$stdout
    for snap in $(sudo virsh snapshot-list $output | egrep "shut off|running" | awk '{ print $1 }'); do
      sudo virsh snapshot-delete $output $snap 2>$stderr 1>$stdout
    done
    sudo virsh destroy $output 2>$stderr 1>$stdout
    sudo virsh undefine $output 2>$stderr 1>$stdout
  fi
}

function cleanup {
  if [ -e /home/stack/instackenv.json-$releasever ]; then
    sudo rm -rf /home/stack/instackenv.json-$releasever
  fi
}
delete_vms undercloud
cleanup
