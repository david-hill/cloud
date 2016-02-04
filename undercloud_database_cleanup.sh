#!/bin/bash

table_list="block_device_mapping; instance_actions_events instance_actions  instance_extra instance_info_caches instance_system_metadata instance_faults instances" 

for table in $table_list; do
    echo "delete from ${table};" | mysql -D nova
done

table_list="ports nodes"

for table in $table_list; do
    echo "delete from ${table};" | mysql -D ironic
done

