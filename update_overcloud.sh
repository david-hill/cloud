#!/bin/bash

source setup.cfg
source functions 

openstack_oc_deploy
rc=$?

exit $rc
