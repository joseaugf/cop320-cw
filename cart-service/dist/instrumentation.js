"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const sdk_node_1 = require("@opentelemetry/sdk-node");
const exporter_trace_otlp_grpc_1 = require("@opentelemetry/exporter-trace-otlp-grpc");
const exporter_metrics_otlp_grpc_1 = require("@opentelemetry/exporter-metrics-otlp-grpc");
const sdk_metrics_1 = require("@opentelemetry/sdk-metrics");
const auto_instrumentations_node_1 = require("@opentelemetry/auto-instrumentations-node");
const resources_1 = require("@opentelemetry/resources");
const semantic_conventions_1 = require("@opentelemetry/semantic-conventions");
const otlpEndpoint = process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://localhost:4317';
const sdk = new sdk_node_1.NodeSDK({
    resource: new resources_1.Resource({
        [semantic_conventions_1.SemanticResourceAttributes.SERVICE_NAME]: 'cart-service',
        [semantic_conventions_1.SemanticResourceAttributes.SERVICE_NAMESPACE]: 'petshop-demo',
    }),
    traceExporter: new exporter_trace_otlp_grpc_1.OTLPTraceExporter({
        url: otlpEndpoint,
    }),
    metricReader: new sdk_metrics_1.PeriodicExportingMetricReader({
        exporter: new exporter_metrics_otlp_grpc_1.OTLPMetricExporter({
            url: otlpEndpoint,
        }),
        exportIntervalMillis: 10000,
    }),
    instrumentations: [(0, auto_instrumentations_node_1.getNodeAutoInstrumentations)()],
});
sdk.start();
process.on('SIGTERM', () => {
    sdk.shutdown()
        .then(() => console.log('Tracing terminated'))
        .catch((error) => console.log('Error terminating tracing', error))
        .finally(() => process.exit(0));
});
exports.default = sdk;
