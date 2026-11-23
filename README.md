# DevOps Lab 5: Kubernetes Deployments, Services, scaling and rolling updates

Samuel Shine (2547149), MCA, Christ University

Pod Pulse is a small Node.js web app that reports which pod answered each request. It runs on a
three-node Kubernetes cluster (Docker Desktop, v1.34) and is used to show:

- a Deployment with probes, resource limits and a RollingUpdate strategy (maxSurge 1, maxUnavailable 0)
- a LoadBalancer Service that spreads requests across replicas
- manual scaling with `kubectl scale` and automatic scaling with a HorizontalPodAutoscaler
- self-healing when a pod is deleted or its process dies
- a zero-downtime rolling update from 1.0.0 to 2.0.0
- a broken release (3.0.0-bad) that stalls safely, then `kubectl rollout undo`

## Layout

```
app/        Node.js app, page and Dockerfile
k8s/        namespace, ConfigMap, Deployment, Service, HPA
scripts/    traffic.sh (request logger used during updates), validate.sh (checks)
screenshots/
```

## Run it

```bash
docker run -d --name lab5-registry --restart unless-stopped -p 5001:5000 registry:2
docker build -t localhost:5001/pod-pulse:1.0.0 --build-arg APP_VERSION=1.0.0 app
docker build -t localhost:5001/pod-pulse:2.0.0 --build-arg APP_VERSION=2.0.0 app
docker build -t localhost:5001/pod-pulse:3.0.0-bad --build-arg APP_VERSION=3.0.0-bad --build-arg BROKEN=true app
docker push localhost:5001/pod-pulse --all-tags

kubectl apply -f k8s/
kubectl -n lab5 rollout status deploy/pod-pulse
open http://localhost:8085
```

The HPA needs metrics-server in the cluster.

## Endpoints

| Path | What it does |
|------|--------------|
| `/` | interactive page (burst, live watch, CPU load) |
| `/api/info` | pod name, node, IP, version, uptime |
| `/api/load?ms=400` | burns CPU for the given time, for the HPA demo |
| `/healthz` | liveness probe |
| `/readyz` | readiness probe (fails during the 3 s warm-up, during shutdown, and always in 3.0.0-bad) |
