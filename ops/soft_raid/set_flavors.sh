boot_mode=bios
for profile in compute controller; do
   openstack flavor set --property "cpu_arch"="x86_64" --property "capabilities:boot_option"="local" --property "capabilities:profile"="$profile" --property "capabilities:raid_level"="1" --property "capabilities:boot_mode"="$boot_mode" $profile
done

