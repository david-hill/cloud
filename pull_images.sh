#!/bin/bash

source functions

source_rc setup.cfg

rc=255

function create_local_docker_registry {
  rc=0
  if [ $use_docker -eq 1 ]; then
    vernum=$( echo $releasever | sed -e 's/rhosp//' )
    if [ -e /home/stack/internal ]; then
      url=docker-registry.engineering.redhat.com
      grep -q $url /etc/sysconfig/docker
      rc=$?
      if [ $rc -ne 0 ]; then
        sudo sed -i -e "s/\"$/ --insecure-registry $url\"/" /etc/sysconfig/docker
        rc=$?
        if [ $rc -eq 0 ]; then
          sudo systemctl restart docker
          rc=$?
        fi
      fi
    else
      url=registry.access.redhat.com
    fi
    if [[ $vernum -lt 13 ]]; then
      if [ $rc -eq 0 ]; then
        rc=255
        startlog "Discover latest container image tag"
        tag=$(sudo openstack overcloud container image tag discover --image ${url}/${releasever}/openstack-base:latest --tag-from-label version-release)
        if [ -z "$tag" ]; then
          tag=$(sudo openstack overcloud container image tag discover --image ${url}/${releasever}/openstack-base:latest --tag-from-label {version}-{release})
          if [ -z "$tag" ]; then
            tag=latest
          fi
        fi
        endlog "done"
        startlog "Preparing local image registry"
        openstack overcloud container image prepare ${extradockerimages} --namespace=${url}/${releasever} --prefix=openstack- --tag=$tag --output-images-file /home/stack/${releasever}/local_registry_images.yaml 2>>$stderr 1>>$stdout
        rc=$?
        if [ $rc -eq 0 ]; then
          endlog "done"
          startlog "Uploading local image registry"
          sudo openstack overcloud container image upload --config-file  /home/stack/${releasever}/local_registry_images.yaml --verbose 2>>$stderr 1>>$stdout
          rc=$?
          if [ $rc -eq 0 ]; then
            endlog "done"
            startlog "Preparing local container image registry"
            openstack overcloud container image prepare --namespace=192.0.2.1:8787/${releasever} --prefix=openstack- --tag=$tag --output-env-file=/home/stack/${releasever}/overcloud_images.yaml 2>>$stderr 1>>$stdout
            rc=$?
            if [ $rc -eq 0 ]; then
              endlog "done"
            else
              endlog "error"
            fi
          else
            endlog "error"
          fi
        else
          endlog "error"
        fi
      else
        endlog "error"
      fi
    elif [[ $vernum -ge 13 ]]; then
      startlog "Preparing container image configuration files"
      openstack overcloud container image prepare ${extradockerimages} --namespace=registry.access.redhat.com/${releasever} --push-destination=192.0.2.1:8787 --prefix=openstack- --tag-from-label {version}-{release} --output-env-file=/home/stack/${releasever}/overcloud_images.yaml --output-images-file /home/stack/local_registry_images.yaml 2>>$stderr 1>>$stdout
      rc=$?
      if [ $rc -eq 0 ]; then
        endlog "done"
        startlog "Uploading images"
        sudo openstack overcloud container image upload --config-file  /home/stack/local_registry_images.yaml --verbose 2>>$stderr 1>>$stdout
        rc=$?
        if [ $rc -eq 0 ]; then
          endlog "done"
        else
          endlog "error"
        fi
      else
        endlog "error"
      fi
    fi
  fi
  return $rc
}

create_local_docker_registry
rc=$?

exit $rc
