# Phase 1 Journal: Commands, What and Why

##Task 1: Minikube (single-node local cluster), namespace `internship-rishi`.

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

## First deployment

### Study the app and test with Docker

| Command | What it does | Why I ran it |
|---|---|---|
| `git clone <simple-webapp-flask-url>` | Downloads the app's source code | Get the sample app to study and deploy |
| `rm -rf simple-webapp-flask/.git` | Removes the cloned repo's git history | Avoid a git repo nested inside my internship repo |
| `cat app.py` | Prints the app's code | Find the port (5000), the host binding and what the app returns |
| `docker build -t simple-webapp-flask:latest .` | Builds an image from the Dockerfile and names it | Package the app as an image |
| `docker run -d -p 5000:5000 --name flask-test simple-webapp-flask:latest` | Runs the image in the background and maps host port 5000 to container port 5000 | Test the app locally before using Kubernetes |
| `docker ps` | Lists running containers | Confirm the container is running |
| `curl -i http://localhost:5000` | Sends an HTTP request and shows the response headers and body | Prove the app answers over HTTP |
| `docker logs flask-test` | Shows the container's output | See what the app printed and check for errors |
| `docker stop flask-test && docker rm flask-test` | Stops and removes the container | Clean up so the port is free |

### Make the image available to Minikube

| Command | What it does | Why I ran it |
|---|---|---|
| `minikube image load simple-webapp-flask:latest` | Copies the image from my Docker into Minikube's own Docker | The cluster can't see images on my laptop's Docker, so it would fail with `ErrImagePull` |
| `minikube image ls \| grep simple-webapp-flask` | Lists images inside Minikube, filtered by name | Confirm the image is available in the cluster |

### Deployment

| Command | What it does | Why I ran it |
|---|---|---|
| `kubectl apply -f phase1/manifests/10-deployment.yaml` | Creates or updates the Deployment to match the YAML file | Deploy 2 replicas declaratively, as the task requires |
| `kubectl get deployments -n internship-rishi` | Lists Deployments and how many replicas are ready | Confirm 2/2 are ready |
| `kubectl get pods -n internship-rishi -o wide` | Lists pods with their node and IP address | Confirm 2 pods are Running and see their IPs |

### Service

| Command | What it does | Why I ran it |
|---|---|---|
| `kubectl apply -f phase1/manifests/20-service.yaml` | Creates or updates the Service from the YAML file | Give the pods a stable address and load balancing |
| `kubectl get svc -n internship-rishi` | Lists Services, their type and ports | Confirm the Service exists and see its port |
| `kubectl get endpoints -n internship-rishi` | Shows the pod IPs a Service sends traffic to | Confirm the Service selector matches my 2 pods |
| `minikube service flask-webapp-svc -n internship-rishi --url` | Prints a URL and opens a tunnel to the Service | Reach the app from my laptop's browser |
| `kubectl port-forward svc/flask-webapp-svc 8081:80 -n internship-rishi` | Forwards a local port to the Service | Alternative way to reach the app if the tunnel doesn't work |

### Investigation

| Command | What it does | Why I ran it |
|---|---|---|
| `kubectl describe pod <pod-name> -n internship-rishi` | Shows a pod's config, status, restarts and events | See what Kubernetes did with the pod and check the Events section |
| `kubectl logs <pod-name> -n internship-rishi` | Shows the application's output | See what the app itself did, such as request lines |
| `kubectl logs -f <pod-name> -n internship-rishi` | Streams logs live | Watch requests arrive while I refresh the browser |
| `kubectl get events -n internship-rishi --sort-by=.metadata.creationTimestamp` | Lists namespace events in time order | See the timeline: scheduled, pulled, created, started |

### What each investigation command reveals (my own words)

- **describe:** the pod's configuration and state, plus the Events at the bottom. It shows what Kubernetes did.
- **logs:** what the app printed. It shows what the app did.
- **events:** a timeline of Kubernetes actions across the namespace.

### Key concepts

- **Image vs container:** an image is the packaged app, and a container is a running copy of it.
- **Deployment:** keeps the desired number of pod copies running and replaces failed ones.
- **Service:** a stable address in front of pods, because pod IPs change. It finds pods using a label selector.
- **Port flow:** browser to Service `port: 80` to `targetPort: 5000` to the app's container port 5000.
