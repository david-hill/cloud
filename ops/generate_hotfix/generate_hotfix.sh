#!/bin/bash

set -x

TOP_DIR=$(cd $(dirname "$0") && pwd)

bz=123456

function build_image() {
    image_tag=$( cat /home/stack/local_registry_images.yaml  | grep $service |  awk -F: '{ print $3 }' )
    set -e

    rm -rf /tmp/hotfix
    mkdir /tmp/hotfix
    cp hotfix.yaml $PWD/ansible-role-tripleo-modify-image
    cp *.rpm /tmp/hotfix
    cd $PWD/ansible-role-tripleo-modify-image
    ansible-playbook -e "image_tag=$image_tag registry=$2 service=$1 bz=$3" hotfix.yaml
    cd $TOP_DIR
    rm -rf /tmp/hotfix
    set +e
}


git clone https://github.com/openstack/ansible-role-tripleo-modify-image
mkdir ansible-role-tripleo-modify-image/roles
ln -s $PWD/ansible-role-tripleo-modify-image $PWD/ansible-role-tripleo-modify-image/roles/tripleo-modify-image

service=nova-compute
registry=$( cat /home/stack/local_registry_images.yaml  | grep $service |  awk '{ print $3 }' | cut -d\/ -f1 )

build_image $service $registry $bz

