#!/bin/bash

source functions
source_rc setup.cfg

function delete_vms {
  type=$1
  inc=0
  if [[ $type =~ control ]]; then
    max=$controlscale
  elif [[ $type =~ ceph ]]; then
    max=$cephscale
  else
    max=$computescale
  fi
  while [ $inc -lt $max ]; do
    output=$(sudo virsh list --all | grep "$type-$inc-$releasever")
    if [[ "$output" =~ $type-$inc ]]; then 
      for snap in $(sudo virsh snapshot-list $type-$inc-$releasever | egrep "running|shut off" | awk '{ print $1 }'); do
        sudo virsh snapshot-delete $type-$inc-$releasever $snap > /dev/null
      done
      sudo virsh destroy $type-$inc-$releasever > /dev/null
      sudo virsh undefine $type-$inc-$releasever > /dev/null
    else
      ip=$(ip addr)
      if [[ ! "$ip" =~ $kvmhost ]]; then
        output=$(ssh root@$kvmhost "sudo virsh list --all | grep $type-$inc-$releasever")
        if [[ "$output" =~ $type-$inc-$releaserver ]]; then
          ssh root@$kvmhost "sudo virsh destroy $type-$inc-$releasever" > /dev/null
          ssh root@$kvmhost "sudo virsh undefine $type-$inc-$releasever" > /dev/null
        fi
      fi
    fi
    inc=$(expr $inc + 1)
  done
}

function cleanup {
  if [ -e /home/stack/instackenv.json ]; then
    sudo rm -rf /home/stack/instackenv.json
  fi
}
delete_vms control
delete_vms ceph
delete_vms compute
cleanup
