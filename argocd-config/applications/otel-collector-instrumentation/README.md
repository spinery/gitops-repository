# OpenTelemetry Collector e Instrumentation (manifiestos planos)

Esta carpeta contiene los manifiestos que sincroniza la Application **otel-collector-instrumentation** de Argo CD.

## Recursos

- **collector.yaml**: `OpenTelemetryCollector` (modo deployment). Ajusta `receivers`, `processors` y `exporters` según tu backend (Jaeger, OTLP, Prometheus, etc.).
- **instrumentation.yaml**: `Instrumentation` para auto-instrumentación. Configura el runtime (java, python, nodejs, go, dotnet) y el endpoint del Collector.

## Requisitos

- OpenTelemetry Operator instalado en el cluster (Application `opentelemetry-operator`).

## Uso

1. Coloca aquí tus manifiestos de `OpenTelemetryCollector`, `Instrumentation` o otros recursos del operator.
2. Para inyectar auto-instrumentación en un Deployment, añade al Pod (o al Namespace):

   ```yaml
   annotations:
     instrumentation.opentelemetry.io/inject: "true"
   ```

3. El Collector de ejemplo expone OTLP en `4317` (gRPC) y `4318` (HTTP). El endpoint en Instrumentation debe apuntar al servicio del Collector en tu namespace (por defecto `observability`).
