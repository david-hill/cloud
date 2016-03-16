#!/bin/bash

source functions 

source_rc setup.cfg
source_rc /home/stack/stackrc

openstack_oc_deploy
rc=$?

exit $rc
