#!/bin/bahs

source setup.cfg

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
    output=$(sudo "virsh list" | grep "$type-$inc")
    if [[ "$output" =~ $type-$inc ]]; then 
      virsh undefine $type-$inc
    else
      ssh root@$kvmhost "virsh undefine $type-$inc"
    fi
    inc=$(expr $inc + 1)
  done
}

function cleanup {
  sudo rm -rf instackenv.json
}
delete_vms control
delete_vms ceph
delete_vms compute
cleanup
