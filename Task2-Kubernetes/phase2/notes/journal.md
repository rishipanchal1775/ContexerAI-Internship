# Phase 2 Journal: Commands, What and Why

Task 2: Kubernetes Phase 2 — Real multi-service application. Namespace: `voting-app-rishi`. Application: example voting app with Vote, Redis, Worker, PostgreSQL (`db`) and Result.

## Architecture and deployment

### Docker images and application architecture

| Command | What it does | Why I ran it |
|---|---|---|
| `docker images` | Lists the images available locally, including tags and image IDs. | I used it to check which application images I had built. |
| `docker images \| grep -E "^voting-"` | Filters the image list to my voting application images. | I used it to check that Vote, Worker and Result each had their own image tag. |
| `docker build -t voting-vote:v1 ./vote` | Builds the Vote image and gives it the `voting-vote:v1` tag. | I used it to package the Vote service separately. |
| `docker build -t voting-worker:v1 ./worker` | Builds the Worker image. | I used it because Worker is a separate component with its own code and role. |
| `docker build -t voting-result:v1 ./result` | Builds the Result image. | I used it to build the service that displays the vote totals. |
| `docker compose up --build` | Builds and starts the services defined in the Compose file. | I used Compose to understand how the services work together before deploying them to Kubernetes. |
| `docker compose ps` | Shows the Compose services and their status. | I used it to check whether the containers were running. |
| `docker compose down` | Stops and removes the Compose containers and network created for the project. | I used it when I needed to stop the local Compose application and avoid port conflicts. |

I learned that I must not reuse the same image tag for different services. I accidentally reused `voting-vote:v1` while building another component, and the tag ended up pointing to the last image built. I checked the image IDs and rebuilt Vote, Worker and Result with separate tags.

### Check Kubernetes and the namespace

| Command | What it does | Why I ran it |
|---|---|---|
| `kubectl config current-context` | Shows which Kubernetes context `kubectl` is using. | I used it to confirm I was working with the correct cluster before applying manifests. |
| `kubectl get nodes` | Lists the cluster nodes and their status. | I used it to check that the Minikube node was available. |
| `kubectl get namespaces` | Lists the namespaces in the cluster. | I used it to check the namespace where I wanted to deploy the application. |
| `kubectl create namespace voting-app-rishi` | Creates the application namespace. | I used it to keep the voting application resources grouped together. |
| `kubectl get pods -A` | Lists Pods across all namespaces. | I used it to get a wider view of what was running in the cluster. |
| `kubectl get pods -n voting-app-rishi` | Lists Pods in my application namespace. | I used it to check the status of the voting application components. |

### Build and load images for Minikube

| Command | What it does | Why I ran it |
|---|---|---|
| `minikube image ls` | Lists images available to the Minikube environment. | I used it to check whether my local images were available inside the cluster. |
| `minikube image load voting-vote:v1` | Loads the Vote image into Minikube. | I used it so Kubernetes could start Vote without pulling my local image from a remote registry. |
| `minikube image load voting-worker:v1` | Loads the Worker image into Minikube. | I used it to make the Worker image available to the cluster. |
| `minikube image load voting-result:v1` | Loads the Result image into Minikube. | I used it to make the Result image available to the cluster. |
| `minikube image ls \| grep voting-` | Filters the Minikube image list. | I used it to verify that the images I needed were available. |

### Apply and inspect Kubernetes manifests

| Command | What it does | Why I ran it |
|---|---|---|
| `kubectl apply -f manifests/` | Creates or updates resources defined in the YAML files. | I used it to deploy the application declaratively rather than relying only on imperative commands. |
| `kubectl get pods,services,endpoints -n voting-app-rishi` | Lists Pods, Services and their endpoints. | I used it to check whether the application components were running and whether Services had Pods behind them. |
| `kubectl get svc -n voting-app-rishi` | Lists Services and their types and ports. | I used it to check which services were exposed and which were internal. |
| `kubectl get endpoints -n voting-app-rishi` | Shows the Pod addresses selected by each Service. | I used it to investigate whether a Service was connected to ready Pods. |
| `kubectl describe svc vote -n voting-app-rishi` | Shows details about the Vote Service, including selectors, ports and events. | I used it to investigate service routing and connectivity. |
| `kubectl get configmap,secret,pvc,pv -n voting-app-rishi` | Lists configuration objects and persistent storage resources. | I used it to check whether the supporting resources existed. |
| `kubectl describe pvc db-pvc -n voting-app-rishi` | Shows the status and storage details of the database claim. | I used it to check whether PostgreSQL had a persistent volume claim. |

### Access Vote and Result

| Command | What it does | Why I ran it |
|---|---|---|
| `minikube service vote -n voting-app-rishi --url` | Gets a URL for accessing the Vote Service. | I used it to open the voting page from my laptop. |
| `minikube service result -n voting-app-rishi --url` | Gets a URL for accessing the Result Service. | I used it to open the page that displays vote totals. |
| `kubectl port-forward svc/vote 8090:80 -n voting-app-rishi` | Forwards local port `8090` to port `80` on the Vote Service. | I used it as another way to access Vote when the original local port was unavailable. |
| `kubectl port-forward svc/result 8091:80 -n voting-app-rishi` | Forwards local port `8091` to port `80` on the Result Service. | I used it to access Result from a separate terminal. |
| `ss -tulpn \| grep 8080` | Checks which process is listening on local port `8080`. | I used it to investigate why port forwarding could not bind to that port. |
| `docker ps` | Lists running Docker containers. | I used it to check whether an old container was already using a port. |
| `ps aux \| grep -E "port-forward|minikube" \| grep -v grep` | Searches running processes for port-forwarding or Minikube commands. | I used it to look for an old process that might have been holding the port. |

The port-forward format is `LOCAL_PORT:SERVICE_PORT`. When local port `8080` was already in use, I could change the local side to `8090` and keep the Service port as `80`.

### What each investigation command reveals

- `docker images` helps me catch a missing image or an image tag that points to the wrong build.
- `minikube image ls` helps me check whether Minikube can access my locally built images.
- `kubectl config current-context` prevents me from accidentally working against the wrong cluster.
- `kubectl get pods` gives me the current Pod status, readiness and restart count.
- `kubectl get svc` shows the stable network endpoints and ports Kubernetes has created.
- `kubectl get endpoints` helps me see whether the Service has matching ready Pods. Empty endpoints can mean the selector does not match the Pod labels or the Pods are not ready.
- `kubectl describe svc` gives more detail about the selector, ports and recent events when service connectivity is not working.
- `kubectl logs -f deploy/worker -n voting-app-rishi` streams Worker logs so I can check whether votes are being processed.
- `kubectl get configmap,secret,pvc,pv` helps me check whether configuration and storage resources exist.
- `ss -tulpn` and `docker ps` help me investigate local port conflicts instead of assuming Kubernetes is broken.

### Key concepts

- **Multi-service application:** The application has separate services with different jobs. Vote accepts a choice, Redis holds the vote data for processing, Worker processes votes, PostgreSQL stores the results, and Result displays the totals.
- **Docker image and container:** An image packages the application; a container is a running instance of that image.
- **Image tags:** Each service needs the correct image name and tag. Reusing a tag can make it point to the wrong image.
- **Docker Compose:** Compose lets me run multiple related containers together and understand their connections before moving to Kubernetes.
- **Kubernetes Deployment:** A Deployment describes the desired number of replicas and manages the Pods for an application component.
- **Kubernetes Service:** A Service gives a stable address to a group of Pods. Services can keep working even when individual Pod IP addresses change.
- **ClusterIP and NodePort:** ClusterIP is intended for communication inside the cluster. NodePort exposes a service through a port on the cluster node. In this app, Vote and Result need laptop access, while Redis and PostgreSQL should normally stay internal.
- **Namespace:** `voting-app-rishi` groups the resources for this application and separates them from resources in other namespaces.
- **ConfigMap and Secret:** ConfigMaps hold non-sensitive configuration, while Secrets are intended for sensitive values. I should not put real passwords or tokens in my journal.
- **PersistentVolume and PersistentVolumeClaim:** A PVC requests storage and a PV represents the storage supplied to it. PostgreSQL needs persistent storage so its data is not tied only to the lifetime of a Pod.
- **Service discovery:** Services provide stable names for components to communicate with each other inside the cluster.
- **End-to-end testing:** A page loading successfully does not prove the full application works. I need to submit a vote and check that it appears on Result.

## Operations and incidents

### Check Pod status, logs and events

| Command | What it does | Why I ran it |
|---|---|---|
| `kubectl get pods -n voting-app-rishi -w` | Continuously watches Pod status changes. | I used it to observe what happened during deployments and troubleshooting experiments. |
| `kubectl describe pod <pod-name> -n voting-app-rishi` | Shows details about a Pod, its containers, conditions and events. | I used it to investigate why a Pod was not starting or becoming ready. |
| `kubectl logs <pod-name> -n voting-app-rishi` | Displays the container's application logs. | I used it to look for startup errors or application failures. |
| `kubectl logs -f deploy/worker -n voting-app-rishi` | Streams the Worker logs. | I used it to follow vote processing while testing the application. |
| `kubectl logs <pod-name> -n voting-app-rishi --previous` | Shows logs from a previous container instance when available. | I used it to investigate errors that happened before a container restarted. |
| `kubectl get events -n voting-app-rishi --sort-by=.metadata.creationTimestamp` | Lists namespace events in time order. | I used it to look for scheduling, image-pull, probe and rollout problems. |
| `kubectl get deployments -n voting-app-rishi` | Shows Deployment replica and availability status. | I used it to check whether Kubernetes had reached the desired number of replicas. |

### Resource usage and scaling

| Command | What it does | Why I ran it |
|---|---|---|
| `minikube addons enable metrics-server` | Enables Metrics Server in Minikube. | I used it to make resource usage metrics available. |
| `kubectl top pods -n voting-app-rishi` | Shows current CPU and memory usage for Pods. | I used it to inspect the resources the application was using. |
| `kubectl top nodes` | Shows CPU and memory usage for nodes. | I used it to inspect resource usage at the node level. |
| `kubectl scale deployment/vote --replicas=3 -n voting-app-rishi` | Changes the desired number of Vote replicas to three. | I used it to learn how scaling a Deployment works. |
| `kubectl rollout status deployment/vote -n voting-app-rishi` | Shows whether the Deployment rollout has completed. | I used it to verify that the requested replicas became available. |

### Failure and recovery experiments

| Command | What it does | Why I ran it |
|---|---|---|
| `kubectl delete pod <pod-name> -n voting-app-rishi` | Deletes the selected Pod. | I used or planned to use it as a controlled test of Kubernetes self-healing. If a Deployment manages the Pod, Kubernetes should create a replacement. |
| `kubectl get pods -n voting-app-rishi -w` | Watches Pods while the deleted Pod is replaced. | I used it to observe the recovery rather than assuming it happened. |
| `kubectl apply -f experiments/invalid-image.yaml` | Applies a temporary manifest with an invalid image for testing. | I planned this experiment to learn how an image-pull failure appears. I should run it only with a separate test manifest. |
| `kubectl describe pod <pod-name> -n voting-app-rishi` | Shows the reason a Pod is failing to start, including image-pull and probe events. | I used it to identify the cause rather than guessing from the status alone. |
| `kubectl rollout history deployment/vote -n voting-app-rishi` | Lists the available rollout revisions. | I used it to inspect Deployment history before rollback. |
| `kubectl set image deployment/vote vote=voting-vote:v2 -n voting-app-rishi` | Updates the image used by the Vote container. | I used or planned to use it to understand how an application version is updated. I must confirm the container name and image tag in my manifest first. |
| `kubectl rollout undo deployment/vote -n voting-app-rishi` | Rolls back the Deployment to a previous revision. | I used or planned to use it to practise recovery from a bad update. |
| `kubectl get pvc,pv -n voting-app-rishi` | Lists persistent storage claims and volumes. | I used it to check whether the database storage remains after workload cleanup. |

### PostgreSQL persistence and cleanup

| Command | What it does | Why I ran it |
|---|---|---|
| `kubectl get pvc -n voting-app-rishi` | Lists the namespace's PersistentVolumeClaims. | I used it to check the database claim before and after a restart or cleanup. |
| `kubectl exec -n voting-app-rishi deploy/db -- psql -U postgres -c "SELECT vote, COUNT(*) FROM votes GROUP BY vote;"` | Runs a SQL query inside PostgreSQL to count votes by choice. | I used or planned to use it to compare the vote counts before and after restarting the database Pod. I need to verify the actual database schema and credentials first. |
| `kubectl delete pod <db-pod-name> -n voting-app-rishi` | Deletes the database Pod. | I used or planned to use it to test whether PostgreSQL can restart and reuse its persistent storage. |
| `kubectl get all,configmap,secret,pvc,pv -n voting-app-rishi` | Lists application resources and supporting configuration/storage objects. | I used it to take a snapshot before cleanup and check what remained afterwards. |
| `kubectl delete deployment db -n voting-app-rishi` | Deletes the database Deployment without deleting the PVC by itself. | I used this approach when I wanted to inspect leftover storage separately from the workload. |
| `kubectl delete service db -n voting-app-rishi` | Deletes the database Service. | I used it to remove the database network endpoint as part of cleanup. |
| `kubectl delete pvc db-pvc -n voting-app-rishi` | Deletes the database storage claim. | I planned to use it only after recording evidence, because deleting the claim can affect the stored data depending on the storage reclaim policy. |

### What each investigation command reveals

- `kubectl get pods -w` shows the sequence of Pod states, including whether a replacement starts after a Pod is deleted.
- `kubectl describe pod` shows detailed state and events, which help explain `ImagePullBackOff`, failed probes or scheduling issues.
- `kubectl logs` shows application-level errors. Kubernetes events and application logs provide different kinds of evidence, so I should check both.
- `kubectl get events` shows recent Kubernetes warnings and lifecycle events in order.
- `kubectl top pods` and `kubectl top nodes` show current resource usage, provided Metrics Server is working.
- `kubectl get deployments` and `kubectl rollout status` show whether the desired replicas are available and whether an update has finished.
- `kubectl rollout history` helps me understand which Deployment revisions are available for rollback.
- Comparing SQL vote counts before and after a PostgreSQL Pod restart helps me check whether the data survived.
- Comparing `kubectl get pvc,pv` before and after deleting workloads helps me understand that storage objects have a lifecycle separate from Pods and Deployments.

### Key concepts

- **Readiness probe:** Checks whether a container is ready to receive traffic. If it fails, the Pod is removed from ready Service endpoints but is not automatically restarted just because readiness failed.
- **Liveness probe:** Checks whether a container is stuck or unhealthy. Repeated liveness failures can cause the kubelet to restart it.
- **Resource requests and limits:** Requests help Kubernetes schedule Pods; limits restrict the resources a container can use. I should choose values based on the application and verify them instead of copying them blindly.
- **Scaling:** A Deployment can run more replicas of a stateless service such as Vote. I need to check the new Pods become ready and that the application still works.
- **Self-healing:** Kubernetes controllers try to match the desired state. When a Deployment-managed Pod is deleted, the controller normally creates a replacement.
- **Image-pull failure:** A wrong image name or tag can cause `ErrImagePull` or `ImagePullBackOff`. Pod details and events help me confirm the reason.
- **Rollout and rollback:** A rollout changes the application version. Rollback returns the Deployment to a previous revision, but I need to check the result and test the application afterwards.
- **Persistent storage:** Pods can be replaced, but PostgreSQL data should remain on persistent storage. I need to compare real vote counts before and after a restart to verify this.
- **Storage lifecycle:** Deleting a Deployment does not automatically mean the PVC is deleted. I should inspect PVCs and PVs separately and be careful with destructive cleanup.
- **Incident investigation:** My process is to check the current state, read events and logs, identify a likely cause, make one controlled change, and verify recovery.
- **Evidence:** I should only mark an exercise as completed after I have run it and checked the output. For experiments that I only planned or discussed, I should keep them labelled as planned until I have verified them.
