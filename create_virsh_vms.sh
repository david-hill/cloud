#!/bin/bash

source functions
source_rc setup.cfg

function gen_disks {
    startlog "Creating $tpath/$type-$inc-$releasever.qcow2"
    sudo qemu-img create -f qcow2 $tpath/$type-$inc-$releasever.qcow2 40G > /dev/null
    endlog "done"
}
function update_instackenv {
  if [ ! -z "$rootpassword" ]; then
    if [ ! -e instackenv.json ]; then
       echo "{ \"nodes\" : [ { \"arch\": \"x86_64\", \"pm_user\": \"root\", \"pm_addr\": \"$kvmhost\", \"pm_password\": \"$rootpassword\", \"pm_type\": \"pxe_ssh\", \"mac\": [ \"$mac1\" ], \"cpu\": \"1\", \"memory\": \"1024\", \"disk\": \"1\" } ] }" > instackenv.json
    else
       sed -i 's/\} \] \}$//' instackenv.json
       echo "}, { \"arch\": \"x86_64\", \"pm_user\": \"root\", \"pm_addr\": \"$kvmhost\", \"pm_password\": \"$rootpassword\", \"pm_type\": \"pxe_ssh\", \"mac\": [ \"$mac1\" ], \"cpu\": \"1\", \"memory\": \"1024\", \"disk\": \"1\" } ] }">> instackenv.json
    fi
  fi
}
function create_vm {
  type=$1
  inc=0
  if [[ $type =~ control ]]; then
    max=$controlscale
    memory=$controlmemory
  elif [[ $type =~ ceph ]]; then
    max=$cephscale
    memory=$cephmemory
  else
    max=$computescale
    memory=$computememory
  fi
  while [ $inc -lt $max ]; do
    tmpfile=$(mktemp)
    uuid=$(uuidgen)
    tpath=$(df | sort -k4,4n | tail -1 | awk '{ print $6 }')
    gen_macs
    gen_xml
    gen_disks
    create_domain
    cleanup
    update_instackenv
    inc=$(expr $inc + 1)
  done
}

function send_images {
  ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no stack@$undercloudip 'if [ ! -e images ]; then mkdir images; fi' > /dev/null
  cd images/$releasever/$minorver
  for file in *.tar; do
    rc=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no stack@$undercloudip "if [ -e images/$file ]; then echo present; fi")
    if [[ ! "$rc" =~ present ]] ; then
      scp -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $file stack@$undercloudip:images/ > /dev/null
      ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no stack@$undercloudip "cd images; tar xf $file" > /dev/null
    fi
  done
  cd ..
}

function send_instackenv {
  startlog "Copying instackenv to $undercloudip"
  scp -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no instackenv.json stack@$undercloudip: > /dev/null
  endlog "done"
}
rm -rf instackenv.json
validate_env
if [ $? -eq 0 ]; then
  create_vm control
  create_vm compute
  create_vm ceph
  send_instackenv
  send_images
else
  echo "Please run this from the KVM host..."
fi
