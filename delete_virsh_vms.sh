#!/bin/bahs

source setup.cfg

function delete_vms {
  type=$1
  inc=0
  if [[ $type =~ control ]]; then
    max=$controlscale
  else
    max=$computescale
  fi
  while [ $inc -lt $max ]; do
    virsh destroy $type-$inc
#    virsh undefine $type-$inc
    inc=$(expr $inc + 1)
  done
}

delete_vms control
delete_vms compute
