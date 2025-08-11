import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-http';
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';
import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';

// Configure trace exporter
const traceExporter = new OTLPTraceExporter({
  url: (process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://localhost:4318') + '/v1/traces',
});

// Configure metrics exporter
const metricExporter = new OTLPMetricExporter({
  url: (process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://localhost:4318') + '/v1/metrics',
});

// Define service resource attributes
const resource = Resource.default().merge(
  new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'oracle-service',
    [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
    [SemanticResourceAttributes.SERVICE_NAMESPACE]: 'vntp',
    [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: process.env.NODE_ENV || 'development',
    'service.type': 'master-data-api',
    'service.component': 'oracle',
  }),
);

const sdk = new NodeSDK({
  resource,
  traceExporter,
  metricReader: new PeriodicExportingMetricReader({
    exporter: metricExporter,
    exportIntervalMillis: 30000,
  }) as any,
  instrumentations: [
    getNodeAutoInstrumentations({
      // Disable noisy instrumentations
      '@opentelemetry/instrumentation-fs': {
        enabled: false,
      },
      '@opentelemetry/instrumentation-dns': {
        enabled: false,
      },
      // Enable useful ones with specific configuration
      '@opentelemetry/instrumentation-http': {
        enabled: true,
        requestHook: (span, request) => {
          const headers = 'headers' in request ? request.headers : {};
          span.setAttributes({
            'http.request.body.size': headers['content-length'] || 0,
          });
        },
      },
      '@opentelemetry/instrumentation-express': {
        enabled: true,
      },
      '@opentelemetry/instrumentation-pg': {
        enabled: true,
      },
      '@opentelemetry/instrumentation-redis': {
        enabled: true,
      },
    }),
  ],
});

export default sdk;