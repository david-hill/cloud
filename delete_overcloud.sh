#!/bin/bash

source functions

source_rc setup.cfg

function delete_nova_nodes {
  startlog "Deleting nova nodes"
  for node in $(nova list | awk '{ print $2 }' | grep -v ID); do
    nova delete $node
  done
  if [ ! -z "$node" ]; then
    tnode=$(nova list | grep $node)
    while [[ "$tnode" =~ $node ]]; do
      tnode=$(nova list | grep $node)
    done
  fi
  endlog "done"
}

function poweroff_ironic_nodes {
  startlog "Powering off ironic nodes"
  for node in $(ironic node-list | grep "power on" | awk '{ print $2 }'); do
    ironic node-set-power-state $node off
    tnode=$(ironic node-list | grep $node | grep "power on")
    while [[ "$tnode" =~ $node ]]; do
      tnode=$(ironic node-list | grep $node | grep "power on")
    done
  done
  endlog "done"
}

function delete_ironic_nodes {
  startlog "Deleting ironic nodes.."
  for node in $(ironic node-list | egrep "True|False" | awk '{ print $2 }'); do
    ironic node-delete $node > /dev/null
    tnode=$(ironic node-list | grep $node)
    while [[ "$tnode" =~ $node ]]; do
      tnode=$(ironic node-list | grep $node)
    done
  done
  endlog "done"
}
function delete_nodes {
  delete_nova_nodes
  poweroff_ironic_nodes
  delete_ironic_nodes
}

delete_overcloud
delete_nodes
