#!/bin/bash

source functions
source_rc setup.cfg

function delete_snapshots {
  type=$1
  inc=0
  if [[ $type =~ control ]]; then
    max=$controlscale
  elif [[ $type =~ ceph ]]; then
    max=$cephscale
  elif [[ $type =~ undercloud ]]; then
    max=0
  else
    max=$computescale
  fi
  while [ $inc -lt $max ]; do
    output=$(sudo virsh list --all | grep "$type-$inc-$releasever")
    if [[ "$output" =~ $type-$inc ]]; then
      for snap in $( sudo virsh snapshot-list $type-$inc-$releasever | grep poweroff | awk '{ print $1 }' ); do
        sudo virsh snapshot-delete $type-$inc-$releasever $snap > /dev/null
      done
    else
      ip=$(ip addr)
      if [[ ! "$ip" =~ $kvmhost ]]; then
        output=$(ssh root@$kvmhost "sudo virsh list --all | grep $type-$inc-$releasever")
        if [[ "$output" =~ $type-$inc-$releaserver ]]; then
          ssh root@$kvmhost "sudo virsh snapshot-delete $type-$inc-$releasever" > /dev/null
        fi
      fi
    fi
    inc=$(expr $inc + 1)
  done
}

delete_snapshots control
delete_snapshots ceph
delete_snapshots compute
delete_snapshots undercloud
