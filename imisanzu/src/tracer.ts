import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { ConsoleSpanExporter } from '@opentelemetry/sdk-trace-base';

// Configure trace exporter - use console for development debugging
const debugExporter = new ConsoleSpanExporter();

const otlpEndpoint = (process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://signoz-otel-collector:4318') + '/v1/traces';
console.log('🔗 OTEL Endpoint configured:', otlpEndpoint);

const otlpExporter = new OTLPTraceExporter({
  url: otlpEndpoint,
  timeoutMillis: 5000, // 5 second timeout
});

const traceExporter = process.env.NODE_ENV === 'development' 
  ? debugExporter 
  : otlpExporter;

// Create SDK instance with comprehensive configuration
const sdk = new NodeSDK({
  traceExporter,
  instrumentations: [
    getNodeAutoInstrumentations({
      // Disable instrumentations that might cause issues
      '@opentelemetry/instrumentation-fs': { enabled: false },
      // Configure HTTP instrumentation for better trace context
      '@opentelemetry/instrumentation-http': {
        enabled: true,
        ignoreIncomingRequestHook: (req) => {
          // Ignore health check endpoints
          return req.url?.includes('/health') || req.url?.includes('/metrics') || false;
        },
      },
    }),
  ],
});

export default sdk;