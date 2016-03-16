#!/bin/bash

source functions

source_rc setup.cfg
source_rc overcloudrc
if [ $? -eq 0 ]; then
  startlog "Removing interface from router"
  neutron router-interface-delete test-router test-subnet > /dev/null
  endlog "done"
  startlog "Clearing router gateway"
  neutron router-gateway-clear test-router > /dev/null
  endlog "done"

  startlog "Deleting test subnet"
  neutron subnet-delete test-subnet > /dev/null
  op=$( neutron subnet-list | grep test-subnet )
  while [ ! -z "$op" ]; do
    op=$( neutron subnet-list | grep test-subnet )
    echo -n "."
  done
  endlog "done"

  startlog "Deleting test network"
  neutron net-delete test > /dev/null
  op=$( neutron net-list | grep test )
  while [ ! -z "$op" ]; do
    op=$( neutron net-list | grep test )
    echo -n "."
  done
  endlog "done"

  startlog "Deleting external subnet"
  neutron subnet-delete ext-subnet > /dev/null
  endlog "done"

  startlog "Deleting external network"
  neutron net-delete ext-net > /dev/null
  endlog "done"

  startlog "Deleting router"
  neutron router-delete test-router > /dev/null
  endlog "done"
fi
exit 0
