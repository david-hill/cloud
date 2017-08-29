#!/bin/bash

source functions
source_rc setup.cfg
source_rc overcloudrc

if [ $? -eq 0 ]; then
  if [ ! -z "$gw" ]; then
    gwarg="--gateway $gw"
  else
    gwarg=""
  fi
  startlog "Listing networks"
  neutron router-list | grep -q test-router
  if [ $? -ne 0 ]; then
    endlog "done"
    startlog "Creating router"
    neutron router-create test-router 2>>$stderr 1>>$stdout
    rc=$?
    if [ $rc -eq 0 ]; then
      endlog "done"
      startlog "Creating external network"
      neutron net-create ext-net --router:external True --provider:physical_network datacentre --provider:network_type flat 2>>$stderr 1>>$stdout
      rc=$?
      if [ $rc -eq 0 ]; then
        endlog "done"
        startlog "Creating external subnet"
        neutron subnet-create --name ext-subnet --allocation-pool start=192.168.122.201,end=192.168.122.254 --dns-nameserver 8.8.8.8 --disable-dhcp $gwarg ext-net 192.168.122.0/24 2>>$stderr 1>>$stdout
        rc=$?
        if [ $rc -eq 0 ]; then
          endlog "done"
          startlog "Setting external gateway"
          neutron router-gateway-set test-router ext-net 2>>$stderr 1>>$stdout
          rc=$?
          if [ $rc -eq 0 ]; then
            endlog "done"
            startlog "Creating test network"
            neutron net-create --provider:network_type $neutronnwtype test 2>>$stderr 1>>$stdout
            rc=$?
            if [ $rc -eq 0 ]; then
              endlog "done"
              startlog "Creating test subnet"
              neutron subnet-create test 10.254.0.0/16 --name test-subnet 2>>$stderr 1>>$stdout
              rc=$?
              if [ $rc -eq 0 ]; then
                endlog "done"
                startlog "Adding interface to router"
                neutron router-interface-add test-router test-subnet 2>>$stderr 1>>$stdout
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
  else
    endlog "error"
    rc=255
  fi
fi
exit $rc
