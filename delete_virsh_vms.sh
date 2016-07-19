#!/bin/bash

source functions
source_rc setup.cfg

if [ ! -z $1 ]; then
  installtype=$1
  if [ ! -z $2 ]; then
    releasever=$2
  fi
fi

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
        sudo virsh snapshot-delete $type-$inc-$releasever $snap 2>$stderr 1>$stdout
      done
      sudo virsh destroy $type-$inc-$releasever 2>$stderr 1>$stdout
      sudo virsh undefine $type-$inc-$releasever 2>$stderr 1>$stdout
    else
      ip=$(ip addr)
      if [[ ! "$ip" =~ $kvmhost ]]; then
        output=$(ssh root@$kvmhost "sudo virsh list --all | grep $type-$inc-$releasever")
        if [[ "$output" =~ $type-$inc-$releaserver ]]; then
          ssh root@$kvmhost "sudo virsh destroy $type-$inc-$releasever" 2>$stderr 1>$stdout
          ssh root@$kvmhost "sudo virsh undefine $type-$inc-$releasever" 2>$stderr 1>$stdout
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
