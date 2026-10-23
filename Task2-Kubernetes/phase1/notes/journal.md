# Phase 1 Journal: Commands, What and Why

Task 1: Minikube (single-node local cluster), namespace `internship-rishi`.

## Setup and verification

| Command | What it does | Why I ran it 
|---|---|---|---|
| `git --version` / `docker --version` / `kubectl version --client` | Prints the installed tool versions | Confirm the required tools are installed 
| `minikube version` | Checks Minikube is installed | It was missing at first, so I installed it 
| `kubectl get nodes` (before Minikube) | Lists the nodes of the current cluster | Tested kubectl. It showed `desktop-control-plane`, which is Docker Desktop's cluster, not Minikube 
| `kubectl config get-contexts` / `kubectl config current-context` | Shows which cluster kubectl is talking to | kubectl runs against whichever context is active, so I must confirm it is `minikube` before every lab 

## Cluster start and investigation

| Command | What it does | Why I ran it 
|---|---|---|---|
| `minikube start --driver=docker --cpus=2 --memory=4096` | Creates and starts a local cluster inside a Docker container | Phase 1 needs a cluster. Resources are set now because changing them later requires recreating the cluster 
| `minikube status` | Shows the state of the Minikube components | Confirm the cluster is running 
| `kubectl get nodes -o wide` | Lists nodes with IP, OS and version | Confirm the node `minikube` is `Ready` 
| `kubectl describe node minikube` | Shows node capacity, conditions and recent events | See how much CPU/memory is available and whether the node is healthy 
| `kubectl get namespaces` | Lists namespaces | See the defaults: `default`, `kube-system`, `kube-public`, `kube-node-lease` 
| `kubectl get pods -A` | Lists pods in all namespaces (`-A`) | See everything running in the cluster 
| `kubectl get pods -n kube-system` | Lists pods in one namespace (`-n`) | See the control-plane components and system add-ons 
| `kubectl get events -A --sort-by=.metadata.creationTimestamp` | Shows cluster events in time order | Events are the timeline of what happened, and my main troubleshooting tool 
| `kubectl cluster-info` | Shows the API server and DNS addresses | Confirm where kubectl is connecting 

## Namespace

| Command | What it does | Why I ran it
|---|---|---|---|
| `kubectl create namespace internship-rishi` | Creates a separate folder to group and organize your app's components. | Keeps development work completely isolated from production so they do not crash or overwrite each other.
| `kubectl get pods -n internship-rishi` | Lists pods in my namespace | Confirm the namespace exists and is empty

## Concepts in my own words

- **Node:** one machine in the cluster. Minikube has one node that runs everything.
- **Control plane:** the decision-making part. It includes the API server (front door for kubectl), scheduler (picks the node for a pod), controller manager (makes reality match the desired state) and etcd (stores cluster state).
- **kubelet:** the agent on each node that starts the containers for assigned pods and reports their health.
- **Namespace:** a named partition for resources. Names are scoped per namespace, and quotas and access rules can be applied per namespace. It does not block network traffic by default.
- **kubectl:** the command-line client that sends requests to the API server using the details in the kubeconfig.
