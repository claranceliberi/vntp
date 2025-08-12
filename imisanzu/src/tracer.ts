import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-http';
import { ConsoleSpanExporter } from '@opentelemetry/sdk-trace-base';
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';
import { Resource } from '@opentelemetry/resources';

const baseEndpoint = process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://signoz-otel-collector:4318';
const traceEndpoint = baseEndpoint + '/v1/traces';
const metricsEndpoint = baseEndpoint + '/v1/metrics';

console.log('🔗 OTEL Trace Endpoint:', traceEndpoint);
console.log('📊 OTEL Metrics Endpoint:', metricsEndpoint);

// Configure trace exporter - use console for development debugging
const debugExporter = new ConsoleSpanExporter();

const otlpTraceExporter = new OTLPTraceExporter({
  url: traceEndpoint,
  timeoutMillis: 5000,
});

const traceExporter = process.env.NODE_ENV === 'development' 
  ? debugExporter 
  : otlpTraceExporter;

// Create metrics exporter
const metricExporter = new OTLPMetricExporter({
  url: metricsEndpoint,
  headers: {},
  timeoutMillis: 5000,
});

// Create metrics reader
const metricReader = new PeriodicExportingMetricReader({
  exporter: metricExporter,
  exportIntervalMillis: 5000,
});

// Create SDK instance with comprehensive configuration
const sdk = new NodeSDK({
  traceExporter,
  metricReader,
  resource: new Resource({
    'service.name': 'imisanzu-service',
    'service.version': '1.0.0',
    'service.namespace': 'vntp',
    'deployment.environment': process.env.NODE_ENV || 'docker',
    'service.type': 'aggregation-api',
    'service.component': 'imisanzu',
  }),
  instrumentations: [
    getNodeAutoInstrumentations({
      // Disable instrumentations that might cause issues
      '@opentelemetry/instrumentation-fs': { enabled: false },
      '@opentelemetry/instrumentation-dns': { enabled: false },
      // Configure HTTP instrumentation for better trace context
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
      },
    }),
  ],
});

export default sdk;