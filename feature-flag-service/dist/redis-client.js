"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.redisClient = void 0;
exports.connectRedis = connectRedis;
exports.disconnectRedis = disconnectRedis;
const redis_1 = require("redis");
const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';
exports.redisClient = (0, redis_1.createClient)({
    url: redisUrl,
});
exports.redisClient.on('error', (err) => {
    console.error('Redis Client Error:', err);
});
exports.redisClient.on('connect', () => {
    console.log('Redis Client Connected');
});
exports.redisClient.on('ready', () => {
    console.log('Redis Client Ready');
});
exports.redisClient.on('reconnecting', () => {
    console.log('Redis Client Reconnecting');
});
async function connectRedis() {
    try {
        await exports.redisClient.connect();
        console.log('Successfully connected to Redis');
    }
    catch (error) {
        console.error('Failed to connect to Redis:', error);
        throw error;
    }
}
async function disconnectRedis() {
    try {
        await exports.redisClient.quit();
        console.log('Redis connection closed');
    }
    catch (error) {
        console.error('Error closing Redis connection:', error);
    }
}
