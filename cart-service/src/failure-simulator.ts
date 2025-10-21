import { trace, Span } from '@opentelemetry/api';
import { featureFlagClient } from './feature-flag-client';

const tracer = trace.getTracer('cart-service');

export class SimulatedError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'SimulatedError';
  }
}

export class FailureSimulator {
  /**
   * Check feature flags and apply failure simulations
   */
  async checkAndApplyFailures(operation: string = 'cart_operation'): Promise<void> {
    return tracer.startActiveSpan('failure_simulation.check', async (span) => {
      try {
        span.setAttribute('operation', operation);

        // Check for high latency simulation
        await this.simulateHighLatency(span);

        // Check for error rate simulation
        await this.simulateErrorRate(span);
      } catch (error) {
        span.recordException(error as Error);
        throw error;
      } finally {
        span.end();
      }
    });
  }

  /**
   * Simulate high latency if flag is enabled
   */
  private async simulateHighLatency(span: Span): Promise<void> {
    const flagName = 'cart_high_latency';

    if (await featureFlagClient.isFlagEnabled(flagName)) {
      const config = await featureFlagClient.getFlagConfig(flagName);
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
  private async simulateErrorRate(span: Span): Promise<void> {
    const flagName = 'cart_error_rate';

    if (await featureFlagClient.isFlagEnabled(flagName)) {
      const config = await featureFlagClient.getFlagConfig(flagName);
      const errorRate = config.errorRate || 30; // Default 30%

      // Generate random number to determine if error should occur
      const randomValue = Math.floor(Math.random() * 100);
      
      if (randomValue < errorRate) {
        console.error(`Simulating error (rate: ${errorRate}%)`);
        span.setAttribute('simulated.error', true);
        span.setAttribute('simulated.error_rate', errorRate);
        span.addEvent('error_simulation', { error_rate: errorRate });

        throw new SimulatedError(
          `Simulated error for observability demo (error rate: ${errorRate}%)`
        );
      }
    }
  }
}

// Global instance
export const failureSimulator = new FailureSimulator();
