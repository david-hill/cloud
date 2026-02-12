param="-uroot -proot -h moriarty.orion -P 3362"
tablelist="block_device_mapping instance_extra instance_info_caches instance_metadata instance_system_metadata virtual_interfaces instance_faults migrations"
output="2>&1 | grep -v Using\ a"
output=""
sleep=0.1
for p in {477..0..-1}; do
  echo $p;
  current_timestamp=$(mysql $param -ss -e 'select current_timestamp();' $output )
  deletestring="deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY)"
  selectinstances="select uuid from instances where $deletestring"

  nbr=$(mysql $param -ss -Dnova -e "select count(*) from instances where $deletestring;" $output)
  if [ $nbr -gt 0 ]; then
    echo instance_actions
    nbr=$(mysql $param -ss -Dnova -e "select count(*) from instance_actions where instance_uuid in ($selectinstances);" $output)
    if [ $nbr -gt 0 ]; then
      echo instance_actions_events
      nbr=$(mysql $param -ss -Dnova -e "select count(*) from instance_actions_events where action_id in (select id from instance_actions where instance_uuid in ( $selectinstances ));" $output)
      if [ $nbr -gt 0 ]; then
         mysql $param -ss -Dnova -e "delete from instance_actions_events where action_id in (select id from instance_actions where instance_uuid in ( $selectinstances ));" $output
      fi
      mysql $param -ss -Dnova -e "delete from instance_actions where instance_uuid in ($selectinstances);" $output
    fi

    for table in $tablelist; do
      echo $table
      nbr=$(mysql $param -ss -Dnova -e "select count(*) from $table where instance_uuid in ($selectinstances);" $output)
      if [ $nbr -gt 0 ]; then
        mysql $param -ss -Dnova -e "delete from $table where instance_uuid in ($selectinstances);" $output
      fi
    done

    echo "instances"
    mysql $param -Dnova -e "delete from instances where $deletestring;" $output
  fi
  sleep $sleep;
done
