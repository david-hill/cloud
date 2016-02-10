#!/bin/bash

rc=255

image=$( glance image-list | grep cirros | head -1 | awk '{ print $2 }')
neutron=$( neutron net-list | grep test | awk '{ print $2 }')

echo "Creating m1.micro VM..."
nova flavor-create m1.micro auto 256 1 1
echo "Creating test VM..."
nova boot --flavor m1.micro --image $image  --nic net-id=$neutron test-vm

state=$(nova list | grep test-vm | awk '{ print $6 }')
while [[ ! "$state" =~ ACTIVE ]] && [[ ! "$state" =~ ERROR ]]; do
  state=$(nova list | grep test-vm | awk '{ print $6 }')
  echo -n .
done

if [[ "$state" =~ ACTIVE ]]; then
  echo "VM creation was successful ! :)"
  nova secgroup-add-rule default icmp -1 -1 0/0
  if [ $? -eq 0 ]; then
    nova floating-ip-create ext-net
    if [ $? -eq 0 ]; then
      ip=$( nova floating-ip-list | grep ext-net | awk -F\| '{print $3 }')
      if [ ! -z "$ip" ]; then
        nova floating-ip-associate test-vm $ip
        if [ $? -eq 0 ]; then
          sleep 5
          ping -c1 $ip
          if [ $? -eq 0 ]; then
            nova secgroup-delete-rule default icmp -1 -1 0.0.0.0/0
            if [ $? -eq 0 ]; then
              echo "Deleting test VM..."
              nova delete test-vm
              state=$(nova list | grep test-vm  )
              while [ "$state" != "" ]; do
                state=$(nova list | grep test-vm )
                echo -n .
              done
              rc=0
            else
              echo "Failed to delete secgroup rule..."
            fi
          else
            echo "Failed to ping the floating ip..."
          fi
        else
          echo "Failed to associate the floating ip..."
        fi
      else
        echo "Failed to create a floating ip..."
      fi
    else
      echo "Failure to create a floating ip ..."
    fi
  else
    echo "Failure to add secgroup rule..."
  fi
else
  echo "VM creation failed ! :("
fi

exit $rc
