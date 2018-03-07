#!/bin/bash
set -x
set -eu
set -o pipefail

# Change  to UID/GID of the docker user
# We use the default assignment to zero to prevent triggering
# unbound variable exit. Since we chown all files to mysql, this
# must be done at the beginning of the script here.
if [ "${DDEV_UID:=0}" -gt "0" ] ; then
        echo "changing mysql user to uid: $DDEV_UID"
        usermod -o -u $DDEV_UID mysql
fi
if [ "${DDEV_GID:=0}" -gt 0 ] ; then
        echo "changing mysql group to gid: $DDEV_GID"
        groupmod -o -g $DDEV_GID mysql
fi

# If mariadb has not been initialized, copy in the base image.
if [ ! -d "/var/lib/mysql/mysql" ]; then
	mkdir -p /var/lib/mysql
	# The tarball should include only the contents of the db and mysql directories.
	tar  -C /var/lib/mysql -zxf /var/tmp/mariadb_10.1_base_db.tgz
	chown -R mysql:mysql /var/lib/mysql /var/log/mysql*
	echo 'Database initialized'
fi


echo
echo 'MySQL init process done. Ready for start up.'
echo

chown -R mysql:mysql /var/lib/mysql /var/log/mysql*

# Allow mysql to write /var/tmp/mysql.sock
chgrp mysql /var/tmp
chmod ug+w /var/tmp

echo "Starting mysqld."
exec mysqld --max-allowed-packet=${MYSQL_MAX_ALLOWED_PACKET:-16m}
