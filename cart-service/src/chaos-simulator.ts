/**
 * Chaos Engineering Simulator for safe infrastructure failure simulation.
 */

import * as os from 'os';
import * as fs from 'fs';
import * as path from 'path';
import { FeatureFlagClient } from './feature-flag-client';

interface ChaosConfig {
  // Disk Stress
  intensityLevel?: number;      // 1-10
  durationSeconds?: number;     // Duration in seconds
  
  // Pod Crash
  crashIntervalMinutes?: number;  // Interval between checks
  crashProbability?: number;      // 0-100 percentage
  
  // Network Delay
  delayMs?: number;              // Base delay in milliseconds
  jitterMs?: number;             // Random jitter ±ms
  
  // Allow any additional properties from feature flag config
  [key: string]: any;
}

interface SystemMetrics {
  timestamp: string;
  active_simulations: string[];
  cpu_usage_percent?: number;
  memory_usage_mb?: number;
}

/**
 * ChaosSimulator class for simulating infrastructure failures safely.
 */
class ChaosSimulator {
  private activeSimulations: Map<string, boolean> = new Map();
  private diskStressInterval?: NodeJS.Timeout;
  private crashSchedulerInterval?: NodeJS.Timeout;
  private tempFiles: string[] = [];

  constructor() {
    console.log('ChaosSimulator initialized');
  }

  /**
   * Check for active chaos flags and apply corresponding simulations.
   */
  async checkAndApplyChaos(
    serviceName: string,
    flagClient: FeatureFlagClient
  ): Promise<void> {
    try {
      // Check disk stress flag
      const diskStressFlag = await flagClient.getFlag('infrastructure_disk_stress');
      if (diskStressFlag?.enabled) {
        await this.simulateDiskStress(diskStressFlag.config);
      }

      // Check pod crash flag
      const podCrashFlag = await flagClient.getFlag('infrastructure_pod_crash');
      if (podCrashFlag?.enabled) {
        await this.simulatePodCrash(podCrashFlag.config, serviceName);
      }

      // Check network delay flag
      const networkDelayFlag = await flagClient.getFlag('infrastructure_network_delay');
      if (networkDelayFlag?.enabled) {
        await this.simulateNetworkDelay(networkDelayFlag.config);
      }
    } catch (error) {
      // Don't let chaos simulator errors crash the service
      console.error('Error in chaos simulation:', error);
    }
  }

  /**
   * Get current system metrics for monitoring chaos effects.
   */
  getSystemMetrics(): SystemMetrics {
    const metrics: SystemMetrics = {
      timestamp: new Date().toISOString(),
      active_simulations: Array.from(this.activeSimulations.entries())
        .filter(([_, active]) => active)
        .map(([name, _]) => name)
    };

    // Add basic memory metrics
    try {
      const memUsage = process.memoryUsage();
      metrics.memory_usage_mb = memUsage.rss / 1024 / 1024;
      
      // CPU usage (approximation using process.cpuUsage())
      const cpuUsage = process.cpuUsage();
      metrics.cpu_usage_percent = (cpuUsage.user + cpuUsage.system) / 1000000; // Convert to seconds
    } catch (error) {
      console.warn('Error collecting system metrics:', error);
    }

    return metrics;
  }

  /**
   * Simulate network latency between services.
   */
  private async simulateNetworkDelay(config: ChaosConfig): Promise<void> {
    const delayMs = config.delayMs ?? 2000;
    const jitterMs = config.jitterMs ?? 500;

    // Calculate actual delay with random jitter
    const jitter = Math.floor(Math.random() * (jitterMs * 2 + 1)) - jitterMs;
    const actualDelayMs = Math.max(0, delayMs + jitter);

    console.log(`🔥 CHAOS: Simulating network delay (${actualDelayMs}ms)`);

    // Apply the delay
    await new Promise(resolve => setTimeout(resolve, actualDelayMs));
  }

  /**
   * Simulate pod crashes by scheduling periodic exits.
   */
  private async simulatePodCrash(
    config: ChaosConfig,
    serviceName: string
  ): Promise<void> {
    // Check if already running
    if (this.activeSimulations.get('pod_crash')) {
      return;
    }

    const intervalMinutes = config.crashIntervalMinutes ?? 5;
    const crashProbability = config.crashProbability ?? 30;

    console.log(
      `🔥 CHAOS: Starting pod crash scheduler ` +
      `(interval=${intervalMinutes}min, probability=${crashProbability}%)`
    );
    this.activeSimulations.set('pod_crash', true);

    // Start crash scheduler
    const intervalMs = intervalMinutes * 60 * 1000;
    this.crashSchedulerInterval = setInterval(() => {
      // Check if we should crash based on probability
      const roll = Math.floor(Math.random() * 100) + 1;
      if (roll <= crashProbability) {
        console.error(
          `🔥 CHAOS: Simulating pod crash for ${serviceName} ` +
          `(probability=${crashProbability}%)`
        );
        // Force exit the process
        process.exit(1);
      }
    }, intervalMs);
  }

  /**
   * Simulate high disk I/O by creating intensive read/write operations.
   */
  private async simulateDiskStress(config: ChaosConfig): Promise<void> {
    // Check if already running
    if (this.activeSimulations.get('disk_stress')) {
      return;
    }

    const intensity = config.intensityLevel ?? 5;
    const duration = config.durationSeconds ?? 30;

    console.log(
      `🔥 CHAOS: Starting disk I/O stress simulation ` +
      `(intensity=${intensity}, duration=${duration}s)`
    );
    this.activeSimulations.set('disk_stress', true);

    // Start disk stress in background
    this.performDiskStress(intensity, duration);
  }

  /**
   * Perform disk stress operations in the background.
   */
  private performDiskStress(intensity: number, duration: number): void {
    const startTime = Date.now();
    const fileSizeMB = intensity; // 1-10 MB per file
    const numFiles = intensity; // 1-10 files
    const tmpDir = os.tmpdir();

    // Create temp files
    for (let i = 0; i < numFiles; i++) {
      const tempFile = path.join(tmpDir, `chaos_disk_stress_${process.pid}_${i}.tmp`);
      this.tempFiles.push(tempFile);

      try {
        // Write operation
        const data = Buffer.alloc(fileSizeMB * 1024 * 1024);
        fs.writeFileSync(tempFile, data);

        // Read operation
        fs.readFileSync(tempFile);
      } catch (error) {
        console.warn(`Error during disk I/O: ${error}`);
      }
    }

    // Keep doing I/O operations until duration expires
    const ioInterval = setInterval(() => {
      const elapsed = (Date.now() - startTime) / 1000;
      
      if (elapsed >= duration) {
        clearInterval(ioInterval);
        this.cleanupDiskStress();
        return;
      }

      // Perform read/write cycles on existing files
      for (const tempFile of this.tempFiles) {
        try {
          if (fs.existsSync(tempFile)) {
            // Read
            fs.readFileSync(tempFile);

            // Write (append)
            const data = Buffer.alloc(1024);
            fs.appendFileSync(tempFile, data);
          }
        } catch (error) {
          console.warn(`Error during disk I/O cycle: ${error}`);
        }
      }
    }, 100); // Small delay between cycles
  }

  /**
   * Cleanup disk stress resources.
   */
  private cleanupDiskStress(): void {
    // Cleanup temp files
    for (const tempFile of this.tempFiles) {
      try {
        if (fs.existsSync(tempFile)) {
          fs.unlinkSync(tempFile);
        }
      } catch (error) {
        console.warn(`Error removing temp file ${tempFile}: ${error}`);
      }
    }

    this.tempFiles = [];
    this.activeSimulations.set('disk_stress', false);
    console.log('🔥 CHAOS: Disk I/O stress simulation completed');
  }
}

// Global instance
export const chaosSimulator = new ChaosSimulator();
