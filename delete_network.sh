#!/bin/bash

source setup.cfg
source functions

source_rc overcloudrc
if [ $? -eq 0 ]; then
  neutron router-interface-delete test-router test-subnet
  neutron router-gateway-clear test-router

  neutron subnet-delete test-subnet
  op=$( neutron subnet-list | grep test-subnet )
  while [ ! -z "$op" ]; do
    op=$( neutron subnet-list | grep test-subnet )
    echo -n "."
  done

  neutron net-delete test
  op=$( neutron net-list | grep test )
  while [ ! -z "$op" ]; do
    op=$( neutron net-list | grep test )
    echo -n "."
  done

  neutron subnet-delete ext-subnet
  neutron net-delete ext-net

  neutron router-delete test-router
fi
exit 0
