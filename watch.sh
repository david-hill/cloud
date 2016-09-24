#!/bin/bash

source functions

source_rc /home/stack/stackrc
source_rc setup.cfg

if [ $? -eq 0 ]; then
  watch "ironic node-list && nova list && heat resource-list -n10 $overcloudname | grep -vi complete"
fi
