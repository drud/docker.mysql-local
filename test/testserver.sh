#!/bin/bash
#set -x
set -euo pipefail

IMAGE="$1"  # Full image name with tag
MYSQL_VERSION="$2"
CONTAINER_NAME="testserver"
HOSTPORT=33000

DDEV_UID=0
DDEV_GID=0
if [ $(uname -s) == "linux" ]; then
	DDEV_UID=$(id -u)
	DDEV_GID=$(id -g)
fi

# Always clean up the container on exit.
function cleanup {
	echo "Removing ${CONTAINER_NAME}"
	docker rm -f $CONTAINER_NAME 2>/dev/null || true
}

# Wait for container to be ready.
function containercheck {
	for i in {60..0};
	do
		# status contains uptime and health in parenthesis, sed to return health
		status="$(docker ps --format "{{.Status}}" --filter "name=$CONTAINER_NAME" | sed  's/.*(\(.*\)).*/\1/')"
		if [[ "$status" == "healthy" ]]
		then
			return 0
		fi
		sleep 1
	done
	return 1
}


# Just to make sure we're starting with a clean environment.
cleanup

echo "Starting image with MySQL image $IMAGE"
if ! docker run -e DDEV_UID=$DDEV_UID -e DDEV_GID=$DDEV_UID --name=$CONTAINER_NAME -p $HOSTPORT:3306 -d $IMAGE; then
	echo "MySQL server start failed with error code $?"
	exit 2
fi

# Now that we've got a container running, we need to make sure to clean up
# at the end of the test run, even if something fails.
trap cleanup EXIT

echo "Connecting to mysql server..."
if ! containercheck; then
	echo "Container did not become ready"
fi
echo "Connected to mysql server."

# Try basic connection using root user/password.
if ! mysql --user=root --password=root --database=mysql --host=127.0.0.1 --port=$HOSTPORT -e "SELECT 1;"; then
	exit 1;
fi

# Test to make sure the db user and database are installed properly
if ! mysql -udb -pdb --database=db --host=127.0.0.1 --port=$HOSTPORT -e "SHOW TABLES;"; then
	exit 2
fi

# Make sure we have the right mysql version and can query it (and have root user setup)
OUTPUT=$(mysql --user=root --password=root --skip-column-names --host=127.0.0.1 --port=$HOSTPORT -e "SHOW VARIABLES like \"version\";")
RES=$?
if [ $RES -eq 0 ]; then
	echo "Successful mysql show variables, output=$OUTPUT"
fi
versionregex="version	$MYSQL_VERSION"
if [[ $OUTPUT =~ $versionregex ]];
then
	echo "Version check ok - found '$MYSQL_VERSION'"
else
	echo "Expected to see $versionregex. Actual output: $OUTPUT"
	exit 3
fi

echo "Test passed"
exit 0
