<p align="center">
<image width="145" height="170" src="images/docker-machine.png"></image>&nbsp;
<image width="250" height="170" src="images/icon_101_docker-v-kubernetes.png">
&nbsp;<image width="163" height="170" src="images/helm-logo.png"></image>
</p><br/>

# Rancher Kubernetes experience using docker-machine tool

Prcedure for creating local/remote Rancher Server with Kubernetes cluster provisioning via docker-machine.


## Goals

Main goal is to reproduce locally or on the cloud a Rancher orchestrated kubernetes cluster with the possibility to test locally 
any containers provisioning, having a full demo of the Rancher / Kubernetes combined architecture.


## Rancher Kubernetes Architecture

Kuberernetes and rancher combine architecture will be composed of following actors:

* etcd -  Nodes with the etcd role run etcd, which is a consistent and highly available key value store used as Kubernetes’ backing store for all cluster data. etcd replicates the data to each node. (Nodes with the etcd role are shown as Unschedulable in the UI, meaning no pods will be scheduled to these nodes by default)

* controlplane - Nodes with the controlplane role run the Kubernetes master components (excluding etcd, as it’s a separate role). See Kubernetes: Master Components for a detailed list of components (Nodes with the controlplane role are shown as Unschedulable in the UI, meaning no pods will be scheduled to these nodes by default).

* kube-apiserver - The Kubernetes API server (kube-apiserver) scales horizontally. Each node with the role controlplane will be added to the NGINX proxy on the nodes with components that need to access the Kubernetes API server. This means that if a node becomes unreachable, the local NGINX proxy on the node will forward the request to another Kubernetes API server in the list.

* kube-controller-manager - The Kubernetes controller manager uses leader election using an endpoint in Kubernetes. One instance of the kube-controller-manager will create an entry in the Kubernetes endpoints and updates that entry in a configured interval. Other instances will see an active leader and wait for that entry to expire (for example, when a node is unresponsive).

* kube-scheduler - The Kubernetes scheduler uses leader election using an endpoint in Kubernetes. One instance of the kube-scheduler will create an entry in the Kubernetes endpoints and updates that entry in a configured interval. Other instances will see an active leader and wait for that entry to expire (for example, when a node is unresponsive).

* worker - Nodes with the worker role run the Kubernetes node components. See Kubernetes: Node Components for a detailed list of components.

![rancher-kubernetes-architecture](/images/Rancher-2.0.png)

A whole picture overview architectural of Rancher-Kubernetes cluster is available [here](/images/clusterdiagram.png)



## Privided artifacts

Following scripts are provided for the experience:

* [create-docker-machine-rancher.sh](/create-docker-machine-rancher.sh) - Provides platform creation via docker-machine command (required)

* [destroy-docker-machine-rancher.sh](/destroy-docker-machine-rancher.sh) - Destroys required infrastructure

* [provision-docker-machines-rancher.sh](/provision-docker-machines-rancher.sh) - Provision a new Kubernetes cluster


### Create the infrastructure 

Privided infrastructure command [create-docker-machine-rancher.sh](/create-docker-machine-rancher.sh) has some input arguments:

* docker-machine engine (mandatory) - It describes the reuired docker-machine engine

* project machine prefix (optional but strongly suggested) - It describes the machine prefix and distinguish multiple infrastructures under docker-machine and Rancher Server

* force flag [-f] (optional) - It provides a mutual acceptance of entry parameters (strongly not reccommended for cluod platforms, in case of non experience)


Are available some environment variables:

* GOOGLE_APPLICATION_CREDENTIALS (mandatory in case of google cloud engine driver) - Describe location of the json GCE authentication keys file

* GOOGLE_CUSTOM_CONFIG_FILE (optional) - Describes only the name of a custom GCE environment file, clone of [gce-config.env](/gce-config.env)

* RANCHER_KUBERNETES_NODES (optional) - Numeric value of worker nodes siding the rancher server (default 2), it's strongly suggested to use a number grater than 2, because one node is the rancher-kubernetes stack orchestrator delegate and etcd manager one, and the other simple workers

Use script as follow:
```
workspace-dir> export RANCHER_KUBERNETES_NODES={n >= 2} && ./create-docker-machine-rancher.sh {-hv|-vb|-gce} {nodes_prefix} -f
```



### Provisioning the infrastructure with the Kubernetes cluster

Provisioning script [provision-docker-machines-rancher.sh](/provision-docker-machines-rancher.sh) is automatically invoked during the first cluster installation.

It has been tought available for users, due to a future implementation of Kubernetes clusters provisioning in rancher server, automated with anoter future script.

It takes following arguments:

* project id (mandatory) - It's the project id into the rancher server available list, list displayed running the script with an unexisting project id.

* project name (mandatory) - Single work project descriptor that will reflect on the Kubernees Cluster stack name 

* project machine prefix (optional but strongly suggested) - It describes the machine prefix and distinguish multiple infrastructures under docker-machine and Rancher Server

* force flag [-f] (optional) - It provides a mutual acceptance of entry parameters (strongly not reccommended for cluod platforms, in case of non experience)


Use script as follow:
```
workspace-dir> export RANCHER_KUBERNETES_NODES={n >= 2} && ./provision-docker-machines-rancher.sh {project id} {project name} {nodes_prefix} -f
```


### Destorying the infrastructure

The infrastructure can be easily and fully destoryed locally and remotely using the provided script: [destroy-docker-machine-rancher.sh](/destroy-docker-machine-rancher.sh)

It accepts following arguments:

* project machine prefix (optional but strongly suggested) - It describes the machine prefix and distinguish multiple infrastructures under docker-machine and Rancher Server



Use script as follow:
```
workspace-dir> export RANCHER_KUBERNETES_NODES={n >= 2} && ./destroy-docker-machine-rancher.sh {nodes_prefix}
```


## Provided docker-machine engines

Here list of provided docker-machine engines:

* Microsoft Hyper-V -> -hv

* Oracle Virtualbox -> -vb

* Google Cloud engine -> -gce


Enjoy your experience

## License

The library is licensed with [LGPL v. 3.0](/LICENSE) clauses, with prior authorization of author before any production or commercial use. Use of this library or any extension is prohibited due to high risk of damages due to improper use. No warranty is provided for improper or unauthorized use of this library or any implementation.

Any request can be prompted to the author [Fabrizio Torelli](https://www.linkedin.com/in/fabriziotorelli) at the follwoing email address:

[hellgate75@gmail.com](mailto:hellgate75@gmail.com)
