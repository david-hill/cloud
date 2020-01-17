#!/bin/bash

set -x

bz=1780287
servicelist="neutron-server neutron-dhcp-agent neutron-l3-agent neutron-metadata-agent neutron-openvswitch-agent"
localregistry=""

TOP_DIR=$(cd $(dirname "$0") && pwd)

function build_image() {
    image_tag=$( cat /home/stack/local_registry_images.yaml  | grep $service |  awk -F: '{ print $3 }' )
    set -e

    rm -rf /tmp/hotfix
    mkdir /tmp/hotfix
    cp hotfix.yaml $PWD/ansible-role-tripleo-modify-image
    cp *.rpm /tmp/hotfix
    cd $PWD/ansible-role-tripleo-modify-image
    ansible-playbook -e "image_tag=$image_tag registry=$2 service=$1 bz=$3 localregistry=$4" hotfix.yaml
    if [ -e /home/stack/templates/overcloud_images.yaml ]; then
      sed -i "s/$service:$image_tag$/$service:${image_tag}-hotfix-bz$3/" /home/stack/templates/overcloud_images.yaml
    fi
    cd $TOP_DIR
    rm -rf /tmp/hotfix
    docker push $localregistry/rhosp13/openstack-$service:$image_tag-hotfix-bz$3
    set +e
}

function gettags {
   tags=$( curl -s ${localregistry}/v2/$p/tags/list )
   echo $tags
}

git clone https://github.com/openstack/ansible-role-tripleo-modify-image
cd ansible-role-tripleo-modify-image
git fetch https://review.opendev.org/openstack/ansible-role-tripleo-modify-image refs/changes/02/703202/2 && git cherry-pick FETCH_HEAD
cd ..
mkdir ansible-role-tripleo-modify-image/roles
ln -s $PWD/ansible-role-tripleo-modify-image $PWD/ansible-role-tripleo-modify-image/roles/tripleo-modify-image

registry=registry.access.redhat.com

if [ ! -e /home/stack/templates/overcloud_images.yaml ]; then
  echo WARNING: /home/stack/templates/overcloud_images.yaml was not found .  You will have to manually edit the file to add the generated image_tag to your overcloud_images.yaml file.
fi

if [ -e /home/stack/local_registry_images.yaml ]; then
  registry=$( cat /home/stack/local_registry_images.yaml  | grep imagename |  awk '{ print $3 }' | cut -d\/ -f1 | tail -1 )
  if [ -z "$localregistry" ]; then
    localregistry=$( cat /home/stack/local_registry_images.yaml  | grep push_destination | awk '{ print $2 }' | tail -1 )
    if [ -z "$localregistry" ]; then
      echo "Error: localregistry is undefined"
      exit 1
    fi
  fi
else
  echo Error: /home/stack/local_registry_images.yaml is missing
  exit 1
fi

for service in $servicelist; do
  build_image $service $registry $bz $localregistry
  catalog=$( curl -s $localregistry/v2/_catalog )
  for p in $(echo $catalog | sed -e 's/,/\n/g' | sed -e 's/repositories//' -e 's/"//g' -e 's/{:\[//g' -e 's/\]}//g' | grep $service); do
    gettags
  done
done
