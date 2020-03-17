#!/bin/sh

PREFIX="$1"

if [ "" != "$PREFIX" ]; then
	PREFIX="${PREFIX}-"
fi

docker-machine rm -f ${PREFIX}rancher-node-master
docker-machine rm -f ${PREFIX}rancher-node-2
docker-machine rm -f ${PREFIX}rancher-node-3
