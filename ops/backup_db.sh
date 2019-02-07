DATE=`date '+%Y%m%d%H%M%S'`

mysqldump --all-database | gzip > /root/db/backup.$DATE.sql.gz

