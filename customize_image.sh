#!/bin/bash

cd images
for p in *; do
  if [[ "$p" =~ overcloud-full ]]; then
    mkdir tmp
    cp $p tmp/
    cd tmp/
    tar xf $p
    virt-customize -a overcloud-full.qcow2 --root-password password:rootpwd
    tar uf $p *
    cd ../
  fi
done


