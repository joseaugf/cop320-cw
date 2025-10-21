import { metrics } from '@opentelemetry/api';
import { MeterProvider } from '@opentelemetry/sdk-metrics';

const meterProvider = metrics.getMeterProvider() as MeterProvider;
const meter = meterProvider.getMeter('cart-service');

// Counter for cart operations
export const cartOperationsCounter = meter.createCounter('cart_operations_total', {
  description: 'Total number of cart operations',
});

// Histogram for cart value
export const cartValueHistogram = meter.createHistogram('cart_value', {
  description: 'Distribution of cart values',
  unit: 'USD',
});

// Histogram for items count
export const itemsCountHistogram = meter.createHistogram('cart_items_count', {
  description: 'Distribution of items count in carts',
  unit: 'items',
});

// Counter for cart errors
export const cartErrorsCounter = meter.createCounter('cart_errors_total', {
  description: 'Total number of cart errors',
});

/**
 * Record a cart operation
 */
export function recordCartOperation(operation: string, success: boolean = true): void {
  cartOperationsCounter.add(1, {
    operation,
    success: success.toString(),
  });
}

/**
 * Record cart value
 */
export function recordCartValue(value: number, itemCount: number): void {
  cartValueHistogram.record(value, {
    item_count: itemCount.toString(),
  });
  
  itemsCountHistogram.record(itemCount);
}

/**
 * Record cart error
 */
export function recordCartError(operation: string, errorType: string): void {
  cartErrorsCounter.add(1, {
    operation,
    error_type: errorType,
  });
}
