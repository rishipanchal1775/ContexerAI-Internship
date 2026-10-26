# Task 2: Hands-on Kubernetes (Phase 1)

**Name:** Rishi
**Track:** DevOps Engineering
**Phase covered:** Phase 1, Local Kubernetes and first service
**Repository path:** `ContexerAI-Internship/Task2-Kubernetes/`

## Table of contents
1. Overview
2. Machine and tools
3. Folder structure
4. Cluster setup and core concepts
5. First deployment
6. Failure and recovery practice
7. Stopping vs deleting a cluster
8. How I used Claude Code
9. Problems encountered
10. What I learned
11. How to reproduce this setup
12. Evidence links

---

## 1. Overview

In Phase 1 I set up a local Kubernetes cluster with Minikube and deployed a small Flask web app (`simple-webapp-flask`) using YAML manifests. I then investigated the running resources and tested how Kubernetes reacts to failures: deleting a pod, scaling, and stopping and restarting the cluster.

Everything was deployed declaratively with `kubectl apply -f`, and I used Claude Code to understand the app and review my YAML, verifying its suggestions myself.

**Key facts:**

| Item | Value |
|---|---|
| Cluster | Minikube (single node, Docker driver) |
| Namespace | `internship-rishi` |
| App | `simple-webapp-flask` (Flask) |
| Image | `simple-webapp-flask:latest` |
| App port | 5000 |
| Deployment | `flask-webapp` (2 replicas) |
| Service | `flask-webapp-svc` (NodePort, port 80 to targetPort 5000) |

---

## 2. Tools

| Tool | Check command |
|---|---|---|
| Git | `git --version` |
| Docker | `docker --version` |
| kubectl | `kubectl version --client` |
| Minikube | `minikube version` |
| Claude Code | `claude --version` |

---

## 3. Folder structure

```
ContexerAI-Internship/
├── Task1-Onboarding/
└── Task2-Kubernetes/
    ├── README.md
    ├── CLAUDE.md
    └── phase1/
        ├── simple-webapp-flask/        # the cloned app
        ├── manifests/
        │   ├── 00-namespace.yaml
        │   ├── 10-deployment.yaml
        │   └── 20-service.yaml
        ├── notes/
        │   ├── journal.md              # every command: what and why
        │   ├── ai-log.md               # every Claude Code use
        │   └── observations.md         # observations and failure notes
        └── screenshots/
```

---

## 4. Cluster setup and core concepts

### What I did
- Installed and verified Git, Docker, kubectl and Minikube.
- Started the cluster: `minikube start --driver=docker --cpus=2 --memory=4096`
- Confirmed I was talking to the right cluster: `kubectl config current-context` (must show `minikube`).
- Inspected the cluster: `kubectl get nodes -o wide`, `kubectl describe node minikube`, `kubectl get namespaces`, `kubectl get pods -A`, `kubectl get pods -n kube-system`, `kubectl get events -A`.
- Created the namespace from a YAML file: `kubectl apply -f phase1/manifests/00-namespace.yaml`

### Concepts in my own words

**Node:** one machine in the cluster. Minikube gives me a single node that runs everything.

**Control plane:** the decision-making part of the cluster. It includes the API server (the front door that kubectl talks to), the scheduler (decides which node runs a pod), the controller manager (keeps reality matching the desired state) and etcd (the database that stores cluster state). In Minikube these run as pods in the `kube-system` namespace.

**kubelet:** the agent on each node. It starts the containers for the pods assigned to its node, watches their health and reports back to the control plane.

**Namespace:** a named partition inside the cluster. Resource names only need to be unique within a namespace, and quotas and access rules can be applied per namespace. Deleting a namespace deletes everything in it.

**kubectl:** the command-line client. It sends requests to the API server using the connection details in the kubeconfig file.

### Resource isolation
A namespace separates resources by name, so two namespaces can both contain a Deployment called `web` without clashing. It also makes cleanup easy and lets quotas and permissions be set per namespace. It is organisational isolation, not a security wall: by default, pods in different namespaces can still talk to each other unless network policies block it.

### Investigation commands
- `kubectl describe node`: shows the node's capacity, conditions and allocated resources.
- `kubectl get pods -n kube-system`: shows the cluster's own components (etcd, kube-apiserver, kube-scheduler, kube-controller-manager, coredns, kube-proxy, storage-provisioner).
- `kubectl get events`: a timeline of what happened in the cluster, which is the main tool for troubleshooting.

---

## 5. First deployment

### 5.1 Studying the app
I cloned `simple-webapp-flask` and read `app.py` before deploying it. The app is a small Flask web app that listens on **port 5000**, [add: what it returns, which host it binds to, and its dependencies].

### 5.2 Build and run locally with Docker
```bash
docker build -t simple-webapp-flask:latest .
docker run -d -p 5000:5000 --name flask-test simple-webapp-flask:latest
curl -i http://localhost:5000
docker logs flask-test
docker stop flask-test && docker rm flask-test
```
I tested in plain Docker first, so that if something failed later I would know it was a Kubernetes problem and not an app problem.

### 5.3 Loading the image into Minikube
```bash
minikube image load simple-webapp-flask:latest
```
Minikube's node has its own Docker, separate from my laptop's Docker, so it cannot see images I built locally. Without this step the pod fails with `ErrImagePull`.

### 5.4 Deployment (`10-deployment.yaml`)
Applied with `kubectl apply -f phase1/manifests/10-deployment.yaml`.

| Field | Meaning |
|---|---|
| `kind: Deployment` | The manager that keeps the desired number of pods running and handles updates |
| `namespace: internship-rishi` | Places it in my namespace |
| `replicas: 2` | Desired state: two pods at all times |
| `selector.matchLabels` | How the Deployment recognises its pods |
| `template.metadata.labels` | Labels given to each pod. They must match the selector |
| `image: simple-webapp-flask:latest` | The image to run |
| `imagePullPolicy: IfNotPresent` | Use the local image and don't download it. With the `:latest` tag Kubernetes defaults to `Always`, which would fail because the image only exists locally |
| `containerPort: 5000` | The port the app listens on |

Result: [e.g., 2/2 pods Running]

### 5.5 Service (`20-service.yaml`)
Applied with `kubectl apply -f phase1/manifests/20-service.yaml`.

| Field | Meaning |
|---|---|
| `type: NodePort` | Also opens a port on the node so traffic can come from outside the cluster |
| `selector: app: flask-webapp` | The Service sends traffic to pods with this label |
| `port: 80` | The port the Service listens on inside the cluster |
| `targetPort: 5000` | The port on the pod where the app listens. It must match the app |
| `nodePort: 30080` | The port opened on the node |

Why a Service is needed: pods are temporary and their IPs change every time one is replaced, so the Service provides one stable address and load-balances across the pods.

I checked that the Service found my pods with `kubectl get endpoints -n internship-rishi`. It should list both pod IPs, and an empty list means the selector doesn't match the pod labels.

### 5.6 Accessing the app
```bash
minikube service flask-webapp-svc -n internship-rishi --url
```
This opens a tunnel and prints a URL for the browser. Alternative: `kubectl port-forward svc/flask-webapp-svc 8081:80 -n internship-rishi`

Result: [what the browser showed]

### 5.7 Investigating the pods

| Command | What it reveals |
|---|---|
| `kubectl describe pod <name> -n internship-rishi` | The pod's configuration and state (node, IP, image, restarts) and the Events at the bottom, which show what Kubernetes did |
| `kubectl logs <name> -n internship-rishi` | What the application itself printed, such as the Flask request lines |
| `kubectl get events -n internship-rishi` | A timeline of Kubernetes actions: scheduled, pulled, created, started |

Rule I use: `describe` and `events` tell me what Kubernetes did, and `logs` tells me what the app did.

---

## 6. Failure and recovery practice

### 6.1 Deleting a managed pod
```bash
kubectl get pods -n internship-rishi -w        # terminal A: live watch
kubectl delete pod <pod-name> -n internship-rishi   # terminal B
```
**What happened:** [e.g., the old pod went Terminating and a new pod was created within N seconds]
**What differed:** the new pod had [a different name and IP].
**Did the app stay available:** [yes/no, and how I checked]

**Why:** a Deployment owns a ReplicaSet, and the ReplicaSet keeps comparing the actual pod count with the desired count (2). When I deleted one pod, the actual count dropped to 1, so it created a replacement. This is self-healing. Because pod IPs change, I need the Service for a stable address.

### 6.2 Scaling: 2 to 4 to 1
I changed `replicas` in `10-deployment.yaml` and ran `kubectl apply -f` each time.

| Step | Result I observed |
|---|---|
| 2 to 4 | [new pods went Pending, ContainerCreating, Running; existing pods untouched] |
| 4 to 1 | [3 pods went Terminating; Kubernetes chose which] |

I also tried `kubectl scale deployment flask-webapp --replicas=3 -n internship-rishi` once to compare. It works instantly, but then my YAML file no longer matches the cluster (configuration drift), which I confirmed with `kubectl diff -f`. That is why I used the declarative way for the main demonstration. Afterwards I restored `replicas: 2` and applied it.

### 6.3 Stopping and restarting Minikube
```bash
minikube stop
minikube status
kubectl get nodes
minikube start
kubectl get pods -n internship-rishi -w
```
**While stopped:** `minikube status` showed Stopped, `kubectl get nodes` failed with [the error I saw], and the app was unreachable. The Minikube container showed as Exited in `docker ps -a`.

**After restart:** [the namespace, Deployment and Service were still there; pods came back after about N seconds; pod names were the same/different; RESTARTS showed N]. I had to restart the `minikube service` tunnel to reach the app again.

**Why it recovers:** my desired state (namespace, Deployment, Service) is stored in etcd inside the stopped Minikube container. Stopping keeps that data, so when the cluster starts, the controllers read it and make sure the pods are running again.

---

## 7. Stopping vs deleting a cluster

| | `minikube stop` | `minikube delete` |
|---|---|---|
| What happens | Shuts the cluster down. The Minikube container stays (Exited) | Removes the cluster and its container completely |
| Deployments, Services, namespaces | Kept in etcd | Gone |
| Images loaded into Minikube | Kept | Gone, must be loaded again |
| Running apps | Unavailable until restart | Gone |
| Use it when | Finished for the day | I want a clean start or the cluster is broken |

An analogy I use: stop is like shutting down a laptop, and delete is like wiping it. I did not run `minikube delete` during this phase, so I wouldn't lose my setup.

---

## 8. How I used Claude Code

Claude Code was used for two substantial tasks in Phase 1, plus supporting questions. The full log, with prompts and verification, is in `phase1/notes/ai-log.md`.

| Where | Prompt (short) | How I verified |
|---|---|---|
| Understand the app | "Explain how this app runs: dependencies, port and host, what it returns" | [read `app.py` myself, ran it in Docker and curled it] |
| Review the Deployment YAML | "Review this Deployment manifest for mistakes against the app's port and image" | [Kubernetes docs, `kubectl apply`, `kubectl describe`] |
| Concepts and predictions | [control plane vs node vs kubelet; what happens when I delete a pod] | [compared with docs and my own output] |

**An accepted suggestion:** [Describe one. What Claude suggested, why I accepted it, and how I checked it worked.]

**A suggestion I corrected or rejected:** [Describe one. What Claude suggested, what was wrong or unsuitable, and what I did instead. Example types: a wrong port, replacing `IfNotPresent` or using `kubectl scale` instead of editing the YAML.]

**Safety:** I never shared my kubeconfig, tokens or keys with Claude Code. I only pasted non-sensitive command output and read every command before approving it.

---

## 9. Problems encountered

| Problem | Cause | Fix |
|---|---|---|
| `minikube: command not found` | Minikube was not installed | Installed it from the official release and verified with `minikube version` |
| `kubectl get nodes` showed `desktop-control-plane` | kubectl was pointing at Docker Desktop's built-in Kubernetes, not Minikube | Checked `kubectl config current-context`, started Minikube (which switches the context) and verified the node is called `minikube` |
| [Image pull error, if you had one] | [Image not loaded into Minikube, or the pull policy] | [`minikube image load` and `imagePullPolicy: IfNotPresent`] |
| [Browser could not reach the app, if it happened] | [WSL and the Docker driver, so the node IP is not directly reachable] | [Used `minikube service --url` or `port-forward`] |
| [Add your own] | | |

---

## 10. What I learned

- **Desired state:** I describe what I want in YAML and Kubernetes keeps working to make reality match it. Almost every behaviour I saw follows from this.
- **Layers:** Deployment, then ReplicaSet, then Pods. The ReplicaSet is what replaces deleted pods.
- **Pods are disposable:** names and IPs change, so I use Services for stable access.
- **Labels and selectors connect things:** the Deployment finds its pods and the Service finds its endpoints through labels. A mismatch gives empty endpoints.
- **Declarative beats imperative:** editing YAML and applying keeps files as the source of truth, while direct commands cause drift.
- **Troubleshooting order:** `get` for the overall state, `describe` and `events` for what Kubernetes did, and `logs` for what the app did.
- **The cluster state survives a stop:** because it is stored in etcd.
- **Local images need loading:** Minikube has its own Docker, and the `:latest` tag changes the default pull policy.
- **Check the context first:** `kubectl config current-context` prevents running commands against the wrong cluster.
- **AI is helpful but must be verified:** I confirmed its output with kubectl, running the app and the docs.

---

## 11. How to reproduce this setup

```bash
# 1. Start the cluster
minikube start --driver=docker --cpus=2 --memory=4096
kubectl config current-context        # must show: minikube

# 2. Create the namespace
kubectl apply -f phase1/manifests/00-namespace.yaml

# 3. Build the image and load it into Minikube
cd phase1/simple-webapp-flask
docker build -t simple-webapp-flask:latest .
minikube image load simple-webapp-flask:latest
cd ../..

# 4. Deploy
kubectl apply -f phase1/manifests/10-deployment.yaml
kubectl apply -f phase1/manifests/20-service.yaml

# 5. Verify
kubectl get pods,svc,endpoints -n internship-rishi

# 6. Open the app (keep this terminal open)
minikube service flask-webapp-svc -n internship-rishi --url
```

---

## 12. Evidence

- Screenshots: `phase1/screenshots/` 
- Narrated video (deployment, pod deletion, scaling, restart)
- Manifests: `phase1/manifests/` 
- Journal: `phase1/notes/journal.md` [link]

*No credentials, tokens or kubeconfig contents are included in this repository, the screenshots or the video.*
