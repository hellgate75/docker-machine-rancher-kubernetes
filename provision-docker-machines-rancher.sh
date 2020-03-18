#!/bin/sh
FOLDER="$(realpath "$(dirname "$0")")"
PREFIX="$1"
CMD_PREFIX=""
if [ "windows" == "$($FOLDER/os.sh)" ]; then
	echo "Welcome windows user ..."
	CMD_PREFIX="$FOLDER/"
else
	if [ "" = "$(which curl)" ]; then
		echo "Please install curl and check if you have installed jq, before proceed ..."
		exit 1
	fi
	if [ "" = "$(which jq)" ]; then
		echo "Please install jq, before proceed ..."
		exit 1
	fi
fi
if [ "" != "$PREFIX" ]; then
	PREFIX="${PREFIX}-"
fi

echo "Rancher master node: ${PREFIX}rancher-node-master"

IP="$(docker-machine ip ${PREFIX}rancher-node-master)"

while [ "" == "$(${CMD_PREFIX}curl -sL http://$IP1:8080/v2-beta 2> /dev/null)" ]; do echo "Waiting for Rancher server to be active: http://$IP1:8080/v2-beta"; sleep 20; done

#${CMD_PREFIX}wget -qO - http://${IP}:8080/v2-beta/projects 2> /dev/null

