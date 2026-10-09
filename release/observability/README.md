# Local observability stack

Logs → **Loki**, traces → **Tempo** or **Jaeger** (swappable), metrics → **Prometheus**, all viewed in **Grafana**.
Services run on the host and export over OTLP; they need no change when the trace backend is swapped.

| What | URL |
|---|---|
| Grafana (login from `.env`) | http://localhost:3000 |
| Spring Boot dashboard | http://localhost:3000/d/spring-boot-observability |
| Prometheus | http://localhost:9090 |
| Jaeger UI (jaeger profile only) | http://localhost:16686 |
| OTLP traces (Tempo or Jaeger) | http://localhost:4318/v1/traces |
| OTLP logs (Loki) | http://localhost:3100/otlp/v1/logs |

## Grafana login

Credentials come from `release/observability/.env` (git-ignored), which compose reads automatically:

```
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=<choose one>
```

Grafana applies them only when its volume is first created. To change the password later:
`docker compose exec grafana grafana cli admin reset-admin-password '<new>'`.

## Start / swap the trace backend

```bash
cd release/observability
COMPOSE_PROFILES=tempo  docker compose up -d          # Tempo (default choice)

# Tempo -> Jaeger (stop the other backend first: both bind 4317/4318)
docker compose --profile tempo stop tempo
COMPOSE_PROFILES=jaeger docker compose up -d          # Jaeger UI: http://localhost:16686

# Jaeger -> Tempo
docker compose --profile jaeger stop jaeger
COMPOSE_PROFILES=tempo  docker compose up -d

docker compose --profile '*' down                      # stop everything (data is kept)
```

Check which backend is active: `docker compose ps` (the running one of `tempo`/`jaeger`).

### How the swap works

Nothing in the services changes; the swap is three pieces of configuration:

| Piece | Where | What it does |
|---|---|---|
| Compose profiles | `docker-compose.yml`: `tempo` has `profiles: ["tempo"]`, `jaeger` has `profiles: ["jaeger"]` | `COMPOSE_PROFILES` picks which backend container starts. Loki, Prometheus and Grafana have no profile, so they always start. |
| Same OTLP ports | both containers publish `127.0.0.1:4317` (gRPC) and `127.0.0.1:4318` (HTTP) | Services always export to `TRACING_OTLP_ENDPOINT` = `http://localhost:4318/v1/traces`, whichever backend owns the port. That is also why only one can run at a time. |
| Grafana link target | `docker-compose.yml`: `TRACING_BACKEND: ${COMPOSE_PROFILES:-tempo}` on grafana; used in `grafana/provisioning/datasources/datasources.yaml` (`datasourceUid: ${TRACING_BACKEND}`) | Points the TraceID link on Loki log lines at the active backend's datasource (uid `tempo` or `jaeger`). Both datasources are always provisioned and both link traces back to Loki logs. |

Each backend keeps its own volume (`tempo_data`, `jaeger_data`), so traces recorded under one backend are not visible in the other after a swap.

The older standalone Jaeger in `release/docker-compose.yml` (container `alramz-jaeger`) is separate from this stack; stop it with `docker stop alramz-jaeger` so it does not compete for the ports.

## Storage and retention

Data lives in named volumes (`alramz-observability_{loki,tempo,jaeger,grafana,prometheus}_data`) and survives restarts and swaps.

| Variable | Default | Applies to |
|---|---|---|
| `TRACE_RETENTION` | `72h` | Tempo block retention, Jaeger Badger TTL |
| `LOG_RETENTION` | `168h` | Loki retention (compactor) |
| `METRICS_RETENTION` | `15d` | Prometheus TSDB retention |

`docker compose --profile '*' down -v` deletes all stored logs and traces.

## Service side

Configured in each service's `application.yml` (override with env vars):

- `TRACING_OTLP_ENDPOINT` (default `http://localhost:4318/v1/traces`)
- `LOGS_OTLP_ENDPOINT` (default `http://localhost:3100/otlp/v1/logs`)

Every log record carries `trace_id`/`span_id` plus the MDC fields (correlationId, clientIp, ...).
In Grafana, a log line's **TraceID** link opens the trace; a trace's **Logs** button opens its log lines.
Loki labels: `service_name`, `deployment_environment` (the active Spring profile).

## Metrics and dashboard

Prometheus scrapes `http://host.docker.internal:808{0..3}/actuator/prometheus` every 15s (`prometheus/prometheus.yml`);
the endpoint is public in the `dev` profile only (`company.jwt.permit-all-urls`). Metrics carry an `application` label.

`grafana/dashboards/spring-boot-observability.json` is grafana.com dashboard 17175, auto-loaded, with its two log
panels rewritten for OTLP logs (`service_name`, `detected_level`, `correlationId`, `trace_id`).
