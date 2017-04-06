#!/bin/bash
dbfile="/db/data.sql"
files="/db/*.sql"

# if sql dump(s) have been mounted into /db combine and import them
if [ -f $files ]; then
    cat $files > $dbfile
    echo "Importing database..."
    MYSQL_PWD=$MYSQL_ROOT_PASSWORD mysql -u root $MYSQL_DATABASE -e "SOURCE $dbfile"
    rm $dbfile
else
    echo "No file to import found."
    exit 1
fi
