import React, { useState } from 'react';
import {
  Share2,
  CheckCircle2,
  AlertCircle,
  RefreshCw,
  ExternalLink,
  Sliders,
  Database,
  ArrowRightLeft,
  ShieldCheck,
  Check
} from 'lucide-react';
import { useApp } from '../context/AppContext';

export default function CrmSync() {
  const { crmConnectors, toggleCrmConnector, dbEngine } = useApp();
  const [isSyncing, setIsSyncing] = useState(false);
  const [syncSuccessMsg, setSyncSuccessMsg] = useState<string | null>(null);

  const handleManualSyncAll = () => {
    setIsSyncing(true);
    setSyncSuccessMsg(null);
    setTimeout(() => {
      setIsSyncing(false);
      setSyncSuccessMsg(`✓ All CRM pipelines successfully synchronized with ${dbEngine.toUpperCase()} database tables!`);
      setTimeout(() => setSyncSuccessMsg(null), 5000);
    }, 1200);
  };

  return (
    <div style={{ padding: '1rem 1.5rem 4rem', maxWidth: '1440px', margin: '0 auto', display: 'flex', flexDirection: 'column', gap: '2rem' }}>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '1rem' }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
            <h1 style={{ fontSize: '1.85rem', fontWeight: 800, margin: 0, color: 'var(--text-main)' }}>
              CRM Integration & Webhook Pipeline
            </h1>
            <span className="glass-pill" style={{ color: 'var(--accent-emerald)', fontSize: '0.75rem' }}>
              Bi-Directional Sync Active • {dbEngine.toUpperCase()}
            </span>
          </div>
          <p style={{ color: 'var(--text-dim)', fontSize: '0.88rem', marginTop: '0.25rem' }}>
            Automated event streaming: mobile call recordings, transcripts, notes, and WhatsApp messages auto-populate CRM records.
          </p>
        </div>

        <button
          onClick={handleManualSyncAll}
          disabled={isSyncing}
          className="btn-primary"
          style={{ fontSize: '0.85rem', padding: '0.6rem 1.25rem' }}
        >
          <RefreshCw size={16} className={isSyncing ? 'animate-spin' : ''} />
          <span>{isSyncing ? 'Syncing Connectors...' : 'Force Sync All CRMs'}</span>
        </button>
      </div>

      {syncSuccessMsg && (
        <div className="glass-panel" style={{
          padding: '0.85rem 1.25rem',
          background: 'rgba(16, 185, 129, 0.15)',
          border: '1px solid rgba(16, 185, 129, 0.3)',
          color: '#34d399',
          fontSize: '0.88rem',
          fontWeight: 600,
          display: 'flex',
          alignItems: 'center',
          gap: '0.5rem'
        }}>
          <Check size={18} />
          <span>{syncSuccessMsg}</span>
        </div>
      )}

      {/* Connectors Grid */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '1.25rem' }}>
        {crmConnectors.map(crm => (
          <div key={crm.id} className="glass-card" style={{ padding: '1.5rem', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '1rem' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                  <span style={{ fontSize: '2rem' }}>{crm.icon}</span>
                  <div>
                    <h3 style={{ fontSize: '1.2rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>
                      {crm.name}
                    </h3>
                    <span style={{
                      fontSize: '0.75rem',
                      color: crm.isConnected ? 'var(--accent-emerald)' : 'var(--text-dim)',
                      fontWeight: 600
                    }}>
                      {crm.isConnected ? '● Connected & Streaming' : '○ Disabled'}
                    </span>
                  </div>
                </div>

                <button
                  onClick={() => toggleCrmConnector(crm.id)}
                  style={{
                    padding: '4px 10px',
                    borderRadius: '20px',
                    border: 'none',
                    fontSize: '0.75rem',
                    fontWeight: 700,
                    cursor: 'pointer',
                    background: crm.isConnected ? 'rgba(16, 185, 129, 0.2)' : 'rgba(255, 255, 255, 0.1)',
                    color: crm.isConnected ? '#34d399' : 'var(--text-muted)'
                  }}
                >
                  {crm.isConnected ? 'ON' : 'OFF'}
                </button>
              </div>

              <p style={{ fontSize: '0.82rem', color: 'var(--text-muted)', lineHeight: 1.45, marginBottom: '1.25rem' }}>
                {crm.description}
              </p>
            </div>

            <div style={{ borderTop: '1px solid var(--border-subtle)', paddingTop: '1rem' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.8rem', color: 'var(--text-dim)', marginBottom: '0.35rem' }}>
                <span>Records Synced:</span>
                <span style={{ fontWeight: 600, color: 'var(--text-main)', fontFamily: 'var(--font-mono)' }}>
                  {crm.syncedRecordsCount.toLocaleString()}
                </span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.8rem', color: 'var(--text-dim)', marginBottom: '0.75rem' }}>
                <span>Last Sync Activity:</span>
                <span style={{ color: 'var(--accent-cyan)' }}>{crm.lastSyncTime}</span>
              </div>

              <div style={{ display: 'flex', gap: '0.5rem' }}>
                <button className="btn-secondary" style={{ flex: 1, fontSize: '0.75rem', padding: '0.4rem' }}>
                  <Sliders size={12} /> Configure Schema
                </button>
                <button className="btn-ghost" style={{ fontSize: '0.75rem', padding: '0.4rem' }} title="Test Ping">
                  <RefreshCw size={12} />
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Field Mapping Schema Visualizer */}
      <div className="glass-panel" style={{ padding: '1.5rem' }}>
        <div style={{ marginBottom: '1.25rem' }}>
          <h3 style={{ fontSize: '1.15rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>
            Bi-Directional CRM Field Mapping
          </h3>
          <p style={{ fontSize: '0.8rem', color: 'var(--text-dim)', marginTop: '2px' }}>
            Defines how RingVia360 telemetry translates into standard and custom CRM entities.
          </p>
        </div>

        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', minWidth: '650px' }}>
            <thead>
              <tr style={{ borderBottom: '1px solid var(--border-glass)', fontSize: '0.8rem', color: 'var(--text-dim)' }}>
                <th style={{ padding: '0.85rem' }}>RINGVIA360 TELEMETRY ATTRIBUTE</th>
                <th style={{ padding: '0.85rem' }}>DATA TYPE</th>
                <th style={{ padding: '0.85rem' }}>RINGVIA360 CRM FIELD</th>
                <th style={{ padding: '0.85rem' }}>HUBSPOT / EXTERNAL FIELD</th>
                <th style={{ padding: '0.85rem' }}>SYNC POLICY</th>
              </tr>
            </thead>
            <tbody>
              {[
                { source: 'Caller Direction (Inbound/Outbound)', type: 'Enum', crm: 'Calls.direction', hub: 'hs_call_direction', policy: 'Instant (Zero-Click)' },
                { source: 'Call Duration', type: 'Integer (Sec)', crm: 'Calls.duration_seconds', hub: 'hs_call_duration', policy: 'Hardware Telemetry' },
                { source: 'AI Speech-to-Text Transcript', type: 'Rich Text / JSON', crm: 'Calls.transcript', hub: 'hs_call_body', policy: 'Whisper Diarized' },
                { source: 'Encrypted Audio Recording URL', type: 'Secure Link', crm: 'Calls.recording_url', hub: 'hs_call_recording_url', policy: 'AES-256 KMS' },
                { source: 'AI Deal Sentiment & Risk Score', type: 'Integer (0-100)', crm: 'Calls.sentiment_score', hub: 'deal_sentiment_score', policy: 'Real-time NLP' },
                { source: 'WhatsApp Business Chat Log', type: 'Message Stream', crm: 'WhatsApp.threads', hub: 'hs_communication_body', policy: 'Dual-SIM Isolated' }
              ].map((row, i) => (
                <tr key={i} style={{ borderBottom: '1px solid var(--border-subtle)', fontSize: '0.85rem' }}>
                  <td style={{ padding: '0.85rem', fontWeight: 600, color: 'var(--text-main)' }}>
                    {row.source}
                  </td>
                  <td style={{ padding: '0.85rem', color: 'var(--text-dim)', fontFamily: 'var(--font-mono)', fontSize: '0.75rem' }}>
                    {row.type}
                  </td>
                  <td style={{ padding: '0.85rem', color: 'var(--primary)', fontFamily: 'var(--font-mono)', fontSize: '0.8rem' }}>
                    {row.crm}
                  </td>
                  <td style={{ padding: '0.85rem', color: '#f97316', fontFamily: 'var(--font-mono)', fontSize: '0.8rem' }}>
                    {row.hub}
                  </td>
                  <td style={{ padding: '0.85rem' }}>
                    <span className="glass-pill" style={{ color: 'var(--accent-emerald)', fontSize: '0.72rem' }}>
                      <CheckCircle2 size={10} />
                      {row.policy}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
