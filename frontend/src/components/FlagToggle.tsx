import { useState } from 'react';
import { FeatureFlag } from '../api/featureFlags';
import './FlagToggle.css';

interface FlagToggleProps {
  flag: FeatureFlag;
  onUpdate: (name: string, enabled: boolean, config: any) => Promise<void>;
}

function FlagToggle({ flag, onUpdate }: FlagToggleProps) {
  const [enabled, setEnabled] = useState(flag.enabled);
  const [errorRate, setErrorRate] = useState(flag.config.errorRate || 0);
  const [latencyMs, setLatencyMs] = useState(flag.config.latencyMs || 0);
  const [memoryLeakMb, setMemoryLeakMb] = useState(flag.config.memoryLeakMb || 0);
  const [updating, setUpdating] = useState(false);

  const handleToggle = async () => {
    const newEnabled = !enabled;
    setEnabled(newEnabled);
    
    try {
      setUpdating(true);
      await onUpdate(flag.name, newEnabled, {
        errorRate,
        latencyMs,
        memoryLeakMb,
      });
    } catch (err) {
      // Revert on error
      setEnabled(!newEnabled);
    } finally {
      setUpdating(false);
    }
  };

  const handleConfigUpdate = async () => {
    try {
      setUpdating(true);
      await onUpdate(flag.name, enabled, {
        errorRate,
        latencyMs,
        memoryLeakMb,
      });
    } finally {
      setUpdating(false);
    }
  };

  return (
    <div className={`flag-toggle ${enabled ? 'enabled' : 'disabled'}`}>
      <div className="flag-header">
        <div className="flag-info">
          <h3 className="flag-name">{flag.name}</h3>
          <p className="flag-description">{flag.description}</p>
        </div>
        <button
          className={`toggle-switch ${enabled ? 'on' : 'off'}`}
          onClick={handleToggle}
          disabled={updating}
        >
          <span className="toggle-slider"></span>
        </button>
      </div>

      {enabled && (
        <div className="flag-config">
          {flag.config.errorRate !== undefined && (
            <div className="config-field">
              <label htmlFor={`${flag.name}-errorRate`}>
                Error Rate (%): {errorRate}
              </label>
              <input
                type="range"
                id={`${flag.name}-errorRate`}
                min="0"
                max="100"
                value={errorRate}
                onChange={(e) => setErrorRate(Number(e.target.value))}
                onMouseUp={handleConfigUpdate}
                onTouchEnd={handleConfigUpdate}
              />
            </div>
          )}

          {flag.config.latencyMs !== undefined && (
            <div className="config-field">
              <label htmlFor={`${flag.name}-latencyMs`}>
                Latency (ms): {latencyMs}
              </label>
              <input
                type="range"
                id={`${flag.name}-latencyMs`}
                min="0"
                max="5000"
                step="100"
                value={latencyMs}
                onChange={(e) => setLatencyMs(Number(e.target.value))}
                onMouseUp={handleConfigUpdate}
                onTouchEnd={handleConfigUpdate}
              />
            </div>
          )}

          {flag.config.memoryLeakMb !== undefined && (
            <div className="config-field">
              <label htmlFor={`${flag.name}-memoryLeakMb`}>
                Memory Leak (MB/min): {memoryLeakMb}
              </label>
              <input
                type="range"
                id={`${flag.name}-memoryLeakMb`}
                min="0"
                max="100"
                step="5"
                value={memoryLeakMb}
                onChange={(e) => setMemoryLeakMb(Number(e.target.value))}
                onMouseUp={handleConfigUpdate}
                onTouchEnd={handleConfigUpdate}
              />
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export default FlagToggle;
