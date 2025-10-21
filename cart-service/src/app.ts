import express, { Request, Response, NextFunction } from 'express';
import { redisClient } from './redis-client';
import routes from './routes';

const app = express();

app.use(express.json());

// API routes
app.use(routes);

// Health check endpoint
app.get('/health', async (req: Request, res: Response) => {
  try {
    // Check Redis connection
    await redisClient.ping();
    
    res.status(200).json({
      status: 'healthy',
      service: 'cart-service',
      timestamp: new Date().toISOString(),
      redis: 'connected',
    });
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      service: 'cart-service',
      timestamp: new Date().toISOString(),
      redis: 'disconnected',
      error: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

// Error handling middleware
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  console.error('Error:', err);
  res.status(500).json({
    error: {
      code: 'INTERNAL_SERVER_ERROR',
      message: err.message,
      timestamp: new Date().toISOString(),
    },
  });
});

export default app;
