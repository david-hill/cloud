#!/bin/bash

source functions
source overcloudrc

rc=255

startlog "Getting image list"
image=$( glance image-list | grep cirros | head -1 | awk '{ print $2 }')
endlog "done"

startlog "Getting network list"
neutron=$( neutron net-list | grep test | awk '{ print $2 }')
endlog "done"

startlog "Creating m1.micro flavor"
nova flavor-create m1.micro auto 256 1 1 > /dev/null
if [ $? -eq 0 ]; then
  endlog "done"
  startlog "Creating test VM"
  nova boot --flavor m1.micro --image $image  --nic net-id=$neutron test-vm > /dev/null
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
      nova secgroup-add-rule default icmp -1 -1 0/0 > /dev/null
      if [ $? -eq 0 ]; then
        endlog "done"
        startlog "Creating a floating IP"
        nova floating-ip-create ext-net > /dev/null
        if [ $? -eq 0 ]; then
          ip=$( nova floating-ip-list | grep ext-net | awk -F\| '{print $3 }')
          endlog "done"
          if [ ! -z "$ip" ]; then
            startlog "Attaching a floating IP"
            nova floating-ip-associate test-vm $ip > /dev/null
            if [ $? -eq 0 ]; then
              sleep 5
              endlog "done"
              startlog "Pinging $ip"
              ping -c1 $ip > /dev/null
              if [ $? -eq 0 ]; then
                endlog "done"
                startlog "Deleting rule from default security group"
                nova secgroup-delete-rule default icmp -1 -1 0.0.0.0/0 > /dev/null
                if [ $? -eq 0 ]; then
                  endlog "done"
                  startlog "Deleting test VM"
                  nova delete test-vm > /dev/null
                  state=$(nova list | grep test-vm  )
                  while [ "$state" != "" ]; do
                    state=$(nova list | grep test-vm )
                    echo -n .
                  done
                  endlog "done"
                  startlog "Deleting floating IP"
                  nova floating-ip-delete $ip > /dev/null
                  if [ $? -eq 0 ]; then
                    endlog "done"
                    startlog "Deleting flavor"
                    nova flavor-delete m1.micro > /dev/null
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
