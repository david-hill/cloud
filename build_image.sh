#!/bin/bash

rc=0

source functions
source_rc stackrc

cp /usr/share/openstack-tripleo-common/image-yaml/overcloud-hardened-images.yaml /home/stack/overcloud-hardened-images-custom.yaml
rc=$?
if [ $rc -eq 0 ]; then
  export DIB_LOCAL_IMAGE=/home/stack/images/rhel-guest-image-local.qcow2
  export REG_METHOD=portal
  export REG_USER=${rhnusername}
  export REG_PASSWORD=${rhnpassword}
  export REG_REPOS="rhel-7-server-rpms \
    rhel-7-server-extras-rpms \
    rhel-ha-for-rhel-7-server-rpms \
    rhel-7-server-optional-rpms \
    rhel-7-server-openstack-13-rpms"
  export DIB_BLOCK_DEVICE_CONFIG='
- local_loop:
    name: image0
- partitioning:
    base: image0
    label: mbr
    partitions:
      - name: root
        flags: [ boot,primary ]
        size: 23G
- lvm:
    name: lvm
    base: [ root ]
    pvs:
        - name: pv
          base: root
          options: [ "--force" ]
    vgs:
        - name: vg
          base: [ "pv" ]
          options: [ "--force" ]
    lvs:
        - name: lv_root
          base: vg
          extents: 80%VG
        - name: lv_home
          base: vg
          extents: 20%VG
- mkfs:
    name: fs_root
    base: lv_root
    type: xfs
    label: "img-rootfs"
    mount:
        mount_point: /
        fstab:
            options: "rw,relatime"
            fsck-passno: 1
- mkfs:
    name: fs_home
    base: lv_home
    type: xfs
    mount:
        mount_point: /home
        fstab:
            options: "rw,nodev,relatime"
            fsck-passno: 2
'
  if [ $rc -eq 0 ]; then
    openstack overcloud image build --image-name overcloud-hardened-full --config-file /home/stack/overcloud-hardened-images-custom.yaml --config-file /usr/share/openstack-tripleo-common/image-yaml/overcloud-hardened-images-rhel7.yaml
    rc=$?
    if [ $rc -eq 0 ]; then
      mv overcloud-hardened-full.qcow2 ~/images/overcloud-full.qcow2
      rc=$?
      if [ $rc -eq 0 ]; then
        openstack image delete overcloud-full
        rc=$?
        if [ $rc -eq 0 ]; then
          openstack image delete overcloud-full-initrd
          rc=$?
          if [ $rc -eq 0 ]; then
            openstack image delete overcloud-full-vmlinuz
            rc=$?
            if [ $rc -eq 0 ]; then
              openstack overcloud image upload --image-path /home/stack/images --whole-disk
              rc=$?
            fi
          fi
        fi
      fi
    fi
  fi
fi
exit $rc
