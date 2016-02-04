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
  echo "Deleting test VM..."
  nova delete test-vm
  state=$(nova list | grep test-vm  )
  while [ "$state" != "" ]; do
    state=$(nova list | grep test-vm )
    echo -n .
  done
  rc=0
else
  echo "VM creation failed ! :("
fi

exit $rc
