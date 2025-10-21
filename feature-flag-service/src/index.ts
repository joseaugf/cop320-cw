import './instrumentation';
import app from './app';
import { connectRedis, disconnectRedis } from './redis-client';
import { initializeDefaultFlags } from './flag-storage';

const PORT = process.env.PORT || 3003;

async function startServer() {
  try {
    // Connect to Redis
    await connectRedis();
    
    // Initialize default flags
    await initializeDefaultFlags();
    
    // Start Express server
    const server = app.listen(PORT, () => {
      console.log(`Feature Flag Service listening on port ${PORT}`);
    });

    // Graceful shutdown
    const shutdown = async () => {
      console.log('Shutting down gracefully...');
      server.close(async () => {
        await disconnectRedis();
        process.exit(0);
      });
    };

    process.on('SIGTERM', shutdown);
    process.on('SIGINT', shutdown);
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

startServer();
