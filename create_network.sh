#!/bin/bash

source setup.cfg

neutron net-create --provider:network_type vlan $neutronnwtype
neutron subnet-create test 10.254.0.0/16 --name test-subnet
