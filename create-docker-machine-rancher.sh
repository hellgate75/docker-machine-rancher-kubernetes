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

ENGINE="$1"
if [ "-gce" = "$ENGINE" ] && [ "" != "$(which dos2unix)" ]; then
	dos2unix $FOLDER/install-docker.sh
fi


CONFIG_FILE_NAME="gce-config.env"
if [ "" != "$GOOGLE_CUSTOM_CONFIG_FILE" ]; then
	CONFIG_FILE_NAME="$GOOGLE_CUSTOM_CONFIG_FILE"
fi
if [ "-gce" = "$ENGINE" ] && [ -e "$FOLDER/$CONFIG_FILE_NAME" ]; then
	echo "Loading GCE env config file: $FOLDER/$CONFIG_FILE_NAME ..."
	source $FOLDER/$CONFIG_FILE_NAME
fi
if [ "-gce" = "$ENGINE" ] && [ "" = "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
	echo "Please set-up credentials file in variable: GOOGLE_APPLICATION_CREDENTIALS, cannot continue..."
	exit 1
fi

function usage(){
	echo "create-docker-machine-rancher.sh [-hv|-vb|-gce] {nodes_prefix} [-f]"
	echo "  -hv    		   Use Hyper-V provisioning provider"
	echo "  -vb    		   Use VirtualBox provisioning provider"
	echo "  -gce		   Use Google Cloud Engine provider"
	echo "  nodes_prefix   Prefix used to create VMs"
	echo "  -f     		   Force and create environment without questions"
}

function printVMAttributes(){
	echo "-------------------------------------"
	if [ "-hv" = "$ENGINE" ] || [ "-vb" = "$ENGINE" ]; then
		echo "Memory is $MEMORY MB"
		echo "Disk Size is $DISKSIZE MB"
		echo "Number of cores: $CORES"
	elif [ "-gce" = "$ENGINE" ]; then
		echo "GCE project: $GOOGLE_PROJECT"
		echo "GCE zone: $GOOGLE_ZONE"
		echo "GCE machine type: $GOOGLE_MACHINE_TYPE"
		echo "GCE machine image: $GOOGLE_MACHINE_IMAGE"
		echo "GCE disk size: $GOOGLE_DISK_SIZE"
		echo "Only from config file '$FOLDER/$CONFIG_FILE_NAME' :"
		echo "GCE address: $GOOGLE_ADDRESS"
		echo "GCE disk type: $GOOGLE_DISK_TYPE"
		echo "GCE network: $GOOGLE_NETWORK"
		echo "GCE open port: $GOOGLE_OPEN_PORT"
		echo "GCE Preemptible: $GOOGLE_PREEMPTIBLE"
		echo "GCE Scopes: $GOOGLE_SCOPES"
		echo "GCE service account: $GOOGLE_SERVICE_ACCOUNT"
		echo "GCE Subnetworks: $GOOGLE_SUBNETWORK"
		echo "GCE Tags: $GOOGLE_TAGS"
		echo "GCE Use Existing: $GOOGLE_USE_EXISTING"
		echo "GCE Use Internal IP: $GOOGLE_USE_INTERNAL_IP"
		echo "GCE Use Only Internal IP: $GOOGLE_USE_INTERNAL_IP_ONLY"
		echo "GCE User name: $GOOGLE_USERNAME"
	fi
	echo "-------------------------------------"
	echo " "
}

function printNewVMAttributes(){
	echo "-------------------------------------"
	if [ "-hv" = "$1" ] || [ "-vb" = "$1" ]; then
		echo "Memory is $2 MB"
		echo "Disk Size is $3 MB"
		echo "Number of cores: $4"
	elif [ "-gce" = "$1" ]; then
		echo "GCE project: $5"
		echo "GCE region: $6"
		echo "GCE machine type: $7"
		echo "GCE machine image: $8"
		echo "GCE disk size: $9"
		echo "Only from config file '$FOLDER/$CONFIG_FILE_NAME' :"
		echo "GCE address: $GOOGLE_ADDRESS"
		echo "GCE disk type: $GOOGLE_DISK_TYPE"
		echo "GCE network: $GOOGLE_NETWORK"
		echo "GCE open port: $GOOGLE_OPEN_PORT"
		echo "GCE Preemptible: $GOOGLE_PREEMPTIBLE"
		echo "GCE Scopes: $GOOGLE_SCOPES"
		echo "GCE service account: $GOOGLE_SERVICE_ACCOUNT"
		echo "GCE Subnetworks: $GOOGLE_SUBNETWORK"
		echo "GCE Tags: $GOOGLE_TAGS"
		echo "GCE Use Existing: $GOOGLE_USE_EXISTING"
		echo "GCE Use Internal IP: $GOOGLE_USE_INTERNAL_IP"
		echo "GCE Use Only Internal IP: $GOOGLE_USE_INTERNAL_IP_ONLY"
		echo "GCE User name: $GOOGLE_USERNAME"
	fi
	echo "-------------------------------------"
	echo " "
}
CMD_PREFIX=""

MEMORY="2048"
DISKSIZE="25000"
CORES="3"


ISO_IMAGE="https://releases.rancher.com/os/latest/rancheros.iso"
if [ "-hv" = "$ENGINE" ]; then
    ISO_IMAGE="https://releases.rancher.com/os/latest/hyperv/rancheros.iso"
elif [ "-vw" = "$ENGINE" ]; then
	ISO_IMAGE="https://releases.rancher.com/os/latest/vmware/rancheros.iso"
fi

PREFIX="$2"
PASS_PRFX="$2"

if [ "windows" = "$($FOLDER/os.sh)" ]; then
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

if [ "-hv" = "$1" ]; then
	echo "Using Microsoft Hyper-V provisioner ..."
elif  [ "-vb" = "$1" ]; then
	echo "Using Oracle VirtualBox provisioner ..."
elif  [ "-gce" = "$1" ]; then
	echo "Using Google Cloud Engine provisioner ..."
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
		if [ "-hv" = "$ENGINE" ] || [ "-vb" = "$ENGINE" ]; then
			read -p "Please provide memory used by any machine in MB? [default $MEMORY]: " MEM_INPUT
			if [ "" != "$MEM_INPUT" ]; then
				if [ "true" = "$(checkNumber "$MEM_INPUT")" ]; then
					CHANGES="yes"
				else
					MEM_INPUT="$MEMORY"
					echo "Memory parameter must be  number, we keep $MEMORY value"
				fi
			else
				MEM_INPUT="$MEMORY"
			fi
			read -p "Please provide disk size used by any machine in MB? [default $DISKSIZE]: " DISK_INPUT
			if [ "" != "$DISK_INPUT" ]; then
				if [ "true" = "$(checkNumber "$DISK_INPUT")" ]; then
					CHANGES="yes"
				else
					DISK_INPUT="$DISKSIZE"
					echo "Disk size parameter must be  number, we keep $DISKSIZE value"
				fi
			else
				DISK_INPUT="$DISKSIZE"
			fi
			read -p "Please provide host assigned CPU cores used by any machine? [default $CORES]: " CORES_INPUT
			if [ "" != "$CORES_INPUT" ]; then
				if [ "true" = "$(checkNumber "$CORES_INPUT")" ]; then
					CHANGES="yes"
				else
					CORES_INPUT="$CORES"
					echo "Host assigned CPU cores parameter must be  number, we keep $CORES value"
				fi
			else
				CORES_INPUT="$CORES"
			fi
		elif [ "-gce" = "$ENGINE" ]; then
			read -p "Please provide GCE project? [default $GOOGLE_PROJECT]: " GCE_PROJECT_INPUT
			if [ "" != "$GCE_PROJECT_INPUT" ]; then
				CHANGES="yes"
			else
				GCE_PROJECT_INPUT="$GOOGLE_PROJECT"
				echo "GCE Project parameter must be not empty, we keep $GOOGLE_PROJECT value"
			fi
			read -p "Please provide GCE zone? [default $GOOGLE_ZONE]: " GCE_REGION_INPUT
			if [ "" != "$GCE_REGION_INPUT" ]; then
				CHANGES="yes"
			else
				GCE_REGION_INPUT="$GOOGLE_ZONE"
				echo "GCE zone parameter must be not empty, we keep $GOOGLE_ZONE value"
			fi
			read -p "Please provide GCE machine type? [default $GOOGLE_MACHINE_TYPE]: " GCE_MACHINE_SIZE_INPUT
			if [ "" != "$GCE_MACHINE_SIZE_INPUT" ]; then
				CHANGES="yes"
			else
				GCE_MACHINE_SIZE_INPUT="$GOOGLE_MACHINE_TYPE"
				echo "GCE machine type parameter must be not empty, we keep $GOOGLE_MACHINE_TYPE value"
			fi
			read -p "Please provide GCE machine image? [default $GOOGLE_MACHINE_IMAGE]: " GCE_MACHINE_IMAGE_INPUT
			if [ "" != "$GCE_MACHINE_IMAGE_INPUT" ]; then
				CHANGES="yes"
			else
				GCE_MACHINE_IMAGE_INPUT="$GOOGLE_MACHINE_IMAGE"
				echo "GCE machine type parameter must be not empty, we keep $GOOGLE_MACHINE_IMAGE value"
			fi
			read -p "Please provide GCE disk size used by any machine in MB? [default $GOOGLE_DISK_SIZE]: " GCE_DISK_SIZE_INPUT
			if [ "" != "$GCE_DISK_SIZE_INPUT" ]; then
				if [ "true" = "$(checkNumber "$GCE_DISK_SIZE_INPUT")" ]; then
					CHANGES="yes"
				else
					GCE_DISK_SIZE_INPUT="$GOOGLE_DISK_SIZE"
					echo "GCE Disk size parameter must be  number, we keep $GOOGLE_DISK_SIZE value"
				fi
			else
				GCE_DISK_SIZE_INPUT="$GOOGLE_DISK_SIZE"
			fi
		fi
		if [ "yes" = "$CHANGES" ]; then
			echo " "
			echo "Here applied changes:"
			echo -e "$(printNewVMAttributes "$ENGINE" "$MEM_INPUT" "$DISK_INPUT" "$CORES_INPUT" "$GCE_PROJECT_INPUT" "$GCE_REGION_INPUT" "$GCE_MACHINE_SIZE_INPUT" "$GCE_MACHINE_IMAGE_INPUT" "$GCE_DISK_SIZE_INPUT")"
		else
			echo " "
			echo "No changes done on the default VM attributes..."
			echo " "
		fi
		read -p "Do you agree with given resources for used by 3 hosts? [y/N]: " ANSWER
		if [ "yes" = "$CHANGES" ]; then
			if [ "y" = "$ANSWER" ] || [ "Y" = "$ANSWER" ]; then
				if [ "-hv" = "$ENGINE" ] || [ "-vb" = "$ENGINE" ]; then
					MEMORY="$MEM_INPUT"
					DISKSIZE="$DISK_INPUT"
					CORES="$CORES_INPUT"
				elif [ "-gce" = "$ENGINE" ]; then
					GOOGLE_PROJECT="$GCE_PROJECT_INPUT"
					GOOGLE_ZONE="$GCE_REGION_INPUT"
					GOOGLE_MACHINE_TYPE="$GCE_MACHINE_SIZE_INPUT"
					GOOGLE_MACHINE_IMAGE="$GCE_MACHINE_IMAGE_INPUT"
					GOOGLE_DISK_SIZE="$GCE_DISK_SIZE_INPUT"
				fi
			fi
		fi
	done
fi

MACHINE_RESOURCES=""

if [ "-hv" = "$1" ]; then
	MACHINE_RESOURCES="-d hyperv --hyperv-memory $MEMORY --hyperv-disk-size $DISKSIZE --hyperv-cpu-count $CORES --hyperv-disable-dynamic-memory --hyperv-boot2docker-url "
elif  [ "-vb" = "$1" ]; then
	MACHINE_RESOURCES="-d virtualbox --virtualbox-memory $MEMORY --virtualbox-disk-size $DISKSIZE --virtualbox-cpu-count $CORES --virtualbox-disable-dynamic-memory --virtualbox-boot2docker-url "
elif  [ "-gce" = "$1" ]; then
	if [ "" = "$GOOGLE_PROJECT" ]; then
		echo "Variable GOOGLE_PROJECT is mandatory for running the virtual machines ... EXIT!!"
		exit 1
	fi
	ISO_IMAGE=""
	MACHINE_RESOURCES="-d google"
	if [ "" != "$GOOGLE_ADDRESS" ]; then
		MACHINE_RESOURCES="$MACHINE_RESOURCES --google-address $GOOGLE_ADDRESS"
	fi
	if [ "" != "$GOOGLE_DISK_SIZE" ]; then
		MACHINE_RESOURCES="$MACHINE_RESOURCES --google-disk-size $GOOGLE_DISK_SIZE"
	fi
	if [ "" != "$GOOGLE_DISK_TYPE" ]; then
		MACHINE_RESOURCES="$MACHINE_RESOURCES --google-disk-type $GOOGLE_DISK_TYPE"
	fi
	if [ "" != "$GOOGLE_MACHINE_IMAGE" ]; then
		MACHINE_RESOURCES="$MACHINE_RESOURCES --google-machine-image $GOOGLE_MACHINE_IMAGE"
	fi
	if [ "" != "$GOOGLE_MACHINE_TYPE" ]; then
		MACHINE_RESOURCES="$MACHINE_RESOURCES --google-machine-type $GOOGLE_MACHINE_TYPE"
	fi
	if [ "" != "$GOOGLE_NETWORK" ]; then
		MACHINE_RESOURCES="$MACHINE_RESOURCES --google-network $GOOGLE_NETWORK"
	fi
	if [ "" != "$GOOGLE_OPEN_PORT" ]; then
		MACHINE_RESOURCES="$MACHINE_RESOURCES --google-open-port $GOOGLE_OPEN_PORT"
	fi
	if [ "" != "$GOOGLE_PREEMPTIBLE" ]; then
		MACHINE_RESOURCES="$MACHINE_RESOURCES --google-preemptible $GOOGLE_PREEMPTIBLE"
	fi
	if [ "" != "$GOOGLE_PROJECT" ]; then
		MACHINE_RESOURCES="$MACHINE_RESOURCES --google-project $GOOGLE_PROJECT"
	fi
	if [ "" != "$GOOGLE_SCOPES" ]; then
		MACHINE_RESOURCES="$MACHINE_RESOURCES --google-scopes $GOOGLE_SCOPES"
	fi
	if [ "" != "$GOOGLE_SERVICE_ACCOUNT" ]; then
		MACHINE_RESOURCES="$MACHINE_RESOURCES --google-service-account $GOOGLE_SERVICE_ACCOUNT"
	fi
	if [ "" != "$GOOGLE_SUBNETWORK" ]; then
		MACHINE_RESOURCES="$MACHINE_RESOURCES --google-subnetwork $GOOGLE_SUBNETWORK"
	fi
	if [ "" != "$GOOGLE_TAGS" ]; then
		MACHINE_RESOURCES="$MACHINE_RESOURCES --google-tags $GOOGLE_TAGS"
	fi
	if [ "" != "$GOOGLE_USE_EXISTING" ]; then
		MACHINE_RESOURCES="$MACHINE_RESOURCES --google-use-existing $GOOGLE_USE_EXISTING"
	fi
	if [ "" != "$GOOGLE_USE_INTERNAL_IP" ]; then
		MACHINE_RESOURCES="$MACHINE_RESOURCES --google-use-internal-ip $GOOGLE_USE_INTERNAL_IP"
	fi
	if [ "" != "$GOOGLE_USE_INTERNAL_IP_ONLY" ]; then
		MACHINE_RESOURCES="$MACHINE_RESOURCES --google-use-internal-ip-only $GOOGLE_USE_INTERNAL_IP_ONLY"
	fi
	if [ "" != "$GOOGLE_USERNAME" ]; then
		MACHINE_RESOURCES="$MACHINE_RESOURCES --google-username \"$GOOGLE_USERNAME\""
	fi
	if [ "" != "$GOOGLE_ZONE" ]; then
		MACHINE_RESOURCES="$MACHINE_RESOURCES --google-zone \"$GOOGLE_ZONE\""
	fi

	echo "GCE: $MACHINE_RESOURCES"
	exit 0
else
	echo "$(usage)"
	exit 1
fi

echo " "
echo "Number of workers: $RANCHER_NODES"
echo " "

echo "Creating MASTER Rancher node ..."
docker-machine create $MACHINE_RESOURCES $ISO_IMAGE ${PREFIX}rancher-node-master
if [ "-gce" = "$ENGINE" ]; then
	echo "MASTER Rancher node: installing docker on host ..."
	docker-machine.exe ssh ${PREFIX}-rancher-node-master "echo '$( cat $FOLDER/install-docker.sh )' > ./install-docker.sh && chmod 777 ./install-docker.sh && ./install-docker.sh"
fi
echo "MASTER Rancher node installing curl container ..."
docker-machine ssh ${PREFIX}-rancher-node-master "sudo sh -c \"echo \\\"docker run --rm curlimages/curl \$ @\\\" > /usr/bin/curl && chmod +x /usr/bin/curl && sed -i 's/$ @/\\\$@/g' /usr/bin/curl && curl --help \""
echo "MASTER Rancher node installing Rancher Server ..."
docker-machine ssh ${PREFIX}rancher-node-master "sudo mkdir /var/lib/cattle && sudo mkdir /var/lib/mysql && sudo mkdir /var/log/mysql"
docker-machine ssh ${PREFIX}rancher-node-master "sudo system-docker pull rancher/server"
docker-machine ssh ${PREFIX}rancher-node-master "sudo system-docker run -d --restart=always -v /var/lib/cattle:/var/lib/cattle -v /var/lib/mysql:/var/lib/mysql -v /var/log/mysql:/var/log/mysql -p 8080:8080 -p 8081:8081 -p 8088:8088 -p 9345:9345 -p 9000:9000 -p 3306:3306 -it --user root:root --privileged --name rancher-server rancher/server"
IP1="$(docker-machine ip ${PREFIX}rancher-node-master)"
echo "MASTER Rancher node Ip: $IP1"
while [ "" = "$(${CMD_PREFIX}curl -sL http://$IP1:8080/v1 2> /dev/null)" ]; do echo "Waiting for Rancher server to be active: http://$IP1:8080"; sleep 20; done
PROJECT_ID="$(${CMD_PREFIX}curl -sL http://$IP1:8080/v1/projects | ${CMD_PREFIX}jq -r '.data[0].id')"
echo "Waiting 60 seconds for giving the API engine time to read database data..."
sleep 60
IP_W=()
for (( i=1; i<=$RANCHER_NODES; i++ )); do
	echo "Creating SLAVE Rancher node #${i} ..."
	docker-machine create $MACHINE_RESOURCES $ISO_IMAGE "${PREFIX}rancher-worker-${i}"
	if [ "-gce" = "$ENGINE" ]; then
		echo "SLAVE Rancher node #${i}: installing docker on host ..."
		docker-machine.exe ssh "${PREFIX}rancher-worker-${i}" "echo '$( cat $FOLDER/install-docker.sh )' > ./install-docker.sh && chmod 777 ./install-docker.sh && ./install-docker.sh"
	fi
	echo "SLAVE Rancher node #${i} installing curl container ..."
	docker-machine ssh "${PREFIX}rancher-worker-${i}" "sudo sh -c \"echo \\\"docker run --rm curlimages/curl \$ @\\\" > /usr/bin/curl && chmod +x /usr/bin/curl && sed -i 's/$ @/\\\$@/g' /usr/bin/curl && curl --help \""
	docker-machine ssh "${PREFIX}rancher-worker-${i}" "sudo mkdir -p var/etcd/backups"
	IP_W[${i}]="$(docker-machine ip "${PREFIX}rancher-worker-${i}")"
	echo "SLAVE Rancher node #${i} Ip: $IP2"
	REG_TOKEN_REFERENCE="$(${CMD_PREFIX}curl -sL -X POST -H 'Accept: application/json' http://$IP1:8080/v1/registrationtokens?projectId=$PROJECT_ID 2> /dev/null|${CMD_PREFIX}/jq -r '.actions.activate' 2> /dev/null)"
	sleep 5
	COMMAND="$(${CMD_PREFIX}curl -s -X GET $REG_TOKEN_REFERENCE 2> /dev/null | ${CMD_PREFIX}jq -r '.command' 2> /dev/null)"
	#Place server lables for kubernetes
	COMMAND="$(echo $COMMAND|sed 's/ docker run / docker run  -e CATTLE_HOST_LABELS=\"etcd=true\&orchestration=true\" /g')"
	echo "SLAVE Rancher node #${i} Command: $COMMAND"
	if [ "" != "$COMMAND" ]; then
		docker-machine ssh "${PREFIX}rancher-worker-${i}" "$COMMAND"
	else
		echo "Please register your server ${PREFIX}rancher-worker-${i} manually on the web interface at: http://$IP1:8080 -> Host"
	fi
	sleep 30
done

echo "----------------------------------"
echo "Master: $IP1"
for (( i=1; i<=$RANCHER_NODES; i++ )); do
	IP_X="${IP_W[${i}]}"
	echo "Slave #${i} IP: $IP_X"
done
#echo "Slave: $IP2"
#echo "Slave: $IP3"
echo "Rancher Server Url: http://$IP1:8080"
echo "----------------------------------"
echo ""
echo "Provisinging Rancher Kubernetes cluster"
$FOLDER/provision-docker-machines-rancher.sh "$PROJECT_ID" "${PASS_PRFX}" "${PASS_PRFX}" "$3"
exit 0