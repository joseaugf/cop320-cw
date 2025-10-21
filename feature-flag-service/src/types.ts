export interface ChaosConfig {
  // Disk Stress
  intensityLevel?: number;      // 1-10
  durationSeconds?: number;     // Duration in seconds
  
  // Pod Crash
  crashIntervalMinutes?: number;  // Interval between checks
  crashProbability?: number;      // 0-100 percentage
  
  // DB Connection Fail
  failureRate?: number;          // 0-100 percentage
  timeoutMs?: number;            // Timeout in milliseconds
  
  // Network Delay
  delayMs?: number;              // Base delay in milliseconds
  jitterMs?: number;             // Random jitter ±ms
}

export interface FeatureFlagConfig {
  errorRate?: number;      // 0-100
  latencyMs?: number;       // milliseconds
  memoryLeakMb?: number;    // MB per minute
  ioIntensity?: number;     // 1-100 (disk I/O stress intensity)
  crashInterval?: number;   // seconds between crashes
  delayMs?: number;         // network delay in milliseconds
  
  // Chaos-specific configs (using ChaosConfig properties)
  intensityLevel?: number;
  durationSeconds?: number;
  crashIntervalMinutes?: number;
  crashProbability?: number;
  failureRate?: number;
  timeoutMs?: number;
  jitterMs?: number;
}

export interface FeatureFlag {
  name: string;
  enabled: boolean;
  description: string;
  config: FeatureFlagConfig;
}

export const DEFAULT_FLAGS: FeatureFlag[] = [
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
