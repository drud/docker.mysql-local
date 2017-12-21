#!/bin/bash

IMAGE=$1
echo "Running cleanup"
docker kill testserver
docker rm testserver
echo "Cleanup complete"

