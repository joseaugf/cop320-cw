"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
require("./instrumentation");
const app_1 = __importDefault(require("./app"));
const redis_client_1 = require("./redis-client");
const flag_storage_1 = require("./flag-storage");
const PORT = process.env.PORT || 3003;
async function startServer() {
    try {
        // Connect to Redis
        await (0, redis_client_1.connectRedis)();
        // Initialize default flags
        await (0, flag_storage_1.initializeDefaultFlags)();
        // Start Express server
        const server = app_1.default.listen(PORT, () => {
            console.log(`Feature Flag Service listening on port ${PORT}`);
        });
        // Graceful shutdown
        const shutdown = async () => {
            console.log('Shutting down gracefully...');
            server.close(async () => {
                await (0, redis_client_1.disconnectRedis)();
                process.exit(0);
            });
        };
        process.on('SIGTERM', shutdown);
        process.on('SIGINT', shutdown);
    }
    catch (error) {
        console.error('Failed to start server:', error);
        process.exit(1);
    }
}
startServer();
