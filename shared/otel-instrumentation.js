/**
 * Shared OpenTelemetry instrumentation configuration for Node.js services
 */
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');
const { OTLPMetricExporter } = require('@opentelemetry/exporter-metrics-otlp-grpc');
const { PeriodicExportingMetricReader } = require('@opentelemetry/sdk-metrics');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');
const { HttpInstrumentation } = require('@opentelemetry/instrumentation-http');
const { ExpressInstrumentation } = require('@opentelemetry/instrumentation-express');

/**
 * Setup OpenTelemetry instrumentation for a Node.js service
 * 
 * @param {string} serviceName - Name of the service
 * @param {string} serviceVersion - Version of the service
 * @param {Array} additionalInstrumentations - Additional instrumentations to include
 * @returns {NodeSDK} Configured OpenTelemetry SDK instance
 */
function setupTelemetry(serviceName, serviceVersion = '1.0.0', additionalInstrumentations = []) {
  // Get OTLP endpoint from environment or use default
  const otlpEndpoint = process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'adot-collector:4317';
  
  // Create resource with service information
  const resource = new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: serviceName,
    [SemanticResourceAttributes.SERVICE_VERSION]: serviceVersion,
    [SemanticResourceAttributes.SERVICE_NAMESPACE]: 'petshop-demo',
    [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: process.env.ENVIRONMENT || 'demo',
  });
  
  // Configure trace exporter
  const traceExporter = new OTLPTraceExporter({
    url: otlpEndpoint,
  });
  
  // Configure metric exporter
  const metricExporter = new OTLPMetricExporter({
    url: otlpEndpoint,
  });
  
  const metricReader = new PeriodicExportingMetricReader({
    exporter: metricExporter,
    exportIntervalMillis: 10000,
  });
  
  // Create SDK with instrumentations
  const sdk = new NodeSDK({
    resource,
    traceExporter,
    metricReader,
    instrumentations: [
      new HttpInstrumentation(),
      new ExpressInstrumentation(),
      ...additionalInstrumentations,
    ],
  });
  
  // Start the SDK
  sdk.start();
  
  // Graceful shutdown
  process.on('SIGTERM', () => {
    sdk.shutdown()
      .then(() => console.log('OpenTelemetry SDK shut down successfully'))
      .catch((error) => console.error('Error shutting down OpenTelemetry SDK', error))
      .finally(() => process.exit(0));
  });
  
  return sdk;
}

module.exports = { setupTelemetry };
