#!/usr/bin/env bash
# CKAD UPDATED Practice – Auto Checker (check.sh)
# Run this AFTER:
#   ./prep.sh
# And after you've attempted the tasks.

set -euo pipefail

PASSED=0
TOTAL=30

green()  { printf "\e[32m%s\e[0m\n" "$1"; }
red()    { printf "\e[31m%s\e[0m\n" "$1"; }

pass() {
  local q="$1"; shift
  green "Q$q: PASS - $*"
  PASSED=$((PASSED+1))
}

fail() {
  local q="$1"; shift
  red "Q$q: FAIL - $*"
}

# ---------------- Q1: billing-api env -> Secret billing-secret ----------------
check_q1() {
  local ok=1

  local user_key pass_key
  user_key=$(kubectl get secret billing-secret -n default -o jsonpath='{.data.DB_USER}' 2>/dev/null || echo "")
  pass_key=$(kubectl get secret billing-secret -n default -o jsonpath='{.data.DB_PASS}' 2>/dev/null || echo "")
  [[ -z "$user_key" || -z "$pass_key" ]] && ok=0

  local user_secret pass_secret
  user_secret=$(kubectl get deploy billing-api -n default \
    -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="DB_USER")].valueFrom.secretKeyRef.name}' 2>/dev/null || echo "")
  pass_secret=$(kubectl get deploy billing-api -n default \
    -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="DB_PASS")].valueFrom.secretKeyRef.name}' 2>/dev/null || echo "")
  [[ "$user_secret" != "billing-secret" ]] && ok=0
  [[ "$pass_secret" != "billing-secret" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 1 "billing-secret created and billing-api uses secretKeyRef for DB_USER/DB_PASS"
  else
    fail 1 "Secret and/or env secretKeyRef not configured correctly for billing-api"
  fi
}

# ---------------- Q2: store-ingress fixed to store-svc:8080 Prefix /shop ----------------
check_q2() {
  local name port path pt ok=1
  path=$(kubectl get ingress store-ingress -n default -o jsonpath='{.spec.rules[0].http.paths[0].path}' 2>/dev/null || echo "")
  pt=$(kubectl get ingress store-ingress -n default -o jsonpath='{.spec.rules[0].http.paths[0].pathType}' 2>/dev/null || echo "")
  name=$(kubectl get ingress store-ingress -n default -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' 2>/dev/null || echo "")
  port=$(kubectl get ingress store-ingress -n default -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' 2>/dev/null || echo "")

  [[ "$path" != "/shop" ]] && ok=0
  [[ "$pt" != "Prefix" ]] && ok=0
  [[ "$name" != "store-svc" ]] && ok=0
  [[ "$port" != "8080" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 2 "store-ingress routes /shop (Prefix) to store-svc:8080"
  else
    fail 2 "store-ingress not correctly configured (path/pathType/service/port)"
  fi
}

# ---------------- Q3: internal-api-ingress ----------------
check_q3() {
  local host name port ok=1
  host=$(kubectl get ingress internal-api-ingress -n default -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "")
  name=$(kubectl get ingress internal-api-ingress -n default -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' 2>/dev/null || echo "")
  port=$(kubectl get ingress internal-api-ingress -n default -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' 2>/dev/null || echo "")

  [[ "$host" != "internal.company.local" ]] && ok=0
  [[ "$name" != "internal-api-svc" ]] && ok=0
  [[ "$port" != "3000" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 3 "internal-api-ingress correctly routes internal.company.local/ -> internal-api-svc:3000"
  else
    fail 3 "internal-api-ingress host/service/port not configured correctly"
  fi
}

# ---------------- Q4: RBAC for dev-deployment in meta ----------------
check_q4() {
  local ok=1

  kubectl get sa dev-sa -n meta >/dev/null 2>&1 || ok=0

  local verbs resources api_groups
  verbs=$(kubectl get role dev-deploy-role -n meta -o jsonpath='{.rules[0].verbs}' 2>/dev/null || echo "")
  resources=$(kubectl get role dev-deploy-role -n meta -o jsonpath='{.rules[0].resources}' 2>/dev/null || echo "")
  api_groups=$(kubectl get role dev-deploy-role -n meta -o jsonpath='{.rules[0].apiGroups}' 2>/dev/null || echo "")

  echo "$resources"   | grep -q "deployments" || ok=0
  echo "$api_groups"  | grep -q "apps"        || ok=0
  echo "$verbs"       | grep -q "get"         || ok=0
  echo "$verbs"       | grep -q "list"        || ok=0
  echo "$verbs"       | grep -q "watch"       || ok=0

  local rb_sa
  rb_sa=$(kubectl get rolebinding dev-deploy-rb -n meta -o jsonpath='{.subjects[0].name}' 2>/dev/null || echo "")
  [[ "$rb_sa" != "dev-sa" ]] && ok=0

  local pod_sa
  pod_sa=$(kubectl get deploy dev-deployment -n meta -o jsonpath='{.spec.template.spec.serviceAccountName}' 2>/dev/null || echo "")
  [[ "$pod_sa" != "dev-sa" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 4 "RBAC fixed (dev-sa + dev-deploy-role + dev-deploy-rb) and deployment updated"
  else
    fail 4 "RBAC not correctly configured for dev-deployment"
  fi
}

# ---------------- Q5: startup-pod fixed with initContainer + emptyDir ----------------
check_q5() {
  local ok=1

  local phase
  phase=$(kubectl get pod startup-pod -n default -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  [[ "$phase" != "Running" ]] && ok=0

  local init_names
  init_names=$(kubectl get pod startup-pod -n default -o jsonpath='{.spec.initContainers[*].name}' 2>/dev/null || echo "")
  [[ -z "$init_names" ]] && ok=0

  local vol_name main_mount
  vol_name=$(kubectl get pod startup-pod -n default -o jsonpath='{.spec.volumes[?(@.emptyDir)].name}' 2>/dev/null || echo "")
  main_mount=$(kubectl get pod startup-pod -n default -o jsonpath='{.spec.containers[0].volumeMounts[?(@.mountPath=="/app")].mountPath}' 2>/dev/null || echo "")

  [[ -z "$vol_name" ]] && ok=0
  [[ "$main_mount" != "/app" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 5 "startup-pod Running with initContainer + emptyDir mounted at /app"
  else
    fail 5 "startup-pod not correctly fixed (initContainer/volume/mount/state)"
  fi
}

# ---------------- Q6: Docker image api-app:2.1 built & /root/api-app.tar ----------------
check_q6() {
  local ok=1

  # MD requires /root/api-app.tar
  [[ -f "/root/api-app.tar" ]] || ok=0

  if command -v docker >/dev/null 2>&1; then
    docker image inspect api-app:2.1 >/dev/null 2>&1 || ok=0
  fi

  if [[ $ok -eq 1 ]]; then
    pass 6 "api-app:2.1 exists and image tar found at /root/api-app.tar"
  else
    fail 6 "Expected api-app:2.1 and /root/api-app.tar (OCI archive) but missing"
  fi
}

# ---------------- Q7: resource-pod + dev-quota ----------------
check_q7() {
  local ok=1

  local req_cpu req_mem lim_cpu lim_mem
  req_cpu=$(kubectl get pod resource-pod -n dev -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "")
  req_mem=$(kubectl get pod resource-pod -n dev -o jsonpath='{.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "")
  lim_cpu=$(kubectl get pod resource-pod -n dev -o jsonpath='{.spec.containers[0].resources.limits.cpu}' 2>/dev/null || echo "")
  lim_mem=$(kubectl get pod resource-pod -n dev -o jsonpath='{.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "")

  [[ "$req_cpu" != "200m" ]] && ok=0
  [[ "$req_mem" != "128Mi" ]] && ok=0
  [[ "$lim_cpu" != "500m" ]] && ok=0
  [[ "$lim_mem" != "256Mi" ]] && ok=0

  local pods cpu mem
  pods=$(kubectl get resourcequota dev-quota -n dev -o jsonpath='{.spec.hard.pods}' 2>/dev/null || echo "")
  cpu=$(kubectl get resourcequota dev-quota -n dev -o jsonpath='{.spec.hard.requests\.cpu}' 2>/dev/null || echo "")
  mem=$(kubectl get resourcequota dev-quota -n dev -o jsonpath='{.spec.hard.requests\.memory}' 2>/dev/null || echo "")

  [[ "$pods" != "10" ]] && ok=0
  [[ "$cpu"  != "2" ]] && ok=0
  [[ "$mem"  != "4Gi" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 7 "resource-pod resources and dev-quota set correctly in dev"
  else
    fail 7 "resource-pod and/or dev-quota not set correctly"
  fi
}

# ---------------- Q8: old-deploy fixed from /root/old.yaml ----------------
check_q8() {
  local ok=1

  kubectl get deploy old-deploy -n default >/dev/null 2>&1 || ok=0

  local api
  api=$(kubectl get deploy old-deploy -n default -o jsonpath='{.apiVersion}' 2>/dev/null || echo "")
  [[ "$api" != "apps/v1" ]] && ok=0

  local sel_app
  sel_app=$(kubectl get deploy old-deploy -n default -o jsonpath='{.spec.selector.matchLabels.app}' 2>/dev/null || echo "")
  [[ "$sel_app" != "old-app" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 8 "old-deploy applied successfully (apps/v1 + selector present)"
  else
    fail 8 "old-deploy not correctly fixed/applied"
  fi
}

# ---------------- Q9: app-canary ----------------
check_q9() {
  local ok=1

  kubectl get deploy app-canary -n default >/dev/null 2>&1 || ok=0

  local app_canary ver_canary replicas
  app_canary=$(kubectl get deploy app-canary -n default -o jsonpath='{.spec.template.metadata.labels.app}' 2>/dev/null || echo "")
  ver_canary=$(kubectl get deploy app-canary -n default -o jsonpath='{.spec.template.metadata.labels.version}' 2>/dev/null || echo "")
  replicas=$(kubectl get deploy app-canary -n default -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "")

  [[ "$app_canary" != "core" ]] && ok=0
  [[ "$ver_canary" != "v2" ]] && ok=0
  [[ "$replicas" != "1" ]] && ok=0

  local sel_app
  sel_app=$(kubectl get svc app-svc -n default -o jsonpath='{.spec.selector.app}' 2>/dev/null || echo "")
  [[ "$sel_app" != "core" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 9 "app-canary exists (replicas=1, app=core, version=v2) behind app-svc selector app=core"
  else
    fail 9 "app-canary and/or service selector not correct"
  fi
}

# ---------------- Q10: web-app-svc selector ----------------
check_q10() {
  local selector
  selector=$(kubectl get svc web-app-svc -n default -o jsonpath='{.spec.selector.app}' 2>/dev/null || echo "")

  if [[ "$selector" == "webapp" ]]; then
    pass 10 "web-app-svc correctly selects app=webapp"
  else
    fail 10 "web-app-svc selector not matching app=webapp"
  fi
}

# ---------------- Q11: healthz livenessProbe ----------------
check_q11() {
  local ok=1
  local path port delay
  path=$(kubectl get pod healthz -n default -o jsonpath='{.spec.containers[0].livenessProbe.httpGet.path}' 2>/dev/null || echo "")
  port=$(kubectl get pod healthz -n default -o jsonpath='{.spec.containers[0].livenessProbe.httpGet.port}' 2>/dev/null || echo "")
  delay=$(kubectl get pod healthz -n default -o jsonpath='{.spec.containers[0].livenessProbe.initialDelaySeconds}' 2>/dev/null || echo "")

  [[ "$path"  != "/healthz" ]] && ok=0
  [[ "$port"  != "80" ]] && ok=0
  [[ "$delay" != "5" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 11 "healthz has correct livenessProbe (/healthz, 80, delay=5)"
  else
    fail 11 "healthz livenessProbe not configured correctly"
  fi
}

# ---------------- Q12: shop-api readinessProbe ----------------
check_q12() {
  local ok=1
  local path port delay
  path=$(kubectl get deploy shop-api -n default -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}' 2>/dev/null || echo "")
  port=$(kubectl get deploy shop-api -n default -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.port}' 2>/dev/null || echo "")
  delay=$(kubectl get deploy shop-api -n default -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.initialDelaySeconds}' 2>/dev/null || echo "")

  [[ "$path"  != "/ready" ]] && ok=0
  [[ "$port"  != "8080" ]] && ok=0
  [[ "$delay" != "5" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 12 "shop-api has readinessProbe (/ready, 8080, delay=5)"
  else
    fail 12 "shop-api readinessProbe not configured correctly"
  fi
}

# ---------------- Q13: metrics-job CronJob ----------------
check_q13() {
  local ok=1
  local schedule image comps parall backoff rp

  schedule=$(kubectl get cronjob metrics-job -n default -o jsonpath='{.spec.schedule}' 2>/dev/null || echo "")
  image=$(kubectl get cronjob metrics-job -n default -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].image}' 2>/dev/null || echo "")
  comps=$(kubectl get cronjob metrics-job -n default -o jsonpath='{.spec.jobTemplate.spec.completions}' 2>/dev/null || echo "")
  parall=$(kubectl get cronjob metrics-job -n default -o jsonpath='{.spec.jobTemplate.spec.parallelism}' 2>/dev/null || echo "")
  backoff=$(kubectl get cronjob metrics-job -n default -o jsonpath='{.spec.jobTemplate.spec.backoffLimit}' 2>/dev/null || echo "")
  rp=$(kubectl get cronjob metrics-job -n default -o jsonpath='{.spec.jobTemplate.spec.template.spec.restartPolicy}' 2>/dev/null || echo "")

  [[ "$schedule" != "* * * * *" ]] && ok=0
  [[ "$image"    != "busybox" ]] && ok=0
  [[ "$comps"    != "4" ]] && ok=0
  [[ "$parall"   != "2" ]] && ok=0
  [[ "$backoff"  != "3" ]] && ok=0
  [[ "$rp"       != "Never" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 13 "metrics-job CronJob configured correctly"
  else
    fail 13 "metrics-job CronJob not set as required (schedule/image/completions/parallelism/backoff/restartPolicy)"
  fi
}

# ---------------- Q14: audit-runner RBAC ----------------
check_q14() {
  local ok=1

  kubectl get sa audit-sa -n default >/dev/null 2>&1 || ok=0

  local verbs resources
  verbs=$(kubectl get role audit-role -n default -o jsonpath='{.rules[0].verbs}' 2>/dev/null || echo "")
  resources=$(kubectl get role audit-role -n default -o jsonpath='{.rules[0].resources}' 2>/dev/null || echo "")

  echo "$resources" | grep -q "pods"  || ok=0
  echo "$verbs"     | grep -q "get"   || ok=0
  echo "$verbs"     | grep -q "list"  || ok=0
  echo "$verbs"     | grep -q "watch" || ok=0

  local rb_sa
  rb_sa=$(kubectl get rolebinding audit-rb -n default -o jsonpath='{.subjects[0].name}' 2>/dev/null || echo "")
  [[ "$rb_sa" != "audit-sa" ]] && ok=0

  local pod_sa
  pod_sa=$(kubectl get pod audit-runner -n default -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null || echo "")
  [[ "$pod_sa" != "audit-sa" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 14 "audit-runner fixed with audit-sa + audit-role + audit-rb"
  else
    fail 14 "audit-runner RBAC not correctly configured"
  fi
}

# ---------------- Q15: winter logs -> /opt/winter/logs.txt ----------------
check_q15() {
  local ok=1

  if [[ ! -f /opt/winter/logs.txt ]]; then
    ok=0
  else
    [[ ! -s /opt/winter/logs.txt ]] && ok=0
  fi

  if [[ $ok -eq 1 ]]; then
    pass 15 "/opt/winter/logs.txt exists and contains logs"
  else
    fail 15 "winter logs file /opt/winter/logs.txt missing or empty"
  fi
}

# ---------------- Q16: highest CPU pod name -> /opt/winter/highest.txt ----------------
check_q16() {
  local ok=1

  if [[ ! -f /opt/winter/highest.txt ]]; then
    ok=0
  else
    local name
    name=$(head -n1 /opt/winter/highest.txt | tr -d '[:space:]')
    [[ -z "$name" ]] && ok=0
    kubectl get pod "$name" -n cpu-load >/dev/null 2>&1 || ok=0
  fi

  if [[ $ok -eq 1 ]]; then
    pass 16 "highest CPU pod name written to /opt/winter/highest.txt and exists in cpu-load"
  else
    fail 16 "highest CPU pod name not correctly written to /opt/winter/highest.txt"
  fi
}

# ---------------- Q17: video-svc NodePort ----------------
check_q17() {
  local ok=1
  local type sel_app port tport
  type=$(kubectl get svc video-svc -n default -o jsonpath='{.spec.type}' 2>/dev/null || echo "")
  sel_app=$(kubectl get svc video-svc -n default -o jsonpath='{.spec.selector.app}' 2>/dev/null || echo "")
  port=$(kubectl get svc video-svc -n default -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "")
  tport=$(kubectl get svc video-svc -n default -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null || echo "")

  [[ "$type" != "NodePort" ]] && ok=0
  [[ "$sel_app" != "video-api" ]] && ok=0
  [[ "$port" != "80" ]] && ok=0
  [[ "$tport" != "9090" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 17 "video-svc correctly exposes video-api as NodePort 80->9090"
  else
    fail 17 "video-svc not correctly configured (type/selector/ports)"
  fi
}

# ---------------- Q18: client-ingress fixed pathType Prefix + backend ----------------
check_q18() {
  local ok=1
  local pt name port path

  path=$(kubectl get ingress client-ingress -n default -o jsonpath='{.spec.rules[0].http.paths[0].path}' 2>/dev/null || echo "")
  pt=$(kubectl get ingress client-ingress -n default -o jsonpath='{.spec.rules[0].http.paths[0].pathType}' 2>/dev/null || echo "")
  name=$(kubectl get ingress client-ingress -n default -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' 2>/dev/null || echo "")
  port=$(kubectl get ingress client-ingress -n default -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' 2>/dev/null || echo "")

  [[ "$path" != "/" ]] && ok=0
  [[ "$pt" != "Prefix" ]] && ok=0
  [[ "$name" != "client-svc" ]] && ok=0
  [[ "$port" != "80" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 18 "client-ingress fixed: / (Prefix) -> client-svc:80"
  else
    fail 18 "client-ingress incorrect (expected path=/, pathType=Prefix, backend client-svc:80)"
  fi
}

# ---------------- Q19: syncer securityContext ----------------
check_q19() {
  local ok=1
  local runas caps

  runas=$(kubectl get deploy syncer -n default \
    -o jsonpath='{.spec.template.spec.securityContext.runAsUser}' 2>/dev/null || echo "")
  caps=$(kubectl get deploy syncer -n default \
    -o jsonpath='{.spec.template.spec.containers[0].securityContext.capabilities.add}' 2>/dev/null || echo "")

  [[ "$runas" != "1000" ]] && ok=0
  echo "$caps" | grep -q "NET_ADMIN" || ok=0

  if [[ $ok -eq 1 ]]; then
    pass 19 "syncer has Pod runAsUser=1000 and NET_ADMIN capability on container"
  else
    fail 19 "syncer securityContext not correctly configured"
  fi
}

# ---------------- Q20: redis32 pod in cachelayer ----------------
check_q20() {
  local ok=1
  local image port

  kubectl get pod redis32 -n cachelayer >/dev/null 2>&1 || ok=0
  image=$(kubectl get pod redis32 -n cachelayer -o jsonpath='{.spec.containers[0].image}' 2>/dev/null || echo "")
  port=$(kubectl get pod redis32 -n cachelayer -o jsonpath='{.spec.containers[0].ports[0].containerPort}' 2>/dev/null || echo "")

  echo "$image" | grep -q "redis:3.2" || ok=0
  [[ "$port" != "6379" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 20 "redis32 pod running redis:3.2 and exposing 6379 in cachelayer"
  else
    fail 20 "redis32 pod not correctly configured (image/port/ns)"
  fi
}

# ---------------- Q21: netpol-chain pod labels ----------------
check_q21() {
  local ok=1
  local f b d

  f=$(kubectl get pod frontend -n netpol-chain -o jsonpath='{.metadata.labels.role}' 2>/dev/null || echo "")
  b=$(kubectl get pod backend  -n netpol-chain -o jsonpath='{.metadata.labels.role}' 2>/dev/null || echo "")
  d=$(kubectl get pod database -n netpol-chain -o jsonpath='{.metadata.labels.role}' 2>/dev/null || echo "")

  [[ "$f" != "frontend" ]] && ok=0
  [[ "$b" != "backend"  ]] && ok=0
  [[ "$d" != "db"       ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 21 "netpol-chain pods relabeled correctly: frontend/backend/db"
  else
    fail 21 "netpol-chain pod role labels not set to frontend/backend/db"
  fi
}

# ---------------- Q22: dashboard rollout resumed with new image ----------------
check_q22() {
  local ok=1
  local paused image

  paused=$(kubectl get deploy dashboard -n default -o jsonpath='{.spec.paused}' 2>/dev/null || echo "")
  image=$(kubectl get deploy dashboard -n default -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "")

  [[ "$paused" == "true" ]] && ok=0
  [[ "$image" != "nginx:1.25" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 22 "dashboard deployment resumed and using nginx:1.25"
  else
    fail 22 "dashboard deployment not correctly resumed or image not updated"
  fi
}

# ---------------- Q23: external-db ExternalName ----------------
check_q23() {
  local ok=1
  local type name

  type=$(kubectl get svc external-db -n default -o jsonpath='{.spec.type}' 2>/dev/null || echo "")
  name=$(kubectl get svc external-db -n default -o jsonpath='{.spec.externalName}' 2>/dev/null || echo "")

  [[ "$type" != "ExternalName" ]] && ok=0
  [[ "$name" != "database.prod.internal" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 23 "external-db is ExternalName -> database.prod.internal"
  else
    fail 23 "external-db Service not correctly configured"
  fi
}

# ---------------- Q24: hourly-report CronJob restartPolicy/backoffLimit ----------------
check_q24() {
  local ok=1
  local rp backoff

  rp=$(kubectl get cronjob hourly-report -n default -o jsonpath='{.spec.jobTemplate.spec.template.spec.restartPolicy}' 2>/dev/null || echo "")
  backoff=$(kubectl get cronjob hourly-report -n default -o jsonpath='{.spec.jobTemplate.spec.backoffLimit}' 2>/dev/null || echo "")

  [[ "$rp" != "Never" ]] && ok=0
  [[ "$backoff" != "2" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 24 "hourly-report CronJob uses restartPolicy=Never and backoffLimit=2"
  else
    fail 24 "hourly-report CronJob not correctly adjusted (restartPolicy/backoffLimit)"
  fi
}

# ---------------- Q25: broken-app selector/labels match ----------------
check_q25() {
  local ok=1

  kubectl get deploy broken-app -n default >/dev/null 2>&1 || ok=0

  local sel_app tmpl_app
  sel_app=$(kubectl get deploy broken-app -n default -o jsonpath='{.spec.selector.matchLabels.app}' 2>/dev/null || echo "")
  tmpl_app=$(kubectl get deploy broken-app -n default -o jsonpath='{.spec.template.metadata.labels.app}' 2>/dev/null || echo "")

  if [[ -z "$sel_app" || -z "$tmpl_app" ]]; then
    ok=0
  elif [[ "$sel_app" != "$tmpl_app" ]]; then
    ok=0
  fi

  local ready
  ready=$(kubectl get deploy broken-app -n default -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  [[ -z "$ready" || "$ready" == "0" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 25 "broken-app fixed: selector matches template labels and pods are running"
  else
    fail 25 "broken-app still broken (selector/labels/pods)"
  fi
}

# ---------------- Q26: quick-exit must stop after ~8s + manual Job must complete ----------------
check_q26() {
  local ok=1

  kubectl get ns cronlab >/dev/null 2>&1 || ok=0
  kubectl get cronjob quick-exit -n cronlab >/dev/null 2>&1 || ok=0

  local ads
  ads=$(kubectl get cronjob quick-exit -n cronlab -o jsonpath='{.spec.jobTemplate.spec.activeDeadlineSeconds}' 2>/dev/null || echo "")
  [[ -z "$ads" ]] && ok=0

  if [[ -n "$ads" ]]; then
    if [[ "$ads" -lt 7 || "$ads" -gt 10 ]]; then
      ok=0
    fi
  fi

  # manual job should exist and be complete
  kubectl get job quick-exit-manual -n cronlab >/dev/null 2>&1 || ok=0
  local succeeded complete
  succeeded=$(kubectl get job quick-exit-manual -n cronlab -o jsonpath='{.status.succeeded}' 2>/dev/null || echo "0")
  complete=$(kubectl get job quick-exit-manual -n cronlab -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null || echo "")

  if [[ "${succeeded:-0}" -lt 1 && "$complete" != "True" ]]; then
    ok=0
  fi

  if [[ $ok -eq 1 ]]; then
    pass 26 "quick-exit has activeDeadlineSeconds ~8s AND quick-exit-manual Job completed"
  else
    fail 26 "quick-exit not set to ~8s and/or quick-exit-manual not completed"
  fi
}

# ---------------- Q27: Ingress with host+path example.com /path -> web-svc:8080 ----------------
check_q27() {
  local ok=1
  local host path pt name port

  kubectl get ingress web-ingress -n default >/dev/null 2>&1 || ok=0

  host=$(kubectl get ingress web-ingress -n default -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "")
  path=$(kubectl get ingress web-ingress -n default -o jsonpath='{.spec.rules[0].http.paths[0].path}' 2>/dev/null || echo "")
  pt=$(kubectl get ingress web-ingress -n default -o jsonpath='{.spec.rules[0].http.paths[0].pathType}' 2>/dev/null || echo "")
  name=$(kubectl get ingress web-ingress -n default -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' 2>/dev/null || echo "")
  port=$(kubectl get ingress web-ingress -n default -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' 2>/dev/null || echo "")

  [[ "$host" != "example.com" ]] && ok=0
  [[ "$path" != "/path" ]] && ok=0
  case "$pt" in
    Prefix|Exact|ImplementationSpecific) : ;;
    *) ok=0 ;;
  esac
  [[ "$name" != "web-svc" ]] && ok=0
  [[ "$port" != "8080" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 27 "web-ingress routes example.com/path -> web-svc:8080 with valid pathType"
  else
    fail 27 "web-ingress not correct (expected host example.com, path /path, backend web-svc:8080)"
  fi
}

# ---------------- Q28: Fix quota-app so it fits limits-quota ----------------
check_q28() {
  local ok=1

  kubectl get resourcequota limits-quota -n limits >/dev/null 2>&1 || ok=0
  kubectl get deploy quota-app -n limits >/dev/null 2>&1 || ok=0

  local rcpu rmem lcpu lmem
  rcpu=$(kubectl get deploy quota-app -n limits -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "")
  rmem=$(kubectl get deploy quota-app -n limits -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "")
  lcpu=$(kubectl get deploy quota-app -n limits -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' 2>/dev/null || echo "")
  lmem=$(kubectl get deploy quota-app -n limits -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "")

  [[ -z "$rcpu" || -z "$rmem" || -z "$lcpu" || -z "$lmem" ]] && ok=0

  case "$rcpu" in 50m|100m|150m|200m) : ;; *) ok=0 ;; esac
  case "$lcpu" in 100m|200m|300m|400m) : ;; *) ok=0 ;; esac
  case "$rmem" in 64Mi|128Mi|192Mi|256Mi) : ;; *) ok=0 ;; esac
  case "$lmem" in 128Mi|256Mi|384Mi|512Mi) : ;; *) ok=0 ;; esac

  local ready
  ready=$(kubectl get deploy quota-app -n limits -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  [[ -z "$ready" || "$ready" == "0" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 28 "quota-app now fits ResourceQuota and has ready replicas"
  else
    fail 28 "quota-app still violates quota or has no ready replicas (adjust resources down)"
  fi
}

# ---------------- Q29: Fix lr-app so it complies with LimitRange limits-lr ----------------
check_q29() {
  local ok=1

  kubectl get limitrange limits-lr -n limits >/dev/null 2>&1 || ok=0
  kubectl get deploy lr-app -n limits >/dev/null 2>&1 || ok=0

  local rcpu rmem lcpu lmem
  rcpu=$(kubectl get deploy lr-app -n limits -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "")
  rmem=$(kubectl get deploy lr-app -n limits -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "")
  lcpu=$(kubectl get deploy lr-app -n limits -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' 2>/dev/null || echo "")
  lmem=$(kubectl get deploy lr-app -n limits -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "")

  [[ -z "$rcpu" || -z "$rmem" || -z "$lcpu" || -z "$lmem" ]] && ok=0

  case "$rcpu" in 50m|75m|100m|150m|200m) : ;; *) ok=0 ;; esac
  case "$lcpu" in 50m|75m|100m|150m|200m) : ;; *) ok=0 ;; esac
  case "$rmem" in 64Mi|96Mi|128Mi|192Mi|256Mi) : ;; *) ok=0 ;; esac
  case "$lmem" in 64Mi|96Mi|128Mi|192Mi|256Mi) : ;; *) ok=0 ;; esac

  local ready
  ready=$(kubectl get deploy lr-app -n limits -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  [[ -z "$ready" || "$ready" == "0" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 29 "lr-app now complies with LimitRange and has ready replicas"
  else
    fail 29 "lr-app still violates LimitRange or has no ready replicas"
  fi
}

# ---------------- Q30: Fix ratio-app so limits are exactly 2x requests ----------------
check_q30() {
  local ok=1

  kubectl get deploy ratio-app -n prod >/dev/null 2>&1 || ok=0

  local rcpu rmem lcpu lmem
  rcpu=$(kubectl get deploy ratio-app -n prod -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "")
  rmem=$(kubectl get deploy ratio-app -n prod -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "")
  lcpu=$(kubectl get deploy ratio-app -n prod -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' 2>/dev/null || echo "")
  lmem=$(kubectl get deploy ratio-app -n prod -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "")

  [[ "$rcpu" != "100m" ]] && ok=0
  [[ "$rmem" != "128Mi" ]] && ok=0
  [[ "$lcpu" != "200m" ]] && ok=0
  [[ "$lmem" != "256Mi" ]] && ok=0

  local ready
  ready=$(kubectl get deploy ratio-app -n prod -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  [[ -z "$ready" || "$ready" == "0" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 30 "ratio-app limits are exactly 2x requests (cpu=200m, mem=256Mi) and pod is ready"
  else
    fail 30 "ratio-app ratio incorrect. Set limits to cpu=200m, mem=256Mi"
  fi
}

echo "=== CKAD Practice Checker (${TOTAL} Tasks) ==="

check_q1
check_q2
check_q3
check_q4
check_q5
check_q6
check_q7
check_q8
check_q9
check_q10
check_q11
check_q12
check_q13
check_q14
check_q15
check_q16
check_q17
check_q18
check_q19
check_q20
check_q21
check_q22
check_q23
check_q24
check_q25
check_q26
check_q27
check_q28
check_q29
check_q30

echo "========================================"
echo "Passed: $PASSED / $TOTAL"
PCT=$(( PASSED * 100 / TOTAL ))
echo "Score: ${PCT}%"
