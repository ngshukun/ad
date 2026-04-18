#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-/etc/kubernetes/admin.conf}"
export EDITOR="${EDITOR:-vi}"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

log() {
  printf '%b\n' "$1"
}

info() {
  log "${BLUE}[INFO]${NC} $1"
}

ok() {
  log "${GREEN}[OK]${NC} $1"
}

warn() {
  log "${YELLOW}[WARN]${NC} $1"
}

fail() {
  log "${RED}[FAIL]${NC} $1"
}

section() {
  log ""
  log "${BOLD}============================================================${NC}"
  log "${BOLD}$1${NC}"
  log "${BOLD}============================================================${NC}"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    fail "Required command not found: $1"
    exit 1
  }
}

ensure_file_parent() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
}

seed_file_if_missing() {
  local path="$1"
  local content="$2"
  ensure_file_parent "$path"
  if [[ ! -f "$path" ]]; then
    cat >"$path" <<EOF
$content
EOF
    ok "Created $path"
  else
    info "$path already exists"
  fi
}

question_ready() {
  log ""
  ok "Q$1 prep helper ready"
}

q1() { section "Q1 - Secret Refactor"; info "Target Deployment: billing-api"; question_ready 1; }
q2() { section "Q2 - Ingress Repair"; info "Target Ingress: store-ingress"; question_ready 2; }
q3() { section "Q3 - Create Ingress"; info "Target file path: /tmp/internal-api-ingress.yaml"; question_ready 3; }
q4() { section "Q4 - RBAC Debug"; info "Namespace: meta"; question_ready 4; }
q5() { section "Q5 - ConfigMap Mount"; info "Target Deployment: report-app"; question_ready 5; }
q6() { section "Q6 - Liveness Probe"; info "Target Deployment: api-health"; question_ready 6; }
q7() { section "Q7 - Readiness Probe"; info "Target Deployment: checkout"; question_ready 7; }
q8() { section "Q8 - Rolling Update"; info "Target Deployment: shop-front"; question_ready 8; }
q9() { section "Q9 - Rollback"; info "Target Deployment: image-service"; question_ready 9; }
q10() { section "Q10 - Scale and Verify"; info "Target Deployment: inventory"; question_ready 10; }

q11() {
  section "Q11 - Job Creation"
  seed_file_if_missing "/home/candidate/ckad/job.yaml" "apiVersion: batch/v1\nkind: Job\nmetadata:\n  name: sample-job\n  namespace: default\nspec:\n  template:\n    spec:\n      restartPolicy: Never\n      containers:\n      - name: sample\n        image: busybox:1.36\n        command: [\"sh\", \"-c\", \"echo hello\"]"
  question_ready 11
}

q12() { section "Q12 - CronJob Schedule"; info "Target CronJob: backup-cron"; question_ready 12; }
q13() { section "Q13 - Multi-Container Pod"; info "Target Pod: logger-pod"; question_ready 13; }
q14() { section "Q14 - EmptyDir Sharing"; info "Target Pod: shared-data"; question_ready 14; }
q15() { section "Q15 - TLS ConfigMap"; info "Target ConfigMap: tls-settings"; question_ready 15; }
q16() { section "Q16 - Immutable ConfigMap"; info "Target ConfigMap: app-settings"; question_ready 16; }
q17() { section "Q17 - HPA"; info "Target Deployment: web-autoscale"; question_ready 17; }
q18() { section "Q18 - Service Annotation"; info "Target Service: public-api"; question_ready 18; }
q19() { section "Q19 - Helm Rollback"; info "Inspect helm history for the target release"; question_ready 19; }
q20() { section "Q20 - Pending Pod"; info "Use kubectl describe on the failing Pod"; question_ready 20; }
q21() { section "Q21 - Resource Pressure"; info "Inspect node and Pod resource usage"; question_ready 21; }
q22() { section "Q22 - Service Selector"; info "Compare Service selectors with Pod labels"; question_ready 22; }
q23() { section "Q23 - Init Container Failure"; info "Inspect init container logs"; question_ready 23; }
q24() { section "Q24 - Static Pod"; info "Target path: /etc/kubernetes/manifests"; question_ready 24; }
q25() { section "Q25 - Drain and Recover"; info "Drain the required node and restore scheduling"; question_ready 25; }
q26() { section "Q26 - DaemonSet"; info "Target DaemonSet: log-agent"; question_ready 26; }
q27() { section "Q27 - Security Context"; info "Patch the Pod spec securityContext"; question_ready 27; }
q28() { section "Q28 - Wrong Namespace"; info "Export, correct, and reapply the resource"; question_ready 28; }
q29() { section "Q29 - API Connectivity"; info "Follow kubectl connectivity troubleshooting steps"; question_ready 29; }
q30() { section "Q30 - Backup Validation"; info "Verify the required backup artifact"; question_ready 30; }

run_one() {
  case "${1:-}" in
    1) q1 ;;
    2) q2 ;;
    3) q3 ;;
    4) q4 ;;
    5) q5 ;;
    6) q6 ;;
    7) q7 ;;
    8) q8 ;;
    9) q9 ;;
    10) q10 ;;
    11) q11 ;;
    12) q12 ;;
    13) q13 ;;
    14) q14 ;;
    15) q15 ;;
    16) q16 ;;
    17) q17 ;;
    18) q18 ;;
    19) q19 ;;
    20) q20 ;;
    21) q21 ;;
    22) q22 ;;
    23) q23 ;;
    24) q24 ;;
    25) q25 ;;
    26) q26 ;;
    27) q27 ;;
    28) q28 ;;
    29) q29 ;;
    30) q30 ;;
    *)
      fail "Unknown question number: ${1:-missing}"
      info "Usage: ./prep.sh <1-30>"
      info "   or: ./prep.sh all"
      exit 1
      ;;
  esac
}

run_all() {
  q1; q2; q3; q4; q5; q6; q7; q8; q9; q10
  q11; q12; q13; q14; q15; q16; q17; q18; q19; q20
  q21; q22; q23; q24; q25; q26; q27; q28; q29; q30
}

main() {
  require_cmd kubectl

  if [[ $# -eq 0 ]]; then
    fail "No question number provided"
    info "Usage: ./prep.sh <1-30>"
    info "   or: ./prep.sh all"
    exit 1
  fi

  section "CKAD PREP HELPER"

  if [[ "$1" == "all" ]]; then
    run_all
    ok "All CKAD prep helper steps completed"
    exit 0
  fi

  run_one "$1"
  ok "CKAD prep helper completed"
}

main "$@"
