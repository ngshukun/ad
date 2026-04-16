# CKAD Practice Exam – 30 Tasks (2025-Style)

## 🚨 Important Access Notice

Please **do not use this file as the main place to access the CKAD lab**.

To access the CKAD questions and solutions properly, you must use the site below:

👉 https://learn.dripforgeai.com/demo/master/ckad

### Login details

- **Email:** Use the same email you used for your purchase
- **Password:** `CodeGenitor@CKAD`

### Important

- Access is tied to your **purchase email**
- If access does not work, first make sure you are using the **correct purchase email**
- The site is the **official access point** for the CKAD lab content, not this file

## [Visit Site to Access Question](https://learn.dripforgeai.com/demo/ckad)

## Practice environment setup (KillerKoda)

1. Open killerkoda.com → **Playground** → **CKAD**
2. Create the prep script:

   ```bash
   vim prep.sh
   ```

3. Paste the `prep.sh` content → save/exit `:wq`
4. Make executable + run:

   ```bash
   chmod +x prep.sh
   ./prep.sh
   ```

## Check your work

1. Create the checker script:

   ```bash
   vim check.sh
   ```

2. Paste the `check.sh` content → save/exit `:wq`
3. Make executable + run:

   ```bash
   chmod +x check.sh
   ./check.sh
   ```

## How to use this set (recommended)

- KillerKoda free sessions are time-limited.
- Do **10 questions per session**, run `./check.sh`, then move to the next batch.
- If stuck: read the solution, then redo the task once without it.

---

# Question 1 – Move hardcoded env vars to Secret

## Task

In namespace `default`, Deployment `billing-api` exists with hard-coded env vars:

- `DB_USER`
- `DB_PASS`

Do the following:

1. Create a Secret `billing-secret` in `default` containing:
   - `DB_USER`
   - `DB_PASS`

2. Update Deployment `billing-api` so the container reads `DB_USER` and `DB_PASS` using:
   - `valueFrom.secretKeyRef`

**Constraints**

- Do **not** change Deployment name or namespace.

## Solution

### 1) Create Secret

```bash
kubectl create secret generic billing-secret \
  --from-literal=DB_USER=admin \
  --from-literal=DB_PASS=SuperSecret123 \
  -n default
```

### 2) Update Deployment to read from Secret

```bash
kubectl edit deploy billing-api -n default
```

Replace:

```yaml
- name: DB_USER
  value: "admin"
- name: DB_PASS
  value: "SuperSecret123"
```

With:

```yaml
- name: DB_USER
  valueFrom:
    secretKeyRef:
      name: billing-secret
      key: DB_USER
- name: DB_PASS
  valueFrom:
    secretKeyRef:
      name: billing-secret
      key: DB_PASS
```

---

# Question 2 – Fix broken Ingress backend and pathType

## Task

In namespace `default`, these resources exist:

- Deployment `store-deploy`
- Service `store-svc`
- Ingress `store-ingress` (misconfigured)

Fix `store-ingress` so it:

- Routes path `/shop`
- Uses `pathType: Prefix`
- Forwards to Service `store-svc` on port `8080`

**Constraints**

- Do **not** create a new Ingress.

## Solution

```bash
kubectl edit ingress store-ingress -n default
```

Update the path rule to:

```yaml
path: /shop
pathType: Prefix
backend:
  service:
    name: store-svc
    port:
      number: 8080
```

---

# Question 3 – Create Ingress for internal API

## Task

In namespace `default`:

- Deployment `internal-api`
- Service `internal-api-svc` exposing port `3000`

Create an Ingress `internal-api-ingress` that:

- Host: `internal.company.local`
- Path: `/`
- Backend: `internal-api-svc:3000`
- API: `networking.k8s.io/v1`

## Solution

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: internal-api-ingress
  namespace: default
spec:
  rules:
  - host: internal.company.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: internal-api-svc
            port:
              number: 3000
EOF
```

---

# Question 4 – Fix RBAC for a Deployment using logs hint

## Task

In namespace `meta`, Deployment `dev-deployment` logs a forbidden error when trying to list deployments.

Do the following (without deleting the Deployment):

1. Create ServiceAccount `dev-sa` in namespace `meta`
2. Create Role `dev-deploy-role` in `meta` allowing `get,list,watch` on:
   - resource: `deployments`
   - apiGroup: `apps`

3. Create RoleBinding `dev-deploy-rb` binding the Role to `dev-sa`
4. Update Deployment `dev-deployment` to use ServiceAccount `dev-sa`

## Solution

### 1) ServiceAccount

```bash
kubectl create sa dev-sa -n meta
```

### 2) Role

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: dev-deploy-role
  namespace: meta
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get","list","watch"]
EOF
```

### 3) RoleBinding

```bash
kubectl create rolebinding dev-deploy-rb \
  --role=dev-deploy-role \
  --serviceaccount=meta:dev-sa \
  -n meta
```

### 4) Patch Deployment to use SA

```bash
kubectl patch deploy dev-deployment -n meta \
  -p '{"spec":{"template":{"spec":{"serviceAccountName":"dev-sa"}}}}'
```

---

# Question 5 – Fix Pod using initContainer + emptyDir

## Task

In namespace `default`, Pod `startup-pod` fails because it executes `/app/start.sh` (missing).

Recreate `startup-pod` so that:

- An `emptyDir` volume is mounted at `/app`
- An initContainer:
  - writes `/app/start.sh` with: `echo start app`
  - makes it executable

- The main container runs `/app/start.sh`

Pod must reach `Running`.

## Solution

```bash
kubectl delete pod startup-pod -n default
```

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: startup-pod
  namespace: default
spec:
  volumes:
  - name: app-vol
    emptyDir: {}
  initContainers:
  - name: init-script
    image: busybox:1.36
    command: ["/bin/sh","-c"]
    args:
    - |
      cat > /app/start.sh <<'SH'
      #!/bin/sh
      echo start app
      sleep 360000
      SH
      chmod +x /app/start.sh
    volumeMounts:
    - name: app-vol
      mountPath: /app
  containers:
  - name: app
    image: busybox:1.36
    command: ["/app/start.sh"]
    volumeMounts:
    - name: app-vol
      mountPath: /app
EOF
```

---

# Question 6 – Build, tag, and save Docker image

## Task

A valid `Dockerfile` exists in `/root/api-app` (or `$HOME/api-app`).

1. Build image `api-app:2.1`
2. Save image to `/root/api-app.tar`

## Solution

```bash
cd /root/api-app 2>/dev/null || cd "$HOME/api-app"
docker build -t api-app:2.1 .
docker save api-app:2.1 -o /root/api-app.tar
```

---

# Question 7 – Pod resources + namespace ResourceQuota

## Task

In namespace `dev`:

1. Create Pod `resource-pod` (image `nginx`) with:
   - requests: cpu `200m`, memory `128Mi`
   - limits: cpu `500m`, memory `256Mi`

2. Create ResourceQuota `dev-quota`:
   - pods: `10`
   - requests.cpu: `2`
   - requests.memory: `4Gi`

## Solution

### 1) Pod

```bash
kubectl apply -n dev -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: resource-pod
spec:
  containers:
  - name: web
    image: nginx
    resources:
      requests:
        cpu: "200m"
        memory: "128Mi"
      limits:
        cpu: "500m"
        memory: "256Mi"
EOF
```

### 2) ResourceQuota

```bash
kubectl apply -n dev -f - <<EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
spec:
  hard:
    pods: "10"
    requests.cpu: "2"
    requests.memory: "4Gi"
EOF
```

---

# Question 8 – Fix deprecated manifest and strategy

## Task

File `/root/old.yaml` (or `$HOME/old.yaml`) contains a Deployment with:

- deprecated apiVersion
- missing selector (required in apps/v1)
- invalid rollingUpdate values

Fix so:

- `apiVersion: apps/v1`
- selector matches template labels `app: old-app`
- rollingUpdate uses valid values

Apply it so Deployment `old-deploy` is created.

## Solution

### 1) Edit file

```bash
vi /root/old.yaml 2>/dev/null || vi "$HOME/old.yaml"
```

Use:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: old-deploy
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: old-app
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
  template:
    metadata:
      labels:
        app: old-app
    spec:
      containers:
        - name: old-container
          image: nginx:1.14
```

### 2) Apply

```bash
kubectl apply -f /root/old.yaml 2>/dev/null || kubectl apply -f "$HOME/old.yaml"
```

---

# Question 9 – Create a canary Deployment behind existing Service

## Task

In namespace `default`:

- Deployment `app-stable` exists (labels `app=core`, `version=v1`)
- Service `app-svc` exists (selector `app=core`)

Create Deployment `app-canary`:

- labels `app=core`, `version=v2`
- image `nginx`
- replicas `1`

Ensure `app-svc` selects both stable and canary Pods.

## Solution

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-canary
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: core
      version: v2
  template:
    metadata:
      labels:
        app: core
        version: v2
    spec:
      containers:
      - name: app
        image: nginx
EOF
```

---

# Question 10 – Fix Service selector for Deployment

## Task

In namespace `default`:

- Deployment `web-app` Pods have label `app=webapp`
- Service `web-app-svc` selector is wrong

Fix `web-app-svc` selector to `app=webapp`.

## Solution

```bash
kubectl edit svc web-app-svc -n default
```

Set:

```yaml
spec:
  selector:
    app: webapp
```

---

# Question 11 – Add livenessProbe to Pod

## Task

In namespace `default`, Pod `healthz` exists (nginx, port 80).

Add livenessProbe:

- httpGet path `/healthz`
- port `80`
- initialDelaySeconds `5`

## Solution (recreate fast)

```bash
kubectl delete pod healthz -n default
```

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: healthz
  namespace: default
spec:
  containers:
  - name: web
    image: nginx
    ports:
    - containerPort: 80
    livenessProbe:
      httpGet:
        path: /healthz
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 10
EOF
```

---

# Question 12 – Add readinessProbe to Deployment

## Task

In namespace `default`, Deployment `shop-api` listens on port `8080`.

Add readinessProbe:

- httpGet path `/ready`
- port `8080`
- initialDelaySeconds `5`

## Solution

```bash
kubectl edit deploy shop-api -n default
```

Add under container:

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
```

---

# Question 13 – Create CronJob with completions/parallelism/backoff

## Task

In namespace `default`, create CronJob `metrics-job`:

- schedule: `* * * * *`
- image: `busybox`
- prints `collecting metrics`
- completions: `4`
- parallelism: `2`
- backoffLimit: `3`
- restartPolicy: `Never`

## Solution

```bash
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: metrics-job
  namespace: default
spec:
  schedule: "* * * * *"
  jobTemplate:
    spec:
      completions: 4
      parallelism: 2
      backoffLimit: 3
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: metrics
            image: busybox
            command: ["/bin/sh","-c"]
            args: ["echo collecting metrics; sleep 5"]
EOF
```

---

# Question 14 – Fix RBAC for audit Pod

## Task

In namespace `default`:

- Pod `audit-runner` uses ServiceAccount `wrong-sa`
- It runs `kubectl get pods --all-namespaces` and fails with Forbidden

Fix by doing:

1. Create SA `audit-sa` in `default`
2. Create Role `audit-role` in `default` allowing `get,list,watch` on `pods`
3. Create RoleBinding `audit-rb` binding `audit-role` to `audit-sa`
4. Reconfigure `audit-runner` to use `audit-sa` (recreate if needed)

## Solution

### 1) SA

```bash
kubectl create sa audit-sa -n default
```

### 2) Role

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: audit-role
  namespace: default
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get","list","watch"]
EOF
```

### 3) RoleBinding

```bash
kubectl create rolebinding audit-rb \
  --role=audit-role \
  --serviceaccount=default:audit-sa \
  -n default
```

### 4) Pod SA is immutable → recreate

```bash
kubectl get pod audit-runner -n default -o yaml > /tmp/audit-runner.yaml
kubectl delete pod audit-runner -n default
```

Edit `/tmp/audit-runner.yaml`:

- set `spec.serviceAccountName: audit-sa`
- remove runtime fields (at least these):
  - `status:`
  - `metadata.resourceVersion`
  - `metadata.uid`
  - `metadata.creationTimestamp`

Apply:

```bash
kubectl apply -f /tmp/audit-runner.yaml
```

---

# Question 15 – Capture Pod logs to file on node

## Task

In namespace `default`, Pod `winter` exists.

Save its logs to:

- `/opt/winter/logs.txt`

## Solution

```bash
mkdir -p /opt/winter
kubectl logs winter > /opt/winter/logs.txt
```

---

# Question 16 – Find highest CPU Pod and write name to file

## Task

In namespace `cpu-load`, pods `cpu-busy-1` and `cpu-busy-2` exist.

Using `kubectl top`, find the pod using the most CPU and write **name only** to:

- `/opt/winter/highest.txt`

## Solution

```bash
kubectl top pod -n cpu-load
```

Then:

```bash
echo -n "cpu-busy-2" > /opt/winter/highest.txt
```

(Use the real highest pod you see.)

---

# Question 17 – Expose Deployment via NodePort Service

## Task

In namespace `default`, Deployment `video-api` exists:

- label: `app=video-api`
- containerPort: `9090`

Create Service `video-svc`:

- type `NodePort`
- selector `app=video-api`
- port `80` → targetPort `9090`

## Solution

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: video-svc
  namespace: default
spec:
  type: NodePort
  selector:
    app: video-api
  ports:
  - port: 80
    targetPort: 9090
EOF
```

---

# Question 18 – Fix Ingress pathType from invalid manifest

## Task

File `/root/client-ingress.yaml` (or `$HOME/client-ingress.yaml`) fails to apply due to invalid `pathType`.

Fix and ensure Ingress `client-ingress` routes:

- path `/`
- to Service `client-svc`
- port `80`

## Solution

Try apply (see error):

```bash
kubectl apply -f /root/client-ingress.yaml 2>/dev/null || kubectl apply -f "$HOME/client-ingress.yaml"
```

Edit and fix:

```bash
vi /root/client-ingress.yaml 2>/dev/null || vi "$HOME/client-ingress.yaml"
```

Change:

```yaml
pathType: InvalidType
```

To:

```yaml
pathType: Prefix
```

Apply again:

```bash
kubectl apply -f /root/client-ingress.yaml 2>/dev/null || kubectl apply -f "$HOME/client-ingress.yaml"
```

---

# Question 19 – Add Pod-level securityContext and capability

## Task

In namespace `default`, Deployment `syncer` exists.

Update it so that:

- Pod-level: `runAsUser: 1000`
- Container-level (container `sync`): add capability `NET_ADMIN`

## Solution

```bash
kubectl edit deploy syncer -n default
```

Add under `spec.template.spec`:

```yaml
securityContext:
  runAsUser: 1000
```

Under the `sync` container:

```yaml
securityContext:
  capabilities:
    add:
      - NET_ADMIN
```

---

# Question 20 – Create Redis Pod in specific namespace

## Task

In namespace `cachelayer`, create Pod `redis32`:

- image `redis:3.2`
- containerPort `6379`

## Solution

```bash
kubectl apply -n cachelayer -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: redis32
spec:
  containers:
  - name: redis
    image: redis:3.2
    ports:
    - containerPort: 6379
EOF
```

---

# Question 21 – Fix labels to match existing NetworkPolicies

## Task

In namespace `netpol-chain`, pods exist with wrong labels:

- `frontend`, `backend`, `database`

NetworkPolicies expect:

- `role=frontend`
- `role=backend`
- `role=db`

Fix pod labels (do not change policies) so traffic chain works:
`frontend → backend → database`

## Solution

```bash
kubectl label pod frontend -n netpol-chain role=frontend --overwrite
kubectl label pod backend  -n netpol-chain role=backend  --overwrite
kubectl label pod database -n netpol-chain role=db       --overwrite
```

---

# Question 22 – Resume paused rollout and update image

## Task

In namespace `default`, Deployment `dashboard` is paused and uses `nginx:1.23`.

1. Resume rollout
2. Update image to `nginx:1.25`
3. Verify rollout success

## Solution

```bash
kubectl rollout resume deploy dashboard -n default
kubectl set image deploy/dashboard web=nginx:1.25 -n default
kubectl rollout status deploy dashboard -n default
```

---

# Question 23 – Configure ExternalName Service

## Task

In namespace `default`, create Service `external-db`:

- type `ExternalName`
- externalName `database.prod.internal`

## Solution

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: external-db
  namespace: default
spec:
  type: ExternalName
  externalName: database.prod.internal
EOF
```

---

# Question 24 – Fix CronJob restart policy and backoffLimit

## Task

In namespace `default`, CronJob `hourly-report` exists.

Fix it so:

- restartPolicy = `Never`
- backoffLimit = `2`

## Solution

```bash
kubectl edit cronjob hourly-report -n default
```

Ensure:

```yaml
spec:
  jobTemplate:
    spec:
      backoffLimit: 2
      template:
        spec:
          restartPolicy: Never
```

---

# Question 25 – Fix Deployment selector/labels mismatch

## Task

File `/root/broken-app.yaml` (or `$HOME/broken-app.yaml`) has Deployment `broken-app` where:

- selector labels do not match template labels

Fix so selector and template labels match and Pods run.

## Solution

```bash
vi /root/broken-app.yaml 2>/dev/null || vi "$HOME/broken-app.yaml"
```

Set both to the same value, e.g.:

```yaml
spec:
  selector:
    matchLabels:
      app: fixed-app
  template:
    metadata:
      labels:
        app: fixed-app
```

Apply + verify:

```bash
kubectl apply -f /root/broken-app.yaml 2>/dev/null || kubectl apply -f "$HOME/broken-app.yaml"
kubectl rollout status deploy broken-app -n default
```

---

# Question 26 – CronJob must stop after ~8 seconds (no sleep)

## Task

In namespace `cronlab`, CronJob `quick-exit` loops forever.

Modify it so Jobs stop after ~8 seconds using:

- `activeDeadlineSeconds: 8` on the Job spec

## Solution

```bash
kubectl edit cronjob quick-exit -n cronlab
```

Add:

```yaml
spec:
  jobTemplate:
    spec:
      activeDeadlineSeconds: 8
```

---

# Question 27 – Create Job from CronJob and ensure completion

## Task

In namespace `cronlab`, create Job `quick-exit-manual` from CronJob `quick-exit`.
Ensure it completes.

## Solution

```bash
kubectl create job quick-exit-manual -n cronlab --from=cronjob/quick-exit
kubectl wait --for=condition=complete job/quick-exit-manual -n cronlab --timeout=60s
```

---

# Question 28 – Fix ResourceQuota violation (quota-app)

## Task

In namespace `limits`, Deployment `quota-app` violates ResourceQuota `limits-quota`.

Fix Deployment resources so they comply:

- requests.cpu <= `200m`
- requests.memory <= `256Mi`
- limits.cpu <= `400m`
- limits.memory <= `512Mi`

## Solution

```bash
kubectl edit deploy quota-app -n limits
```

Set:

```yaml
resources:
  requests:
    cpu: "200m"
    memory: "256Mi"
  limits:
    cpu: "400m"
    memory: "512Mi"
```

Verify:

```bash
kubectl rollout status deploy quota-app -n limits
```

---

# Question 29 – Fix LimitRange violation (lr-app)

## Task

In namespace `limits`, LimitRange `limits-lr` enforces:

- min cpu `50m`, memory `64Mi`
- max cpu `200m`, memory `256Mi`

Deployment `lr-app` violates it.

Fix `lr-app` requests/limits to fit within min/max.

## Solution

```bash
kubectl edit deploy lr-app -n limits
```

Example valid:

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "200m"
    memory: "256Mi"
```

Verify:

```bash
kubectl rollout status deploy lr-app -n limits
```

---

# Question 30 – Fix requests/limits ratio (limits must be 2× requests)

## Task

In namespace `prod`, Deployment `ratio-app` exists.

Requests must stay:

- cpu `100m`
- memory `128Mi`

Fix limits so they are exactly 2× requests:

- cpu `200m`
- memory `256Mi`

## Solution

```bash
kubectl edit deploy ratio-app -n prod
```

Set:

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "200m"
    memory: "256Mi"
```

Verify:

```bash
kubectl rollout status deploy ratio-app -n prod
```

```
::contentReference[oaicite:0]{index=0}
```
