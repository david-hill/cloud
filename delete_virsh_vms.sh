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
    sudo virsh undefine $type-$inc
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
