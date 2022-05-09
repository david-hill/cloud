nodes="control-0-rhosp16 control-1-rhosp16 control-2-rhosp16 compute-0-rhosp16 compute-1-rhosp16"
boot_mode=bios
for p in $nodes; do
  if [[ $p =~ control ]]; then
    openstack baremetal node set --property capabilities="profile:control,boot_mode:${boot_mode},boot_option:local,raid_level:1" $p
  else
    openstack baremetal node set --property capabilities="profile:compute,boot_mode:${boot_mode},boot_option:local,raid_level:1" $p
    fi
    done

