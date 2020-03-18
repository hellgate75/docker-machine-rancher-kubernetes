#!/bin/sh

function usage(){
	echo "provision-docker-machine-rancher.sh  [project id] {nodes_prefix} [-f]"
	echo "  project id     Rancher project id"
	echo "  nodes_prefix   Prefix used to create VMs"
	echo "  -f     		   Force and create environment without questions"
}

function listAvailableProjects() {
	IDX=0
	ID="$(eval "$2/curl -X GET -H 'Accept: application/json' -sL http://$1:8080/v2-beta/projects 2> /dev/null|$2/jq -r '.data[${IDX}].id' 2> /dev/null|grep -v null")"
	NAME="$(eval "$2/curl -X GET -H 'Accept: application/json' -sL http://$1:8080/v2-beta/projects 2> /dev/null|$2/jq -r '.data[${IDX}].name' 2> /dev/null|grep -v null")"
	while [ "" != "$ID" ]; do
		((IDX=IDX+1))
		echo "Project #${IDX}:"
		echo "  Id: $ID"
		echo "  Name: $NAME"
		echo " "
		ID="$(eval "$2/curl -X GET -H 'Accept: application/json' -sL http://$1:8080/v2-beta/projects 2> /dev/null|$2/jq -r '.data[${IDX}].id' 2> /dev/null|grep -v null")"
		NAME="$(eval "$2/curl -X GET -H 'Accept: application/json' -sL http://$1:8080/v2-beta/projects 2> /dev/null|$2/jq -r '.data[${IDX}].name' 2> /dev/null|grep -v null")"
	done
}

function retrieveGETCallFromServer {
	echo "$(eval "$4/curl -X GET -H 'Accept: application/json' -sL http://$1:8080/v2-beta/$2 2> /dev/null|$4/jq -r '.${3}' 2> /dev/null|grep -v null")"
}

function listGETCallFromServer() {
	IDX=0
	DATA="$(eval "$5/curl -X GET -H 'Accept: application/json' -sL http://$1:8080/v2-beta/$2 2> /dev/null|$5/jq -r '.data[${IDX}].$3' 2> /dev/null|grep -v null")"
	while [ "" != "$DATA" ]; do
		((IDX=IDX+1))
		echo "$4 #${IDX}:"
		echo "  $4: $DATA"
		echo " "
	DATA="$(eval "$5/curl -X GET -H 'Accept: application/json' -sL http://$1:8080/v2-beta/$2 2> /dev/null|$5/jq -r '.data[${IDX}].$3' 2> /dev/null|grep -v null")"
	done
}

function listCustomGETCallFromServer() {
	IDX=0
	DATA="$(eval "$5/curl -X GET -H 'Accept: application/json' -sL http://$1:8080/v2-beta/$2 2> /dev/null|$5/jq -r '.${3}[${IDX}].${4}' 2> /dev/null|grep -v null")"
	while [ "" != "$DATA" ]; do
		((IDX=IDX+1))
		echo "$DATA"
		DATA="$(eval "$5/curl -X GET -H 'Accept: application/json' -sL http://$1:8080/v2-beta/$2 2> /dev/null|$5/jq -r '.${3}[${IDX}].${4}' 2> /dev/null|grep -v null")"
	done
}

function printArguments() { 
	echo " "
	echo "Arguments:"
	echo "-------------------------------------"
	echo "Project id: $1"
	echo "Rancher Project: $2"
	echo "-------------------------------------"
	echo " "
}

if [ $# -lt 2 ]; then
	echo "$(usage)"
	exit 1
fi

FOLDER="$(realpath "$(dirname "$0")")"
PROJECT_ID="$1"
PREFIX="$2"
CMD_PREFIX=""
PASS_PRFX="$PREFIX"

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

echo -e "$(printArguments "$PROJECT_ID" "$PREFIX")"

if [ "-f" != "$3" ]; then 
	ANSWER=""
	while [ "y" != "$ANSWER" ] && [ "Y" != "$ANSWER" ] && [ "n" != "$ANSWER" ] && [ "N" != "$ANSWER" ]; do
		read -p "Do you agree with given input arguments? [y/N]: " ANSWER
	done
fi

if [ "" != "$PREFIX" ]; then
	PREFIX="${PREFIX}-"
fi

echo "Rancher master node: ${PREFIX}rancher-node-master"

IP="$(docker-machine ip ${PREFIX}rancher-node-master 2> /dev/null)"

if [ "" == "$IP" ]; then
	echo "Rancher master node ${PREFIX}rancher-node-master NOT reported in docker-machine!!"
fi

while [ "" == "$(${CMD_PREFIX}curl -sL http://$IP:8080/v2-beta 2> /dev/null)" ]; do echo "Waiting for Rancher server to be active: http://$IP:8080/v2-beta"; sleep 20; done

echo "Rancher server http://$IP:8080/v2-beta active!!"

PROJECT_NAME=



PROJECT_NAME="$(retrieveGETCallFromServer "$IP" "projects/$PROJECT_ID" "name" "$CMD_PREFIX" )"

if [ "" = "$PROJECT_NAME" ]; then
	echo "Project id: $PROJECT_ID not found on the Rancher Server."
	echo "Available projects: "
	echo -e "$(listAvailableProjects "$IP" "$CMD_PREFIX")"
	exit 1
fi

echo "Project name: $PROJECT_NAME"
echo " "

echo "Available Catalogs:"
CATALOGS_VALUE="$(retrieveGETCallFromServer "$IP" "projects/$PROJECT_ID/settings/catalog.url" "value" "$CMD_PREFIX" )"
if [ "" != "$CATALOGS_VALUE" ]; then
	echo -e "$(echo "$CATALOGS_VALUE" | ${CMD_PREFIX}jq -r '.catalogs' )"
else
	echo "No catalogs found!!"
fi
echo " "



#${CMD_PREFIX}wget -qO - http://${IP}:8080/v2-beta/projects 2> /dev/null

