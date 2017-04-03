#!/bin/bash

# if a sql dump has been mounted into /db then import it
dbfile="/db/data.sql"
if [ -f "$dbfile" ]; then
    echo "Importing database"
    MYSQL_PWD=$MYSQL_ROOT_PASSWORD mysql -u root $MYSQL_DATABASE -e "SOURCE $dbfile"
else
    echo "no file to import found at $dbfile"
fi
