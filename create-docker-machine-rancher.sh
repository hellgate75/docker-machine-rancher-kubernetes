#!/bin/sh

function checkNumber() {
	case $1 in
		''|*[!0-9]*) echo "false" ;;
		*) echo "true" ;;
	esac
}

function usage(){
	echo "create-docker-machine-rancher.sh [-hv|-vb] {nodes_prefix} [-f]"
	echo "  -hv    		   Use Hyper-V provisioning provider"
	echo "  -vb    		   Use VirtualBox provisioning provider"
	echo "  nodes_prefix   Prefix used to create VMs"
	echo "  -f     		   Force and create environment without questions"
}

function printVMAttributes(){
	echo "-------------------------------------"
	echo "Memory is $MEMORY MB"
	echo "Disk Size is $DISKSIZE MB"
	echo "Number of cores: $CORES"
	echo "-------------------------------------"
	echo " "
}

function printNewVMAttributes(){
	echo "-------------------------------------"
	echo "Memory is $1 MB"
	echo "Disk Size is $2 MB"
	echo "Number of cores: $3"
	echo "-------------------------------------"
	echo " "
}

FOLDER="$(realpath "$(dirname "$0")")"
CMD_PREFIX=""

MEMORY="2048"
DISKSIZE="25000"
CORES="3"

PREFIX="$2"
PASS_PRFX="$2"

if [ "windows" == "$($FOLDER/os.sh)" ]; then
	echo " "
	echo "Welcome windows user ..."
	echo "We assign to you custom curl and jq commands!!"
	echo " "
	CMD_PREFIX="$FOLDER/"
else
	if [ "" = "$(which curl)" ]; then
		echo " "
		echo "Please install curl and check if you have installed jq, before proceed ..."
		echo " "
		exit 1
	fi
	if [ "" = "$(which jq)" ]; then
		echo " "
		echo "Please install jq, before proceed ..."
		echo " "
		exit 1
	fi
fi

MACHINE_RESOURCES=""

if [ "-hv" == "$1" ]; then
	echo "Using Microsoft Hyper-V provisioner ..."
elif  [ "-vb" == "$1" ]; then
	echo "Using Oracle VirtualBox provisioner ..."
else
	echo "$(usage)"
	exit 1
fi

echo "Rancher Project: $PREFIX"


if [ "" != "$PREFIX" ]; then
	PREFIX="${PREFIX}-"
fi

echo "Default VM attributes:"
echo -e "$(printVMAttributes)"

if [ "-f" != "$3" ]; then 
	ANSWER=""
	while [ "y" != "$ANSWER" ] && [ "Y" != "$ANSWER" ] && [ "n" != "$ANSWER" ] && [ "N" != "$ANSWER" ]; do
		read -p "Do you agree with given resources for used by 3 hosts? [y/N]: " ANSWER
	done

	CHANGES="no"

	while [ "n" = "$ANSWER" ] || [ "N" = "$ANSWER" ]; do
		read -p "Please provide memory used by any machine in MB? [default $MEMORY]: " MEM_INPUT
		if [ "" != "$MEM_INPUT" ]; then
			if [ "true" == "$(checkNumber "$MEM_INPUT")" ]; then
				CHANGES="yes"
			else
				echo "Memory parameter must be  number, we keep $MEMORY value"
			fi
		fi
		read -p "Please provide disk size used by any machine in MB? [default $DISKSIZE]: " DISK_INPUT
		if [ "" != "$DISK_INPUT" ]; then
			if [ "true" == "$(checkNumber "$DISK_INPUT")" ]; then
				CHANGES="yes"
			else
				echo "Disk size parameter must be  number, we keep $DISKSIZE value"
			fi
		fi
		read -p "Please provide host assigned CPU cores used by any machine? [default $CORES]: " CORES_INPUT
		if [ "" != "$CORES_INPUT" ]; then
			if [ "true" == "$(checkNumber "$CORES_INPUT")" ]; then
				CHANGES="yes"
			else
				echo "Host assigned CPU cores parameter must be  number, we keep $CORES value"
			fi
		fi
		if [ "yes" == "$CHANGES" ]; then
			echo " "
			echo "Here applied changes:"
			echo -e "$(printNewVMAttributes "$MEM_INPUT" "$DISK_INPUT" "$CORES_INPUT")"
		else
			echo " "
			echo "No changes done on the default VM attributes..."
			echo " "
		fi
		read -p "Do you agree with given resources for used by 3 hosts? [y/N]: " ANSWER
		if [ "yes" == "$CHANGES" ]; then
			if [ "y" = "$ANSWER" ] || [ "Y" = "$ANSWER" ]; then
				MEMORY="$MEM_INPUT"
				DISKSIZE="$DISK_INPUT"
				CORES="$CORES_INPUT"
			fi
		fi
	done
fi


#IP1="$(docker-machine ip ${PREFIX}rancher-node-master)"
#PROJECT_ID="$(${CMD_PREFIX}curl -sL http://$IP1:8080/v1/projects | ${CMD_PREFIX}jq -r '.data[0].id')"
#echo "Provisinging Rancher Kubernetes cluster"
#$FOLDER/provision-docker-machines-rancher.sh "$PROJECT_ID" "${PASS_PRFX}" "${PASS_PRFX}" "$3"
#exit 0

MACHINE_RESOURCES=""

if [ "-hv" == "$1" ]; then
	MACHINE_RESOURCES="-d hyperv --hyperv-memory $MEMORY --hyperv-disk-size $DISKSIZE --hyperv-cpu-count $CORES --hyperv-disable-dynamic-memory --hyperv-boot2docker-url "
elif  [ "-vb" == "$1" ]; then
	MACHINE_RESOURCES="-d virtualbox --virtualbox-memory $MEMORY --virtualbox-disk-size $DISKSIZE --virtualbox-cpu-count $CORES --virtualbox-disable-dynamic-memory --virtualbox-boot2docker-url "
else
	echo "$(usage)"
	exit 1
fi

echo "Creating MASTER Rancher node ..."
docker-machine create $MACHINE_RESOURCES https://releases.rancher.com/os/latest/rancheros.iso \
 ${PREFIX}rancher-node-master
echo "MASTER Rancher node installing curl container ..."
docker-machine ssh optiim-rancher-node-master "sudo sh -c \"echo \\\"docker run --rm curlimages/curl \$ @\\\" > /usr/bin/curl && chmod +x /usr/bin/curl && sed -i 's/$ @/\\\$@/g' /usr/bin/curl && curl --help \""
echo "MASTER Rancher node installing Rancher Server ..."
docker-machine ssh ${PREFIX}rancher-node-master "sudo mkdir /var/lib/cattle && sudo mkdir /var/lib/mysql && sudo mkdir /var/log/mysql"
docker-machine ssh ${PREFIX}rancher-node-master "sudo system-docker pull rancher/server"
docker-machine ssh ${PREFIX}rancher-node-master "sudo system-docker run -d --restart=always -v /var/lib/cattle:/var/lib/cattle -v /var/lib/mysql:/var/lib/mysql -v /var/log/mysql:/var/log/mysql -p 8080:8080 -p 8081:8081 -p 8088:8088 -p 9345:9345 -p 9000:9000 -p 3306:3306 -it --user root:root --privileged --name rancher-server rancher/server"
IP1="$(docker-machine ip ${PREFIX}rancher-node-master)"
echo "MASTER Rancher node Ip: $IP1"
while [ "" == "$(${CMD_PREFIX}curl -sL http://$IP1:8080/v1 2> /dev/null)" ]; do echo "Waiting for Rancher server to be active: http://$IP1:8080"; sleep 20; done
PROJECT_ID="$(${CMD_PREFIX}curl -sL http://$IP1:8080/v1/projects | ${CMD_PREFIX}jq -r '.data[0].id')"
echo "Waiting 60 seconds for giving the API engine time to read database..."
sleep 60

echo "Creating SLAVE Rancher node #1 ..."
docker-machine create $MACHINE_RESOURCES https://releases.rancher.com/os/latest/rancheros.iso \
 ${PREFIX}rancher-node-2
echo "SLAVE Rancher node #1 installing curl container ..."
docker-machine ssh optiim-rancher-node-2 "sudo sh -c \"echo \\\"docker run --rm curlimages/curl \$ @\\\" > /usr/bin/curl && chmod +x /usr/bin/curl && sed -i 's/$ @/\\\$@/g' /usr/bin/curl && curl --help \""
IP2="$(docker-machine ip ${PREFIX}rancher-node-2)"
echo "SLAVE Rancher node #1 Ip: $IP2"
REG_TOKEN_REFERENCE="$(${CMD_PREFIX}curl -sL  -X POST -H 'Accept: application/json' http://$IP1:8080/v1/registrationtokens?projectId=$PROJECT_ID 2> /dev/null|${CMD_PREFIX}/jq -r '.actions.activate' 2> /dev/null)"
sleep 5
COMMAND="$(${CMD_PREFIX}curl -s -X GET $REG_TOKEN_REFERENCE 2> /dev/null | ${CMD_PREFIX}jq -r '.command' 2> /dev/null)"
echo "SLAVE Rancher node #1 Command: $COMMAND"
if [ "" != "$COMMAND" ]; then
	docker-machine ssh ${PREFIX}rancher-node-2 "$COMMAND"
else
	echo "Please register your server ${PREFIX}rancher-node-2 manually on the web interface at: http://$IP1:8080 -> Host"
fi
sleep 30
echo "Creating SLAVE Rancher node #2 ..."
docker-machine create $MACHINE_RESOURCES https://releases.rancher.com/os/latest/rancheros.iso \
 ${PREFIX}rancher-node-3
echo "SLAVE Rancher node #2 installing curl container ..."
docker-machine ssh optiim-rancher-node-3 "sudo sh -c \"echo \\\"docker run --rm curlimages/curl \$ @\\\" > /usr/bin/curl && chmod +x /usr/bin/curl && sed -i 's/$ @/\\\$@/g' /usr/bin/curl && curl --help \""
IP3="$(docker-machine ip ${PREFIX}rancher-node-3)"
echo "SLAVE Rancher node #2 Ip: $IP3"
REG_TOKEN_REFERENCE="$(${CMD_PREFIX}curl -sL  -X POST -H 'Accept: application/json' http://$IP1:8080/v1/registrationtokens?projectId=$PROJECT_ID 2> /dev/null|${CMD_PREFIX}/jq -r '.actions.activate' 2> /dev/null)"
sleep 5
COMMAND="$(${CMD_PREFIX}curl -s -X GET $REG_TOKEN_REFERENCE 2> /dev/null | ${CMD_PREFIX}jq -r '.command' 2> /dev/null)"
echo "SLAVE Rancher node #2 Command: $COMMAND"
if [ "" != "$COMMAND" ]; then
	docker-machine ssh ${PREFIX}rancher-node-3 "$COMMAND"
else
	echo "Please register your server ${PREFIX}rancher-node-3 manually on the web interface at: http://$IP1:8080 -> Host"
fi

echo "----------------------------------"
echo "Master: $IP1"
echo "Slave: $IP2"
echo "Slave: $IP3"
echo "Rancher Server Url: http://$IP1:8080"
echo "----------------------------------"
echo ""
echo "Provisinging Rancher Kubernetes cluster"
$FOLDER/provision-docker-machines-rancher.sh "$PROJECT_ID" "${PASS_PRFX}" "${PASS_PRFX}" "$3"
exit 0