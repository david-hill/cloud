#!/bin/bash

source functions 

source_rc setup.cfg

openstack_oc_update
rc=$?

exit $rc
