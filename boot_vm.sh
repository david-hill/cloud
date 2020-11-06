#!/bin/bash

source functions
source_rc setup.cfg
source_rc overcloudrc

rc=255

vmname=test-vm

startlog "Getting image list"
image=$( glance image-list 2>>$stderr | grep cirros | head -1 | awk '{ print $2 }')
if [ -z "${image}" ]; then
  image=$( openstack image list 2>>$stderr | grep cirros | head -1 | awk '{ print $2 }')
fi
endlog "done"

startlog "Getting network list"
neutron=$( neutron net-list 2>>$stderr | grep test | awk '{ print $2 }')
endlog "done"

function delete_secgroup_rule {
  startlog "Deleting rule from default security group"
  nova secgroup-delete-rule default icmp -1 -1 0.0.0.0/0 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -ne 0 ]; then
    ruleid=$( neutron security-group-rule-list 2>>$stderr | grep icmp | awk -F\| '{ print $2 }' )
    neutron security-group-rule-delete ${ruleid} 2>>$stderr 1>>$stdout
    rc=$?
  fi
  nova secgroup-delete-rule default tcp 22 22 0.0.0.0/0 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -ne 0 ]; then
    ruleid=$( neutron security-group-rule-list 2>>$stderr | grep tcp | awk -F\| '{ print $2 }' )
    neutron security-group-rule-delete ${ruleid} 2>>$stderr 1>>$stdout
    rc=$?
  fi
  if [ $rc -ne 0 ]; then
    groupid=$(nova list-secgroup ${vmname} | awk -F\| '{ print $2 }' | sed -e 's/Id //')
    openstack security group show ${groupid} 2>>$stderr | grep -q icmp
    if [ $? -eq 0 ]; then
      openstack security group rule delete  --protocol icmp ${groupid} 2>>$stderr 1>>$stdout
      rc=$?
      if [ $rc -eq 0 ]; then
        openstack security group rule delete  --protocol tcp ${groupid} 2>>$stderr 1>>$stdout
        rc=$?
      fi
    fi
  fi
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
  fi
  return $rc
}
function delete_vm {
  startlog "Deleting test VM"
  nova delete ${vmname} 2>>$stderr 1>>$stdout
  state=$(nova list | grep ${vmname}  )
  while [ "$state" != "" ]; do
    state=$(nova list | grep ${vmname} )
  done
  endlog "done"
}
function delete_floating_ip {
  startlog "Deleting floating IP"
  nova floating-ip-delete $ip 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -ne 0 ]; then
    openstack floating ip delete $ip 2>>$stderr 1>>$stdout
    rc=$?
  fi
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
  fi
  return $rc
}
function delete_flavor {
  startlog "Deleting flavor"
  nova flavor-delete m1.micro 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    openstack flavor delete m1.micro 2>>$stderr 1>>$stdout
    rc=$?
    if [ $rc -eq 0 ]; then
      endlog "done"
    else
      endlog "error"
    fi
  fi
  return $rc
}

function unprovision_vm {
  delete_secgroup_rule
  rc=$?
  if [ $rc -eq 0 ]; then
    delete_vm
    delete_floating_ip
    rc=$?
    if [ $rc -eq 0 ]; then
      delete_flavor
      rc=$?
      if [ $rc -eq 0 ]; then
        delete_keypair
        rc=$?
        if [ $rc -eq 0 ]; then
          delete_volume
          rc=$?
        fi
      fi
    fi
  fi
  return $rc
}

function set_flavor {
  startlog "Setting m1.micro flavor properties"
  openstack flavor set m1.micro --property hw:cpu_policy=dedicated
  rc=$?
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
  fi

  return $rc
}
function create_flavor {
  startlog "Creating m1.micro flavor"
  nova flavor-list 2>>$stderr | grep -q m1.micro
  rc=$?
  if [ $rc -eq 1 ]; then
    nova flavor-create m1.micro auto 256 1 1 2>>$stderr 1>>$stdout
    rc=$?
    if [ $rc -eq 0 ]; then
      endlog "done"
    else
      openstack flavor create m1.micro --ram 256 --vcpus 1 --disk 1 2>>$stderr 1>>$stdout
      rc=$?
      if [ $rc -eq 0 ]; then
        endlog "done"
      else
        endlog "error"
      fi
    fi
  else
    rc=0
    endlog "done"
  fi
  return $rc
}

function create_volume {
  startlog "Creating volume test-boot-volume"
  volid=$(cinder list | grep test-boot-volume | awk '{ print $2 }')
  if [ -z "${volid}" ]; then
    volid=$(cinder create --image-id=$image --display_name=test-boot-volume 1 | grep "\ id\ " | awk '{ print $4 }')
  fi
  if [ ! -z "${volid}" ]; then
    endlog "done"
  else
    endlog "error"
  fi
}

function delete_volume {
  rc=0
  if [ ! -z "${volid}" ]; then
    cinder list | grep -q $volid 
    if [ $? -eq  0 ]; then
      startlog "Deleting volume $volid"
      cinder delete $volid 2>>$stderr 1>>$stdout
      rc=$?
      if [ $rc -eq 0 ]; then
        endlog "done"
      else
        endlog "error"
      fi
    else
      rc=0
    fi
  fi
  return $rc
}
function wait_for_volume {
  inc=0
  while ! $( cinder list | grep $volid | egrep -q "available|error") && [ $inc -lt 10 ]; do
    inc=$(( $inc +1 ))
    sleep 1
  done
}

function create_boot_from_volume_test_vm {
  nova list 2>>$stderr | grep -q ${vmname}
  rc=$?
  if [ $rc -eq 1 ]; then
    create_volume
    startlog "Creating test VM"
    if [ ! -z $volid ]; then
      wait_for_volume
      if $( cinder list | grep $volid | grep -q available ); then
#        nova boot --flavor m1.micro --block-device source=volume,id=$volid,dest=volume,size=1,shutdown=preserve,bootindex=0  --nic net-id=$neutron ${vmname} 2>>$stderr 1>>$stdout
        nova boot --key-name test --flavor m1.micro --block-device source=volume,id=$volid,dest=volume,size=1,shutdown=remove,bootindex=0  --nic net-id=$neutron ${vmname} 2>>$stderr 1>>$stdout
        rc=$?
      else
        rc=252
      fi
    fi

    if [ $rc -eq 0 ]; then
      endlog "done"
    else
      endlog "error"
    fi
  else
    delete_vm
    rc=$?
    if [ $rc -eq 0 ]; then
      create_boot_from_volume_test_vm
      rc=$?
    fi
  fi
  return $rc
}

function create_test_vm {
  nova list 2>>$stderr | grep -q ${vmname}
  rc=$?
  if [ $rc -eq 1 ]; then
    startlog "Creating test VM"
    nova boot --key-name test --flavor m1.micro --image $image  --nic net-id=$neutron ${vmname} 2>>$stderr 1>>$stdout
    rc=$?
    if [ $rc -eq 0 ]; then
      endlog "done"
    else
      endlog "error"
    fi
  else
    delete_vm
    rc=$?
    if [ $rc -eq 0 ]; then
      create_test_vm
      rc=$?
    fi
  fi
  return $rc
}

function wait_for_vm {
  rc=0
  startlog "Waiting for VM to come up"
  state=$(nova list | grep ${vmname} | awk '{ print $6 }')
  while [[ ! "$state" =~ ACTIVE ]] && [[ ! "$state" =~ ERROR ]]; do
    state=$(nova list | grep ${vmname} | awk '{ print $6 }')
  done
  if [[ "$state" =~ ACTIVE ]]; then
    endlog "done"
  else
    endlog "error"
    rc=255
  fi
  return $rc
}
function add_secgroup_rule {
  startlog "Adding rule to default security group"
  nova secgroup-list-rules default 2>>$stderr | grep -q icmp
  rc=$?
  if [ $rc -ne 0 ]; then
    nova secgroup-add-rule default icmp -1 -1 0/0 2>>$stderr 1>>$stdout
    rc=$?
    if [ $rc -ne 0 ]; then
      groupid=$(nova list-secgroup ${vmname} | awk -F\| '{ print $2 }' | sed -e 's/Id //')
      openstack security group show ${groupid} 2>>$stderr | grep -q icmp
      rc=$?
      if [ $rc -eq 1 ]; then
        openstack security group rule create --protocol icmp ${groupid} 2>>$stderr 1>>$stdout
        rc=$?
        if [ $rc -eq 0 ]; then
          openstack security group rule create --protocol tcp ${groupid} 2>>$stderr 1>>$stdout
          rc=$?
        fi
      fi
    else
      nova secgroup-add-rule default tcp 22 22 0/0 2>>$stderr 1>>$stdout
      rc=$?
    fi
  fi
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
  fi
  return $rc
}
function create_floating_ip {
  startlog "Creating a floating IP"
  ip=$( nova floating-ip-list 2>>$stderr | grep ext-net | awk -F\| '{print $3 }' | sed -e 's/ //g' | tail -1 )
  if [ -z $ip ]; then
    ip=$( openstack floating ip list | grep None | awk -F\| '{ print $3 }' | sed -e 's/ //g'  | tail -1 )
    if [ -z $ip ]; then
      nova floating-ip-create ext-net 2>>$stderr 1>>$stdout
      rc=$?
      if [ $rc -ne 0 ]; then
        openstack floating ip create ext-net 2>>$stderr 1>>$stdout
        rc=$?
        if [ $rc -eq 0 ]; then
          ip=$( openstack floating ip list | grep None | awk -F\| '{ print $3 }' | sed -e 's/ //g' )
        fi
      else
        ip=$( nova floating-ip-list 2>>$stderr | grep ext-net | awk -F\| '{print $3 }' | sed -e 's/ //g' )
      fi
    else
      rc=3
    fi
  else
    rc=3
  fi
  if [ $rc -eq 0 ]; then
    endlog "done"
  elif [ $rc -eq 3 ]; then
    endlog "skip"
    rc=0
  else
    endlog "error"
  fi
  return $rc
}

function attach_floating_ip {
  startlog "Attaching floating IP ${ip}"
  nova floating-ip-associate ${vmname} $ip 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -ne 0 ]; then
    openstack server add floating ip ${vmname} $ip 2>>$stderr 1>>$stdout
    rc=$?
  fi
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
  fi
  return $rc
}
function ping_floating_ip {
  startlog "Pinging $ip"
  rc=1
  cpt=0
  while [ $rc -ne 0 ] && [ $cpt -lt 15 ]; do
    ping -c1 $ip 2>>$stderr 1>>$stdout
    rc=$?
    cpt=$(( $cpt + 1 ))
    sleep 1
  done
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
  fi
  return $rc
}

function create_keypair {
  nova keypair-list 2>>$stderr | grep -q test
  rc=$?
  if [ $rc -ne 0 ]; then
    startlog "Creating keypair"
    nova keypair-add test 2>>$stderr > id_rsa
    rc=$?
    if [ $rc -eq 0 ]; then
      endlog "done"
    else
      endlog "error"
    fi
  fi
  return $rc
}

function delete_keypair {
  nova keypair-list 2>>$stderr | grep -q test
  rc=$?
  if [ $rc -eq 0 ]; then
    startlog "Deleting keypair"
    nova keypair-delete test 2>>$stderr > id_rsa
    rc=$?
    if [ $rc -eq 0 ]; then
      endlog "done"
    else
      endlog "error"
    fi
  fi
  return $rc
}

function validate_floating_ip {
  startlog "Validating $ip is attached to the VM"
  nova list | grep -q $ip
  rc=$?
  if [ $rc -ne 0 ]; then
    openstack server list | grep -q $ip
    rc=$?
  fi
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
  fi
  return $rc
}

function provision_vm {
  create_flavor
  rc=$?
  if [ $rc -eq 0 ]; then
    set_flavor
    rc=$?
    if [ $rc -eq 0 ]; then
      create_keypair
      rc=$?
      if [ $rc -eq 0 ]; then
        create_test_vm
#        create_boot_from_volume_test_vm
        rc=$?
        if [ $rc -eq 0 ]; then
          wait_for_vm
          rc=$?
          if [ $rc -eq 0 ]; then
            add_secgroup_rule
            rc=$?
            if [ $rc -eq 0 ]; then
              create_floating_ip
              rc=$?
              if [ $rc -eq 0 ]; then
                if [ ! -z "$ip" ]; then
                  attach_floating_ip
                  rc=$?
                  if [ $rc -eq 0 ]; then
                    validate_floating_ip
                    rc=$?
                    if [ $rc -eq 0 ]; then
                      ping_floating_ip
                      rc=$?
                    fi
                  fi
                fi
              fi
            fi
          fi
        fi
      fi
    fi
  fi
  return $rc
}


provision_vm
rc=$?
if [ $rc -eq 0 ]; then
#  unprovision_vm
echo
  rc=$?
fi

exit $rc
