import { Router, Request, Response, NextFunction } from 'express';
import { trace, context } from '@opentelemetry/api';
import { getFlag, getAllFlags, setFlag, resetAllFlags } from './flag-storage';
import { FeatureFlag } from './types';
import { recordFlagChange, recordFlagOperation } from './metrics';

const router = Router();

// Middleware to log requests with trace context
router.use((req: Request, res: Response, next: NextFunction) => {
  const span = trace.getSpan(context.active());
  const traceId = span?.spanContext().traceId || 'no-trace';
  
  console.log({
    timestamp: new Date().toISOString(),
    method: req.method,
    path: req.path,
    trace_id: traceId,
  });
  
  next();
});

// GET /api/flags - List all flags
router.get('/api/flags', async (req: Request, res: Response) => {
  try {
    recordFlagOperation('list');
    const flags = await getAllFlags();
    res.json(flags);
  } catch (error) {
    const span = trace.getSpan(context.active());
    const traceId = span?.spanContext().traceId || 'no-trace';
    
    console.error({
      timestamp: new Date().toISOString(),
      error: 'Failed to get flags',
      trace_id: traceId,
      details: error instanceof Error ? error.message : 'Unknown error',
    });
    
    res.status(500).json({
      error: {
        code: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to retrieve flags',
        trace_id: traceId,
        timestamp: new Date().toISOString(),
      },
    });
  }
});

// GET /api/flags/:name - Get specific flag
router.get('/api/flags/:name', async (req: Request, res: Response) => {
  try {
    const { name } = req.params;
    recordFlagOperation('get', name);
    const flag = await getFlag(name);
    
    if (!flag) {
      const span = trace.getSpan(context.active());
      const traceId = span?.spanContext().traceId || 'no-trace';
      
      return res.status(404).json({
        error: {
          code: 'FLAG_NOT_FOUND',
          message: `Flag '${name}' not found`,
          trace_id: traceId,
          timestamp: new Date().toISOString(),
        },
      });
    }
    
    res.json(flag);
  } catch (error) {
    const span = trace.getSpan(context.active());
    const traceId = span?.spanContext().traceId || 'no-trace';
    
    console.error({
      timestamp: new Date().toISOString(),
      error: 'Failed to get flag',
      flag_name: req.params.name,
      trace_id: traceId,
      details: error instanceof Error ? error.message : 'Unknown error',
    });
    
    res.status(500).json({
      error: {
        code: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to retrieve flag',
        trace_id: traceId,
        timestamp: new Date().toISOString(),
      },
    });
  }
});

// PUT /api/flags/:name - Update flag
router.put('/api/flags/:name', async (req: Request, res: Response) => {
  try {
    const { name } = req.params;
    const flagData = req.body as FeatureFlag;
    
    // Ensure the name in the body matches the URL parameter
    if (flagData.name && flagData.name !== name) {
      const span = trace.getSpan(context.active());
      const traceId = span?.spanContext().traceId || 'no-trace';
      
      return res.status(400).json({
        error: {
          code: 'INVALID_REQUEST',
          message: 'Flag name in body does not match URL parameter',
          trace_id: traceId,
          timestamp: new Date().toISOString(),
        },
      });
    }
    
    // Set the name from URL parameter
    flagData.name = name;
    
    // Check if flag exists
    const existingFlag = await getFlag(name);
    if (!existingFlag) {
      const span = trace.getSpan(context.active());
      const traceId = span?.spanContext().traceId || 'no-trace';
      
      return res.status(404).json({
        error: {
          code: 'FLAG_NOT_FOUND',
          message: `Flag '${name}' not found`,
          trace_id: traceId,
          timestamp: new Date().toISOString(),
        },
      });
    }
    
    await setFlag(name, flagData);
    
    // Record metrics
    recordFlagOperation('update', name);
    recordFlagChange(name, flagData.enabled);
    
    const span = trace.getSpan(context.active());
    const traceId = span?.spanContext().traceId || 'no-trace';
    
    console.log({
      timestamp: new Date().toISOString(),
      action: 'flag_updated',
      flag_name: name,
      enabled: flagData.enabled,
      trace_id: traceId,
    });
    
    res.json(flagData);
  } catch (error) {
    const span = trace.getSpan(context.active());
    const traceId = span?.spanContext().traceId || 'no-trace';
    
    console.error({
      timestamp: new Date().toISOString(),
      error: 'Failed to update flag',
      flag_name: req.params.name,
      trace_id: traceId,
      details: error instanceof Error ? error.message : 'Unknown error',
    });
    
    res.status(400).json({
      error: {
        code: 'VALIDATION_ERROR',
        message: error instanceof Error ? error.message : 'Failed to update flag',
        trace_id: traceId,
        timestamp: new Date().toISOString(),
      },
    });
  }
});

// POST /api/flags/reset - Reset all flags
router.post('/api/flags/reset', async (req: Request, res: Response) => {
  try {
    await resetAllFlags();
    
    // Record metrics
    recordFlagOperation('reset');
    
    const span = trace.getSpan(context.active());
    const traceId = span?.spanContext().traceId || 'no-trace';
    
    console.log({
      timestamp: new Date().toISOString(),
      action: 'flags_reset',
      trace_id: traceId,
    });
    
    res.json({
      message: 'All flags reset to defaults',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    const span = trace.getSpan(context.active());
    const traceId = span?.spanContext().traceId || 'no-trace';
    
    console.error({
      timestamp: new Date().toISOString(),
      error: 'Failed to reset flags',
      trace_id: traceId,
      details: error instanceof Error ? error.message : 'Unknown error',
    });
    
    res.status(500).json({
      error: {
        code: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to reset flags',
        trace_id: traceId,
        timestamp: new Date().toISOString(),
      },
    });
  }
});

export default router;
