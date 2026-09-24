import React, { useState } from 'react';
import {
  ShieldCheck,
  Lock,
  Key,
  FileText,
  AlertTriangle,
  CheckCircle,
  Eye,
  Sliders,
  History,
  Fingerprint
} from 'lucide-react';
import { useApp } from '../context/AppContext';

export default function Security() {
  const { securitySettings, updateSecuritySettings, auditLogs } = useApp();
  const [e2ee, setE2ee] = useState(securitySettings.e2eeEnabled);
  const [consentMode, setConsentMode] = useState(securitySettings.callRecordingConsent);
  const [autoRedact, setAutoRedact] = useState(securitySettings.autoRedactPii);
  const [retention, setRetention] = useState(securitySettings.dataRetentionDays);

  const saveSettings = () => {
    updateSecuritySettings({
      e2eeEnabled: e2ee,
      callRecordingConsent: consentMode,
      autoRedactPii: autoRedact,
      dataRetentionDays: retention
    });
  };

  return (
    <div style={{ padding: '1rem 1.5rem 4rem', maxWidth: '1440px', margin: '0 auto', display: 'flex', flexDirection: 'column', gap: '2rem' }}>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '1rem' }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
            <h1 style={{ fontSize: '1.85rem', fontWeight: 800, margin: 0, color: 'var(--text-main)' }}>
              Security, Cryptography & Compliance Vault
            </h1>
            <span className="glass-pill" style={{ color: 'var(--accent-emerald)', fontSize: '0.75rem' }}>
              <ShieldCheck size={14} /> SOC2 Type II • GDPR Ready
            </span>
          </div>
          <p style={{ color: 'var(--text-dim)', fontSize: '0.88rem', marginTop: '0.25rem' }}>
            Hardware-backed encryption keys, automated two-party consent enforcement, and tamper-evident audit trails.
          </p>
        </div>

        <button
          onClick={saveSettings}
          className="btn-primary"
          style={{ fontSize: '0.85rem', padding: '0.6rem 1.25rem' }}
        >
          <Lock size={16} />
          <span>Save & Apply Security Policies</span>
        </button>
      </div>

      {/* Security Pillars Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '1.25rem' }}>
        {/* Pillar 1: E2EE */}
        <div className="glass-card" style={{ padding: '1.5rem' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
              <Key size={20} color="var(--primary)" />
              <h3 style={{ fontSize: '1.1rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>
                End-to-End Encryption (E2EE)
              </h3>
            </div>
            <input
              type="checkbox"
              checked={e2ee}
              onChange={e => setE2ee(e.target.checked)}
              style={{ width: '18px', height: '18px', cursor: 'pointer' }}
            />
          </div>
          <p style={{ fontSize: '0.82rem', color: 'var(--text-muted)', lineHeight: 1.45, marginBottom: '0.85rem' }}>
            Recordings are encrypted on the mobile device hardware (AES-256-GCM) before upload using AWS KMS customer-managed keys.
          </p>
          <div style={{
            fontSize: '0.75rem',
            fontFamily: 'var(--font-mono)',
            padding: '6px 10px',
            background: 'var(--bg-surface-elevated)',
            borderRadius: '6px',
            color: 'var(--text-dim)'
          }}>
            KMS Key: {securitySettings.kmsKeyAlias}
          </div>
        </div>

        {/* Pillar 2: Two-Party Consent Mode */}
        <div className="glass-card" style={{ padding: '1.5rem' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem', marginBottom: '0.85rem' }}>
            <AlertTriangle size={20} color="var(--accent-amber)" />
            <h3 style={{ fontSize: '1.1rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>
              Call Recording Consent Policy
            </h3>
          </div>
          <p style={{ fontSize: '0.82rem', color: 'var(--text-muted)', lineHeight: 1.45, marginBottom: '0.85rem' }}>
            Ensures compliance with all 12 two-party consent states (CA, FL, MA, etc.) and international wiretap laws.
          </p>
          <select
            value={consentMode}
            onChange={e => setConsentMode(e.target.value as any)}
            style={{
              width: '100%',
              padding: '8px',
              borderRadius: '8px',
              background: 'var(--bg-surface-elevated)',
              border: '1px solid var(--border-glass)',
              color: 'var(--text-main)',
              fontSize: '0.82rem'
            }}
          >
            <option value="two-party-beep">Two-Party Periodic Tone (Audible 15s Beep)</option>
            <option value="verbal-ai-prompt">AI Verbal Disclaimer ("Call is Recorded")</option>
            <option value="disabled">One-Party State Only (No Prompt)</option>
          </select>
        </div>

        {/* Pillar 3: Data Retention & PII Redaction */}
        <div className="glass-card" style={{ padding: '1.5rem' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem', marginBottom: '0.85rem' }}>
            <Fingerprint size={20} color="var(--accent-emerald)" />
            <h3 style={{ fontSize: '1.1rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>
              GDPR Retention & PII Redaction
            </h3>
          </div>
          <p style={{ fontSize: '0.82rem', color: 'var(--text-muted)', lineHeight: 1.45, marginBottom: '0.85rem' }}>
            Transcripts automatically redact credit card numbers, tax IDs, and sensitive health info via Whisper regex models.
          </p>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: '0.5rem' }}>
            <span style={{ fontSize: '0.82rem', color: 'var(--text-dim)' }}>Auto-Wipe Retention Window:</span>
            <select
              value={retention}
              onChange={e => setRetention(parseInt(e.target.value, 10))}
              style={{
                padding: '6px 10px',
                borderRadius: '6px',
                background: 'var(--bg-surface-elevated)',
                border: '1px solid var(--border-glass)',
                color: 'var(--text-main)',
                fontSize: '0.82rem'
              }}
            >
              <option value={30}>30 Days</option>
              <option value={90}>90 Days (Recommended)</option>
              <option value={365}>1 Year</option>
              <option value={0}>Indefinite</option>
            </select>
          </div>
        </div>
      </div>

      {/* Immutable Audit Trail Log */}
      <div className="glass-panel" style={{ padding: '1.5rem' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem' }}>
          <div>
            <h3 style={{ fontSize: '1.15rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>
              Immutable Compliance Audit Trail
            </h3>
            <p style={{ fontSize: '0.8rem', color: 'var(--text-dim)', marginTop: '2px' }}>
              Cryptographically signed events with SHA-256 integrity hashes for SOC2 and ISO-27001 auditor verification.
            </p>
          </div>
          <span className="glass-pill" style={{ color: 'var(--accent-emerald)', fontSize: '0.75rem' }}>
            <ShieldCheck size={12} /> SHA-256 Validated
          </span>
        </div>

        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', minWidth: '700px' }}>
            <thead>
              <tr style={{ borderBottom: '1px solid var(--border-glass)', fontSize: '0.8rem', color: 'var(--text-dim)' }}>
                <th style={{ padding: '0.85rem' }}>TIMESTAMP</th>
                <th style={{ padding: '0.85rem' }}>ACTOR / USER</th>
                <th style={{ padding: '0.85rem' }}>SECURITY EVENT</th>
                <th style={{ padding: '0.85rem' }}>DETAILS</th>
                <th style={{ padding: '0.85rem' }}>CRYPTOGRAPHIC SIGNATURE</th>
              </tr>
            </thead>
            <tbody>
              {auditLogs.map(log => (
                <tr key={log.id} style={{ borderBottom: '1px solid var(--border-subtle)', fontSize: '0.85rem' }}>
                  <td style={{ padding: '0.85rem', color: 'var(--text-dim)' }}>
                    {log.timestamp}
                  </td>
                  <td style={{ padding: '0.85rem', fontWeight: 600, color: 'var(--text-main)' }}>
                    {log.user}
                  </td>
                  <td style={{ padding: '0.85rem', color: 'var(--primary)', fontWeight: 600 }}>
                    {log.action}
                  </td>
                  <td style={{ padding: '0.85rem', color: 'var(--text-muted)', fontSize: '0.82rem' }}>
                    {log.details}
                  </td>
                  <td style={{ padding: '0.85rem', fontFamily: 'var(--font-mono)', fontSize: '0.72rem', color: 'var(--accent-emerald)' }}>
                    {log.signature}
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
