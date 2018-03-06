# Mariadb-local for ddev

This docker image builds a mariadb container for ddev.

It builds/copies a simple starter database (an empty database named "db") and starts up the mariadb server.

# Updating the default starter mariadb databases

In the future there may be a need to add another database or rename a database, etc.

The create_base_db.sh script is there for that. 

```
docker run -it --entrypoint=bash drud/mariadb-local:current_tag
./create_base_db.sh
```

Then use `docker cp` to copy the created tarball from /tmp on the container to the host anad put it into files/var/tmp in this repo.

And rebuild the container with whatever other changes you're working on.
