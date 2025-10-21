import { trace, context, propagation } from '@opentelemetry/api';

// Get the tracer for manual instrumentation
export const getTracer = () => {
  return trace.getTracer('petshop-frontend', '1.0.0');
};

// Helper to inject trace context into HTTP headers
export const injectTraceContext = (headers: Record<string, string> = {}): Record<string, string> => {
  const carrier: Record<string, string> = { ...headers };
  propagation.inject(context.active(), carrier);
  return carrier;
};

// Helper to create a span for an operation
export const withSpan = async <T>(
  name: string,
  operation: () => Promise<T>,
  attributes?: Record<string, string | number | boolean>
): Promise<T> => {
  const tracer = getTracer();
  const span = tracer.startSpan(name);

  if (attributes) {
    span.setAttributes(attributes);
  }

  try {
    const result = await operation();
    span.end();
    return result;
  } catch (error) {
    span.recordException(error as Error);
    span.end();
    throw error;
  }
};
