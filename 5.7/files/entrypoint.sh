#!/bin/bash
# set -x

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

# If no mysql database exists in /var/lib/mysql, run initialization
if [ ! -d "/var/lib/mysql/mysql" ]; then
	if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" -a -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
		echo 'error: database is uninitialized and password option is not specified '
		echo '  You need to specify one of MYSQL_ROOT_PASSWORD, MYSQL_ALLOW_EMPTY_PASSWORD and MYSQL_RANDOM_ROOT_PASSWORD'
		exit 1
	fi

	echo 'Initializing database'
	if ! mysqld --initialize-insecure=on; then
		echo "Failed to initialize empty database, contents of mysqld.log follow"
		cat /var/log/mysqld.log
		exit 3
	fi

	echo 'Database initialized'

	mysqld --skip-networking &
	pid="$!"

	mysql=( mysql --protocol=socket --socket=/var/tmp/mysql.sock -uroot )

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
		CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
		GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
		DROP DATABASE IF EXISTS test ;
		FLUSH PRIVILEGES ;
	EOSQL
	if [ ! -z "$MYSQL_ROOT_PASSWORD" ]; then
		mysql+=( -p"${MYSQL_ROOT_PASSWORD}" )
	fi

	if [ "$MYSQL_DATABASE" ]; then
		echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` ;" | "${mysql[@]}"
		mysql+=( "$MYSQL_DATABASE" )
	fi

	if [ "$MYSQL_USER" -a "$MYSQL_PASSWORD" ]; then
		echo "Creating mysql user $MYSQL_USER"
		echo "CREATE USER '"$MYSQL_USER"'@'%' IDENTIFIED BY '"$MYSQL_PASSWORD"' ;" | "${mysql[@]}"

		if [ "$MYSQL_DATABASE" ]; then
			echo "GRANT ALL ON \`"$MYSQL_DATABASE"\`.* TO '"$MYSQL_USER"'@'%' ;" | "${mysql[@]}"
		fi

		echo 'FLUSH PRIVILEGES ;' | "${mysql[@]}"
	fi
	echo
	for f in /docker-entrypoint-initdb.d/*; do
		case "$f" in
			*.sh)  echo "$0: running $f"; . "$f" ;;
			*.sql) echo "$0: running $f"; "${mysql[@]}" < "$f" && echo ;;
			*)     echo "$0: ignoring $f" ;;
		esac
		echo
	done

	if ! kill -s TERM "$pid" || ! wait "$pid"; then
		echo >&2 'MySQL init process failed.'
		exit 4
	fi

fi
echo
echo 'MySQL init process done. Ready for start up.'
echo

# This .my.cnf configuration prevents the initialization process from
# succeeding, so it is moved into place after initialization is complete.
cp /root/mysqlclient.cnf /root/.my.cnf

exec mysqld --max-allowed-packet=${MYSQL_MAX_ALLOWED_PACKET:-16m}
