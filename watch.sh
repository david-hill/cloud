#!/bin/bash

source /home/stack/stackrc

watch 'ironic node-list && nova list && heat resource-list -n10 overcloud | grep -vi complete'
