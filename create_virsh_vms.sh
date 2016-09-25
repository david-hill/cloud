#!/bin/bash

source functions
source_rc setup.cfg

imagereleasever=$releasever

if [ ! -z $1 ]; then
  installtype=$1
  if [ ! -z $2 ]; then
    releasever=$2
    rdorelease=$releasever
  fi
fi

if [ -z $rdorelease ]; then
  if [ ! -d images/$imagereleasever/$minorver ]; then
    echo "Please put the overcloud images (compressed) in images/$imagereleasever/$minorver and retry..."
    exit 255
  fi
else
  if [ ! -d images/rdo-$rdorelease ]; then
    echo "Please put the overcloud images (compressed) in images/rdo-$rdorelease and retry..."
    exit 255
  fi
fi

function gen_disks {
    sudo qemu-img create -f qcow2 $tpath/$type-$inc-$releasever.qcow2 40G > /dev/null
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
    tpath=$jenkinspath/VMs
    gen_macs
    gen_xml
    gen_disks
    create_domain
    rc=$?
    if [ $rc -ne 0 ]; then
      break
    fi
    cleanup
    update_instackenv
    inc=$(expr $inc + 1)
  done
  return $rc
}

function send_images {
  startlog "Sending overcloud images to undercloud"
  ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no stack@$undercloudip 'if [ ! -e images ]; then mkdir images; fi' > /dev/null
  if [ -z $rdorelease ]; then
    cd images/$imagereleasever/$minorver
  else
    cd images/rdo-$rdorelease
  fi
  for file in *.tar; do
    rc=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no stack@$undercloudip "if [ -e images/$file ]; then echo present; fi")
    if [[ ! "$rc" =~ present ]] ; then
      scp -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $file stack@$undercloudip:images/ > /dev/null
      ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no stack@$undercloudip "cd images; tar xf $file" > /dev/null
      rc=$?
    fi
  done
  if [ -z $rdorelease ]; then
    cd ../../../
  else
    cd ../../
  fi
  if [[ "$installtype" =~ rdo ]]; then
    rhelimage=$(ls -atr images/rhel/ | grep qcow | tail -1)
    rc=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no stack@$undercloudip "if [ -e images/$rhelimage ]; then echo present; fi")
    if [[ ! "$rc" =~ present ]] ; then
      scp -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no images/rhel/$rhelimage stack@$undercloudip:images/ > /dev/null
      rc=$?
    fi
  fi
  endlog "done"
}

function send_instackenv {
  startlog "Copying instackenv to $undercloudip"
  scp -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no instackenv.json stack@$undercloudip: > /dev/null
  endlog "done"
}

if [ -e instackenv.json ]; then
  rm -rf instackenv.json
fi

validate_env
if [ $? -eq 0 ]; then
  startlog "Creating VMs for control"
  create_vm control
  if [ $? -eq 0 ]; then
    endlog "done"
    startlog "Creating VMs for compute"
    create_vm compute
    if [ $? -eq 0 ]; then
      endlog "done"
      startlog "Creating VMs for ceph"
      create_vm ceph
      if [ $? -eq 0 ]; then
        endlog "done"
        wait_for_reboot
        rc=$?
        if [ $rc -eq 0 ]; then
          send_instackenv
          send_images
        fi
      else
        endlog "error"
        rc=255
      fi
    else
      endlog "error"
      rc=255
    fi
  else  
    endlog "error"
    rc=255
  fi
else
  echo "Please run this from the KVM host..."
fi

exit $rc
