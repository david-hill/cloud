for p in $(mysql -D cinder -e 'select count(resource),project_id from quota_usages  group by project_id,resource order by count(resource);' | awk '{ if ($1 > 1) print $2 }' | sort | uniq | grep -v project_id); do
  inc=0
  echo $p
  while read -r line 
  do
    if [ ! -z "$line" ]; then
      inc=$(( $inc + 1 ))
      if [ $(( $inc % 2 )) -eq 1 ]; then
        echo $inc $line
        usage_id=$( echo $line | awk '{ print $1 }'    )
        mysql -D cinder -e "delete from reservations where usage_id = $usage_id"
        mysql -D cinder -e "delete from quota_usages where id = $usage_id"
      else
        echo Skipping $line
      fi
    else
      echo "Nothing to do!"
    fi
  done <<< $( mysql -D cinder -e " select q.id from quota_usages as q where project_id like '$p' order by resource,id; " | grep -v id )
done
