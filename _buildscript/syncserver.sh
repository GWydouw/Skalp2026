#!/usr/bin/env bash
# Script to synchronise relevant data and databases from one Skalp server to another
# usage from local machine:
# ssh -p '65432' 'skalpadmin@license.skalp4sketchup.com' 'bash -s' < ~/Dropbox/Sourcetree_repos/Skalp/EvalC/syncserver.sh "licensedev.skalp4sketchup.com"

TARGET="$1"
TARGET_IP=$(getent hosts "$TARGET" | awk '{ print $1 }')


echo "Synchronizing /var/www/ and databases to $TARGET at $TARGET_IP"

#shellscripts need elevated right to be picked up by rsync
find /var/www/ -iname "*.sh" -exec chmod 400 {} \;
#find /var/www/ -iname "*.sh" -exec touch {} \; #force copying shellscripts
# sync files to new server (licenses, skalp download pages, skalp builds, skalp php scripts,...)
# ATTENTION : does not copy shellscripts with 005 rights, elevate right manually
rsync -avzP /var/www/ -e "ssh -p 65432" "skalpadmin@$TARGET:/var/www"
#rsync -anvzP /var/www/ -e "ssh -p 65432" "skalpadmin@$TARGET:/var/www"
find /var/www/ -iname "*.sh" -exec chmod 005 {} \;

#: <<'COMMENT'
export MYSQL_PWD=skalp14

array=( skalp_v1 skalp_idevaffiliate skalp )

for database_name in "${array[@]}"
do
# delete old database dump
touch ~/"$database_name.sql"
rm -f ~/"$database_name.sql"

# dump a copy of the database
#mysqldump -u root --opt skalp > "$(date '+%F') skalp.sql"
mysqldump -u root --opt "$database_name" > "$database_name.sql"

# copy database to new server
scp -P 65432 "$database_name.sql" "skalpadmin@$TARGET:/home/skalpadmin"

# run remote script on new server
ssh -p '65432' "skalpadmin@$TARGET" <<-EOF
find /var/www/ -iname "*.sh" -exec chmod 005 {} \;
echo "$database_name"
export MYSQL_PWD=skalp14
mysql -u root <<MY_QUERY
DROP DATABASE IF EXISTS $database_name;
CREATE DATABASE $database_name;
USE $database_name;
SOURCE ~/$database_name.sql;
MY_QUERY
unset MYSQL_PWD
EOF
done #for-do-done loop end

unset MYSQL_PWD

#COMMENT

#TODO stop database service (ubuntu 14.06):
#sudo stop mysql # The service must be running
#sudo restart mysql # The service must be running
#sudo start mysql

echo 'You may now stop the mysql service using: sudo stop mysql'
echo 'END OF SCRIPT'