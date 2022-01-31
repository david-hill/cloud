export DIB_LOCAL_IMAGE=./rhel-8.4-x86_64-kvm.qcow2
export REG_METHOD=portal
export REG_USER=
export REG_PASSWORD=""
export REG_RELEASE="8.4"
export REG_POOL_ID=8a85f9a17af8e616017b0d59c6476885
export REG_REPOS="rhel-8-for-x86_64-baseos-eus-rpms \
    rhel-8-for-x86_64-appstream-eus-rpms \
    rhel-8-for-x86_64-highavailability-eus-rpms \
    ansible-2.9-for-rhel-8-x86_64-rpms \
    fast-datapath-for-rhel-8-x86_64-rpms \
    openstack-16.1-for-rhel-8-x86_64-rpms"
export DIB_BLOCK_DEVICE_CONFIG='''
- local_loop:
    name: image0
- partitioning:
    base: image0
    label: mbr
    partitions:
      - name: root
        flags: [ primary ]
        size: 15G
        mkfs:
          type: xfs
          mount:
            mount_point: /
            fstab:
              options: "defaults"
              fsck-passno: 1
'''
#      - name: boot
#        flags: [ boot,primary ]
#        size: 1G
#        mkfs:
#          type: ext2
#          mount:
#            mount_point: /boot
#            fstab:
#              options: "defaults"
#              fsck-passno: 1
#export DIB_BLOCK_DEVICE_CONFIG='''
#- local_loop:
#    name: image0
#- partitioning:
#    base: image0
#    label: mbr
#    partitions:
#      - name: root
#        flags: [ primary ]
#        size: 15G
#      - name: boot
#        flags: [ boot,primary ]
#        size: 1G
#        mkfs:
#          type: ext2
#          mount:
#            mount_point: /boot
#            fstab:
#              options: "defaults"
#              fsck-passno: 1
#- lvm:
#    name: lvm
#    base: [ root ]
#    pvs:
#        - name: pv
#          base: root
#          options: [ "--force" ]
#    vgs:
#        - name: vg
#          base: [ "pv" ]
#          options: [ "--force" ]
#    lvs:
#        - name: lv_root
#          base: vg
#          extents: 23%VG
#        - name: lv_tmp
#          base: vg
#          extents: 4%VG
#        - name: lv_var
#          base: vg
#          extents: 45%VG
#        - name: lv_log
#          base: vg
#          extents: 23%VG
#        - name: lv_audit
#          base: vg
#          extents: 4%VG
#        - name: lv_home
#          base: vg
#          extents: 1%VG
#- mkfs:
#    name: fs_root
#    base: lv_root
#    type: xfs
#    label: "img-rootfs"
#    mount:
#        mount_point: /
#        fstab:
#            options: "rw,relatime"
#            fsck-passno: 1
#- mkfs:
#    name: fs_tmp
#    base: lv_tmp
#    type: xfs
#    mount:
#        mount_point: /tmp
#        fstab:
#            options: "rw,nosuid,nodev,noexec,relatime"
#            fsck-passno: 2
#- mkfs:
#    name: fs_var
#    base: lv_var
#    type: xfs
#    mount:
#        mount_point: /var
#        fstab:
#            options: "rw,relatime"
#            fsck-passno: 2
#- mkfs:
#    name: fs_log
#    base: lv_log
#    type: xfs
#    mount:
#        mount_point: /var/log
#        fstab:
#            options: "rw,relatime"
#            fsck-passno: 3
#- mkfs:
#    name: fs_audit
#    base: lv_audit
#    type: xfs
#    mount:
#        mount_point: /var/log/audit
#        fstab:
#            options: "rw,relatime"
#            fsck-passno: 4
#- mkfs:
#    name: fs_home
#    base: lv_home
#    type: xfs
#    mount:
#        mount_point: /home
#        fstab:
#            options: "rw,nodev,relatime"
#            fsck-passno: 2
#'''

cp /usr/share/openstack-tripleo-common/image-yaml/overcloud-hardened-images-python3.yaml .
sed -i 's/40/16/g' overcloud-hardened-images-python3.yaml

cp ~/images/ironic-python-agent.initramfs .
cp ~/images/ironic-python-agent.kernel .

openstack overcloud image build \
--image-name overcloud-hardened-full \
--config-file overcloud-hardened-images-python3.yaml \
--config-file /usr/share/openstack-tripleo-common/image-yaml/overcloud-hardened-images-rhel8.yaml

cp overcloud-hardened-full.qcow2 overcloud-full.qcow2
