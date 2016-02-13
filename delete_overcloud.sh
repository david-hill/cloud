#!/bin/bash

source functions
source setup.cfg

function delete_nova_nodes {
  echo "Deleting nova nodes.."
  for node in $(nova list | awk '{ print $2 }' | grep -v ID); do
    nova delete $node
  done
  if [ ! -z "$node" ]; then
    tnode=$(nova list | grep $node)
    while [[ "$tnode" =~ $node ]]; do
      tnode=$(nova list | grep $node)
      echo -n "."
    done
  fi
}

function poweroff_ironic_nodes {
  echo "Powering off ironic nodes.."
  for node in $(ironic node-list | grep "power on" | awk '{ print $2 }'); do
    ironic node-set-power-state $node off
    tnode=$(ironic node-list | grep $node | grep "power on")
    while [[ "$tnode" =~ $node ]]; do
      tnode=$(ironic node-list | grep $node | grep "power on")
      echo -n "."
    done
  done
}

function delete_ironic_nodes {
  echo "Deleting ironic nodes.."
  for node in $(ironic node-list | egrep "True|False" | awk '{ print $2 }'); do
    ironic node-delete $node
    tnode=$(ironic node-list | grep $node)
    while [[ "$tnode" =~ $node ]]; do
      tnode=$(ironic node-list | grep $node)
      echo -n "."
    done
  done
}
function delete_nodes {
  echo "Deleting nodes..."
  delete_nova_nodes
  poweroff_ironic_nodes
  delete_ironic_nodes
}

delete_overcloud
delete_nodes
