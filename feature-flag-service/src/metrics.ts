import { metrics } from '@opentelemetry/api';
import { MeterProvider } from '@opentelemetry/sdk-metrics';
import { getAllFlags } from './flag-storage';

const meterProvider = metrics.getMeterProvider() as MeterProvider;
const meter = meterProvider.getMeter('feature-flag-service');

// Counter for flag changes
export const flagChangesCounter = meter.createCounter('flag_changes_total', {
  description: 'Total number of flag changes',
});

// Observable gauge for active flags count
export const activeFlagsGauge = meter.createObservableGauge('active_flags_count', {
  description: 'Number of currently active flags',
});

// Set up callback for active flags gauge
activeFlagsGauge.addCallback(async (observableResult) => {
  try {
    const flags = await getAllFlags();
    const activeCount = flags.filter(flag => flag.enabled).length;
    observableResult.observe(activeCount);
  } catch (error) {
    console.error('Error observing active flags count:', error);
  }
});

// Counter for flag operations
export const flagOperationsCounter = meter.createCounter('flag_operations_total', {
  description: 'Total number of flag operations',
});

export function recordFlagChange(flagName: string, enabled: boolean): void {
  flagChangesCounter.add(1, {
    flag_name: flagName,
    enabled: enabled.toString(),
  });
}

export function recordFlagOperation(operation: string, flagName?: string): void {
  const attributes: Record<string, string> = {
    operation,
  };
  
  if (flagName) {
    attributes.flag_name = flagName;
  }
  
  flagOperationsCounter.add(1, attributes);
}
