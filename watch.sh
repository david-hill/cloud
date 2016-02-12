#!/bin/bash

source functions

source_rc /home/stack/stackrc
if [ $? -eq 0 ]; then
  watch 'ironic node-list && nova list && heat resource-list -n10 overcloud | grep -vi complete'
fi
