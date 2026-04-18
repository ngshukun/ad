#!/usr/bin/env bash
# CKAD 2025 Practice – Environment Prep (Matches MD Questions 1–30)
# Tries to use /root paths (as per exam MD). If not writable, falls back to $HOME.
#
# FIXES INCLUDED:
# 1) Ensures Metrics Server is installed + patched so Metrics API works (kubectl top works)
#    - Adds --kubelet-insecure-tls and preferred address types (common in lab clusters)
#    - Waits (briefly) for metrics-server + apiservice to become Available
# 2) Makes Q13 "metrics-job" INTENTIONALLY WRONG so it FAILS until you fix it during the exercise.

set -euo pipefail

HOME_DIR="${HOME}"

# Prefer /root when writable (matches MD paths)
ROOT_BASE="/root"
if [[ -w "$ROOT_BASE" ]]; then
  BASE_DIR="$ROOT_BASE"
else
  BASE_DIR="$HOME_DIR"
  echo "WARN: /root not writable. Using BASE_DIR=${BASE_DIR} instead (some MD file paths mention /root)."
fi

echo "=== CKAD practice environment prep (Q1–Q30) ==="
echo "Using BASE_DIR: ${BASE_DIR}"
echo

# ---------------- Helpers ----------------
log() { echo "[prep] $*"; }

install_and_fix_metrics_server() {
  # If kubectl top already works, do nothing.
  if kubectl top nodes >/dev/null 2>&1; then
    log "Metrics API already working (kubectl top nodes). Skipping metrics-server install."
    return 0
  fi

  log "Installing metrics-server..."
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml >/dev/null

  # Patch metrics-server args so it works in common lab environments (kind/kubeadm/vagrant)
  # - kubelet TLS often uses self-signed certs -> insecure-tls
  # - prefer InternalIP etc.
  log "Patching metrics-server deployment args..."
  kubectl -n kube-system patch deploy metrics-server \
    --type='json' \
    -p='[
      {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"},
      {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname"}
    ]' >/dev/null 2>&1 || true

  # Wait for deployment rollout (best effort)
  log "Waiting for metrics-server rollout..."
  kubectl -n kube-system rollout status deploy/metrics-server --timeout=90s >/dev/null 2>&1 || true

  # Wait for apiservice to become Available (best effort)
  log "Waiting for v1beta1.metrics.k8s.io APIService to become Available..."
  local tries=30
  for i in $(seq 1 $tries); do
    local cond
    cond="$(kubectl get apiservice v1beta1.metrics.k8s.io -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "")"
    if [[ "$cond" == "True" ]]; then
      log "Metrics APIService is Available."
      break
    fi
    sleep 2
  done

  # Final quick check (non-fatal)
  if kubectl top nodes >/dev/null 2>&1; then
    log "Metrics API now working (kubectl top)."
  else
    log "WARN: Metrics API still not available yet. It may take longer on slow clusters."
    log "      Troubleshoot: kubectl -n kube-system logs deploy/metrics-server"
    log "                    kubectl get apiservice v1beta1.metrics.k8s.io -o wide"
  fi
}

# ---------------- Namespaces used by the questions ----------------
for ns in meta dev cachelayer netpol-chain cpu-load cronlab limits prod; do
  echo "Creating namespace: $ns"
  kubectl get ns "$ns" >/dev/null 2>&1 || kubectl create ns "$ns"
done
echo

# Create /opt/winter if possible (non-fatal)
mkdir -p /opt/winter 2>/dev/null || echo "WARN: could not create /opt/winter (no perms). Create it manually if needed."
echo

# Ensure Metrics API works early (needed for later “top” style tasks)
install_and_fix_metrics_server
echo

# ---------------- Q01: billing-api with hardcoded env vars ----------------
echo "Q01: Creating Deployment billing-api (hardcoded env vars)..."
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: billing-api
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: billing-api
  template:
    metadata:
      labels:
        app: billing-api
    spec:
      containers:
        - name: api
          image: nginx
          env:
            - name: DB_USER
              value: "admin"
            - name: DB_PASS
              value: "SuperSecret123"
EOF
echo

# ---------------- Q02: store-deploy + svc + misconfigured ingress ----------------
echo "Q02: Creating store deployment, service and broken ingress..."
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: store-deploy
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: store
  template:
    metadata:
      labels:
        app: store
    spec:
      containers:
        - name: web
          image: nginx
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: store-svc
  namespace: default
spec:
  selector:
    app: store
  ports:
    - port: 8080
      targetPort: 8080
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: store-ingress
  namespace: default
spec:
  rules:
    - http:
        paths:
          - path: /wrong
            pathType: ImplementationSpecific
            backend:
              service:
                name: wrong-svc
                port:
                  number: 80
EOF
echo

# ---------------- Q03: internal-api deploy + svc ----------------
echo "Q03: Creating internal-api deployment and service..."
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: internal-api
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: internal-api
  template:
    metadata:
      labels:
        app: internal-api
    spec:
      containers:
        - name: api
          image: nginx
          ports:
            - containerPort: 3000
---
apiVersion: v1
kind: Service
metadata:
  name: internal-api-svc
  namespace: default
spec:
  selector:
    app: internal-api
  ports:
    - port: 3000
      targetPort: 3000
EOF
echo

# ---------------- Q04: dev-deployment (RBAC issue in meta) ----------------
echo "Q04: Creating dev-deployment in namespace meta (RBAC issue)..."
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dev-deployment
  namespace: meta
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dev-deployment
  template:
    metadata:
      labels:
        app: dev-deployment
    spec:
      containers:
        - name: runner
          image: bitnami/kubectl:latest
          command: ["/bin/sh","-c"]
          args:
            - |
              while true; do
                echo "Trying to list deployments..."
                kubectl get deployments -n meta || echo "Forbidden?"
                sleep 10
              done
EOF
echo

# ---------------- Q05: broken startup-pod ----------------
echo "Q05: Creating broken startup-pod (missing /app/start.sh)..."
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: startup-pod
  namespace: default
spec:
  containers:
    - name: app
      image: busybox
      command: ["/bin/sh","-c"]
      args: ["/app/start.sh"]
EOF
echo

# ---------------- Q06: Prepare Dockerfile under /root/api-app (or fallback) ----------------
echo "Q06: Writing Dockerfile to ${BASE_DIR}/api-app/Dockerfile..."
mkdir -p "${BASE_DIR}/api-app"
cat > "${BASE_DIR}/api-app/Dockerfile" <<'EOF'
FROM nginx:alpine
RUN echo "Hello from CKAD practice image" > /usr/share/nginx/html/index.html
EOF
echo "Dockerfile written to ${BASE_DIR}/api-app/Dockerfile"
echo "NOTE: MD expects /root/api-app; current BASE_DIR=${BASE_DIR}"
echo

# ---------------- Q07: Namespace dev ready (user creates Pod + ResourceQuota) ----------------
echo "Q07: Namespace dev ready (no objects created; you will create resource-pod + dev-quota)."
echo

# ---------------- Q08: Deprecated deployment manifest at /root/old.yaml (or fallback) ----------------
echo "Q08: Writing deprecated deployment manifest to ${BASE_DIR}/old.yaml..."
cat > "${BASE_DIR}/old.yaml" <<'EOF'
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: old-deploy
  namespace: default
spec:
  replicas: 2
  template:
    metadata:
      labels:
        app: old-app
    spec:
      containers:
        - name: old-container
          image: nginx:1.14
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: "invalid"
      maxUnavailable: "invalid"
EOF
echo

# ---------------- Q09: app-stable + app-svc ----------------
echo "Q09: Creating app-stable deployment and app-svc..."
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-stable
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: core
      version: v1
  template:
    metadata:
      labels:
        app: core
        version: v1
    spec:
      containers:
        - name: app
          image: nginx
---
apiVersion: v1
kind: Service
metadata:
  name: app-svc
  namespace: default
spec:
  selector:
    app: core
  ports:
    - port: 80
      targetPort: 80
EOF
echo

# ---------------- Q10: web-app + broken web-app-svc ----------------
echo "Q10: Creating web-app and broken web-app-svc..."
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
        - name: web
          image: nginx
---
apiVersion: v1
kind: Service
metadata:
  name: web-app-svc
  namespace: default
spec:
  selector:
    app: wronglabel
  ports:
    - port: 80
      targetPort: 80
EOF
echo

# ---------------- Q11: healthz Pod (no liveness yet) ----------------
echo "Q11: Creating healthz pod (no liveness probe yet)..."
kubectl apply -f - <<'EOF'
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
EOF
echo

# ---------------- Q12: shop-api Deployment (no readiness yet) ----------------
echo "Q12: Creating shop-api deployment (no readiness probe yet)..."
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop-api
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: shop-api
  template:
    metadata:
      labels:
        app: shop-api
    spec:
      containers:
        - name: api
          image: nginx
          ports:
            - containerPort: 8080
EOF
echo

# ---------------- Q13: metrics-job CronJob (INTENTIONALLY WRONG) ----------------
echo "Q13: Creating metrics-job CronJob (intentionally wrong; you must fix it)..."
kubectl apply -f - <<'EOF'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: metrics-job
  namespace: default
spec:
  # WRONG on purpose
  schedule: "*/5 * * * *"
  jobTemplate:
    spec:
      # WRONG on purpose
      completions: 1
      parallelism: 1
      backoffLimit: 1
      template:
        spec:
          # WRONG on purpose
          restartPolicy: OnFailure
          containers:
            - name: metrics
              # WRONG on purpose
              image: nginx
              command: ["/bin/sh","-c"]
              args: ["echo collecting"]
EOF
echo

# ---------------- Q14: audit-runner + wrong-sa (RBAC) ----------------
echo "Q14: Creating audit-runner with wrong-sa (should log Forbidden)..."
kubectl get sa wrong-sa -n default >/dev/null 2>&1 || kubectl create sa wrong-sa -n default
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: audit-runner
  namespace: default
spec:
  serviceAccountName: wrong-sa
  containers:
    - name: kubectl
      image: bitnami/kubectl:latest
      command: ["/bin/sh","-c"]
      args:
        - |
          while true; do
            echo "Attempting: kubectl get pods --all-namespaces"
            kubectl get pods --all-namespaces || echo "Forbidden?"
            sleep 10
          done
EOF
echo

# ---------------- Q15: winter pod ----------------
echo "Q15: Preparing winter pod..."
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: winter
  namespace: default
spec:
  containers:
    - name: logger
      image: busybox
      command: ["/bin/sh","-c"]
      args:
        - |
          i=0
          while true; do
            echo "winter log line $i"
            i=$((i+1))
            sleep 5
          done
EOF
echo

# ---------------- Q16: cpu-load pods ----------------
echo "Q16: Creating CPU load pods in namespace cpu-load..."
kubectl apply -n cpu-load -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: cpu-busy-1
spec:
  containers:
    - name: busy
      image: busybox
      command: ["/bin/sh","-c"]
      args:
        - |
          while true; do
            sha1sum /dev/urandom | head -c 20000 >/dev/null
          done
---
apiVersion: v1
kind: Pod
metadata:
  name: cpu-busy-2
spec:
  containers:
    - name: busy
      image: busybox
      command: ["/bin/sh","-c"]
      args:
        - |
          while true; do
            sha1sum /dev/urandom | head -c 10000 >/dev/null
          done
EOF
echo

# ---------------- Q17: video-api Deployment ----------------
echo "Q17: Creating video-api deployment..."
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: video-api
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: video-api
  template:
    metadata:
      labels:
        app: video-api
    spec:
      containers:
        - name: api
          image: nginx
          ports:
            - containerPort: 9090
EOF
echo

# ---------------- Q18: broken client-ingress.yaml file + client-svc exists ----------------
echo "Q18: Writing broken client-ingress manifest to ${BASE_DIR}/client-ingress.yaml..."
cat > "${BASE_DIR}/client-ingress.yaml" <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: client-ingress
  namespace: default
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: InvalidType
            backend:
              service:
                name: client-svc
                port:
                  number: 80
EOF
echo "NOTE: client-ingress.yaml is intentionally invalid. You'll apply and fix it."
echo

echo "Q18: Creating client-app deployment and client-svc..."
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: client-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: client
  template:
    metadata:
      labels:
        app: client
    spec:
      containers:
        - name: web
          image: nginx
---
apiVersion: v1
kind: Service
metadata:
  name: client-svc
  namespace: default
spec:
  selector:
    app: client
  ports:
    - port: 80
      targetPort: 80
EOF
echo

# ---------------- Q19: syncer deployment WITH existing securityContext ----------------
echo "Q19: Creating syncer deployment with existing securityContext..."
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: syncer
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: syncer
  template:
    metadata:
      labels:
        app: syncer
    spec:
      securityContext:
        runAsNonRoot: true
        fsGroup: 2000
      containers:
        - name: sync
          image: nginx
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: false
            capabilities:
              drop: ["ALL"]
EOF
echo

# ---------------- Q20: cachelayer redis pod NOT created (user creates it) ----------------
echo "Q20: Namespace cachelayer ready (you will create Pod redis32)."
echo

# ---------------- Q21: netpol-chain pods WRONG labels + policies CORRECT ----------------
echo "Q21: Creating netpol-chain pods with wrong labels + correct NetworkPolicies..."
kubectl apply -n netpol-chain -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  labels:
    role: wrong-frontend
spec:
  containers:
    - name: app
      image: nginx
---
apiVersion: v1
kind: Pod
metadata:
  name: backend
  labels:
    role: wrong-backend
spec:
  containers:
    - name: app
      image: nginx
---
apiVersion: v1
kind: Pod
metadata:
  name: database
  labels:
    role: wrong-db
spec:
  containers:
    - name: app
      image: nginx
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes: ["Ingress"]
  ingress: []
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
spec:
  podSelector:
    matchLabels:
      role: backend
  policyTypes: ["Ingress"]
  ingress:
    - from:
        - podSelector:
            matchLabels:
              role: frontend
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-db
spec:
  podSelector:
    matchLabels:
      role: db
  policyTypes: ["Ingress"]
  ingress:
    - from:
        - podSelector:
            matchLabels:
              role: backend
EOF
echo

# ---------------- Q22: dashboard deployment paused ----------------
echo "Q22: Creating paused dashboard deployment..."
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dashboard
  namespace: default
spec:
  paused: true
  replicas: 2
  selector:
    matchLabels:
      app: dashboard
  template:
    metadata:
      labels:
        app: dashboard
    spec:
      containers:
        - name: web
          image: nginx:1.23
EOF
echo

# ---------------- Q23: ExternalName service NOT created (user creates it) ----------------
echo "Q23: No ExternalName service created (you will create external-db)."
echo

# ---------------- Q24: hourly-report CronJob misconfigured ----------------
echo "Q24: Creating hourly-report CronJob with wrong restartPolicy/backoffLimit..."
kubectl apply -f - <<'EOF'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hourly-report
  namespace: default
spec:
  schedule: "0 * * * *"
  jobTemplate:
    spec:
      backoffLimit: 5
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: report
              image: busybox
              command: ["/bin/sh","-c"]
              args: ["echo hourly report"]
EOF
echo

# ---------------- Q25: broken-app manifest (file only) ----------------
echo "Q25: Writing broken deployment manifest to ${BASE_DIR}/broken-app.yaml..."
cat > "${BASE_DIR}/broken-app.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broken-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: something-else
  template:
    metadata:
      labels:
        app: fixed-app
    spec:
      containers:
        - name: web
          image: nginx
EOF
echo "NOTE: broken-app.yaml is intentionally mismatched. You'll fix & apply it."
echo

# ---------------- Q26: cronlab quick-exit CronJob prepared for checker ----------------
echo "Q26: Creating cronlab CronJob quick-exit with activeDeadlineSeconds=8..."
kubectl apply -n cronlab -f - <<'EOF'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: quick-exit
spec:
  schedule: "*/5 * * * *"
  jobTemplate:
    spec:
      activeDeadlineSeconds: 8
      backoffLimit: 1
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: runner
              image: busybox
              command: ["/bin/sh","-c"]
              args:
                - |
                  echo "starting endless loop"
                  while true; do
                    date
                    sleep 1
                  done
EOF

kubectl delete job quick-exit-manual -n cronlab --ignore-not-found >/dev/null 2>&1 || true
kubectl create job quick-exit-manual --from=cronjob/quick-exit -n cronlab >/dev/null 2>&1 || true

echo "Waiting for quick-exit-manual to stop..."
for i in $(seq 1 20); do
  succeeded="$(kubectl get job quick-exit-manual -n cronlab -o jsonpath='{.status.succeeded}' 2>/dev/null || echo 0)"
  failed="$(kubectl get job quick-exit-manual -n cronlab -o jsonpath='{.status.failed}' 2>/dev/null || echo 0)"
  if [ "${succeeded:-0}" != "0" ] || [ "${failed:-0}" != "0" ]; then
    break
  fi
  sleep 1
done
echo

# ---------------- Q27: web-svc exists on 8080 (ingress created by user) ----------------
echo "Q27: Creating web deployment + web-svc (port 8080) for host/path ingress task..."
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app-8080
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-8080
  template:
    metadata:
      labels:
        app: web-8080
    spec:
      containers:
        - name: web
          image: nginx
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: web-svc
  namespace: default
spec:
  selector:
    app: web-8080
  ports:
    - port: 8080
      targetPort: 8080
EOF
echo "NOTE: You will create Ingress 'web-ingress' for host example.com and path /path."
echo

# ---------------- Q28: ResourceQuota + violating deployment (limits namespace) ----------------
echo "Q28: Creating namespace limits ResourceQuota + a Deployment that violates it..."
kubectl apply -n limits -f - <<'EOF'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: limits-quota
spec:
  hard:
    pods: "5"
    requests.cpu: "200m"
    requests.memory: "256Mi"
    limits.cpu: "400m"
    limits.memory: "512Mi"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: quota-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: quota-app
  template:
    metadata:
      labels:
        app: quota-app
    spec:
      containers:
        - name: app
          image: nginx
          resources:
            requests:
              cpu: "300m"
              memory: "300Mi"
            limits:
              cpu: "600m"
              memory: "600Mi"
EOF
echo

# ---------------- Q29: LimitRange + violating deployment (limits namespace) ----------------
echo "Q29: Creating LimitRange + Deployment with non-compliant requests/limits..."
kubectl apply -n limits -f - <<'EOF'
apiVersion: v1
kind: LimitRange
metadata:
  name: limits-lr
spec:
  limits:
    - type: Container
      max:
        cpu: "200m"
        memory: "256Mi"
      min:
        cpu: "50m"
        memory: "64Mi"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lr-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: lr-app
  template:
    metadata:
      labels:
        app: lr-app
    spec:
      containers:
        - name: app
          image: nginx
          resources:
            requests:
              cpu: "500m"
              memory: "512Mi"
            limits:
              cpu: "700m"
              memory: "768Mi"
EOF
echo

# ---------------- Q30: ratio-app wrong limits (prod namespace) ----------------
echo "Q30: Creating prod Deployment requiring ratio fix (limits must be exactly 2x requests)..."
kubectl apply -n prod -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ratio-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ratio-app
  template:
    metadata:
      labels:
        app: ratio-app
    spec:
      containers:
        - name: app
          image: nginx
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
EOF
echo

echo "=== CKAD practice environment prep COMPLETE (Q1–Q30) ==="
echo "Manifests written under: ${BASE_DIR}"
echo "Files:"
echo "  - ${BASE_DIR}/old.yaml"
echo "  - ${BASE_DIR}/client-ingress.yaml"
echo "  - ${BASE_DIR}/broken-app.yaml"
echo "  - ${BASE_DIR}/api-app/Dockerfile"
echo
echo "NOTES:"
echo "  - Q13 metrics-job is intentionally WRONG now (it should FAIL until you fix it)."
echo "  - Q18 client-ingress.yaml is intentionally invalid (you apply & fix)."
echo "  - Q20/Q23 are 'create from scratch' (no objects created)."
echo "  - Q26 prepared with activeDeadlineSeconds=8 and quick-exit-manual created."
