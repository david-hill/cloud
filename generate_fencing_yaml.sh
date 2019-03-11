source functions
source_rc setup.cfg

cat<<EOF>>../${releasever}/fencing.yaml
parameter_defaults:
  EnableFencing: true
  FencingConfig:
    devices:
EOF

for p in $( cat ../instackenv.json  | sed -e 's/,/\n/g' -e 's/ //g' -e 's/"//g' -e 's/\[//g' -e 's/\]//g' | egrep "pm|mac" ); do 
  if [[ $p =~ mac: ]]; then
    mac=$( echo $p | sed -e 's/mac://'g)
    mac=$( echo $mac | tr '[A-Z]' '[a-z]' )
    if [[ $pm_type =~ pxe_ipmitool ]]; then
      pm_type=fence_ipmilan
    fi 
cat<<EOF>>../${releasever}/fencing.yaml
    - agent: $pm_type
      host_mac: $mac
      params:
        login: $pm_user
        ipaddr: $pm_addr
        ipport: 623
        passwd: $pm_password
        lanplus: 1
EOF
  else
    var=`echo $p | cut -d: -f1` 
    val=`echo $p | cut -d: -f 2`
    declare "$var=$val" 
  fi
done

