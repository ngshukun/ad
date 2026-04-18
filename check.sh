#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-/etc/kubernetes/admin.conf}"

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  printf "%b\n" "${GREEN}✔ PASS${NC} - $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  printf "%b\n" "${RED}✘ FAIL${NC} - $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

section() {
  printf "\n%b\n" "${BOLD}============================================================${NC}"
  printf "%b\n" "${BOLD}$1${NC}"
  printf "%b\n\n" "${BOLD}============================================================${NC}"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Required command not found: $1" >&2
    exit 1
  }
}

summary() {
  printf "\nPassed: %s\n" "$PASS_COUNT"
  printf "Failed: %s\n" "$FAIL_COUNT"
  if [[ "$FAIL_COUNT" -eq 0 ]]; then
    printf "Result: %b\n" "${GREEN}ALL CHECKS PASSED${NC}"
    return 0
  fi
  printf "Result: %b\n" "${RED}SOME CHECKS FAILED${NC}"
  return 1
}

check_q1() { section "Checking Q1 - Secret Refactor"; kubectl get secret billing-secret -n default >/dev/null 2>&1 && pass "billing-secret exists" || fail "billing-secret missing"; }
check_q2() { section "Checking Q2 - Ingress Repair"; kubectl get ingress store-ingress -n default >/dev/null 2>&1 && pass "store-ingress exists" || fail "store-ingress missing"; }
check_q3() { section "Checking Q3 - Create Ingress"; kubectl get ingress internal-api-ingress -n default >/dev/null 2>&1 && pass "internal-api-ingress exists" || fail "internal-api-ingress missing"; }
check_q4() { section "Checking Q4 - RBAC Debug"; kubectl get sa dev-sa -n meta >/dev/null 2>&1 && pass "dev-sa exists" || fail "dev-sa missing"; }
check_q5() { section "Checking Q5 - ConfigMap Mount"; kubectl get configmap >/dev/null 2>&1 && pass "ConfigMaps queryable" || fail "ConfigMaps unavailable"; }
check_q6() { section "Checking Q6 - Liveness Probe"; kubectl get deploy api-health -n default >/dev/null 2>&1 && pass "api-health exists" || fail "api-health missing"; }
check_q7() { section "Checking Q7 - Readiness Probe"; kubectl get deploy checkout -n default >/dev/null 2>&1 && pass "checkout exists" || fail "checkout missing"; }
check_q8() { section "Checking Q8 - Rolling Update"; kubectl get deploy shop-front -n default >/dev/null 2>&1 && pass "shop-front exists" || fail "shop-front missing"; }
check_q9() { section "Checking Q9 - Rollback"; kubectl get deploy image-service -n default >/dev/null 2>&1 && pass "image-service exists" || fail "image-service missing"; }
check_q10() { section "Checking Q10 - Scale and Verify"; kubectl get deploy inventory -n default >/dev/null 2>&1 && pass "inventory exists" || fail "inventory missing"; }
check_q11() { section "Checking Q11 - Job Creation"; kubectl get job >/dev/null 2>&1 && pass "Jobs queryable" || fail "Jobs unavailable"; }
check_q12() { section "Checking Q12 - CronJob Schedule"; kubectl get cronjob >/dev/null 2>&1 && pass "CronJobs queryable" || fail "CronJobs unavailable"; }
check_q13() { section "Checking Q13 - Multi-Container Pod"; kubectl get pod logger-pod -n default >/dev/null 2>&1 && pass "logger-pod exists" || fail "logger-pod missing"; }
check_q14() { section "Checking Q14 - EmptyDir Sharing"; kubectl get pod shared-data -n default >/dev/null 2>&1 && pass "shared-data exists" || fail "shared-data missing"; }
check_q15() { section "Checking Q15 - TLS ConfigMap"; kubectl get configmap tls-settings -n default >/dev/null 2>&1 && pass "tls-settings exists" || fail "tls-settings missing"; }
check_q16() { section "Checking Q16 - Immutable ConfigMap"; kubectl get configmap app-settings -n default >/dev/null 2>&1 && pass "app-settings exists" || fail "app-settings missing"; }
check_q17() { section "Checking Q17 - HPA"; kubectl get hpa >/dev/null 2>&1 && pass "HPA resources queryable" || fail "HPA resources unavailable"; }
check_q18() { section "Checking Q18 - Service Annotation"; kubectl get svc public-api -n default >/dev/null 2>&1 && pass "public-api exists" || fail "public-api missing"; }
check_q19() { section "Checking Q19 - Helm Rollback"; command -v helm >/dev/null 2>&1 && pass "helm available" || fail "helm not available"; }
check_q20() { section "Checking Q20 - Pending Pod"; kubectl get pods >/dev/null 2>&1 && pass "Pods queryable" || fail "Pods unavailable"; }
check_q21() { section "Checking Q21 - Resource Pressure"; kubectl get nodes >/dev/null 2>&1 && pass "Nodes queryable" || fail "Nodes unavailable"; }
check_q22() { section "Checking Q22 - Service Selector"; kubectl get svc >/dev/null 2>&1 && pass "Services queryable" || fail "Services unavailable"; }
check_q23() { section "Checking Q23 - Init Container Failure"; kubectl get pods >/dev/null 2>&1 && pass "Pods queryable" || fail "Pods unavailable"; }
check_q24() { section "Checking Q24 - Static Pod"; [[ -d /etc/kubernetes/manifests ]] && pass "/etc/kubernetes/manifests exists" || fail "/etc/kubernetes/manifests missing"; }
check_q25() { section "Checking Q25 - Drain and Recover"; kubectl get nodes >/dev/null 2>&1 && pass "Nodes queryable" || fail "Nodes unavailable"; }
check_q26() { section "Checking Q26 - DaemonSet"; kubectl get ds >/dev/null 2>&1 && pass "DaemonSets queryable" || fail "DaemonSets unavailable"; }
check_q27() { section "Checking Q27 - Security Context"; kubectl get pods >/dev/null 2>&1 && pass "Pods queryable" || fail "Pods unavailable"; }
check_q28() { section "Checking Q28 - Wrong Namespace"; kubectl config view --minify >/dev/null 2>&1 && pass "kubectl context available" || fail "kubectl context unavailable"; }
check_q29() { section "Checking Q29 - API Connectivity"; kubectl version --request-timeout=5s >/dev/null 2>&1 && pass "API server reachable" || fail "API server not reachable"; }
check_q30() { section "Checking Q30 - Backup Validation"; command -v etcdctl >/dev/null 2>&1 && pass "etcdctl available" || fail "etcdctl not available"; }

run_one() {
  case "${1:-}" in
    1) check_q1 ;;
    2) check_q2 ;;
    3) check_q3 ;;
    4) check_q4 ;;
    5) check_q5 ;;
    6) check_q6 ;;
    7) check_q7 ;;
    8) check_q8 ;;
    9) check_q9 ;;
    10) check_q10 ;;
    11) check_q11 ;;
    12) check_q12 ;;
    13) check_q13 ;;
    14) check_q14 ;;
    15) check_q15 ;;
    16) check_q16 ;;
    17) check_q17 ;;
    18) check_q18 ;;
    19) check_q19 ;;
    20) check_q20 ;;
    21) check_q21 ;;
    22) check_q22 ;;
    23) check_q23 ;;
    24) check_q24 ;;
    25) check_q25 ;;
    26) check_q26 ;;
    27) check_q27 ;;
    28) check_q28 ;;
    29) check_q29 ;;
    30) check_q30 ;;
    *)
      echo "Usage: ./check.sh <1-30>" >&2
      echo "   or: ./check.sh all" >&2
      exit 1
      ;;
  esac
}

run_all() {
  check_q1; check_q2; check_q3; check_q4; check_q5; check_q6; check_q7; check_q8; check_q9; check_q10
  check_q11; check_q12; check_q13; check_q14; check_q15; check_q16; check_q17; check_q18; check_q19; check_q20
  check_q21; check_q22; check_q23; check_q24; check_q25; check_q26; check_q27; check_q28; check_q29; check_q30
}

main() {
  require_cmd kubectl

  if [[ $# -eq 0 ]]; then
    echo "Usage: ./check.sh <1-30>" >&2
    echo "   or: ./check.sh all" >&2
    exit 1
  fi

  if [[ "$1" == "all" ]]; then
    run_all
    summary
    exit $?
  fi

  run_one "$1"
  summary
}

main "$@"
