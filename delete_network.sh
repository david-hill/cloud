#!/bin/bash
source functions
source_rc setup.cfg
source_rc overcloudrc
if [ $? -eq 0 ]; then
  startlog "Removing interface from router"
  neutron router-interface-delete test-router test-subnet > /dev/null
  rc=$?
  if [ $rc -eq 0 ]; then
    endlog "done"
    startlog "Clearing router gateway"
    neutron router-gateway-clear test-router > /dev/null
    rc=$?
    if [ $rc -eq 0 ]; then
      endlog "done"
      startlog "Deleting test subnet"
      neutron subnet-delete test-subnet > /dev/null
      rc=$?
      if [ $rc -eq 0 ]; then
        op=$( neutron subnet-list | grep test-subnet )
        while [ ! -z "$op" ]; do
          op=$( neutron subnet-list | grep test-subnet )
        done
        endlog "done"
        startlog "Deleting test network"
        neutron net-delete test > /dev/null
        rc=$?
        if [ $rc -eq 0 ]; then
          op=$( neutron net-list | grep test )
          while [ ! -z "$op" ]; do
            op=$( neutron net-list | grep test )
          done
          endlog "done"
          startlog "Deleting external subnet"
          neutron subnet-delete ext-subnet > /dev/null
          rc=$?
          if [ $rc -eq 0 ]; then
            endlog "done"
            startlog "Deleting external network"
            neutron net-delete ext-net > /dev/null
            rc=$?
            if [ $rc -eq 0 ]; then
              endlog "done"
              startlog "Deleting router"
              neutron router-delete test-router > /dev/null
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
exit 0
