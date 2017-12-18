#!/bin/bash

#set -o errexit

IMAGE="$1"  # Full image name with tag
MYSQL_VERSION="$2"
CONTAINER_NAME="testserver"
HOSTPORT=33000

function cleanup {
	echo "Removing ${CONTAINER_NAME}"
	docker rm -f $CONTAINER_NAME 2>/dev/null || true
}

# Just to make sure we're starting with a clean environment.
cleanup

echo "Starting image with MySQL image $IMAGE"
docker run --name=$CONTAINER_NAME -p $HOSTPORT:3306 -d $IMAGE
RES=$?
if [ ! $RES = 0 ]; then
	echo "Server start failed with error code $RES"
	exit 2
fi

# Now that we've got a container running, we need to make sure to clean up
# at the end of the test run, even if something fails.
trap cleanup EXIT


CONTAINER_NAME=$CONTAINER_NAME ./test/containercheck.sh
echo "Connecting to server..."
for i in $(seq 30 -1 0); do
	OUTPUT=$(echo "SHOW VARIABLES like 'version';" | mysql -uroot --password=root -h127.0.0.1 -P$HOSTPORT 2>/dev/null)
	RES=$?
	if [ $RES -eq 0 ]; then
		break
	fi
	sleep 1
done
if [ $i = 0 ]; then
	echo >&2 "Unable to connect to server."
	exit 3
fi

versionregex="version	$MYSQL_VERSION"
if [[ $OUTPUT =~ $versionregex ]];
then
	echo "Version check ok - found '$MYSQL_VERSION'"
else
	echo "Expected to see version $MYSQL_VERSION. Actual output: $OUTPUT"
	exit 4
fi

echo "Test passed"
exit 0
