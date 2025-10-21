"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.flagOperationsCounter = exports.activeFlagsGauge = exports.flagChangesCounter = void 0;
exports.recordFlagChange = recordFlagChange;
exports.recordFlagOperation = recordFlagOperation;
const api_1 = require("@opentelemetry/api");
const flag_storage_1 = require("./flag-storage");
const meterProvider = api_1.metrics.getMeterProvider();
const meter = meterProvider.getMeter('feature-flag-service');
// Counter for flag changes
exports.flagChangesCounter = meter.createCounter('flag_changes_total', {
    description: 'Total number of flag changes',
});
// Observable gauge for active flags count
exports.activeFlagsGauge = meter.createObservableGauge('active_flags_count', {
    description: 'Number of currently active flags',
});
// Set up callback for active flags gauge
exports.activeFlagsGauge.addCallback(async (observableResult) => {
    try {
        const flags = await (0, flag_storage_1.getAllFlags)();
        const activeCount = flags.filter(flag => flag.enabled).length;
        observableResult.observe(activeCount);
    }
    catch (error) {
        console.error('Error observing active flags count:', error);
    }
});
// Counter for flag operations
exports.flagOperationsCounter = meter.createCounter('flag_operations_total', {
    description: 'Total number of flag operations',
});
function recordFlagChange(flagName, enabled) {
    exports.flagChangesCounter.add(1, {
        flag_name: flagName,
        enabled: enabled.toString(),
    });
}
function recordFlagOperation(operation, flagName) {
    const attributes = {
        operation,
    };
    if (flagName) {
        attributes.flag_name = flagName;
    }
    exports.flagOperationsCounter.add(1, attributes);
}
