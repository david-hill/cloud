#!/bin/bash

source functions
source_rc setup.cfg
vbmc=$( which vbmc )

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
  rc=$?
  if [ $rc -eq 0 ]; then
    restore_permissions $tpath/$type-$inc-$releasever.qcow2
    rc=$?
    if [ $rc -eq 0 ]; then
      sudo qemu-img create -f qcow2 $tpath/$type-$inc-$releasever-vdb.qcow2 50G > /dev/null
      rc=$?
      if [ $rc -eq 0 ]; then
        restore_permissions $tpath/$type-$inc-$releasever-vdb.qcow2
        rc=$?
      fi
    fi
  fi
  return $rc
}
function update_instackenv {
  if [ ! -z "${vbmc}" ]; then
    if [ ! -z "$rootpassword" ]; then
      if [ ! -e instackenv.json ]; then
         echo "{ \"nodes\" : [ { \"arch\": \"x86_64\", \"pm_user\": \"root\", \"pm_addr\": \"$pm_ip\", \"pm_password\": \"root\", \"pm_type\": \"pxe_ipmitool\", \"mac\": [ \"$mac1\" ], \"cpu\": \"1\", \"memory\": \"1024\", \"disk\": \"30\" } ] }" > instackenv.json
      else
         sed -i 's/\} \] \}$//' instackenv.json
         echo "}, { \"arch\": \"x86_64\", \"pm_user\": \"root\", \"pm_addr\": \"$pm_ip\", \"pm_password\": \"root\", \"pm_type\": \"pxe_ipmitool\", \"mac\": [ \"$mac1\" ], \"cpu\": \"1\", \"memory\": \"1024\", \"disk\": \"30\" } ] }">> instackenv.json
      fi
    fi
  else
    if [ ! -z "$rootpassword" ]; then
      if [ ! -e instackenv.json ]; then
         echo "{ \"nodes\" : [ { \"arch\": \"x86_64\", \"pm_user\": \"root\", \"pm_addr\": \"$kvmhost\", \"pm_password\": \"$rootpassword\", \"pm_type\": \"pxe_ssh\", \"mac\": [ \"$mac1\" ], \"cpu\": \"1\", \"memory\": \"1024\", \"disk\": \"30\" } ] }" > instackenv.json
      else
         sed -i 's/\} \] \}$//' instackenv.json
         echo "}, { \"arch\": \"x86_64\", \"pm_user\": \"root\", \"pm_addr\": \"$kvmhost\", \"pm_password\": \"$rootpassword\", \"pm_type\": \"pxe_ssh\", \"mac\": [ \"$mac1\" ], \"cpu\": \"1\", \"memory\": \"1024\", \"disk\": \"30\" } ] }">> instackenv.json
      fi
    fi
  fi
}

function get_next_ip {
  prefix="192.168.122."
  suffix=10
  found=0
  output=$( sudo ${vbmc} list )
  while [ $found -eq 0 ]; do
    echo $output | grep 623 | grep -q "$prefix${suffix}\ "
    if [ $? -eq 1 ]; then
      found=1
    else
      suffix=$(( $suffix + 1 ))
    fi
  done
  pm_ip="192.168.122.$suffix"
}

function start_vbmc_instance {
  break=3
  while [ $rc -ne 0 ] && [ $break -gt 0 ]; do
    sudo ${vbmc} start $type-$inc-$localtype 2>>$stderr 1>>$stdout
    rc=$?
    if [ $rc -eq 0 ]; then
      sudo ${vbmc} list 2>>$stderr | grep running | grep -q $type-$inc-$localtype
      rc=$?
    fi
    if [ $rc -ne 0 ]; then
      break=$(( $break - 1))
      sleep $break
    fi
  done
  return $rc
}


function set_bmc_ip {
  rc=255
  if [[ $installtype =~ rdo ]]; then
    localtype=$rdorelease
  else
    localtype=$releasever
  fi
  if [ ! -z "${vbmc}" ]; then
    pm_ip=$(sudo vbmc list | grep $type-$inc-$localtype | awk '{ print $4}')
    if [ -z "${pm_ip}" ]; then
      get_next_ip
      sudo ip addr add $pm_ip dev virbr0 2>>$stderr 1>>$stdout
      sudo vbmc list | grep -q $type-$inc-$localtype
      rc=$?
      if [ $rc -ne 0 ]; then
        sudo ${vbmc} add --address $pm_ip --username root --password root $type-$inc-$localtype 2>>$stderr 1>>$stdout
        rc=$?
      fi
      if [ $rc -eq 0 ]; then
        sudo ${vbmc} list 2>>$stderr | grep running | grep -q $type-$inc-$localtype
        rc=$?
        if [ $rc -ne 0 ]; then
          sudo ${vbmc} list 2>>$stderr | grep down | grep -q $type-$inc-$localtype
          rc=$?
          if [ $rc -eq 0 ]; then 
            start_vbmc_instance
            rc=$?
          fi
        fi
      fi
    fi
  else
    rc=0
  fi
  return $rc
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
    pxeenabled=on
    gen_xml
    gen_disks
    create_domain
    rc=$?
    if [ $rc -ne 0 ]; then
      break
    fi
    cleanup
    set_bmc_ip
    rc=$?
    if [ $rc -ne 0 ]; then
      break
    fi
    update_instackenv
    inc=$(expr $inc + 1)
  done
  return $rc
}

function send_images {
  skip=0
  if [[ "$installtype" =~ internal ]]; then
    subfolder="-$installtype"
    if [ ! -d images/$imagereleasever/${minorver}${subfolder} ]; then
      mkdir -p images/$imagereleasever/${minorver}${subfolder}
      skip=1
    fi
  else
    subfolder=
  fi

  if [ $skip -eq 0 ]; then
    startlog "Sending overcloud images to undercloud"
    ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no stack@$undercloudip 'if [ ! -e images ]; then mkdir images; fi' > /dev/null
    if [ -z $rdorelease ]; then
      cd images/$imagereleasever/${minorver}${subfolder}
      if [ -e rhosp-director-images.latest ]; then
        scp -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no rhosp-director-images.latest stack@$undercloudip:rhosp-director-images.previous 2>>$stderr 1>>$stdout
      fi
    else
      cd images/rdo-$rdorelease
    fi
    for file in *.tar; do
      if [ ! -z "${file}" ]; then
        rc=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no stack@$undercloudip "if [ -e images/$file ]; then echo present; fi")
        if [[ ! "$rc" =~ present ]] ; then
          scp -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $file stack@$undercloudip:images/ > /dev/null
          ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no stack@$undercloudip "cd images; tar xf $file" > /dev/null
          rc=$?
        else
          rc=0
        fi
      fi
    done
    if [ -z $rdorelease ]; then
      cd ../../../
    else
      cd ../../
    fi
  fi
  if [[ "$installtype" =~ rdo ]]; then
    rhelimage=$(ls -atr images/rhel/ | grep qcow2 | grep $rhel | tail -1)
    rc=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no stack@$undercloudip "if [ -e images/$rhelimage ]; then echo present; fi")
    if [[ ! "$rc" =~ present ]] ; then
      scp -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no images/rhel/$rhelimage stack@$undercloudip:images/ > /dev/null
      rc=$?
    else
      rc=0
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
        startlog "Resuming stopped vbmc engines"
        sudo bash resume_vbmc.sh 2>>$stderr 1>>$stdout
        endlog "done"
        startlog "Waiting for VM to reboot"
        wait_for_reboot
        rc=$?
        if [ $rc -eq 0 ]; then
          endlog "done"
          send_instackenv
          send_images
        else
          endlog "error"
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
