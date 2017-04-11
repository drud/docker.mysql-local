#!/bin/bash
dbfile="/db/data.sql"
files=`find /db -name '*.sql'`

# if sql dump(s) have been mounted into /db combine and import them
if [ -n "$files" ]; then
    echo "Importing database..."
    find /db -name '*.sql' | awk '{ print "source",$0 }' | MYSQL_PWD=$MYSQL_ROOT_PASSWORD mysql -u root $MYSQL_DATABASE --batch
    rm /db/*.sql
else
    echo "No file to import found."
    exit 1
fi
