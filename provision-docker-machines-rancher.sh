#!/bin/sh

FOLDER="$(realpath "$(dirname "$0")")"

RANCHER_NODES=2


function checkNumber() {
	case $1 in
		''|*[!0-9]*) echo "false" ;;
		*) echo "true" ;;
	esac
}

if [ "" != "$RANCHER_KUBERNETES_NODES" ] && [ "true" = "$(checkNumber $RANCHER_KUBERNETES_NODES)" ]; then
	RANCHER_NODES=$RANCHER_KUBERNETES_NODES
fi

function usage(){
	echo "provision-docker-machine-rancher.sh  [project id] {project name} {nodes_prefix} [-f]"
	echo "  project id     Rancher project id"
	echo "  project name   Prefix used to create Kubernetes Cluster"
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
PREFIX="$3"
CMD_PREFIX=""
PASS_PRFX="$3"
PROJECT_NAME="$2"

if [ "windows" == "$($FOLDER/os.sh)" ]; then
	echo "Welcome windows user ..."
	CMD_PREFIX="$FOLDER/"
else
	if [ "" = "$(which curl 2> /dev/null)" ]; then
		echo "Please install curl and check if you have installed jq, before proceed ..."
		exit 1
	fi
	if [ "" = "$(which jq 2> /dev/null)" ]; then
		echo "Please install jq, before proceed ..."
		exit 1
	fi
fi

RKE_CMD="$(which rke 2> /dev/null)"
if [ "" = "$RKE_CMD" ]; then
	RKE_CMD="$(ls $FOLDER/rke 2> /dev/null)"
fi

if [ "" = "$RKE_CMD" ]; then
	LATEST="$(${CMD_PREFIX}curl -sL -X GET https://github.com/rancher/rke/releases/latest/ | grep '<a href="/rancher/rke/releases/tag/'|awk 'BEGIN {FS=OFS="<a href=\"/rancher/rke/releases/tag/"}{print $2}'|awk 'BEGIN {FS=OFS="\">"}{print $1}'|head -1)"
	echo "Downloading rke $LATEST"
	OS="$(sh -c $FOLDER/os.sh)"
	ARCH="$(sh -c $FOLDER/arch.sh)"
	EXT=""
	RKE_ARCH=""
	if [ "x86_64" = "$ARCH" ]; then
			RKE_ARCH="amd64"
	else
			RKE_ARCH="386"
			if [ "windows" != "$OS" ]; then
				RKE_ARCH="amd64"
			fi
	fi
	if [ "windows" = "$OS" ]; then
		EXT=".exe"
	fi
	curl -sL "https://github.com/rancher/rke/releases/download/${LATEST}/rke_${OS}-${RKE_ARCH}${EXT}" -o $FOLDER/rke && chmod +x $FOLDER/rke
	echo "See cluster.yaml examples at: https://rancher.com/docs/rke/latest/en/example-yamls/"
	echo " "
	echo " "
	RKE_CMD="$(ls $FOLDER/rke 2> /dev/null)"
fi

RANCHER_COMPOSE_CMD="$(which rancher-compose 2> /dev/null)"
if [ "" = "$RANCHER_COMPOSE_CMD" ]; then
	RANCHER_COMPOSE_CMD="$(ls $FOLDER/rancher-compose*/rancher-compose* 2>/dev/null)"
fi

if [ "" = "$RANCHER_COMPOSE_CMD" ]; then
	LATEST="$(${CMD_PREFIX}curl -sL -X GET https://github.com/rancher/rancher-compose/releases/ | grep '<a href=\"/rancher/rancher-compose/tree/'|awk 'BEGIN {FS=OFS="title=\""}{print $2}'|awk 'BEGIN {FS=OFS="\""}{print $1}'|head -1)"
	echo "Downloading rancher-compose $LATEST"
	OS="$(sh -c $FOLDER/os.sh)"
	ARCH="$(sh -c $FOLDER/arch.sh)"
	EXT=".tar.gz"
	RKE_ARCH=""
	if [ "x86_64" = "$ARCH" ]; then
			RKE_ARCH="amd64"
	else
			RKE_ARCH="386"
			if [ "windows" != "$OS" ]; then
				RKE_ARCH="amd64"
			fi
	fi
	if [ "windows" = "$OS" ]; then
		EXT=".zip"
	fi
	curl -sL "https://github.com/rancher/rancher-compose/releases/download/${LATEST}/rancher-compose-${OS}-${RKE_ARCH}-${LATEST}${EXT}" -o $FOLDER/rancher-compose${EXT} && unzip -qq $FOLDER/rancher-compose -d $FOLDER && rm -f $FOLDER/rancher-compose${EXT} && chmod +x $FOLDER/rancher-compose*/rancher-compose*
	echo " "
	echo " "
	RANCHER_COMPOSE_CMD="$(ls rancher-compose*/rancher-compose* 2>/dev/null)"
fi

RANCHER_CLI_CMD="$(which rancher 2> /dev/null)"
if [ "" = "$RANCHER_CLI_CMD" ]; then
	RANCHER_CLI_CMD="$(ls $FOLDER/rancher-v*/rancher* 2> /dev/null)"
fi
if [ "" = "$RANCHER_CLI_CMD" ]; then
	LATEST="$(${CMD_PREFIX}curl -sL -X GET https://github.com/rancher/cli/releases | grep '<a href=\"/rancher/cli/tree/'|awk 'BEGIN {FS=OFS="title=\""}{print $2}'|awk 'BEGIN {FS=OFS="\""}{print $1}'|head -1)"
	echo "Downloading rancher-cli $LATEST"
	OS="$(sh -c $FOLDER/os.sh)"
	ARCH="$(sh -c $FOLDER/arch.sh)"
	EXT=".tar.gz"
	RKE_ARCH=""
	if [ "x86_64" = "$ARCH" ]; then
			RKE_ARCH="amd64"
	else
			RKE_ARCH="386"
			if [ "windows" != "$OS" ]; then
				RKE_ARCH="amd64"
			fi
	fi
	if [ "windows" = "$OS" ]; then
		EXT=".zip"
	fi
	curl -sL "https://github.com/rancher/cli/releases/download/${LATEST}/rancher-${OS}-${RKE_ARCH}-${LATEST}${EXT}" -o $FOLDER/rancher-cli${EXT} && unzip -qq $FOLDER/rancher-cli -d $FOLDER && rm -f $FOLDER/rancher-cli${EXT} && chmod +x $FOLDER/rancher-v*/rancher*
	echo " "
	echo " "
	RANCHER_CLI_CMD="$(ls $FOLDER/rancher-v*/rancher* 2> /dev/null)"
fi

echo -e "$(printArguments "$PROJECT_ID" "$PREFIX")"

if [ "-f" != "$4" ]; then 
	ANSWER=""
	while [ "y" != "$ANSWER" ] && [ "Y" != "$ANSWER" ] && [ "n" != "$ANSWER" ] && [ "N" != "$ANSWER" ]; do
		read -p "Do you agree with given input arguments? [y/N]: " ANSWER
	done
	if [ "n" == "$ANSWER" ] || [ "N" == "$ANSWER" ]; then
		echo "User required exit ..."
		exit 0
	fi
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

echo "Starting Kuberbetes Cluster: $PROJECT_NAME Kubernetes"
$RANCHER_COMPOSE_CMD --file kubernetes/docker-compose.yml --project-name "$PROJECT_NAME Kubernetes" --url http://$IP:8080/v2-beta/projects/$PROJECT_ID/stacks up
#${CMD_PREFIX}wget -qO - http://${IP}:8080/v2-beta/projects 2> /dev/null

