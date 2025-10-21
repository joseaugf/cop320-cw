import { useState, useEffect } from 'react';
import { getAllFlags, updateFlag, resetAllFlags, FeatureFlag } from '../api/featureFlags';
import FlagToggle from '../components/FlagToggle';
import LoadingSpinner from '../components/LoadingSpinner';
import ErrorMessage from '../components/ErrorMessage';
import './AdminPage.css';

function AdminPage() {
  const [flags, setFlags] = useState<FeatureFlag[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [resetting, setResetting] = useState(false);

  const fetchFlags = async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await getAllFlags();
      setFlags(data);
    } catch (err: any) {
      setError(err.response?.data?.error?.message || 'Failed to load feature flags. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleUpdateFlag = async (name: string, enabled: boolean, config: any) => {
    try {
      const updatedFlag = await updateFlag(name, enabled, config);
      setFlags((prevFlags) =>
        prevFlags.map((flag) => (flag.name === name ? updatedFlag : flag))
      );
    } catch (err: any) {
      alert(err.response?.data?.error?.message || 'Failed to update flag. Please try again.');
      throw err;
    }
  };

  const handleResetAll = async () => {
    if (!window.confirm('Are you sure you want to reset all flags to their default state?')) {
      return;
    }

    try {
      setResetting(true);
      await resetAllFlags();
      await fetchFlags();
    } catch (err: any) {
      alert(err.response?.data?.error?.message || 'Failed to reset flags. Please try again.');
    } finally {
      setResetting(false);
    }
  };

  useEffect(() => {
    fetchFlags();
  }, []);

  if (loading) return <LoadingSpinner />;
  if (error) return <ErrorMessage message={error} onRetry={fetchFlags} />;

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>⚙️ Admin Panel</h1>
        <p className="page-subtitle">Control feature flags to simulate failures</p>
      </div>

      <div className="info-box">
        <p>
          <strong>Note:</strong> Enable flags to simulate various failure scenarios for observability demonstrations.
          When a flag is enabled (red), the corresponding failure will be triggered in the backend services.
        </p>
      </div>

      <div className="admin-actions">
        <button
          className="refresh-button"
          onClick={fetchFlags}
          disabled={loading || resetting}
        >
          🔄 Refresh
        </button>
        <button
          className="reset-button"
          onClick={handleResetAll}
          disabled={loading || resetting}
        >
          {resetting ? 'Resetting...' : '↺ Reset All Flags'}
        </button>
      </div>

      <div className="flags-list">
        {flags.map((flag) => (
          <FlagToggle key={flag.name} flag={flag} onUpdate={handleUpdateFlag} />
        ))}
      </div>
    </div>
  );
}

export default AdminPage;
