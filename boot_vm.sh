#!/bin/bash

source functions
source overcloudrc
source_rc setup.cfg

rc=255

startlog "Getting image list"
image=$( glance image-list | grep cirros | head -1 | awk '{ print $2 }')
endlog "done"

startlog "Getting network list"
neutron=$( neutron net-list 2>>$stderr | grep test | awk '{ print $2 }')
endlog "done"

startlog "Creating m1.micro flavor"
nova flavor-create m1.micro auto 256 1 1 2>>$stderr 1>>$stdout
if [ $? -eq 0 ]; then
  endlog "done"
  startlog "Creating test VM"
  nova boot --flavor m1.micro --image $image  --nic net-id=$neutron test-vm 2>>$stderr 1>>$stdout
  if [ $? -eq 0 ]; then
    endlog "done"
    startlog "Waiting for VM to come up"
    state=$(nova list | grep test-vm | awk '{ print $6 }')
    while [[ ! "$state" =~ ACTIVE ]] && [[ ! "$state" =~ ERROR ]]; do
      state=$(nova list | grep test-vm | awk '{ print $6 }')
    done
    if [[ "$state" =~ ACTIVE ]]; then
      endlog "done"
      startlog "Adding rule to default security group"
      nova secgroup-add-rule default icmp -1 -1 0/0 2>>$stderr 1>>$stdout
      if [ $? -ne 0 ]; then
        groupid=$(nova list-secgroup test-vm | awk -F\| '{ print $2 }' | sed -e 's/Id //')
        openstack security group rule create --protocol icmp ${groupid} 2>>$stderr 1>>$stdout
        rc=$?
      fi
      if [ $rc -eq 0 ]; then
        endlog "done"
        startlog "Creating a floating IP"
        nova floating-ip-create ext-net 2>>$stderr 1>>$stdout
        rc=$?
        if [ $rc -ne 0 ]; then
          openstack floating ip create ext-net 2>>$stderr 1>>$stdout
          rc=$?
          if [ $? -eq 0 ]; then
            ip=$( openstack floating ip list | grep None | awk -F\| '{ print $2 }' )
          fi
        else
          ip=$( nova floating-ip-list | grep ext-net | awk -F\| '{print $3 }')
        fi 
        if [ $rc -eq 0 ]; then
          endlog "done"
          if [ ! -z "$ip" ]; then
            startlog "Attaching a floating IP"
            nova floating-ip-associate test-vm $ip 2>>$stderr 1>>$stdout
            rc=$?
            if [ $rc -ne 0 ]; then
              openstack server add floating ip test-vm $ip 2>>$stderr 1>>$stdout
              rc=$?
            fi
            if [ $rc -eq 0 ]; then
              sleep 5
              endlog "done"
              startlog "Pinging $ip"
              ping -c1 $ip 2>>$stderr 1>>$stdout
              if [ $? -eq 0 ]; then
                endlog "done"
                startlog "Deleting rule from default security group"
                nova secgroup-delete-rule default icmp -1 -1 0.0.0.0/0 2>>$stderr 1>>$stdout
                if [ $? -ne 0 ]; then
                  ruleid=$( neutron security-group-rule-list | grep icmp | awk -F \| '{ print $2 }' )
                  neutron security-group-rule-delete ${ruleid} 2>>$stderr 1>>$stdout
                  rc=$?
		fi
                if [ $rc -eq 0 ]; then
                  endlog "done"
                  startlog "Deleting test VM"
                  nova delete test-vm 2>>$stderr 1>>$stdout
                  state=$(nova list | grep test-vm  )
                  while [ "$state" != "" ]; do
                    state=$(nova list | grep test-vm )
                  done
                  endlog "done"
                  startlog "Deleting floating IP"
                  nova floating-ip-delete $ip 2>>$stderr 1>>$stdout
                  rc=$?
                  if [ $rc -ne 0 ]; then
                    openstack floating ip delete $ip 2>>$stderr 1>>$stdout
                  fi
                  if [ $rc -eq 0 ]; then
                    endlog "done"
                    startlog "Deleting flavor"
                    nova flavor-delete m1.micro 2>>$stderr 1>>$stdout
                    if [ $? -eq 0 ]; then
                      endlog "done"
                      rc=0
                    else
                      endlog "error"
                    fi
                  fi
                else
                  endlog "error"
                fi
              else
                endlog "error"
              fi
            else
              endlog "error"
            fi
          else
            endlog "error"
          fi
        else
          endlog "error"
        fi
      else
        endlog "error"
      fi
    else
      endlog "error"
    fi
  else
    endlog "error"
  fi
else
  endlog "error"
fi

exit $rc
