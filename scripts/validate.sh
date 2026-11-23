#!/usr/bin/env bash
# Checks the Lab 5 deployment and prints PASS or FAIL for each check.
NS=lab5; APP=pod-pulse; URL=http://localhost:8085
pass=0; fail=0
check() { # check "description" command...
  local d="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "PASS  $d"; pass=$((pass+1)); else echo "FAIL  $d"; fail=$((fail+1)); fi
}
jp() { kubectl -n $NS get deploy $APP -o jsonpath="$1"; }

check "namespace $NS exists" kubectl get ns $NS
check "deployment has all replicas ready" test "$(jp '{.status.readyReplicas}')" = "$(jp '{.spec.replicas}')"
check "strategy is RollingUpdate with maxSurge 1, maxUnavailable 0" \
  test "$(jp '{.spec.strategy.type}/{.spec.strategy.rollingUpdate.maxSurge}/{.spec.strategy.rollingUpdate.maxUnavailable}')" = "RollingUpdate/1/0"
check "readiness and liveness probes are set" test -n "$(jp '{.spec.template.spec.containers[0].readinessProbe.httpGet.path}{.spec.template.spec.containers[0].livenessProbe.httpGet.path}')"
check "cpu and memory requests are set" test -n "$(jp '{.spec.template.spec.containers[0].resources.requests.cpu}')"
check "running pods are on more than one node" test "$(kubectl -n $NS get pods -l app=$APP -o wide --no-headers | grep -v Terminating | awk '{print $7}' | sort -u | wc -l)" -ge 2
check "service is a LoadBalancer" test "$(kubectl -n $NS get svc $APP -o jsonpath='{.spec.type}')" = LoadBalancer
check "service has one endpoint per ready pod" test "$(kubectl -n $NS get endpointslices -l kubernetes.io/service-name=$APP -o jsonpath='{range .items[*].endpoints[?(@.conditions.ready==true)]}x{end}' | wc -c | tr -d ' ')" = "$(jp '{.status.readyReplicas}')"
check "app answers HTTP 200 on $URL" curl -sf $URL/api/info
check "20 requests are spread over 2+ pods" test "$(for i in $(seq 20); do curl -s $URL/api/info | sed 's/.*"pod":"\([^"]*\)".*/\1/'; echo; done | sort -u | wc -l)" -ge 2
check "ConfigMap greeting reaches the app" sh -c "curl -s $URL/api/info | grep -q 'Lab 5'"
check "running image is 2.0.0" test "$(jp '{.spec.template.spec.containers[0].image}')" = "localhost:5001/pod-pulse:2.0.0"
check "rollout history has 3 or more revisions" test "$(kubectl -n $NS rollout history deploy/$APP | grep -cE '^[0-9]+')" -ge 3
check "service DNS name resolves inside the cluster" kubectl -n $NS run dns-check --rm -i --restart=Never --image=busybox:1.36 -- nslookup $APP.$NS.svc.cluster.local
check "metrics-server reports pod CPU" kubectl -n $NS top pods

echo "----"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
