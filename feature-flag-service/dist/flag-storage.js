"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.initializeDefaultFlags = initializeDefaultFlags;
exports.getFlag = getFlag;
exports.getAllFlags = getAllFlags;
exports.setFlag = setFlag;
exports.resetAllFlags = resetAllFlags;
const redis_client_1 = require("./redis-client");
const types_1 = require("./types");
const FLAG_PREFIX = 'flags:';
function getFlagKey(name) {
    return `${FLAG_PREFIX}${name}`;
}
async function initializeDefaultFlags() {
    console.log('Initializing default flags...');
    for (const flag of types_1.DEFAULT_FLAGS) {
        const key = getFlagKey(flag.name);
        const exists = await redis_client_1.redisClient.exists(key);
        if (!exists) {
            await redis_client_1.redisClient.set(key, JSON.stringify(flag));
            console.log(`Initialized flag: ${flag.name}`);
        }
    }
    console.log('Default flags initialized');
}
async function getFlag(name) {
    try {
        const key = getFlagKey(name);
        const data = await redis_client_1.redisClient.get(key);
        if (!data) {
            return null;
        }
        return JSON.parse(data);
    }
    catch (error) {
        console.error(`Error getting flag ${name}:`, error);
        throw error;
    }
}
async function getAllFlags() {
    try {
        const keys = await redis_client_1.redisClient.keys(`${FLAG_PREFIX}*`);
        const flags = [];
        for (const key of keys) {
            const data = await redis_client_1.redisClient.get(key);
            if (data) {
                flags.push(JSON.parse(data));
            }
        }
        return flags;
    }
    catch (error) {
        console.error('Error getting all flags:', error);
        throw error;
    }
}
async function setFlag(name, flag) {
    try {
        validateFlag(flag);
        const key = getFlagKey(name);
        await redis_client_1.redisClient.set(key, JSON.stringify(flag));
        console.log(`Flag ${name} updated:`, flag);
    }
    catch (error) {
        console.error(`Error setting flag ${name}:`, error);
        throw error;
    }
}
async function resetAllFlags() {
    try {
        console.log('Resetting all flags to defaults...');
        // Delete all existing flags
        const keys = await redis_client_1.redisClient.keys(`${FLAG_PREFIX}*`);
        if (keys.length > 0) {
            await redis_client_1.redisClient.del(keys);
        }
        // Reinitialize with defaults
        await initializeDefaultFlags();
        console.log('All flags reset to defaults');
    }
    catch (error) {
        console.error('Error resetting flags:', error);
        throw error;
    }
}
function validateFlag(flag) {
    if (!flag.name || typeof flag.name !== 'string') {
        throw new Error('Flag name is required and must be a string');
    }
    if (typeof flag.enabled !== 'boolean') {
        throw new Error('Flag enabled must be a boolean');
    }
    if (!flag.description || typeof flag.description !== 'string') {
        throw new Error('Flag description is required and must be a string');
    }
    if (flag.config) {
        if (flag.config.errorRate !== undefined) {
            if (typeof flag.config.errorRate !== 'number' ||
                flag.config.errorRate < 0 ||
                flag.config.errorRate > 100) {
                throw new Error('Error rate must be a number between 0 and 100');
            }
        }
        if (flag.config.latencyMs !== undefined) {
            if (typeof flag.config.latencyMs !== 'number' || flag.config.latencyMs < 0) {
                throw new Error('Latency must be a positive number');
            }
        }
        if (flag.config.memoryLeakMb !== undefined) {
            if (typeof flag.config.memoryLeakMb !== 'number' || flag.config.memoryLeakMb < 0) {
                throw new Error('Memory leak must be a positive number');
            }
        }
    }
}
