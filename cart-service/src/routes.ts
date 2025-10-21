import { Router, Request, Response } from 'express';
import { trace, context } from '@opentelemetry/api';
import * as cartStorage from './cart-storage';
import { ValidationError, NotFoundError, AddItemRequest, UpdateItemRequest } from './types';
import { failureSimulator, SimulatedError } from './failure-simulator';
import { recordCartOperation, recordCartValue, recordCartError } from './metrics';
import { chaosSimulator } from './chaos-simulator';
import { featureFlagClient } from './feature-flag-client';

const router = Router();
const tracer = trace.getTracer('cart-service');

/**
 * Get trace ID from current context for logging
 */
function getTraceId(): string {
  const span = trace.getSpan(context.active());
  return span?.spanContext().traceId || 'unknown';
}

/**
 * Log with trace context
 */
function logWithTrace(level: 'info' | 'error' | 'warn', message: string, data?: any) {
  const traceId = getTraceId();
  const logData = { trace_id: traceId, ...data };
  console[level](`[${level.toUpperCase()}] ${message}`, logData);
}

/**
 * GET /api/cart - Retrieve cart by session
 */
router.get('/api/cart', async (req: Request, res: Response) => {
  return tracer.startActiveSpan('GET /api/cart', async (span) => {
    try {
      const sessionId = req.headers['x-session-id'] as string || 'default-session';
      span.setAttribute('session.id', sessionId);

      logWithTrace('info', 'Retrieving cart', { sessionId });

      // Check for chaos engineering simulations
      await chaosSimulator.checkAndApplyChaos('cart-service', featureFlagClient);

      // Apply failure simulation
      await failureSimulator.checkAndApplyFailures('get_cart');

      const cart = await cartStorage.getCart(sessionId);

      // Record metrics
      recordCartOperation('get_cart', true);
      recordCartValue(cart.total, cart.items.length);

      logWithTrace('info', 'Cart retrieved successfully', {
        sessionId,
        itemCount: cart.items.length,
        total: cart.total,
      });

      res.status(200).json(cart);
    } catch (error) {
      span.recordException(error as Error);
      
      if (error instanceof SimulatedError) {
        recordCartOperation('get_cart', false);
        recordCartError('get_cart', 'simulated_error');
        logWithTrace('error', 'Simulated error occurred', { error: (error as Error).message });
        res.status(500).json({
          error: {
            code: 'SIMULATED_ERROR',
            message: (error as Error).message,
            trace_id: getTraceId(),
            timestamp: new Date().toISOString(),
          },
        });
      } else {
        recordCartOperation('get_cart', false);
        recordCartError('get_cart', 'internal_error');
        logWithTrace('error', 'Error retrieving cart', { error: (error as Error).message });
        res.status(500).json({
          error: {
            code: 'INTERNAL_SERVER_ERROR',
            message: 'Failed to retrieve cart',
            trace_id: getTraceId(),
            timestamp: new Date().toISOString(),
          },
        });
      }
    } finally {
      span.end();
    }
  });
});

/**
 * POST /api/cart/items - Add item to cart
 */
router.post('/api/cart/items', async (req: Request, res: Response) => {
  return tracer.startActiveSpan('POST /api/cart/items', async (span) => {
    try {
      const sessionId = req.headers['x-session-id'] as string || 'default-session';
      const itemData: AddItemRequest = req.body;

      span.setAttribute('session.id', sessionId);
      span.setAttribute('product.id', itemData.productId);

      logWithTrace('info', 'Adding item to cart', { sessionId, productId: itemData.productId });

      // Check for chaos engineering simulations
      await chaosSimulator.checkAndApplyChaos('cart-service', featureFlagClient);

      // Apply failure simulation
      await failureSimulator.checkAndApplyFailures('add_item');

      const cart = await cartStorage.addItem(sessionId, {
        productId: itemData.productId,
        name: itemData.name,
        price: itemData.price,
        quantity: itemData.quantity,
      });

      // Record metrics
      recordCartOperation('add_item', true);
      recordCartValue(cart.total, cart.items.length);

      logWithTrace('info', 'Item added to cart successfully', {
        sessionId,
        productId: itemData.productId,
        total: cart.total,
      });

      res.status(200).json(cart);
    } catch (error) {
      span.recordException(error as Error);

      if (error instanceof ValidationError) {
        recordCartOperation('add_item', false);
        recordCartError('add_item', 'validation_error');
        logWithTrace('warn', 'Validation error', { error: (error as Error).message });
        res.status(400).json({
          error: {
            code: 'VALIDATION_ERROR',
            message: (error as Error).message,
            trace_id: getTraceId(),
            timestamp: new Date().toISOString(),
          },
        });
      } else if (error instanceof SimulatedError) {
        recordCartOperation('add_item', false);
        recordCartError('add_item', 'simulated_error');
        logWithTrace('error', 'Simulated error occurred', { error: (error as Error).message });
        res.status(500).json({
          error: {
            code: 'SIMULATED_ERROR',
            message: (error as Error).message,
            trace_id: getTraceId(),
            timestamp: new Date().toISOString(),
          },
        });
      } else {
        recordCartOperation('add_item', false);
        recordCartError('add_item', 'internal_error');
        logWithTrace('error', 'Error adding item to cart', { error: (error as Error).message });
        res.status(500).json({
          error: {
            code: 'INTERNAL_SERVER_ERROR',
            message: 'Failed to add item to cart',
            trace_id: getTraceId(),
            timestamp: new Date().toISOString(),
          },
        });
      }
    } finally {
      span.end();
    }
  });
});

/**
 * PUT /api/cart/items/:id - Update item quantity
 */
router.put('/api/cart/items/:id', async (req: Request, res: Response) => {
  return tracer.startActiveSpan('PUT /api/cart/items/:id', async (span) => {
    try {
      const sessionId = req.headers['x-session-id'] as string || 'default-session';
      const productId = req.params.id;
      const { quantity }: UpdateItemRequest = req.body;

      span.setAttribute('session.id', sessionId);
      span.setAttribute('product.id', productId);
      span.setAttribute('quantity', quantity);

      logWithTrace('info', 'Updating item quantity', { sessionId, productId, quantity });

      // Check for chaos engineering simulations
      await chaosSimulator.checkAndApplyChaos('cart-service', featureFlagClient);

      // Apply failure simulation
      await failureSimulator.checkAndApplyFailures('update_item');

      const cart = await cartStorage.updateItem(sessionId, productId, quantity);

      // Record metrics
      recordCartOperation('update_item', true);
      recordCartValue(cart.total, cart.items.length);

      logWithTrace('info', 'Item quantity updated successfully', {
        sessionId,
        productId,
        quantity,
        total: cart.total,
      });

      res.status(200).json(cart);
    } catch (error) {
      span.recordException(error as Error);

      if (error instanceof ValidationError) {
        recordCartOperation('update_item', false);
        recordCartError('update_item', 'validation_error');
        logWithTrace('warn', 'Validation error', { error: (error as Error).message });
        res.status(400).json({
          error: {
            code: 'VALIDATION_ERROR',
            message: (error as Error).message,
            trace_id: getTraceId(),
            timestamp: new Date().toISOString(),
          },
        });
      } else if (error instanceof NotFoundError) {
        recordCartOperation('update_item', false);
        recordCartError('update_item', 'not_found');
        logWithTrace('warn', 'Item not found', { error: (error as Error).message });
        res.status(404).json({
          error: {
            code: 'NOT_FOUND',
            message: (error as Error).message,
            trace_id: getTraceId(),
            timestamp: new Date().toISOString(),
          },
        });
      } else if (error instanceof SimulatedError) {
        recordCartOperation('update_item', false);
        recordCartError('update_item', 'simulated_error');
        logWithTrace('error', 'Simulated error occurred', { error: (error as Error).message });
        res.status(500).json({
          error: {
            code: 'SIMULATED_ERROR',
            message: (error as Error).message,
            trace_id: getTraceId(),
            timestamp: new Date().toISOString(),
          },
        });
      } else {
        recordCartOperation('update_item', false);
        recordCartError('update_item', 'internal_error');
        logWithTrace('error', 'Error updating item', { error: (error as Error).message });
        res.status(500).json({
          error: {
            code: 'INTERNAL_SERVER_ERROR',
            message: 'Failed to update item',
            trace_id: getTraceId(),
            timestamp: new Date().toISOString(),
          },
        });
      }
    } finally {
      span.end();
    }
  });
});

/**
 * DELETE /api/cart/items/:id - Remove item from cart
 */
router.delete('/api/cart/items/:id', async (req: Request, res: Response) => {
  return tracer.startActiveSpan('DELETE /api/cart/items/:id', async (span) => {
    try {
      const sessionId = req.headers['x-session-id'] as string || 'default-session';
      const productId = req.params.id;

      span.setAttribute('session.id', sessionId);
      span.setAttribute('product.id', productId);

      logWithTrace('info', 'Removing item from cart', { sessionId, productId });

      // Check for chaos engineering simulations
      await chaosSimulator.checkAndApplyChaos('cart-service', featureFlagClient);

      // Apply failure simulation
      await failureSimulator.checkAndApplyFailures('remove_item');

      const cart = await cartStorage.removeItem(sessionId, productId);

      // Record metrics
      recordCartOperation('remove_item', true);
      recordCartValue(cart.total, cart.items.length);

      logWithTrace('info', 'Item removed from cart successfully', {
        sessionId,
        productId,
        total: cart.total,
      });

      res.status(200).json(cart);
    } catch (error) {
      span.recordException(error as Error);

      if (error instanceof NotFoundError) {
        recordCartOperation('remove_item', false);
        recordCartError('remove_item', 'not_found');
        logWithTrace('warn', 'Item not found', { error: (error as Error).message });
        res.status(404).json({
          error: {
            code: 'NOT_FOUND',
            message: (error as Error).message,
            trace_id: getTraceId(),
            timestamp: new Date().toISOString(),
          },
        });
      } else if (error instanceof SimulatedError) {
        recordCartOperation('remove_item', false);
        recordCartError('remove_item', 'simulated_error');
        logWithTrace('error', 'Simulated error occurred', { error: (error as Error).message });
        res.status(500).json({
          error: {
            code: 'SIMULATED_ERROR',
            message: (error as Error).message,
            trace_id: getTraceId(),
            timestamp: new Date().toISOString(),
          },
        });
      } else {
        recordCartOperation('remove_item', false);
        recordCartError('remove_item', 'internal_error');
        logWithTrace('error', 'Error removing item', { error: (error as Error).message });
        res.status(500).json({
          error: {
            code: 'INTERNAL_SERVER_ERROR',
            message: 'Failed to remove item',
            trace_id: getTraceId(),
            timestamp: new Date().toISOString(),
          },
        });
      }
    } finally {
      span.end();
    }
  });
});

/**
 * DELETE /api/cart - Clear entire cart
 */
router.delete('/api/cart', async (req: Request, res: Response) => {
  return tracer.startActiveSpan('DELETE /api/cart', async (span) => {
    try {
      const sessionId = req.headers['x-session-id'] as string || 'default-session';

      span.setAttribute('session.id', sessionId);

      logWithTrace('info', 'Clearing cart', { sessionId });

      // Check for chaos engineering simulations
      await chaosSimulator.checkAndApplyChaos('cart-service', featureFlagClient);

      // Apply failure simulation
      await failureSimulator.checkAndApplyFailures('clear_cart');

      await cartStorage.clearCart(sessionId);

      // Record metrics
      recordCartOperation('clear_cart', true);

      logWithTrace('info', 'Cart cleared successfully', { sessionId });

      res.status(204).send();
    } catch (error) {
      span.recordException(error as Error);

      if (error instanceof SimulatedError) {
        recordCartOperation('clear_cart', false);
        recordCartError('clear_cart', 'simulated_error');
        logWithTrace('error', 'Simulated error occurred', { error: (error as Error).message });
        res.status(500).json({
          error: {
            code: 'SIMULATED_ERROR',
            message: (error as Error).message,
            trace_id: getTraceId(),
            timestamp: new Date().toISOString(),
          },
        });
      } else {
        recordCartOperation('clear_cart', false);
        recordCartError('clear_cart', 'internal_error');
        logWithTrace('error', 'Error clearing cart', { error: (error as Error).message });
        res.status(500).json({
          error: {
            code: 'INTERNAL_SERVER_ERROR',
            message: 'Failed to clear cart',
            trace_id: getTraceId(),
            timestamp: new Date().toISOString(),
          },
        });
      }
    } finally {
      span.end();
    }
  });
});

/**
 * GET /chaos/metrics - Get system metrics and active chaos simulations
 */
router.get('/chaos/metrics', (req: Request, res: Response) => {
  try {
    const metrics = chaosSimulator.getSystemMetrics();
    
    res.status(200).json({
      service: 'cart-service',
      timestamp: new Date().toISOString(),
      system_metrics: metrics
    });
  } catch (error) {
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

export default router;
