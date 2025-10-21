import { redisClient } from './redis-client';
import { FeatureFlag, DEFAULT_FLAGS } from './types';

const FLAG_PREFIX = 'flags:';

function getFlagKey(name: string): string {
  return `${FLAG_PREFIX}${name}`;
}

export async function initializeDefaultFlags(): Promise<void> {
  console.log('Initializing default flags...');
  
  for (const flag of DEFAULT_FLAGS) {
    const key = getFlagKey(flag.name);
    const exists = await redisClient.exists(key);
    
    if (!exists) {
      await redisClient.set(key, JSON.stringify(flag));
      console.log(`Initialized flag: ${flag.name}`);
    }
  }
  
  console.log('Default flags initialized');
}

export async function getFlag(name: string): Promise<FeatureFlag | null> {
  try {
    const key = getFlagKey(name);
    const data = await redisClient.get(key);
    
    if (!data) {
      return null;
    }
    
    return JSON.parse(data) as FeatureFlag;
  } catch (error) {
    console.error(`Error getting flag ${name}:`, error);
    throw error;
  }
}

export async function getAllFlags(): Promise<FeatureFlag[]> {
  try {
    const keys = await redisClient.keys(`${FLAG_PREFIX}*`);
    const flags: FeatureFlag[] = [];
    
    for (const key of keys) {
      const data = await redisClient.get(key);
      if (data) {
        flags.push(JSON.parse(data) as FeatureFlag);
      }
    }
    
    return flags;
  } catch (error) {
    console.error('Error getting all flags:', error);
    throw error;
  }
}

export async function setFlag(name: string, flag: FeatureFlag): Promise<void> {
  try {
    validateFlag(flag);
    const key = getFlagKey(name);
    await redisClient.set(key, JSON.stringify(flag));
    console.log(`Flag ${name} updated:`, flag);
  } catch (error) {
    console.error(`Error setting flag ${name}:`, error);
    throw error;
  }
}

export async function resetAllFlags(): Promise<void> {
  try {
    console.log('Resetting all flags to defaults...');
    
    // Delete all existing flags
    const keys = await redisClient.keys(`${FLAG_PREFIX}*`);
    if (keys.length > 0) {
      await redisClient.del(keys);
    }
    
    // Reinitialize with defaults
    await initializeDefaultFlags();
    
    console.log('All flags reset to defaults');
  } catch (error) {
    console.error('Error resetting flags:', error);
    throw error;
  }
}

function validateFlag(flag: FeatureFlag): void {
  if (!flag.name || typeof flag.name !== 'string') {
    throw new Error('Flag name is required and must be a string');
  }
  
  if (typeof flag.enabled !== 'boolean') {
    throw new Error('Flag enabled must be a boolean');
  }
  
  if (!flag.description || typeof flag.description !== 'string') {
    throw new Error('Flag description is required and must be a string');
  }
  
  if (flag.config) {
    if (flag.config.errorRate !== undefined) {
      if (typeof flag.config.errorRate !== 'number' || 
          flag.config.errorRate < 0 || 
          flag.config.errorRate > 100) {
        throw new Error('Error rate must be a number between 0 and 100');
      }
    }
    
    if (flag.config.latencyMs !== undefined) {
      if (typeof flag.config.latencyMs !== 'number' || flag.config.latencyMs < 0) {
        throw new Error('Latency must be a positive number');
      }
    }
    
    if (flag.config.memoryLeakMb !== undefined) {
      if (typeof flag.config.memoryLeakMb !== 'number' || flag.config.memoryLeakMb < 0) {
        throw new Error('Memory leak must be a positive number');
      }
    }
  }
}
