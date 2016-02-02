#!/bin/bahs

source setup.cfg

function gen_macs {
    mac1=$(echo -n 52:54:00; dd bs=1 count=3 if=/dev/random 2>/dev/null |hexdump -v -e '/1 ":%02X"')
    mac2=$(echo -n 52:54:00; dd bs=1 count=3 if=/dev/random 2>/dev/null |hexdump -v -e '/1 ":%02X"')
}

function gen_xml {
    cp template.xml $tmpfile
    sed -i "s/###MAC1###/$mac1/" $tmpfile
    sed -i "s/###MAC2###/$mac2/" $tmpfile
    sed -i "s/###UUID###/$uuid/" $tmpfile
    sed -i "s/###TYPE-INC###/$type-$inc/" $tmpfile
    sed -i "s/###DISK###/$type-$inc/" $tmpfile
}
function gen_disks {
    qemu-img create -f qcow2 /var/lib/libvirt/images/$type-$inc.qcow2 10G
}
function create_domain {
    virsh create $tmpfile
}
function create_vm {
  type=$1
  inc=0
  if [[ $type =~ control ]]; then
    max=$controlscale
  else
    max=$computescale
  fi
  while [ $inc -lt $max ]; do
    tmpfile=$(mktemp)
    uuid=$(uuidgen)
    gen_macs
    gen_xml
    gen_disks
    create_domain
    cleanup
    inc=$(expr $inc + 1)
  done
}

function cleanup {
    rm -rf $tmpfile
}
create_vm control
create_vm compute
