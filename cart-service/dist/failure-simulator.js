"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.failureSimulator = exports.FailureSimulator = exports.SimulatedError = void 0;
const api_1 = require("@opentelemetry/api");
const feature_flag_client_1 = require("./feature-flag-client");
const tracer = api_1.trace.getTracer('cart-service');
class SimulatedError extends Error {
    constructor(message) {
        super(message);
        this.name = 'SimulatedError';
    }
}
exports.SimulatedError = SimulatedError;
class FailureSimulator {
    /**
     * Check feature flags and apply failure simulations
     */
    async checkAndApplyFailures(operation = 'cart_operation') {
        return tracer.startActiveSpan('failure_simulation.check', async (span) => {
            try {
                span.setAttribute('operation', operation);
                // Check for high latency simulation
                await this.simulateHighLatency(span);
                // Check for error rate simulation
                await this.simulateErrorRate(span);
            }
            catch (error) {
                span.recordException(error);
                throw error;
            }
            finally {
                span.end();
            }
        });
    }
    /**
     * Simulate high latency if flag is enabled
     */
    async simulateHighLatency(span) {
        const flagName = 'cart_high_latency';
        if (await feature_flag_client_1.featureFlagClient.isFlagEnabled(flagName)) {
            const config = await feature_flag_client_1.featureFlagClient.getFlagConfig(flagName);
            const latencyMs = config.latencyMs || 1000;
            console.warn(`Simulating high latency: ${latencyMs}ms`);
            span.setAttribute('simulated.latency_ms', latencyMs);
            span.addEvent('high_latency_simulation', { latency_ms: latencyMs });
            await new Promise(resolve => setTimeout(resolve, latencyMs));
        }
    }
    /**
     * Simulate errors based on configured error rate
     */
    async simulateErrorRate(span) {
        const flagName = 'cart_error_rate';
        if (await feature_flag_client_1.featureFlagClient.isFlagEnabled(flagName)) {
            const config = await feature_flag_client_1.featureFlagClient.getFlagConfig(flagName);
            const errorRate = config.errorRate || 30; // Default 30%
            // Generate random number to determine if error should occur
            const randomValue = Math.floor(Math.random() * 100);
            if (randomValue < errorRate) {
                console.error(`Simulating error (rate: ${errorRate}%)`);
                span.setAttribute('simulated.error', true);
                span.setAttribute('simulated.error_rate', errorRate);
                span.addEvent('error_simulation', { error_rate: errorRate });
                throw new SimulatedError(`Simulated error for observability demo (error rate: ${errorRate}%)`);
            }
        }
    }
}
exports.FailureSimulator = FailureSimulator;
// Global instance
exports.failureSimulator = new FailureSimulator();
