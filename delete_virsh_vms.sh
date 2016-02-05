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
    output=$(sudo virsh list --all | grep "$type-$inc")
    if [[ "$output" =~ $type-$inc ]]; then 
      sudo virsh undefine $type-$inc
    else
      ip=$(ip addr)
      if [[ ! "$ip" =~ $kvmhost ]]; then
        output=$(ssh root@$kvmhost "sudo virsh list --all | grep $type-$inc")
        if [[ "$output" =~ $type-$inc ]]; then
          ssh root@$kvmhost "sudo virsh undefine $type-$inc"
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
