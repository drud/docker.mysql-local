#!/bin/bash
# set -x
set -eu
set -o pipefail

SOCKET=/var/tmp/mysql.sock

# If mariadb has not been initialized, initialize it.
# Then create our 'db', database, 'db' user, and permissions.
if [ ! -d "/var/lib/mysql/mysql" ]; then
	mkdir -p /var/lib/mysql
	chown -R mysql:mysql /var/lib/mysql

	echo 'Initializing mysql'
	mysql_install_db --datadir="/var/lib/mysql"
	mysqld --skip-networking >/tmp/mysqld.out 2>&1 &
	pid="$!"

	# Wait for the server to respond to mysqladmin ping, or fail if it never does,
	# or if the process dies.
	for i in {60..0}; do
		if mysqladmin ping -uroot --socket=$SOCKET 2>/dev/null; then
			break
		fi
		# Test to make sure we got it started in the first place. kill -s 0 just tests to see if process exists.
		if ! kill -s 0 $pid 2>/dev/null; then
			echo "MariaDB initialization startup failed"
			exit 3
		fi
		echo "MariaDB initialization startup process in progress... Try# $i"
		sleep 1
	done
	if [ "$i" -eq 0 ]; then
		echo 'MariaDB initialization startup process timed out.'
		exit 1
	fi

	mysql --database=mysql -uroot --password='' -e "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` ;"

	mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -uroot --password='' mysql

	mysql -uroot  --password='' -e "CREATE USER '"$MYSQL_USER"'@'%' IDENTIFIED BY '"$MYSQL_PASSWORD"' ;"
	mysql -uroot  --password='' -e "GRANT ALL ON \`"$MYSQL_DATABASE"\`.* TO '"$MYSQL_USER"'@'%' ;"
	mysql -uroot  --password='' -e 'FLUSH PRIVILEGES ;'

	mysql -uroot --password='' -e "CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';"
	mysql -uroot --password='' -e "GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;"
	mysql -uroot --password='' -e "FLUSH PRIVILEGES;"

	mysqladmin --socket=$SOCKET  -uroot password "$MYSQL_ROOT_PASSWORD"

	if ! kill -s TERM "$pid" || ! wait "$pid"; then
		echo >&2 'Mariadb initialization process failed.'
		exit 1
	fi

	echo 'Mariadb initialized'
fi

echo
echo 'MySQL startup process done. Ready for server start up.'
echo


# Change  to UID/GID of the docker user
# We use the default assignment to zero to prevent triggering
# unbound variable exit
if [ "${DDEV_UID:=0}" -gt "0" ] ; then
        echo "changing mysql user to uid: $DDEV_UID"
        usermod -u $DDEV_UID mysql
fi
if [ "${DDEV_GID:=0}" -gt 0 ] ; then
        echo "changing mysql group to gid: $DDEV_GID"
        groupmod -g $DDEV_GID mysql
fi

chown -R mysql:mysql /var/lib/mysql
chown mysql:mysql /var/log/mysqld.log

echo "Starting mysqld."
exec mysqld --max-allowed-packet=${MYSQL_MAX_ALLOWED_PACKET:-16m}
