#!/bin/bash

source setup.cfg
rc=255

if [ ! -z "$gw" ]; then
  gwarg="--gateway $gw"
else
  gwarg=""
fi

neutron router-list | grep -q test-router
if [ $? -ne 0 ]; then
  neutron router-create test-router
  neutron net-create ext-net --router:external True --provider:physical_network datacentre --provider:network_type flat
  neutron subnet-create --name ext-subnet --allocation-pool start=192.168.122.201,end=192.168.122.254 --dns-nameserver 8.8.8.8 --disable-dhcp $gwarg ext-net 192.168.122.0/24
  neutron router-gateway-set test-router ext-net
  neutron net-create --provider:network_type  $neutronnwtype test
  neutron subnet-create test 10.254.0.0/16 --name test-subnet
  neutron router-interface-add test-router test-subnet
  rc=0
else
  echo "Error creating test-router..."
fi

exit $rc
