"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const redis_client_1 = require("./redis-client");
const routes_1 = __importDefault(require("./routes"));
const app = (0, express_1.default)();
app.use(express_1.default.json());
// API routes
app.use(routes_1.default);
// Health check endpoint
app.get('/health', async (req, res) => {
    try {
        // Check Redis connection
        await redis_client_1.redisClient.ping();
        res.status(200).json({
            status: 'healthy',
            service: 'feature-flag-service',
            timestamp: new Date().toISOString(),
            redis: 'connected',
        });
    }
    catch (error) {
        res.status(503).json({
            status: 'unhealthy',
            service: 'feature-flag-service',
            timestamp: new Date().toISOString(),
            redis: 'disconnected',
            error: error instanceof Error ? error.message : 'Unknown error',
        });
    }
});
// Error handling middleware
app.use((err, req, res, next) => {
    console.error('Error:', err);
    res.status(500).json({
        error: {
            code: 'INTERNAL_SERVER_ERROR',
            message: err.message,
            timestamp: new Date().toISOString(),
        },
    });
});
exports.default = app;
