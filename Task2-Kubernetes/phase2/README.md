# Task 2: Hands-on Kubernetes (Phase 2)

**Track:** DevOps Engineering  
**Phase covered:** Phase 2 — Real multi-service application  
**Application:** [Docker Example Voting App](https://github.com/dockersamples/example-voting-app)  
**Namespace:** `voting-app-rishi`

## Table of contents
1. Overview
2. Application architecture and data flow
3. Components and key concepts
4. Architecture and deployment
5. Configuration, networking and storage
6. Operations and incidents
7. Troubleshooting commands
8. What I learned
9. Reproduce and verify the deployment
10. Cleanup and storage considerations

---

## 1. Overview

In Phase 2, I worked with a real multi-service application instead of a single web app. The Docker Example Voting App has two user-facing web applications and three supporting services. Vote accepts votes, Redis temporarily holds them, the Worker transfers them to PostgreSQL, and Result reads the stored totals and displays them.

I ran the application with Docker Compose to understand how the services work together, then wrote Kubernetes manifests independently and deployed the components into the `voting-app-rishi` namespace. I also worked through configuration, internal service discovery, persistent storage, health probes, resource settings, scaling and failure-recovery exercises.

### Phase checklist

#### Architecture and deployment

- [x] Clone the app, run it using Docker Compose, and diagram request/data flow.
- [x] Identify public versus internal services and explain service-to-service DNS.
- [x] Independently write Kubernetes manifests rather than simply deploying bundled examples.
- [x] Create the `voting-app-rishi` namespace and deploy all five components.
- [x] Create Services and make Vote and Result accessible from the laptop.
- [x] Use ConfigMaps for non-secret configuration and a Secret for demo credentials only.
- [x] Configure a PersistentVolumeClaim for PostgreSQL and verify vote-to-result flow.

#### Operations and incidents

- [x] Add readiness and suitable liveness probes; explain the difference.
- [x] Set CPU/memory requests and limits and scale suitable stateless components.
- [x] Simulate and investigate a deleted Pod and an invalid image.
- [x] Simulate failed probes and document symptoms in events/logs.
- [x] Restart PostgreSQL and verify whether previous voting data persists.
- [x] Perform an app update, induce a failed rollout and roll back to a working version.
- [x] Clean up deployments and identify which storage remains.

---

## 2. Application architecture and data flow

![Phase 2 voting application architecture](architecturediagram.png)

*Architecture diagram: Vote and Result are the user-facing applications. Vote sends new votes to Redis. The Worker reads from Redis and writes the processed votes to PostgreSQL (`db`). Result queries PostgreSQL to display the totals. The Worker is a background service, not a page that users visit directly.*

### Vote-to-result flow

1. A user opens the **Vote** web application and submits a choice.
2. **Vote (Python)** accepts the request and places the vote in **Redis**.
3. **Redis** temporarily holds the vote data until the Worker processes it.
4. **Worker (.NET)** reads votes from Redis, processes them and writes the results to **PostgreSQL**.
5. **PostgreSQL (`db`)** stores the processed voting data.
6. **Result (Node.js)** queries PostgreSQL and displays the current totals to the user.

The flow is asynchronous between Vote and Result. A submitted vote may take a short time to appear on the result page because the Worker must process it first.

### Public versus internal services

| Component | Purpose | Access pattern |
|---|---|---|
| Vote | Web page for submitting a vote | Exposed to the laptop through its Kubernetes Service, port-forward or another configured access method |
| Result | Web page for viewing totals | Exposed to the laptop through its Kubernetes Service, port-forward or another configured access method |
| Redis | Temporary queue/data store for incoming votes | Internal; Vote and Worker connect to it using Kubernetes Service DNS |
| Worker | Moves votes from Redis into PostgreSQL | Internal background process; it does not need a public web endpoint |
| PostgreSQL (`db`) | Persistent database for processed votes | Internal; Worker and Result connect to it using Kubernetes Service DNS |

A Service is not automatically public just because it exists. Exposure depends on its type and how it is accessed. In this setup, Vote and Result are the entry points; Redis and PostgreSQL should normally remain internal.

---

## 3. Components and key concepts

### The five application components

- **Vote (Python):** receives a user's choice and sends it to Redis. It is a frontend/API component and should be reachable by the user.
- **Redis:** a fast in-memory data store used here as a queue between Vote and Worker. It helps separate the request-handling part from background processing. Redis is not a replacement for the persistent PostgreSQL database in this architecture.
- **Worker (.NET):** a background consumer. It reads queued votes from Redis and writes the processed data to PostgreSQL. It does not need to serve a browser page.
- **PostgreSQL (`db`):** the relational database where processed voting data is stored. The PersistentVolumeClaim is used to keep database files on persistent storage rather than relying only on the container's writable layer.
- **Result (Node.js):** reads the totals from PostgreSQL and renders the results page.

### Containers, Pods and images

A **container image** is the packaged application and its dependencies. A **container** is a running instance of an image. Kubernetes normally runs application containers inside **Pods**, which are the smallest deployable units in Kubernetes. A Pod can be recreated, so I should not treat its name, IP address or writable container layer as permanent storage.

### Deployments and self-healing

A **Deployment** declares how a stateless application should run, including its image and replica count. Kubernetes creates and manages ReplicaSets and Pods to reach the desired state. If a managed Pod is deleted, Kubernetes normally creates a replacement. Scaling a suitable stateless component changes the number of replicas; it does not automatically make a single database safe to scale horizontally.

### Services and labels/selectors

A **Service** provides a stable name and virtual IP for a set of Pods. Its selector matches Pod labels, and Kubernetes routes traffic to the matching endpoints. This avoids clients depending on temporary Pod IP addresses. If a Service has no endpoints, I check that its selector and the Pod labels match and that the Pods are ready.

### Kubernetes DNS and service-to-service communication

Within the cluster, workloads can usually connect to a Service by its Service name. For example, a component can use a host such as `redis` or `db` when those are the actual Service names in the same namespace. A fully qualified Service DNS name follows the pattern:

```text
<service-name>.<namespace>.svc.cluster.local
```

For example, the database Service in this namespace would be addressed as `db.voting-app-rishi.svc.cluster.local` if the Service is named `db`. Same-namespace clients can usually use the short name `db`. These names resolve through Kubernetes cluster DNS; they are not public internet DNS records.

### ConfigMaps and Secrets

- A **ConfigMap** holds non-sensitive configuration, such as application settings or service hostnames. It keeps configuration separate from the container image.
- A **Secret** is intended for sensitive values, such as demo database credentials. A Kubernetes Secret is not automatically a complete security solution: access permissions, cluster configuration and safe handling still matter. I use demo credentials only and do not commit real credentials to the repository.

### PersistentVolume and PersistentVolumeClaim

A **PersistentVolume (PV)** represents storage available to the cluster. A **PersistentVolumeClaim (PVC)** is a request for storage made by an application. PostgreSQL uses the PVC so its database files can outlive a Pod replacement or database container restart, depending on the storage provisioner and the lifecycle of the claim and volume. Deleting a Pod is not the same as deleting its PVC.

### Readiness and liveness probes

- **Readiness probe:** asks whether the container is ready to receive traffic. If readiness fails, Kubernetes marks the Pod not ready and normally removes it from Service endpoints. It does not, by itself, restart the container.
- **Liveness probe:** asks whether the container is still functioning. Repeated liveness failures cause Kubernetes to restart the container.

Probe settings must suit the application. A probe that checks too early or uses the wrong path/port can mark a healthy app as unhealthy or repeatedly restart it.

### CPU/memory requests and limits

- **Requests** tell the scheduler how much CPU and memory to reserve when placing a Pod.
- **Limits** cap resource use. A container that exceeds its memory limit can be terminated with an out-of-memory condition; CPU limit pressure usually throttles CPU rather than killing the container.

I set requests and limits based on the workload and observe actual usage before deciding whether to change them.

### Rolling updates and rollbacks

A Deployment update replaces old Pods with new ones according to its rollout strategy. A bad image or broken configuration can prevent the new version from becoming ready. I inspect rollout status, Pod details, events and logs, then use the Deployment rollout history and undo commands to return to a working revision when appropriate.

---

## 4. Architecture and deployment

### Docker Compose first

I used Docker Compose first to understand the app outside Kubernetes. Compose starts the services together and provides service-name networking, which makes it easier to confirm the application components and their dependencies before debugging Kubernetes.

Typical commands (run from the example app directory):

```bash
docker compose up -d
docker compose ps
docker compose logs
docker compose down
```

### Kubernetes namespace and context

I used a dedicated namespace to group the Phase 2 resources and avoid mixing them with other exercises.

```bash
kubectl config current-context
kubectl create namespace voting-app-rishi
kubectl get all -n voting-app-rishi
```

If the namespace already exists, `kubectl create namespace` can report that it already exists; I verify the current state rather than assuming the command must be repeated.

### Independently authored manifests

I wrote manifests for the namespace, Deployments, Services, ConfigMap, demo Secret and PostgreSQL storage. I applied them declaratively so the YAML remains the record of the intended configuration.

```bash
kubectl apply -f <manifest-directory>/
kubectl get deployments,pods,services -n voting-app-rishi
kubectl get endpoints -n voting-app-rishi
kubectl describe deployment <deployment-name> -n voting-app-rishi
```

The actual directory and filenames should match the repository. Before applying a manifest, I check its image name, namespace, labels/selectors, container ports, configuration references, probes and storage settings.

### Making Vote and Result accessible

I exposed only the two web applications for local use. Depending on the Service type and local cluster setup, I can use `minikube service` or port forwarding. Port-forwarding examples (replace the Service names if my manifests use different names):

```bash
kubectl port-forward svc/vote 8080:80 -n voting-app-rishi
kubectl port-forward svc/result 8081:80 -n voting-app-rishi
```

I keep each port-forward process running while using its local URL. If a local port is already occupied, I choose a different local port. The Service port on the right side of the mapping must match the actual Service port.

---

## 5. Configuration, networking and storage

### Configuration checklist

- ConfigMap values are for non-secret settings, such as service names or application configuration.
- Demo credentials are stored in a Secret and referenced by the relevant workload rather than written directly into source code.
- The application components use Service names for internal communication instead of hard-coded Pod IPs.
- Redis and PostgreSQL remain internal services unless there is a specific reason to expose them.

### Verifying vote-to-result flow

I verify the complete path, not just whether the two web pages open:

1. Confirm the Vote, Redis, Worker, database and Result Pods are ready.
2. Submit a vote using the Vote page.
3. Inspect Worker logs for processing activity and errors.
4. Check the Result page for the updated total; allow for asynchronous processing.
5. If the total does not update, inspect Pod status, readiness, Service endpoints, events and logs for each link in the path.

### PostgreSQL persistence

I restart the PostgreSQL Pod or container and then check the result page again. If the PVC is correctly mounted and the storage backend remains available, previously committed data should persist across a Pod replacement. Persistence is not proven merely because a PVC exists: I also verify the mount and test the data after restart.

---

## 6. Operations and incidents

### Deleted Pod

I delete one managed Pod and watch the Deployment/ReplicaSet restore the desired number of replicas.

```bash
kubectl get pods -n voting-app-rishi -w
kubectl delete pod <pod-name> -n voting-app-rishi
kubectl get deployments,replicasets,pods -n voting-app-rishi
```

**Concept:** a Pod managed by a Deployment is replaceable. Kubernetes creates another Pod to match the desired replica count. The replacement may have a different name and IP, while the Service provides a stable endpoint.

### Invalid image

I temporarily use an image name or tag that cannot be pulled, then inspect the symptoms and restore the correct image.

```bash
kubectl get pods -n voting-app-rishi -w
kubectl describe pod <pod-name> -n voting-app-rishi
kubectl get events -n voting-app-rishi --sort-by=.metadata.creationTimestamp
kubectl logs <pod-name> -n voting-app-rishi
```

**What I look for:** image-pull errors such as `ErrImagePull` or `ImagePullBackOff` appear in Pod status and events. Application logs may be empty because the application container never started. After recording the evidence, I restore the valid image and verify the rollout.

### Failed probes

I deliberately configure a probe incorrectly or use a failure threshold suitable for a controlled test, then observe the Pod status and events. A readiness failure should make the Pod unavailable as a Service endpoint; repeated liveness failures should trigger container restarts. I restore the correct probe configuration after the test.

```bash
kubectl describe pod <pod-name> -n voting-app-rishi
kubectl get pods -n voting-app-rishi
kubectl get events -n voting-app-rishi --sort-by=.metadata.creationTimestamp
kubectl logs <pod-name> -n voting-app-rishi --previous
```

`--previous` can show logs from the previous container instance when a container has restarted. Events and restart counts help distinguish a probe failure from an image or configuration problem.

### Resource usage and scaling

I set CPU and memory requests/limits and scale appropriate stateless components, such as Vote or Result, when the application and resource budget allow it.

```bash
kubectl top pods -n voting-app-rishi
kubectl describe pod <pod-name> -n voting-app-rishi
kubectl scale deployment <stateless-deployment> --replicas=2 -n voting-app-rishi
kubectl get deployments,pods -n voting-app-rishi -w
```

`kubectl top` requires the cluster's metrics pipeline to be available. Scaling the frontend may increase its capacity, but it does not automatically scale Redis, Worker or PostgreSQL or remove bottlenecks elsewhere in the flow.

### Application update, failed rollout and rollback

I update an application image or configuration, monitor the rollout, and deliberately test a bad revision. When the new version does not become ready, I use Pod details, events and logs to identify the cause and roll back to the known-good revision.

```bash
kubectl rollout status deployment/<deployment-name> -n voting-app-rishi
kubectl rollout history deployment/<deployment-name> -n voting-app-rishi
kubectl describe deployment <deployment-name> -n voting-app-rishi
kubectl rollout undo deployment/<deployment-name> -n voting-app-rishi
kubectl rollout status deployment/<deployment-name> -n voting-app-rishi
```

After rollback, I verify that the Deployment is available and that the Vote-to-Result path works again. A successful rollout command alone is not enough; I also test the application.

### Troubleshooting order I use

1. `kubectl get` — check the overall state and find which resource is unhealthy.
2. `kubectl describe` — inspect configuration, conditions, restart counts and recent events.
3. `kubectl get events` — read the timeline of Kubernetes actions and failures.
4. `kubectl logs` — read application output; use `--previous` after a restart when useful.
5. Check Services and endpoints — confirm selectors match ready Pods.
6. Check configuration and dependencies — verify ConfigMap/Secret references, service names, ports and database connectivity.
7. Re-test the full vote-to-result flow after applying a fix.

---

## 7. Troubleshooting commands

| Command | What it tells me |
|---|---|
| `kubectl get pods -n voting-app-rishi` | Pod state, readiness, restart counts and names |
| `kubectl get deployments -n voting-app-rishi` | Desired, updated, ready and available replicas |
| `kubectl get svc -n voting-app-rishi` | Service types, cluster IPs and ports |
| `kubectl get endpoints -n voting-app-rishi` | Which Pod addresses each Service can route to |
| `kubectl describe pod <pod> -n voting-app-rishi` | Pod configuration, state, conditions and events |
| `kubectl logs <pod> -n voting-app-rishi` | Output from the application container |
| `kubectl logs <pod> -n voting-app-rishi --previous` | Output from the previous container instance after a restart |
| `kubectl get events -n voting-app-rishi --sort-by=.metadata.creationTimestamp` | Time-ordered Kubernetes events |
| `kubectl get pvc,pv -n voting-app-rishi` | Claims and their storage binding state; PVs are cluster-scoped, so `kubectl get pv` lists them across namespaces |
| `kubectl rollout status deployment/<name> -n voting-app-rishi` | Whether a Deployment rollout has completed |
| `kubectl rollout history deployment/<name> -n voting-app-rishi` | Recorded Deployment revisions |
| `kubectl top pods -n voting-app-rishi` | Current CPU and memory usage when metrics are available |

---

## 8. What I learned

- **A multi-service app is a chain of dependencies.** Vote can accept a request while a later step still fails, so I need to check Redis, Worker, PostgreSQL and Result as well.
- **Asynchronous processing introduces a delay.** Vote puts data in Redis and the Worker processes it later, so the Result page may not update instantly.
- **Internal DNS is more stable than Pod IPs.** Components use Kubernetes Service names to find one another.
- **Only user-facing components need to be exposed.** Redis and PostgreSQL are normally internal services; the Worker is a background process.
- **Readiness and liveness solve different problems.** Readiness controls whether a Pod receives traffic; liveness can cause a stuck container to restart.
- **Requests and limits have different roles.** Requests affect scheduling, while limits constrain resource consumption.
- **A PVC is important for database data.** Pods can be replaced, but persistent storage should keep committed data when the claim and backing volume are retained and mounted correctly.
- **Rollbacks need verification.** I check rollout status and then test the application flow, not just the Kubernetes resource state.
- **Events and logs answer different questions.** Events show Kubernetes actions and reasons; logs show what the application printed.
- **Cleanup has a storage consequence.** Deleting application resources does not necessarily delete a PVC or its backing PV. I must inspect the storage resources and reclaim policy before assuming the data is gone.

---

## 9. How to reproduce and verify the deployment

```bash
# 1. Start the local cluster and check the active context
minikube start --driver=docker --cpus=2 --memory=4096
kubectl config current-context

# 2. Start the example with Compose to understand the app
# Run from the Docker Example Voting App directory
docker compose up -d
docker compose ps

# 3. Apply the independently written Kubernetes manifests
kubectl apply -f <manifest-directory>/

# 4. Verify the five components and their Services
kubectl get deployments,pods,services -n voting-app-rishi
kubectl get endpoints -n voting-app-rishi
kubectl get pvc -n voting-app-rishi

# 5. Inspect logs and events if anything is unhealthy
kubectl get events -n voting-app-rishi --sort-by=.metadata.creationTimestamp
kubectl logs <pod-name> -n voting-app-rishi

# 6. Open Vote and Result using the configured Service ports
kubectl port-forward svc/vote 8080:80 -n voting-app-rishi
# In a separate terminal:
kubectl port-forward svc/result 8081:80 -n voting-app-rishi

# 7. Submit a vote, wait for Worker processing, and check Result
# 8. Restart PostgreSQL and verify whether the previous vote remains
# 9. Test a controlled failure, restore the valid configuration and verify recovery
```

---

## 10. Cleanup and storage considerations

**This task is not yet marked complete.** Before cleanup, record the resources and PVC state:

```bash
kubectl get all -n voting-app-rishi
kubectl get pvc -n voting-app-rishi
kubectl get pv
```

Then delete the resources using the actual manifest directory or the namespace, depending on the cleanup scope. For example, deleting the namespace removes namespaced resources in it, but the fate of the underlying persistent volume depends on the PVC/PV configuration and storage provisioner's reclaim policy. A PV may be deleted, retained or released; I should inspect its status and reclaim policy rather than assume.

After cleanup, verify what remains:

```bash
kubectl get namespaces
kubectl get pvc -A
kubectl get pv
```

---

*Security note: the Secret in this exercise is for demo credentials only. Do not commit real passwords, tokens, kubeconfig files or other credentials to the repository.*
