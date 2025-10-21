"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.DEFAULT_FLAGS = void 0;
exports.DEFAULT_FLAGS = [
    {
        name: 'catalog_high_latency',
        enabled: false,
        description: 'Simulates high latency in catalog service',
        config: {
            latencyMs: 2000,
        },
    },
    {
        name: 'catalog_error_rate',
        enabled: false,
        description: 'Simulates errors in catalog service',
        config: {
            errorRate: 30,
        },
    },
    {
        name: 'cart_high_latency',
        enabled: false,
        description: 'Simulates high latency in cart service',
        config: {
            latencyMs: 1500,
        },
    },
    {
        name: 'cart_error_rate',
        enabled: false,
        description: 'Simulates errors in cart service',
        config: {
            errorRate: 25,
        },
    },
    {
        name: 'checkout_failure',
        enabled: false,
        description: 'Simulates checkout failures',
        config: {
            errorRate: 50,
        },
    },
    {
        name: 'database_slow_queries',
        enabled: false,
        description: 'Simulates slow database queries',
        config: {
            latencyMs: 3000,
        },
    },
    {
        name: 'memory_leak_simulation',
        enabled: false,
        description: 'Simulates memory leak',
        config: {
            memoryLeakMb: 10,
        },
    },
    {
        name: 'infrastructure_disk_stress',
        enabled: false,
        description: 'Simulates high disk I/O stress',
        config: {
            intensityLevel: 5,
            durationSeconds: 30,
        },
    },
    {
        name: 'infrastructure_pod_crash',
        enabled: false,
        description: 'Causes pods to crash periodically',
        config: {
            crashIntervalMinutes: 5,
            crashProbability: 30,
        },
    },
    {
        name: 'infrastructure_db_connection_fail',
        enabled: false,
        description: 'Simulates database connection failures',
        config: {
            failureRate: 50,
            timeoutMs: 1000,
        },
    },
    {
        name: 'infrastructure_network_delay',
        enabled: false,
        description: 'Simulates network latency between services',
        config: {
            delayMs: 2000,
            jitterMs: 500,
        },
    },
];
