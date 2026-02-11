#mysql -uroot -proot -h moriarty.orion -P 3359

param="-uroot -proot -hmoriarty.orion -P3359"
tablelist="block_device_mapping instance_extra instance_info_caches instance_metadata instance_system_metadata virtual_interfaces instance_faults migrations"
output="2>&1 | grep -v Using\ a"
output=""
sleep=0.1
for p in {477..0..-1}; do 
  echo $p;
  current_timestamp=$(mysql $param -ss -e 'select current_timestamp();' $output )
  
  nbr=$(mysql $param -ss -Dnova -e "select count(*) from instances where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY);" $output)
  if [ $nbr -gt 0 ]; then
    echo instance_actions
    nbr=$(mysql $param -ss -Dnova -e "select count(*) from instance_actions where instance_uuid in (select instance_uuid from instances where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY));" $output)
    if [ $nbr -gt 0 ]; then
      echo instance_actions_events
      nbr=$(mysql $param -ss -Dnova -e "select count(*) from instance_actions_events where action_id in (select id from instance_actions where instance_uuid in ( select instance_uuid from instances where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY)));" $output)
      if [ $nbr -gt 0 ]; then
        mysql $param -ss -Dnova -e "delete from instance_actions_events where action_id in (select id from instance_actions where instance_uuid in ( select instance_uuid from instances where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY)));" $output
      fi
      mysql $param -ss -Dnova -e "delete from instance_actions where instance_uuid in (select instance_uuid from instances where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY));" $output
    fi
  
    for table in $tablelist; do  
      echo $table
      nbr=$(mysql $param -ss -Dnova -e "select count(*) from $table where instance_uuid in (select instance_uuid from instances where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY));" $output)
      if [ $nbr -gt 0 ]; then
        mysql $param -ss -Dnova -e "delete from $table where instance_uuid in (select instance_uuid from instances where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY));" $output
      fi
    done
  
    echo "instances"
    mysql $param -Dnova -e "delete from instances where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY);" $output
  fi
  sleep $sleep;
done

