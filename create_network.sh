#!/bin/bash

source setup.cfg

neutron router-create test-router
neutron net-create ext-net --router:external True --provider:physical_network datacentre --provider:network_type flat
neutron subnet-create --name ext-subnet --allocation-pool start=10.1.2.60,end=10.1.2.70 --disable-dhcp --gateway 10.1.2.1 ext-net 10.1.2.0/24
neutron router-gateway-set test-router ext-net
neutron net-create --provider:network_type  $neutronnwtype test
neutron subnet-create test 10.254.0.0/16 --name test-subnet
neutron router-interface-add test-router test-subnet
