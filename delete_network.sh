#!/bin/bash

source setup.cfg

neutron subnet-delete test-subnet
neutron net-delete test
