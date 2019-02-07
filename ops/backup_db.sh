DATE=`date '+%Y%m%d%H%M%S'`


if [ ! -d /root/db ]; then
  mkdir /root/db
fi

mysqldump --all-databases | gzip > /root/db/backup.$DATE.sql.gz
if [ $? -ne 0 ]; then
  echo Warning!
fi
