sleep=30
for p in {60..31..-1}; do 
echo $p;
current_timestamp=$(mysql -ss -e 'select current_timestamp();' )

echo "volume_admin_metadata"
mysql -ss -Dcinder -e "select count(*) from volume_admin_metadata where volume_id in (select id from volumes where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY));";
mysql -Dcinder -e "delete from volume_admin_metadata where volume_id in (select id from volumes where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY));";
sleep $sleep;
echo "volume_glance_metadata (volumes)"
mysql -ss -Dcinder -e "select count(*) from volume_glance_metadata where volume_id in (select id from volumes where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY));";
mysql -Dcinder -e "delete from volume_glance_metadata where volume_id in (select id from volumes where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY));";
sleep $sleep;
echo "volume_glance_metadata (snapshots)"
mysql -ss -Dcinder -e "select count(*) from volume_glance_metadata where snapshot_id in (select id from snapshots where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY));";
mysql -Dcinder -e "delete from volume_glance_metadata where snapshot_id in (select id from snapshots where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY));";
sleep $sleep;
echo "reservations"
nbr=$(mysql -ss -Dcinder -e "select count(*) from reservations where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY);")
if [ $nbr -gt 0 ]; then
  echo "$nbr"
  mysql -Dcinder -e "delete from reservations where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY);";
  sleep $sleep;
else
  echo "0"
fi
echo "volume_metadata"
mysql -ss -Dcinder -e "select count(*) from volume_metadata where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY);";
mysql -Dcinder -e "delete from volume_metadata where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY);";
mysql -Dcinder -e "delete from volume_metadata where volume_id in (select id from volumes where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY))";
sleep $sleep;
echo "volume_attachment"
mysql -ss -Dcinder -e "select count(*) from volume_attachment where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY);";
mysql -Dcinder -e "delete from volume_attachment where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY);";
sleep $sleep;
echo "volume_attachment (volumes)"
mysql -ss -Dcinder -e "select count(*) from volume_attachment where volume_id in (select id from volumes where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY));"
mysql -Dcinder -e "delete from volume_attachment where volume_id in (select id from volumes where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY));"
echo "snapshot_metadata"
mysql -ss -Dcinder -e "select count(*) from snapshot_metadata where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY);";
mysql -Dcinder -e "delete from snapshot_metadata where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY);";
mysql -Dcinder -e "delete from snapshot_metadata where snapshot_id in ( select id from snapshots where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY));";
sleep $sleep;
echo "snapshots"
mysql -ss -Dcinder -e "select count(*) from snapshots where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY);";
mysql -Dcinder -e "delete from snapshots where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY);";
sleep $sleep;
echo "volumes"
nbr=$(mysql -ss -Dcinder -e "select count(*) from volumes where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY);")
if [ $nbr -gt 0 ]; then
  echo "$nbr"
  mysql -Dcinder -e "delete from volumes where deleted_at < DATE_SUB('$current_timestamp', INTERVAL $p DAY);";
else
  echo "0"
  sleep $sleep;
fi
done | tee output.log

