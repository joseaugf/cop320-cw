import { featureFlagApi } from './axios';

export interface FeatureFlagConfig {
  errorRate?: number;
  latencyMs?: number;
  memoryLeakMb?: number;
}

export interface FeatureFlag {
  name: string;
  enabled: boolean;
  description: string;
  config: FeatureFlagConfig;
}

export const getAllFlags = async (): Promise<FeatureFlag[]> => {
  const response = await featureFlagApi.get<FeatureFlag[]>('/api/flags');
  return response.data;
};

export const getFlag = async (name: string): Promise<FeatureFlag> => {
  const response = await featureFlagApi.get<FeatureFlag>(`/api/flags/${name}`);
  return response.data;
};

export const updateFlag = async (
  name: string,
  enabled: boolean,
  config: FeatureFlagConfig,
  description?: string
): Promise<FeatureFlag> => {
  // Get the current flag to preserve the description
  const currentFlag = await getFlag(name);
  
  const response = await featureFlagApi.put<FeatureFlag>(`/api/flags/${name}`, {
    name,
    enabled,
    description: description || currentFlag.description,
    config,
  });
  return response.data;
};

export const resetAllFlags = async (): Promise<void> => {
  await featureFlagApi.post('/api/flags/reset');
};
