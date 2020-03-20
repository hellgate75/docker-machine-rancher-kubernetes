#!/bin/sh

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

PREFIX="$1"

if [ "" != "$PREFIX" ]; then
	PREFIX="${PREFIX}-"
fi

for (( i=1; i<=$RANCHER_NODES; i++ )); do
	echo "Destroying SLAVE Rancher node #${i} ..."
	docker-machine rm -f "${PREFIX}rancher-worker-${i}"
done

echo "Destroying MASTER Rancher node ..."
docker-machine rm -f ${PREFIX}rancher-node-master
