"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.featureFlagClient = exports.FeatureFlagClient = void 0;
const axios_1 = __importDefault(require("axios"));
const api_1 = require("@opentelemetry/api");
const tracer = api_1.trace.getTracer('cart-service');
class FeatureFlagClient {
    constructor() {
        this.baseUrl = process.env.FEATURE_FLAG_SERVICE_URL || 'http://localhost:3003';
        this.timeout = 2000; // 2 second timeout
    }
    /**
     * Get a specific feature flag
     */
    async getFlag(flagName) {
        return tracer.startActiveSpan('feature_flag.get_flag', async (span) => {
            try {
                span.setAttribute('flag.name', flagName);
                const response = await axios_1.default.get(`${this.baseUrl}/api/flags/${flagName}`, {
                    timeout: this.timeout,
                    headers: { 'Content-Type': 'application/json' },
                });
                if (response.status === 200) {
                    span.setAttribute('flag.enabled', response.data.enabled);
                    return response.data;
                }
                return null;
            }
            catch (error) {
                if (axios_1.default.isAxiosError(error)) {
                    const axiosError = error;
                    if (axiosError.response?.status === 404) {
                        console.warn(`Flag '${flagName}' not found`);
                    }
                    else if (axiosError.code === 'ECONNABORTED') {
                        console.warn(`Timeout fetching flag '${flagName}'`);
                    }
                    else {
                        console.error(`Error fetching flag '${flagName}':`, axiosError.message);
                    }
                }
                else {
                    console.error(`Error fetching flag '${flagName}':`, error);
                }
                span.setAttribute('error', true);
                return null;
            }
            finally {
                span.end();
            }
        });
    }
    /**
     * Check if a feature flag is enabled
     */
    async isFlagEnabled(flagName) {
        const flag = await this.getFlag(flagName);
        return flag?.enabled ?? false;
    }
    /**
     * Get the configuration for a feature flag
     */
    async getFlagConfig(flagName) {
        const flag = await this.getFlag(flagName);
        return flag?.config ?? {};
    }
}
exports.FeatureFlagClient = FeatureFlagClient;
// Global instance
exports.featureFlagClient = new FeatureFlagClient();
