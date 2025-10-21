"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const api_1 = require("@opentelemetry/api");
const cartStorage = __importStar(require("./cart-storage"));
const types_1 = require("./types");
const failure_simulator_1 = require("./failure-simulator");
const metrics_1 = require("./metrics");
const chaos_simulator_1 = require("./chaos-simulator");
const feature_flag_client_1 = require("./feature-flag-client");
const router = (0, express_1.Router)();
const tracer = api_1.trace.getTracer('cart-service');
/**
 * Get trace ID from current context for logging
 */
function getTraceId() {
    const span = api_1.trace.getSpan(api_1.context.active());
    return span?.spanContext().traceId || 'unknown';
}
/**
 * Log with trace context
 */
function logWithTrace(level, message, data) {
    const traceId = getTraceId();
    const logData = { trace_id: traceId, ...data };
    console[level](`[${level.toUpperCase()}] ${message}`, logData);
}
/**
 * GET /api/cart - Retrieve cart by session
 */
router.get('/api/cart', async (req, res) => {
    return tracer.startActiveSpan('GET /api/cart', async (span) => {
        try {
            const sessionId = req.headers['x-session-id'] || 'default-session';
            span.setAttribute('session.id', sessionId);
            logWithTrace('info', 'Retrieving cart', { sessionId });
            // Check for chaos engineering simulations
            await chaos_simulator_1.chaosSimulator.checkAndApplyChaos('cart-service', feature_flag_client_1.featureFlagClient);
            // Apply failure simulation
            await failure_simulator_1.failureSimulator.checkAndApplyFailures('get_cart');
            const cart = await cartStorage.getCart(sessionId);
            // Record metrics
            (0, metrics_1.recordCartOperation)('get_cart', true);
            (0, metrics_1.recordCartValue)(cart.total, cart.items.length);
            logWithTrace('info', 'Cart retrieved successfully', {
                sessionId,
                itemCount: cart.items.length,
                total: cart.total,
            });
            res.status(200).json(cart);
        }
        catch (error) {
            span.recordException(error);
            if (error instanceof failure_simulator_1.SimulatedError) {
                (0, metrics_1.recordCartOperation)('get_cart', false);
                (0, metrics_1.recordCartError)('get_cart', 'simulated_error');
                logWithTrace('error', 'Simulated error occurred', { error: error.message });
                res.status(500).json({
                    error: {
                        code: 'SIMULATED_ERROR',
                        message: error.message,
                        trace_id: getTraceId(),
                        timestamp: new Date().toISOString(),
                    },
                });
            }
            else {
                (0, metrics_1.recordCartOperation)('get_cart', false);
                (0, metrics_1.recordCartError)('get_cart', 'internal_error');
                logWithTrace('error', 'Error retrieving cart', { error: error.message });
                res.status(500).json({
                    error: {
                        code: 'INTERNAL_SERVER_ERROR',
                        message: 'Failed to retrieve cart',
                        trace_id: getTraceId(),
                        timestamp: new Date().toISOString(),
                    },
                });
            }
        }
        finally {
            span.end();
        }
    });
});
/**
 * POST /api/cart/items - Add item to cart
 */
router.post('/api/cart/items', async (req, res) => {
    return tracer.startActiveSpan('POST /api/cart/items', async (span) => {
        try {
            const sessionId = req.headers['x-session-id'] || 'default-session';
            const itemData = req.body;
            span.setAttribute('session.id', sessionId);
            span.setAttribute('product.id', itemData.productId);
            logWithTrace('info', 'Adding item to cart', { sessionId, productId: itemData.productId });
            // Check for chaos engineering simulations
            await chaos_simulator_1.chaosSimulator.checkAndApplyChaos('cart-service', feature_flag_client_1.featureFlagClient);
            // Apply failure simulation
            await failure_simulator_1.failureSimulator.checkAndApplyFailures('add_item');
            const cart = await cartStorage.addItem(sessionId, {
                productId: itemData.productId,
                name: itemData.name,
                price: itemData.price,
                quantity: itemData.quantity,
            });
            // Record metrics
            (0, metrics_1.recordCartOperation)('add_item', true);
            (0, metrics_1.recordCartValue)(cart.total, cart.items.length);
            logWithTrace('info', 'Item added to cart successfully', {
                sessionId,
                productId: itemData.productId,
                total: cart.total,
            });
            res.status(200).json(cart);
        }
        catch (error) {
            span.recordException(error);
            if (error instanceof types_1.ValidationError) {
                (0, metrics_1.recordCartOperation)('add_item', false);
                (0, metrics_1.recordCartError)('add_item', 'validation_error');
                logWithTrace('warn', 'Validation error', { error: error.message });
                res.status(400).json({
                    error: {
                        code: 'VALIDATION_ERROR',
                        message: error.message,
                        trace_id: getTraceId(),
                        timestamp: new Date().toISOString(),
                    },
                });
            }
            else if (error instanceof failure_simulator_1.SimulatedError) {
                (0, metrics_1.recordCartOperation)('add_item', false);
                (0, metrics_1.recordCartError)('add_item', 'simulated_error');
                logWithTrace('error', 'Simulated error occurred', { error: error.message });
                res.status(500).json({
                    error: {
                        code: 'SIMULATED_ERROR',
                        message: error.message,
                        trace_id: getTraceId(),
                        timestamp: new Date().toISOString(),
                    },
                });
            }
            else {
                (0, metrics_1.recordCartOperation)('add_item', false);
                (0, metrics_1.recordCartError)('add_item', 'internal_error');
                logWithTrace('error', 'Error adding item to cart', { error: error.message });
                res.status(500).json({
                    error: {
                        code: 'INTERNAL_SERVER_ERROR',
                        message: 'Failed to add item to cart',
                        trace_id: getTraceId(),
                        timestamp: new Date().toISOString(),
                    },
                });
            }
        }
        finally {
            span.end();
        }
    });
});
/**
 * PUT /api/cart/items/:id - Update item quantity
 */
router.put('/api/cart/items/:id', async (req, res) => {
    return tracer.startActiveSpan('PUT /api/cart/items/:id', async (span) => {
        try {
            const sessionId = req.headers['x-session-id'] || 'default-session';
            const productId = req.params.id;
            const { quantity } = req.body;
            span.setAttribute('session.id', sessionId);
            span.setAttribute('product.id', productId);
            span.setAttribute('quantity', quantity);
            logWithTrace('info', 'Updating item quantity', { sessionId, productId, quantity });
            // Check for chaos engineering simulations
            await chaos_simulator_1.chaosSimulator.checkAndApplyChaos('cart-service', feature_flag_client_1.featureFlagClient);
            // Apply failure simulation
            await failure_simulator_1.failureSimulator.checkAndApplyFailures('update_item');
            const cart = await cartStorage.updateItem(sessionId, productId, quantity);
            // Record metrics
            (0, metrics_1.recordCartOperation)('update_item', true);
            (0, metrics_1.recordCartValue)(cart.total, cart.items.length);
            logWithTrace('info', 'Item quantity updated successfully', {
                sessionId,
                productId,
                quantity,
                total: cart.total,
            });
            res.status(200).json(cart);
        }
        catch (error) {
            span.recordException(error);
            if (error instanceof types_1.ValidationError) {
                (0, metrics_1.recordCartOperation)('update_item', false);
                (0, metrics_1.recordCartError)('update_item', 'validation_error');
                logWithTrace('warn', 'Validation error', { error: error.message });
                res.status(400).json({
                    error: {
                        code: 'VALIDATION_ERROR',
                        message: error.message,
                        trace_id: getTraceId(),
                        timestamp: new Date().toISOString(),
                    },
                });
            }
            else if (error instanceof types_1.NotFoundError) {
                (0, metrics_1.recordCartOperation)('update_item', false);
                (0, metrics_1.recordCartError)('update_item', 'not_found');
                logWithTrace('warn', 'Item not found', { error: error.message });
                res.status(404).json({
                    error: {
                        code: 'NOT_FOUND',
                        message: error.message,
                        trace_id: getTraceId(),
                        timestamp: new Date().toISOString(),
                    },
                });
            }
            else if (error instanceof failure_simulator_1.SimulatedError) {
                (0, metrics_1.recordCartOperation)('update_item', false);
                (0, metrics_1.recordCartError)('update_item', 'simulated_error');
                logWithTrace('error', 'Simulated error occurred', { error: error.message });
                res.status(500).json({
                    error: {
                        code: 'SIMULATED_ERROR',
                        message: error.message,
                        trace_id: getTraceId(),
                        timestamp: new Date().toISOString(),
                    },
                });
            }
            else {
                (0, metrics_1.recordCartOperation)('update_item', false);
                (0, metrics_1.recordCartError)('update_item', 'internal_error');
                logWithTrace('error', 'Error updating item', { error: error.message });
                res.status(500).json({
                    error: {
                        code: 'INTERNAL_SERVER_ERROR',
                        message: 'Failed to update item',
                        trace_id: getTraceId(),
                        timestamp: new Date().toISOString(),
                    },
                });
            }
        }
        finally {
            span.end();
        }
    });
});
/**
 * DELETE /api/cart/items/:id - Remove item from cart
 */
router.delete('/api/cart/items/:id', async (req, res) => {
    return tracer.startActiveSpan('DELETE /api/cart/items/:id', async (span) => {
        try {
            const sessionId = req.headers['x-session-id'] || 'default-session';
            const productId = req.params.id;
            span.setAttribute('session.id', sessionId);
            span.setAttribute('product.id', productId);
            logWithTrace('info', 'Removing item from cart', { sessionId, productId });
            // Check for chaos engineering simulations
            await chaos_simulator_1.chaosSimulator.checkAndApplyChaos('cart-service', feature_flag_client_1.featureFlagClient);
            // Apply failure simulation
            await failure_simulator_1.failureSimulator.checkAndApplyFailures('remove_item');
            const cart = await cartStorage.removeItem(sessionId, productId);
            // Record metrics
            (0, metrics_1.recordCartOperation)('remove_item', true);
            (0, metrics_1.recordCartValue)(cart.total, cart.items.length);
            logWithTrace('info', 'Item removed from cart successfully', {
                sessionId,
                productId,
                total: cart.total,
            });
            res.status(200).json(cart);
        }
        catch (error) {
            span.recordException(error);
            if (error instanceof types_1.NotFoundError) {
                (0, metrics_1.recordCartOperation)('remove_item', false);
                (0, metrics_1.recordCartError)('remove_item', 'not_found');
                logWithTrace('warn', 'Item not found', { error: error.message });
                res.status(404).json({
                    error: {
                        code: 'NOT_FOUND',
                        message: error.message,
                        trace_id: getTraceId(),
                        timestamp: new Date().toISOString(),
                    },
                });
            }
            else if (error instanceof failure_simulator_1.SimulatedError) {
                (0, metrics_1.recordCartOperation)('remove_item', false);
                (0, metrics_1.recordCartError)('remove_item', 'simulated_error');
                logWithTrace('error', 'Simulated error occurred', { error: error.message });
                res.status(500).json({
                    error: {
                        code: 'SIMULATED_ERROR',
                        message: error.message,
                        trace_id: getTraceId(),
                        timestamp: new Date().toISOString(),
                    },
                });
            }
            else {
                (0, metrics_1.recordCartOperation)('remove_item', false);
                (0, metrics_1.recordCartError)('remove_item', 'internal_error');
                logWithTrace('error', 'Error removing item', { error: error.message });
                res.status(500).json({
                    error: {
                        code: 'INTERNAL_SERVER_ERROR',
                        message: 'Failed to remove item',
                        trace_id: getTraceId(),
                        timestamp: new Date().toISOString(),
                    },
                });
            }
        }
        finally {
            span.end();
        }
    });
});
/**
 * DELETE /api/cart - Clear entire cart
 */
router.delete('/api/cart', async (req, res) => {
    return tracer.startActiveSpan('DELETE /api/cart', async (span) => {
        try {
            const sessionId = req.headers['x-session-id'] || 'default-session';
            span.setAttribute('session.id', sessionId);
            logWithTrace('info', 'Clearing cart', { sessionId });
            // Check for chaos engineering simulations
            await chaos_simulator_1.chaosSimulator.checkAndApplyChaos('cart-service', feature_flag_client_1.featureFlagClient);
            // Apply failure simulation
            await failure_simulator_1.failureSimulator.checkAndApplyFailures('clear_cart');
            await cartStorage.clearCart(sessionId);
            // Record metrics
            (0, metrics_1.recordCartOperation)('clear_cart', true);
            logWithTrace('info', 'Cart cleared successfully', { sessionId });
            res.status(204).send();
        }
        catch (error) {
            span.recordException(error);
            if (error instanceof failure_simulator_1.SimulatedError) {
                (0, metrics_1.recordCartOperation)('clear_cart', false);
                (0, metrics_1.recordCartError)('clear_cart', 'simulated_error');
                logWithTrace('error', 'Simulated error occurred', { error: error.message });
                res.status(500).json({
                    error: {
                        code: 'SIMULATED_ERROR',
                        message: error.message,
                        trace_id: getTraceId(),
                        timestamp: new Date().toISOString(),
                    },
                });
            }
            else {
                (0, metrics_1.recordCartOperation)('clear_cart', false);
                (0, metrics_1.recordCartError)('clear_cart', 'internal_error');
                logWithTrace('error', 'Error clearing cart', { error: error.message });
                res.status(500).json({
                    error: {
                        code: 'INTERNAL_SERVER_ERROR',
                        message: 'Failed to clear cart',
                        trace_id: getTraceId(),
                        timestamp: new Date().toISOString(),
                    },
                });
            }
        }
        finally {
            span.end();
        }
    });
});
/**
 * GET /chaos/metrics - Get system metrics and active chaos simulations
 */
router.get('/chaos/metrics', (req, res) => {
    try {
        const metrics = chaos_simulator_1.chaosSimulator.getSystemMetrics();
        res.status(200).json({
            service: 'cart-service',
            timestamp: new Date().toISOString(),
            system_metrics: metrics
        });
    }
    catch (error) {
        console.error('Error retrieving chaos metrics:', error);
        res.status(500).json({
            error: {
                code: 'INTERNAL_SERVER_ERROR',
                message: 'Failed to retrieve chaos metrics',
                timestamp: new Date().toISOString(),
            },
        });
    }
});
exports.default = router;
