# Phase 2 Troubleshooting Report — Kubernetes Voting Application

**Track:** DevOps Engineering  
**Phase:** Phase 2 — Real multi-service application  
**Application:** [Docker Example Voting App](https://github.com/dockersamples/example-voting-app)  
**Namespace:** `voting-app-rishi`

## 1. Purpose

In Phase 2, I worked with a multi-service voting application made up of Vote (Python), Redis, Worker (.NET), PostgreSQL (`db`) and Result (Node.js). I used Kubernetes commands, logs, events and resource status to understand how the components communicate and how I can investigate failures.

My troubleshooting approach is to check the overall state first, inspect the affected resource, read application logs and Kubernetes events, make one controlled change, and then verify recovery. I do not treat a task as verified until I have checked the actual command output and application behaviour.

## 2. Application flow to keep in mind

1. I submit a vote through **Vote**.
2. Vote sends the vote to **Redis**, which temporarily holds it.
3. **Worker** reads the vote from Redis and writes it to **PostgreSQL**.
4. **Result** reads the stored data from PostgreSQL and displays the totals.

This flow helps me narrow down a problem. If Vote accepts a submission but Result does not update, I check Redis, Worker, PostgreSQL and the Result application instead of assuming the Vote page is the cause.

## 3. First checks I run

```bash
# Confirm the current Kubernetes context before making changes
kubectl config current-context

# Check the main resources in my application namespace
kubectl get pods,deployments,services -n voting-app-rishi

# Check Service endpoints and whether selectors find ready Pods
kubectl get endpoints -n voting-app-rishi

# Inspect recent events in chronological order
kubectl get events -n voting-app-rishi --sort-by=.metadata.creationTimestamp

# Check configuration and persistent storage resources
kubectl get configmaps,secrets,pvc,pv -n voting-app-rishi
```

I check the namespace and context first so I do not accidentally investigate or change resources in the wrong cluster. For any affected Pod, I then use `kubectl describe pod <pod-name> -n voting-app-rishi` and `kubectl logs <pod-name> -n voting-app-rishi`.

## 4. Incident and operations notes

### 4.1 A Pod is deleted or disappears

**What I am testing:** Kubernetes self-healing for a Pod managed by a Deployment.

**How I investigate:**

```bash
kubectl get pods -n voting-app-rishi -w
kubectl delete pod <pod-name> -n voting-app-rishi
kubectl get deployments -n voting-app-rishi
kubectl get pods -n voting-app-rishi -o wide
```

**What I expect:** The deleted Pod terminates and its managing controller creates a replacement to bring the number of ready replicas back to the desired count. The replacement may have a different name and IP address.

**What I verify:** I confirm that the replacement becomes ready and test the application again. I also check that the Service has endpoints:

```bash
kubectl get endpoints -n voting-app-rishi
```

**What I learned:** Pods are replaceable. I should use Services for stable communication rather than relying on Pod IPs. A standalone Pod that is not managed by a controller will not necessarily be recreated automatically.

### 4.2 Invalid image or image-pull failure

**Possible symptoms:** A Pod remains in `ErrImagePull` or `ImagePullBackOff`, and the application is unavailable.

**How I investigate:**

```bash
kubectl get pods -n voting-app-rishi
kubectl describe pod <pod-name> -n voting-app-rishi
kubectl get events -n voting-app-rishi --sort-by=.metadata.creationTimestamp
```

I look at the image name and tag, pull policy, and the event messages. I do not assume the cause from the Pod status alone.

**Likely cause in a controlled test:** The manifest refers to an image name or tag that does not exist or cannot be pulled.

**Recovery:** I correct the image reference in the manifest, apply the corrected configuration, and wait for the rollout:

```bash
kubectl apply -f <corrected-manifest.yaml>
kubectl rollout status deployment/<deployment-name> -n voting-app-rishi
kubectl get pods -n voting-app-rishi
```

**What I verify:** The new Pod starts, becomes ready, and the affected application function works again. I run invalid-image tests only with a temporary test manifest, not by accidentally changing the working production-like configuration.

### 4.3 Readiness probe fails

**Possible symptoms:** A Pod can still be running, but it is marked `NotReady` and may not receive traffic through its Service.

**How I investigate:**

```bash
kubectl describe pod <pod-name> -n voting-app-rishi
kubectl get pods -n voting-app-rishi
kubectl get endpoints -n voting-app-rishi
kubectl logs <pod-name> -n voting-app-rishi
kubectl get events -n voting-app-rishi --sort-by=.metadata.creationTimestamp
```

I check whether the probe path, port, initial delay and timing match the application. I also check whether the application is still starting or depends on another service.

**Recovery:** I correct the probe configuration or the underlying application issue, apply the manifest and wait until the Pod becomes ready.

**What I learned:** Readiness controls whether a Pod is considered ready to receive Service traffic. A readiness failure alone does not restart the container.

### 4.4 Liveness probe fails

**Possible symptoms:** Kubernetes reports liveness probe failures and may repeatedly restart the container. The restart count can increase.

**How I investigate:**

```bash
kubectl describe pod <pod-name> -n voting-app-rishi
kubectl logs <pod-name> -n voting-app-rishi
kubectl logs <pod-name> -n voting-app-rishi --previous
kubectl get events -n voting-app-rishi --sort-by=.metadata.creationTimestamp
```

I use `--previous` when a previous container instance exists, because the latest logs may not show the error that happened before a restart. I check the probe's path, port, timing and failure threshold.

**Recovery:** I fix the incorrect probe or application problem, apply the corrected manifest and confirm that restarts stop and the Pod becomes healthy.

**What I learned:** Liveness is intended to detect a container that is no longer functioning correctly. Repeated liveness failures can cause a restart, so an overly aggressive probe can make a healthy but slow-starting application unstable.

### 4.5 A vote does not appear on the Result page

**Possible symptoms:** Vote accepts the submission, but the totals on Result do not change as expected.

**How I investigate the path one component at a time:**

```bash
kubectl get pods,services,endpoints -n voting-app-rishi
kubectl logs <vote-pod-name> -n voting-app-rishi
kubectl logs <worker-pod-name> -n voting-app-rishi
kubectl logs <result-pod-name> -n voting-app-rishi
kubectl logs <db-pod-name> -n voting-app-rishi
kubectl get events -n voting-app-rishi --sort-by=.metadata.creationTimestamp
```

I check that the relevant Pods are ready, Service endpoints exist, and each component is using the correct internal Service name and port. I then follow the data flow:

- **Vote → Redis:** check the Vote logs and Redis connectivity.
- **Redis → Worker:** check that the Worker is running and processing queued votes.
- **Worker → PostgreSQL:** check Worker/database connection errors and PostgreSQL health.
- **PostgreSQL → Result:** check Result logs and its database connection.

**Recovery:** I correct the component or configuration that the evidence points to, then submit a new test vote and confirm that it appears on Result. A page loading successfully by itself is not enough to prove the whole data flow works.

### 4.6 Service has no endpoints or another service cannot connect

**Possible symptoms:** A Service exists, but traffic cannot reach the intended Pods, or an application reports a connection/DNS error.

**How I investigate:**

```bash
kubectl get services -n voting-app-rishi
kubectl get endpoints -n voting-app-rishi
kubectl get pods --show-labels -n voting-app-rishi
kubectl describe service <service-name> -n voting-app-rishi
kubectl describe pod <pod-name> -n voting-app-rishi
```

I compare the Service selector with the labels on the intended Pods and check that the Pods are ready. I also confirm that the application uses the actual Service name and correct port. Inside the same namespace, a client can normally use a short Service name such as `redis` or `db`, provided those are the configured Service names.

**Recovery:** I fix a selector/label mismatch, readiness issue, Service port or application hostname as appropriate, then check endpoints and retest the connection.

**What I learned:** Services provide stable discovery, but they only route to matching, ready endpoints. A Service object existing does not guarantee that it has a working backend.

### 4.7 PostgreSQL restarts and data persistence

**What I am testing:** Whether voting data survives a PostgreSQL Pod restart when the database uses a PersistentVolumeClaim (PVC).

**Before the restart:** I check the database Pod and claim, then record the vote totals using the actual database name, schema and credentials for my deployment.

```bash
kubectl get pods,pvc,pv -n voting-app-rishi
kubectl describe pvc <pvc-name> -n voting-app-rishi
```

If my deployment uses the expected PostgreSQL database and schema, I can run a query similar to the following after confirming the correct table and column names:

```bash
kubectl exec -n voting-app-rishi deploy/db -- \
  psql -U postgres -c "SELECT vote, COUNT(*) FROM votes GROUP BY vote;"
```

**Restart test:**

```bash
kubectl delete pod <db-pod-name> -n voting-app-rishi
kubectl get pods -n voting-app-rishi -w
```

**After the restart:** I run the same query again and compare the counts. I also check that Result can still read the data.

**What I expect:** If PostgreSQL is correctly configured to store its data on the PVC and the claim/volume remains intact, the existing data should survive a Pod replacement.

**Important:** I should record the actual before-and-after counts rather than claiming persistence based only on the Pod becoming ready. A PVC protects data only when PostgreSQL is configured to use the mounted storage correctly; the final outcome also depends on the storage provisioner and volume lifecycle.

### 4.8 CPU/memory usage and scaling

**How I investigate usage:**

```bash
minikube addons enable metrics-server
kubectl top pods -n voting-app-rishi
kubectl top nodes
kubectl describe pod <pod-name> -n voting-app-rishi
```

If metrics are not available immediately, I check that Metrics Server is running and wait for metrics to become available. I compare the observed usage with the resource requests and limits in the manifest.

**Scaling a stateless component:**

```bash
kubectl scale deployment/vote --replicas=3 -n voting-app-rishi
kubectl rollout status deployment/vote -n voting-app-rishi
kubectl get pods -n voting-app-rishi -o wide
kubectl get endpoints -n voting-app-rishi
```

**What I verify:** The expected number of Vote replicas becomes ready, and the Service has healthy endpoints. I test Vote again after scaling.

**What I learned:** Requests help the scheduler place Pods, while limits constrain resource use. CPU limit pressure can throttle a container; exceeding a memory limit can lead to an out-of-memory termination. I scale stateless components such as Vote only when appropriate; scaling PostgreSQL or another stateful component requires a separate design rather than simply increasing replicas.

### 4.9 Application update fails and rollback

**What I am testing:** How to recover if an application update does not become healthy.

**Before the update:** I check the current state and rollout history:

```bash
kubectl get deployments -n voting-app-rishi
kubectl rollout history deployment/vote -n voting-app-rishi
```

**Apply an update:** I confirm the correct container name and image tag in my manifest before changing the image. For example, the command pattern is:

```bash
kubectl set image deployment/vote <container-name>=<valid-image:tag> -n voting-app-rishi
kubectl rollout status deployment/vote -n voting-app-rishi
```

A wrong image can be used in a controlled exercise to create a failed rollout, but I keep the test scoped to this application and restore a working image afterwards.

**Investigate:**

```bash
kubectl get pods -n voting-app-rishi
kubectl describe pod <pod-name> -n voting-app-rishi
kubectl get events -n voting-app-rishi --sort-by=.metadata.creationTimestamp
kubectl rollout history deployment/vote -n voting-app-rishi
```

**Rollback:**

```bash
kubectl rollout undo deployment/vote -n voting-app-rishi
kubectl rollout status deployment/vote -n voting-app-rishi
kubectl get pods -n voting-app-rishi
```

**What I verify:** The Deployment returns to a working revision, the expected replicas become ready, and I test the Vote page and end-to-end vote-to-result flow. I do not treat a successful rollback command alone as proof that the application is working.

### 4.10 Cleanup and storage that remains

The Phase 2 checklist still has cleanup marked as incomplete, so I should complete this section only after running and verifying the cleanup.

**Before cleanup, I record what exists:**

```bash
kubectl get all,configmaps,secrets,pvc -n voting-app-rishi
kubectl get pv
```

**Cleanup:** I remove only the resources intended by my task and use the actual manifest paths or resource names from my repository. For example, if the manifests are organised by application resources, I can remove those manifests with `kubectl delete -f <manifest-path>`.

**After cleanup, I check again:**

```bash
kubectl get all,configmaps,secrets,pvc -n voting-app-rishi
kubectl get pv
```

**What I check:** Whether Deployments, Pods, Services, ConfigMaps, Secrets and PVCs are gone, and whether any PV remains. Deleting a Deployment does not automatically delete its PVC. Deleting a PVC can cause data loss, and whether the underlying volume is retained or deleted depends on its reclaim policy and storage provisioner. I only delete persistent storage after confirming that I no longer need the data and have recorded the evidence required for the task.

## 5. Quick command reference

| Command | What it tells me |
|---|---|
| `kubectl get pods -n voting-app-rishi` | Current Pod status and restart counts |
| `kubectl describe pod <pod-name> -n voting-app-rishi` | Pod configuration, conditions and recent events |
| `kubectl logs <pod-name> -n voting-app-rishi` | Application output and errors |
| `kubectl logs <pod-name> -n voting-app-rishi --previous` | Logs from the previous container instance, if available |
| `kubectl get events -n voting-app-rishi --sort-by=.metadata.creationTimestamp` | Timeline of Kubernetes warnings and actions |
| `kubectl get deployments -n voting-app-rishi` | Desired and available replicas |
| `kubectl get services,endpoints -n voting-app-rishi` | Service definitions and the Pods receiving traffic |
| `kubectl top pods -n voting-app-rishi` | Current Pod CPU and memory usage, when metrics are available |
| `kubectl rollout status deployment/<name> -n voting-app-rishi` | Whether a Deployment update has completed |
| `kubectl rollout history deployment/<name> -n voting-app-rishi` | Available rollout revisions |
| `kubectl get pvc,pv -n voting-app-rishi` | Claims and persistent volumes associated with the database storage |

## 6. Main lessons from Phase 2

- I troubleshoot the whole request/data path instead of focusing only on the frontend.
- `describe` and Events help me understand what Kubernetes did; application logs help me understand what the application reported.
- Readiness and liveness probes have different purposes: readiness controls traffic eligibility, while liveness can trigger restarts.
- Service selectors, Pod labels, readiness and ports all affect whether traffic reaches the right backend.
- A failed image pull is usually investigated through the image reference and Pod events.
- Rollback must be followed by checks that the Pods are healthy and the application works.
- I verify PostgreSQL persistence by comparing data before and after a restart, not by assuming the PVC guarantees success automatically.
- I inspect PVCs and PVs separately during cleanup because workload lifecycle and storage lifecycle are different.
- I only report exact outcomes, timings, errors and vote counts that I captured from my own terminal output or screenshots.

## 7. Evidence to attach

To make this report an accurate record of my hands-on work, I attach or link the evidence I captured for each relevant exercise:

- [ ] Pod deletion and replacement (`kubectl get pods -w` output or screenshot)
- [ ] Invalid image and the resulting Pod events
- [ ] Readiness/liveness probe failure symptoms and recovery
- [ ] Before-and-after PostgreSQL vote counts around the restart
- [ ] Resource usage and scaling output
- [ ] Failed rollout, rollback and final application verification
- [ ] Cleanup results showing remaining PVC/PV resources

*I use this report to document the investigation process and expected checks. Where I have not saved actual output or screenshots, I add the real observed result before submitting rather than presenting an expected result as something I personally observed.*
