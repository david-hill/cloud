#!/bin/bash
source functions
source_rc setup.cfg
source_rc overcloudrc

neutron router-port-list test-router 2>>$stderr | grep -q 10.254.
if [ $? -eq 0 ]; then
  startlog "Removing interface from router"
  neutron router-interface-delete test-router test-subnet 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
  fi
fi

if [ $rc -eq 0 ]; then
  neutron router-show test-router 2>>$stderr | grep gateway | grep -q ip_address
  if [ $? -eq 0 ]; then
    startlog "Clearing router gateway"
    neutron router-gateway-clear test-router 2>>$stderr 1>>$stdout
    rc=$?
    if [ $rc -eq 0 ]; then
      endlog "done"
    else
      endlog "error"
    fi
  fi
fi



if [ $rc -eq 0 ]; then
  neutron subnet-list 2>>$stderr | grep -q test-subnet
  if [ $? -eq 0 ]; then
    startlog "Deleting test subnet"
    neutron subnet-delete test-subnet 2>>$stderr 1>>$stdout
    rc=$?
    if [ $rc -eq 0 ]; then
      endlog "done"
    else
      endlog "error"
    fi
  fi
fi


if [ $rc -eq 0 ]; then
  neutron net-list 2>>$stderr | grep -q test
  if [ $? -eq 0 ]; then
    startlog "Deleting test network"
    neutron net-delete test 2>>$stderr 1>>$stdout
    rc=$?
    if [ $rc -eq 0 ]; then
      endlog "done"
    else
      endlog "error"
    fi
  fi
fi

if [ $rc -eq 0 ]; then
  neutron floatingip-list 2>>$stderr | grep -q 192.168.122
  if [ $? -eq 0 ]; then
    startlog "Deleting floating ips"
    uuid=$( neutron floatingip-list 2>>$stderr | grep 192.168.122 | awk '{ print $2 }'  )
    neutron floatingip-delete $uuid 2>>$stderr 1>>$stdout
    rc=$?
    if [ $rc -eq 0 ]; then
      endlog "done"
    else
      endlog "error"
    fi
  fi
fi

if [ $rc -eq 0 ]; then
  neutron subnet-list 2>>$stderr | grep -q ext-subnet
  if [ $? -eq 0 ]; then
    startlog "Deleting external subnet"
    neutron subnet-delete ext-subnet 2>>$stderr 1>>$stdout
    rc=$?
    if [ $rc -eq 0 ]; then
      endlog "done"
    else
      endlog "error"
    fi
  fi
fi

if [ $rc -eq 0 ]; then
  neutron net-list 2>>$stderr | grep -q ext-net
  if [ $? -eq 0 ]; then
    startlog "Deleting external network"
    neutron net-delete ext-net 2>>$stderr 1>>$stdout
    rc=$?
    if [ $rc -eq 0 ]; then
      endlog "done"
    else
      endlog "error"
    fi
  fi
fi

if [ $rc -eq 0 ]; then
  neutron router-list 2>>$stderr | grep -q test-router
  if [ $? -eq 0 ]; then
    startlog "Deleting router"
    neutron router-delete test-router 2>>$stderr 1>>$stdout
    rc=$?
    if [ $rc -eq 0 ]; then
      endlog "done"
    else
      endlog "error"
    fi
  fi
fi

exit $rc
