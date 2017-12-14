#!/bin/bash
set -xeo pipefail

# # Change  to UID/GID of the docker user
# if [ -n "$DDEV_UID" ] ; then
# 	echo "changing mysql user to uid: $DDEV_UID"
# 	usermod -u $DDEV_UID mysql
# fi
# if [ -n "$DDEV_GID" ] ; then
# 	echo "changing mysql group to uid: $DDEV_GID"
# 	groupmod -g $DDEV_GID mysql
# fi
# chown -R mysql:mysql /var/lib/mysql

echo "Starting mysqld."
exec mysqld --max-allowed-packet=${MYSQL_MAX_ALLOWED_PACKET:-16m}
