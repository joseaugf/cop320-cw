"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.cartErrorsCounter = exports.itemsCountHistogram = exports.cartValueHistogram = exports.cartOperationsCounter = void 0;
exports.recordCartOperation = recordCartOperation;
exports.recordCartValue = recordCartValue;
exports.recordCartError = recordCartError;
const api_1 = require("@opentelemetry/api");
const meterProvider = api_1.metrics.getMeterProvider();
const meter = meterProvider.getMeter('cart-service');
// Counter for cart operations
exports.cartOperationsCounter = meter.createCounter('cart_operations_total', {
    description: 'Total number of cart operations',
});
// Histogram for cart value
exports.cartValueHistogram = meter.createHistogram('cart_value', {
    description: 'Distribution of cart values',
    unit: 'USD',
});
// Histogram for items count
exports.itemsCountHistogram = meter.createHistogram('cart_items_count', {
    description: 'Distribution of items count in carts',
    unit: 'items',
});
// Counter for cart errors
exports.cartErrorsCounter = meter.createCounter('cart_errors_total', {
    description: 'Total number of cart errors',
});
/**
 * Record a cart operation
 */
function recordCartOperation(operation, success = true) {
    exports.cartOperationsCounter.add(1, {
        operation,
        success: success.toString(),
    });
}
/**
 * Record cart value
 */
function recordCartValue(value, itemCount) {
    exports.cartValueHistogram.record(value, {
        item_count: itemCount.toString(),
    });
    exports.itemsCountHistogram.record(itemCount);
}
/**
 * Record cart error
 */
function recordCartError(operation, errorType) {
    exports.cartErrorsCounter.add(1, {
        operation,
        error_type: errorType,
    });
}
