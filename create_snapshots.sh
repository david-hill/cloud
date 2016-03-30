#!/bin/bash

source functions
source_rc setup.cfg

function create_snapshosts {
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
      sudo virsh snapshot-create $type-$inc-$releasever $snap > /dev/null
    else
      ip=$(ip addr)
      if [[ ! "$ip" =~ $kvmhost ]]; then
        output=$(ssh root@$kvmhost "sudo virsh list --all | grep $type-$inc-$releasever")
        if [[ "$output" =~ $type-$inc-$releaserver ]]; then
          ssh root@$kvmhost "sudo virsh snapshot-create $type-$inc-$releasever" > /dev/null
        fi
      fi
    fi
    inc=$(expr $inc + 1)
  done
}

create_snapshots control
create_snapshots ceph
create_snapshots compute
