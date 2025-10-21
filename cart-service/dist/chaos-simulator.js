"use strict";
/**
 * Chaos Engineering Simulator for safe infrastructure failure simulation.
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.chaosSimulator = void 0;
const os = __importStar(require("os"));
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
/**
 * ChaosSimulator class for simulating infrastructure failures safely.
 */
class ChaosSimulator {
    constructor() {
        this.activeSimulations = new Map();
        this.tempFiles = [];
        console.log('ChaosSimulator initialized');
    }
    /**
     * Check for active chaos flags and apply corresponding simulations.
     */
    async checkAndApplyChaos(serviceName, flagClient) {
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
        }
        catch (error) {
            // Don't let chaos simulator errors crash the service
            console.error('Error in chaos simulation:', error);
        }
    }
    /**
     * Get current system metrics for monitoring chaos effects.
     */
    getSystemMetrics() {
        const metrics = {
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
        }
        catch (error) {
            console.warn('Error collecting system metrics:', error);
        }
        return metrics;
    }
    /**
     * Simulate network latency between services.
     */
    async simulateNetworkDelay(config) {
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
    async simulatePodCrash(config, serviceName) {
        // Check if already running
        if (this.activeSimulations.get('pod_crash')) {
            return;
        }
        const intervalMinutes = config.crashIntervalMinutes ?? 5;
        const crashProbability = config.crashProbability ?? 30;
        console.log(`🔥 CHAOS: Starting pod crash scheduler ` +
            `(interval=${intervalMinutes}min, probability=${crashProbability}%)`);
        this.activeSimulations.set('pod_crash', true);
        // Start crash scheduler
        const intervalMs = intervalMinutes * 60 * 1000;
        this.crashSchedulerInterval = setInterval(() => {
            // Check if we should crash based on probability
            const roll = Math.floor(Math.random() * 100) + 1;
            if (roll <= crashProbability) {
                console.error(`🔥 CHAOS: Simulating pod crash for ${serviceName} ` +
                    `(probability=${crashProbability}%)`);
                // Force exit the process
                process.exit(1);
            }
        }, intervalMs);
    }
    /**
     * Simulate high disk I/O by creating intensive read/write operations.
     */
    async simulateDiskStress(config) {
        // Check if already running
        if (this.activeSimulations.get('disk_stress')) {
            return;
        }
        const intensity = config.intensityLevel ?? 5;
        const duration = config.durationSeconds ?? 30;
        console.log(`🔥 CHAOS: Starting disk I/O stress simulation ` +
            `(intensity=${intensity}, duration=${duration}s)`);
        this.activeSimulations.set('disk_stress', true);
        // Start disk stress in background
        this.performDiskStress(intensity, duration);
    }
    /**
     * Perform disk stress operations in the background.
     */
    performDiskStress(intensity, duration) {
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
            }
            catch (error) {
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
                }
                catch (error) {
                    console.warn(`Error during disk I/O cycle: ${error}`);
                }
            }
        }, 100); // Small delay between cycles
    }
    /**
     * Cleanup disk stress resources.
     */
    cleanupDiskStress() {
        // Cleanup temp files
        for (const tempFile of this.tempFiles) {
            try {
                if (fs.existsSync(tempFile)) {
                    fs.unlinkSync(tempFile);
                }
            }
            catch (error) {
                console.warn(`Error removing temp file ${tempFile}: ${error}`);
            }
        }
        this.tempFiles = [];
        this.activeSimulations.set('disk_stress', false);
        console.log('🔥 CHAOS: Disk I/O stress simulation completed');
    }
}
// Global instance
exports.chaosSimulator = new ChaosSimulator();
