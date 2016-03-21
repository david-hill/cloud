#!/bin/bash

date=$(date +%Y%m%d.%H%M%S)
iam=$(whoami)
mysql=$(which mysql)
mysqldump=$(which mysqldump)
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

if [ -z "${username}" ]||[ -z "${password}" ]; then
  echo please specify a username, a password and the number of days of DELETED data you want to keep in the tables
  exit 1
fi

$mysqldump glance -r /var/lib/mysql/backup/glance.sql.${date} -u$username -p$password
if [ $? -ne 0 ]; then
  echo failed to backup table glance, exiting now 
  exit $?
fi

echo "update image_properties set deleted_at=current_timestamp, deleted=1 where image_id in (select id from images where status like 'queued');" | ${mysql} -u ${username} -p${password} -D glance
echo "update image_locations set deleted_at=current_timestamp, deleted=1 where image_id in (select id from images where status like 'queued');" | ${mysql} -u ${username} -p${password} -D glance
echo "update images set deleted_at=current_timestamp,status='deleted',deleted=1 where status='queued';" | ${mysql} -u ${username} -p ${password} -D glance

