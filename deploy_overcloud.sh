#!/bin/bash

source setup.cfg
source functions 

source_rc /home/stack/stackrc

openstack_oc_deploy
rc=$?

exit $rc
