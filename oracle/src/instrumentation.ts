import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-http';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { Resource } from '@opentelemetry/resources';
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';

const baseEndpoint = process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://signoz-otel-collector:4318';
const traceEndpoint = baseEndpoint + '/v1/traces';
const metricsEndpoint = baseEndpoint + '/v1/metrics';

console.log('🔗 OTEL Trace Endpoint:', traceEndpoint);
console.log('📊 OTEL Metrics Endpoint:', metricsEndpoint);

// Create trace exporter
const traceExporter = new OTLPTraceExporter({
  url: traceEndpoint,
  headers: {},
  timeoutMillis: 5000,
});

// Create metrics exporter
const metricExporter = new OTLPMetricExporter({
  url: metricsEndpoint,
  headers: {},
  timeoutMillis: 5000,
});

// Create metrics reader
const metricReader = new PeriodicExportingMetricReader({
  exporter: metricExporter,
  exportIntervalMillis: 5000, // Export metrics every 5 seconds
});

const otelSDK = new NodeSDK({
  traceExporter,
  metricReader,
  instrumentations: [
    getNodeAutoInstrumentations({
      // Disable noisy instrumentations
      '@opentelemetry/instrumentation-fs': {
        enabled: false,
      },
      '@opentelemetry/instrumentation-dns': {
        enabled: false,
      },
      // Enable useful instrumentations with enhanced config
      '@opentelemetry/instrumentation-http': {
        enabled: true,
        ignoreIncomingRequestHook: (req) => {
          return req.url?.includes('/health') || req.url?.includes('/metrics') || false;
        },
      },
      '@opentelemetry/instrumentation-express': {
        enabled: true,
      },
      '@opentelemetry/instrumentation-nestjs-core': {
        enabled: true,
      },
      '@opentelemetry/instrumentation-pg': {
        enabled: true,
        enhancedDatabaseReporting: true,
      },
      '@opentelemetry/instrumentation-redis': {
        enabled: true,
        dbStatementSerializer: (cmdName, cmdArgs) => {
          return `${cmdName} ${cmdArgs.join(' ')}`;
        },
      },
    }),
  ],
  resource: new Resource({
    'service.name': 'oracle-service',
    'service.version': '1.0.0',
    'service.namespace': 'vntp',
    'deployment.environment': process.env.NODE_ENV || 'docker',
    'service.type': 'master-data-api',
    'service.component': 'oracle',
  }),
});

export default otelSDK;