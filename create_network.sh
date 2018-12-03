#!/bin/bash

source functions
source_rc setup.cfg
source_rc overcloudrc


function add_router_interface {
  startlog "Adding interface to router"
  neutron router-interface-add test-router test-subnet 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
    rc=255
  fi
  return $rc
}

function create_router {
  startlog "Creating router"
  neutron router-create test-router 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
  fi
  return $rc
}

function create_ext_network {
  startlog "Creating external network"
  neutron net-create ext-net --router:external True --provider:physical_network datacentre --provider:network_type flat 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
  fi
  return $rc
}

function create_ext_subnet {
  startlog "Creating external subnet"
  neutron subnet-create --name ext-subnet --allocation-pool start=192.168.122.201,end=192.168.122.254 --dns-nameserver 8.8.8.8 --disable-dhcp $gwarg ext-net 192.168.122.0/24 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
  fi
	return $rc
}

function set_external_gateway {
  startlog "Setting external gateway"
  neutron router-gateway-set test-router ext-net 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
    rc=255
  fi
  return $rc
}

function create_test_network {
  startlog "Creating test network"
  neutron net-create --provider:network_type $neutronnwtype test 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
    rc=255
  fi
  return $rc
}

function create_test_subnet {
  startlog "Creating test subnet"
  neutron subnet-create test 10.254.0.0/16 --name test-subnet 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
    rc=255
  fi
  return $rc
}

if [ ! -z "$gw" ]; then
  gwarg="--gateway $gw"
else
  gwarg=""
fi

rc=0

neutron router-list 2>>$stderr 2>>$stderr | grep -q test-router
if [ $? -ne 0 ]; then
  create_router
  rc=$?
fi

if [ $rc -eq 0 ]; then
  neutron net-list 2>>$stderr | grep -q ext-net
  if [ $? -ne 0 ]; then
     create_ext_network
     rc=$?
  fi
fi

if [ $rc -eq 0 ]; then
  neutron subnet-list 2>>$stderr | grep -q ext-subnet
  if [ $? -ne 0 ]; then
     create_ext_subnet
     rc=$?
  fi
fi

if [ $rc -eq 0 ]; then
  neutron router-show test-router 2>>$stderr | grep gateway | grep -q ip_address
  if [ $? -ne 0 ]; then
    set_external_gateway
    rc=$?
  fi
fi

if [ $rc -eq 0 ]; then
  neutron net-list 2>>$stderr | grep -q test
  if [ $? -ne 0 ]; then
    create_test_network
    rc=$?
  fi
fi

if [ $rc -eq 0 ]; then
  neutron subnet-list 2>>$stderr | grep -q test-subnet
  if [ $? -ne 0 ]; then
    create_test_subnet
    rc=$?
  fi
fi

if [ $rc -eq 0 ]; then
  neutron router-port-list test-router 2>>$stderr | grep -q 10.254.
  if [ $? -ne 0 ]; then
    add_router_interface
    rc=$?
  fi
fi

exit $rc
