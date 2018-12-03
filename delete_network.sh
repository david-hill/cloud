#!/bin/bash
source functions
source_rc setup.cfg
source_rc overcloudrc
if [ $? -eq 0 ]; then
  startlog "Removing interface from router"
  neutron router-interface-delete test-router test-subnet 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -eq 0 ]; then
    endlog "done"
    startlog "Clearing router gateway"
    neutron router-gateway-clear test-router 2>>$stderr 1>>$stdout
    rc=$?
    if [ $rc -eq 0 ]; then
      endlog "done"
      startlog "Deleting test subnet"
      neutron subnet-delete test-subnet 2>>$stderr 1>>$stdout
      rc=$?
      if [ $rc -eq 0 ]; then
        op=$( neutron subnet-list 2>>$stderr | grep test-subnet )
        while [ ! -z "$op" ]; do
          op=$( neutron subnet-list 2>>$stderr | grep test-subnet )
        done
        endlog "done"
        startlog "Deleting test network"
        neutron net-delete test 2>>$stderr 1>>$stdout
        rc=$?
        if [ $rc -eq 0 ]; then
          op=$( neutron net-list 2>>$stderr | grep test )
          while [ ! -z "$op" ]; do
            op=$( neutron net-list 2>>$stderr | grep test )
          done
          endlog "done"
          startlog "Deleting floating ips"
          uuid=$( neutron floatingip-list 2>>$stderr | grep 192.168.122 | awk '{ print $2 }'  )
          if [ ! -z $uuid ]; then
            neutron floatingip-delete $uuid 2>>$stderr 1>>$stdout
            rc=$?
          fi
          endlog "done"
          startlog "Deleting external subnet"
          neutron subnet-delete ext-subnet 2>>$stderr 1>>$stdout
          rc=$?
          if [ $rc -eq 0 ]; then
            endlog "done"
            startlog "Deleting external network"
            neutron net-delete ext-net 2>>$stderr 1>>$stdout
            rc=$?
            if [ $rc -eq 0 ]; then
              endlog "done"
              startlog "Deleting router"
              neutron router-delete test-router 2>>$stderr 1>>$stdout
              rc=$?
              if [ $rc -eq 0 ]; then
                endlog "done"
              else
                endlog "error"
                rc=255
              fi
            else
              endlog "error"
              rc=255
            fi
          else
            endlog "error"
            rc=255
          fi
        else
          endlog "error"
          rc=255
        fi
      else
        endlog "error"
        rc=255
      fi
    else
      endlog "error"
      rc=255
    fi
  else
    endlog "error"
    rc=255
  fi
fi
exit $rc
