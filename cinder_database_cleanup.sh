#!/bin/bash

date=$(date +%Y%m%d.%H%M%S)
iam=$(whoami)
mysql=$(which mysql)
mysqldump=$(which mysqldump)
numberofdays=
username=
password=

if [ ! -e "${mysql}" ]; then
  echo mysql binary is not in your path, please fix this
  exit 1
fi

if [ ! -e "${mysqldump}" ]; then
  echo mysqldump binary is not in your path, please fix this
  exit 1
fi

if [[ ! "${iam}" =~ root ]]; then
  echo you must be root, please fix this
  exit 1
fi

if [ ! -d "/var/lib/mysql/backup" ]; then
   mkdir -p /var/lib/mysql/backup
fi

while getopts ":vu:p:d:" opt; do

  case $opt in
    v) debug=1 ;;
    d) numberofdays=$OPTARG ;;
    u) username=$OPTARG ;;
    p) password=$OPTARG ;;
    \?)
      echo "Invalid option: -$OPTARG"
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument."
      exit 1
      ;;
  esac

done

if [ -z "${username}" ]||[ -z "${password}" ]||[ -z "${numberofdays}" ]; then
  echo please specify a username, a password and the number of days of DELETED data you want to keep in the tables
  exit 1
fi

$mysqldump cinder -r /var/lib/mysql/backup/cinder.sql.${date} -u$username -p$password
if [ $? -ne 0 ]; then
  echo failed to backup table cinder, exiting now 
  exit $?
fi

table_list="backups volume_glance_metadata snapshots cgsnapshots consistencygroups encryption iscsi_targets quality_of_service_specs quota_classes quota_usages quotas reservations services snapshot_metadata transfers volume_admin_metadata volume_metadata volume_type_extra_specs volume_types volumes"

for table in $table_list; do

  todelete=$(echo "select count(*) from ${table} where deleted_at < DATE_SUB(current_timestamp, INTERVAL $numberofdays day);" | ${mysql} -D cinder -u$username -p$password | grep -v count)

  if [ "${todelete}" -gt 0 ]; then

    echo We will delete $todelete rows from table ${table} in the cinder database
    echo "delete from ${table} where deleted_at < DATE_SUB(current_timestamp, INTERVAL $numberofdays day);" | ${mysql} -D cinder -u$username -p$password

    if [ $? -ne 0 ]; then

      echo mysql encountered an error, exiting
      exit $?

    fi
  elif [ "$debug" ]; then 
    echo Skipping $table; 
  fi
done

