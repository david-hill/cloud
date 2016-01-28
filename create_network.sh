#!/bin/bash

neutron net-create --provider:network_type vlan test
neutron subnet-create --name test 10.254.0.0/16
