#!/bin/bash

image=$( glance image-list | grep cirros | head -1 | awk '{ print $2 }')
neutron=$( neutron net-list | grep test | awk '{ print $2 }')

echo "Creating test VM..."
nova boot --flavor m1.tiny --image $image  --nic net-id=$neutron test

state=$(nova list | grep test-vm | awk '{ print $6 }')
while [[ ! "$state" =~ ACTIVE ]] && [[ ! "$state" =~ FAILED ]]; do
  state=$(nova list | grep test-vm | awk '{ print $6 }')
  echo -n .
done

echo "Deleting test VM..."
nova delete test-vm
state=$(nova list | grep test-vm  )
while [ "$state" != "" ]; do
  state=$(nova list | grep test-vm )
  echo -n .
done
