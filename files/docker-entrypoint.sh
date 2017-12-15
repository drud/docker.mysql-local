#!/bin/bash
# set -x

# If no mysql database exists in /var/lib/mysql, run initialization
if [ ! -d "/var/lib/mysql/mysql" ]; then
	mkdir -p /var/lib/mysql
	chown -R mysql:mysql /var/lib/mysql

	echo 'Initializing database'
	mysql_install_db --datadir="/var/lib/mysql" --rpm
	echo 'Database initialized'

	mysqld --skip-networking &
	pid="$!"

	mysql=( mysql --protocol=socket -uroot -hlocalhost --socket="/var/run/mysqld/mysqld.sock" )

	for i in {30..0}; do
		if mysql -e "SELECT 1" &> /dev/null; then
			break
		fi
		echo 'MySQL init process in progress...'
		sleep 1
	done
	if [ "$i" = 0 ]; then
		echo 'MySQL init process failed.'
		exit 1
	fi

	mysql_tzinfo_to_sql /usr/share/zoneinfo | "${mysql[@]}" mysql


	"${mysql[@]}" <<-EOSQL
	-- What's done in this file shouldn't be replicated
	--  or products like mysql-fabric won't work
	SET @@SESSION.SQL_LOG_BIN=0;
	DELETE FROM mysql.user WHERE user NOT IN ('mysql.sys', 'mysqlxsys');
	CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
	GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
	DROP DATABASE IF EXISTS test ;
	FLUSH PRIVILEGES ;
	EOSQL

	mysql+=(--password="${MYSQL_ROOT_PASSWORD}")

	echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` ;" | "${mysql[@]}"
	mysql+=(--database="$MYSQL_DATABASE" )

	echo "Creating mysql user $MYSQL_USER"
	echo "CREATE USER '"$MYSQL_USER"'@'%' IDENTIFIED BY '"$MYSQL_PASSWORD"' ;" | "${mysql[@]}"
	echo "GRANT ALL ON \`"$MYSQL_DATABASE"\`.* TO '"$MYSQL_USER"'@'%' ;" | "${mysql[@]}"
	echo 'FLUSH PRIVILEGES ;' | "${mysql[@]}"

	if ! kill -s TERM "$pid" || ! wait "$pid"; then
		echo >&2 'MySQL init process failed.'
		exit 1
	fi

	echo "Generating .my.cnf"
	echo "[client]" > /root/.my.cnf
	echo "user=${MYSQL_USER}" >> /root/.my.cnf
	echo "password=${MYSQL_PASSWORD}" >> /root/.my.cnf
	echo "database=${MYSQL_DATABASE}" >> /root/.my.cnf
fi

echo
echo 'MySQL init process done. Ready for start up.'
echo

# Change  to UID/GID of the docker user
if [ -n "$DDEV_UID" ] ; then
	echo "changing mysql user to uid: $DDEV_UID"
	usermod -u $DDEV_UID mysql
fi
if [ -n "$DDEV_GID" ] ; then
	echo "changing mysql group to uid: $DDEV_GID"
	groupmod -g $DDEV_GID mysql
fi
chown -R mysql:mysql /var/lib/mysql
chown mysql:mysql /var/log/mysqld.log

echo "Starting mysqld."
exec mysqld --max-allowed-packet=${MYSQL_MAX_ALLOWED_PACKET:-16m}
