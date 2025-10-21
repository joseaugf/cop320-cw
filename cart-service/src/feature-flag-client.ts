import axios, { AxiosError } from 'axios';
import { trace } from '@opentelemetry/api';

const tracer = trace.getTracer('cart-service');

interface FeatureFlag {
  name: string;
  enabled: boolean;
  description: string;
  config: {
    errorRate?: number;
    latencyMs?: number;
    [key: string]: any;
  };
}

export class FeatureFlagClient {
  private baseUrl: string;
  private timeout: number;

  constructor() {
    this.baseUrl = process.env.FEATURE_FLAG_SERVICE_URL || 'http://localhost:3003';
    this.timeout = 2000; // 2 second timeout
  }

  /**
   * Get a specific feature flag
   */
  async getFlag(flagName: string): Promise<FeatureFlag | null> {
    return tracer.startActiveSpan('feature_flag.get_flag', async (span) => {
      try {
        span.setAttribute('flag.name', flagName);

        const response = await axios.get<FeatureFlag>(
          `${this.baseUrl}/api/flags/${flagName}`,
          {
            timeout: this.timeout,
            headers: { 'Content-Type': 'application/json' },
          }
        );

        if (response.status === 200) {
          span.setAttribute('flag.enabled', response.data.enabled);
          return response.data;
        }

        return null;
      } catch (error) {
        if (axios.isAxiosError(error)) {
          const axiosError = error as AxiosError;
          if (axiosError.response?.status === 404) {
            console.warn(`Flag '${flagName}' not found`);
          } else if (axiosError.code === 'ECONNABORTED') {
            console.warn(`Timeout fetching flag '${flagName}'`);
          } else {
            console.error(`Error fetching flag '${flagName}':`, axiosError.message);
          }
        } else {
          console.error(`Error fetching flag '${flagName}':`, error);
        }
        span.setAttribute('error', true);
        return null;
      } finally {
        span.end();
      }
    });
  }

  /**
   * Check if a feature flag is enabled
   */
  async isFlagEnabled(flagName: string): Promise<boolean> {
    const flag = await this.getFlag(flagName);
    return flag?.enabled ?? false;
  }

  /**
   * Get the configuration for a feature flag
   */
  async getFlagConfig(flagName: string): Promise<Record<string, any>> {
    const flag = await this.getFlag(flagName);
    return flag?.config ?? {};
  }
}

// Global instance
export const featureFlagClient = new FeatureFlagClient();
