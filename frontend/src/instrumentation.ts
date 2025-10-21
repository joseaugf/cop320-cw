import { WebTracerProvider } from '@opentelemetry/sdk-trace-web';
import { BatchSpanProcessor } from '@opentelemetry/sdk-trace-base';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { registerInstrumentations } from '@opentelemetry/instrumentation';
import { DocumentLoadInstrumentation } from '@opentelemetry/instrumentation-document-load';
import { UserInteractionInstrumentation } from '@opentelemetry/instrumentation-user-interaction';
import { ZoneContextManager } from '@opentelemetry/context-zone';
import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';

export function initializeTracing() {
  // Create a resource with service information
  const resource = new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'petshop-frontend',
    [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
    [SemanticResourceAttributes.SERVICE_NAMESPACE]: 'petshop-demo',
  });

  // Create tracer provider
  const provider = new WebTracerProvider({
    resource,
  });

  // Configure OTLP exporter
  // Use relative URL so it goes through Nginx proxy to ADOT collector
  const collectorUrl = import.meta.env.VITE_OTEL_COLLECTOR_URL || '/v1/traces';
  const exporter = new OTLPTraceExporter({
    url: collectorUrl,
  });

  // Add batch span processor
  provider.addSpanProcessor(new BatchSpanProcessor(exporter));

  // Register the provider
  provider.register({
    contextManager: new ZoneContextManager(),
  });

  // Register instrumentations
  registerInstrumentations({
    instrumentations: [
      new DocumentLoadInstrumentation(),
      new UserInteractionInstrumentation({
        eventNames: ['click', 'submit'],
      }),
    ],
  });

  console.log('OpenTelemetry Browser SDK initialized');
}
