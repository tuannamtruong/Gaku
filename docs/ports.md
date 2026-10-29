# Ports

## 1. Host

| Port | Purpose | What | Runs in | How |
| --- | --- | --- | --- | --- |
| 3000 | Local monitoring | Grafana | minikube | `make monitoring_grafana` |
| 3001 | Archive monitoring | Grafana | docker compose | `make monitoring_view` |
| 5432 | Local development | PostgreSQL | docker compose | `make pg_up` |
| 8080 | Local development | gaku-api | docker compose | `docker compose up` |
| 8081 | Local development | gaku-web | docker compose | `docker compose up` |
| 8082 | Local cluster | gaku-api | minikube | `make startup` |
| 8090 | CI/CD | Jenkins | docker compose | `make jenkins_up` |
| 9090 | Local monitoring | Prometheus | minikube | `make startup` |
| 9091 | Archive monitoring | Prometheus | docker compose | `make monitoring_view` |
| 9464 | Local monitoring | gaku-api metrics | minikube | `make startup` |
| 9465 | Local monitoring | gaku-web metrics | minikube | `make startup` |
| 32768–32772 | Local cluster | minikube node: SSH, Docker, registry, API server, 32443 | minikube | `make startup` |
| 50000 | CI/CD | Jenkins agents | docker compose | `make jenkins_up` |
