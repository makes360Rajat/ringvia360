import React, { useState } from 'react';
import {
  Users,
  Smartphone,
  ShieldCheck,
  Database,
  QrCode,
  Download,
  Trash2,
  Clock,
  AlertTriangle,
  Sliders,
  CheckCircle2,
  HardDrive,
  RefreshCw,
  FileSpreadsheet,
  Layers,
  Lock,
  Plus,
  Search,
  Check,
  Mail,
  X,
  CreditCard,
  Key,
  Play,
  Headphones,
  PhoneCall,
  ArrowDownLeft,
  ArrowUpRight,
  Sparkles
} from 'lucide-react';
import { useApp } from '../context/AppContext';

export default function Admin() {
  const { reps, securitySettings, updateSecuritySettings, auditLogs, calls, setActiveAudioCall } = useApp();
  const [activeTab, setActiveTab] = useState<'users' | 'devices' | 'recording' | 'crm-rules' | 'privacy' | 'export'>('users');
  const [recordingSearch, setRecordingSearch] = useState('');

  // User management state
  const [userList, setUserList] = useState([
    { id: 'u-1', name: 'Sarah Jenkins', email: 'sarah.jenkins@ringvia.com', role: 'Sales Rep', status: 'Active', sim: 'SIM 1 Bound', device: 'Galaxy S24 Ultra', lastActive: '2m ago' },
    { id: 'u-2', name: 'Marcus Vance', email: 'marcus.vance@ringvia.com', role: 'Sales Rep', status: 'Active', sim: 'SIM 1 Bound', device: 'iPhone 15 Pro Max', lastActive: '8m ago' },
    { id: 'u-3', name: 'Liam O’Connor', email: 'liam.oconnor@ringvia.com', role: 'Sales Rep', status: 'Active', sim: 'SIM 1 Bound', device: 'Pixel 9 Pro', lastActive: '15m ago' },
    { id: 'u-4', name: 'Priya Sharma', email: 'priya.sharma@ringvia.com', role: 'Team Lead', status: 'Active', sim: 'SIM 1 Bound', device: 'Galaxy Z Fold 6', lastActive: '1h ago' },
    { id: 'u-5', name: 'David Miller', email: 'david.miller@ringvia.com', role: 'Compliance Auditor', status: 'Active', sim: 'Unbound', device: 'MacBook Pro / Web', lastActive: 'Yesterday' },
  ]);

  const [inviteModalOpen, setInviteModalOpen] = useState(false);
  const [newUserName, setNewUserName] = useState('');
  const [newUserEmail, setNewUserEmail] = useState('');
  const [newUserRole, setNewUserRole] = useState('Sales Rep');
  const [qrModalRep, setQrModalRep] = useState<string | null>(null);

  // Policy states
  const [workHoursActive, setWorkHoursActive] = useState(true);
  const [recordingMode, setRecordingMode] = useState<'all' | 'outbound_only' | 'inbound_only' | 'consent_only'>('all');
  const [storageProvider, setStorageProvider] = useState<'aws_s3' | 'gcs' | 'customer_kms'>('customer_kms');
  const [autoSyncOnWrapUp, setAutoSyncOnWrapUp] = useState(true);
  const [createLeadIfNotFound, setCreateLeadIfNotFound] = useState(true);
  const [adminNotification, setAdminNotification] = useState<string | null>(null);

  const notify = (msg: string) => {
    setAdminNotification(msg);
    setTimeout(() => setAdminNotification(null), 4000);
  };

  const handleAddUser = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newUserEmail || !newUserName) return;
    const newUser = {
      id: `u-${Date.now()}`,
      name: newUserName,
      email: newUserEmail,
      role: newUserRole,
      status: 'Active',
      sim: 'Pending Pairing',
      device: 'Awaiting MDM QR',
      lastActive: 'Invited'
    };
    setUserList([newUser, ...userList]);
    setNewUserName('');
    setNewUserEmail('');
    setInviteModalOpen(false);
    notify(`✓ Invitation and MDM Enrollment QR code dispatched to ${newUser.email}!`);
  };

  const handleDeleteUser = (id: string, name: string) => {
    setUserList(prev => prev.filter(u => u.id !== id));
    notify(`Revoked license and disconnected companion app for ${name}`);
  };

  return (
    <div style={{ padding: '1rem 1.5rem 4rem', maxWidth: '1440px', margin: '0 auto', display: 'flex', flexDirection: 'column', gap: '1.75rem' }}>
      {/* Top Header & Org Tenant Info */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '1rem' }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
            <h1 style={{ fontSize: '1.85rem', fontWeight: 800, margin: 0, color: 'var(--text-main)' }}>
              Enterprise Admin & Fleet Command
            </h1>
            <span className="glass-pill" style={{ color: 'var(--accent-emerald)', fontSize: '0.75rem' }}>
              <span className="live-dot" /> Tenant #482 • Active
            </span>
          </div>
          <p style={{ color: 'var(--text-dim)', fontSize: '0.88rem', marginTop: '0.25rem' }}>
            Global policies, mobile device MDM enrollment, call recording storage vaults, and CRM sync rules.
          </p>
        </div>

        {/* Global Stats Counter */}
        <div style={{ display: 'flex', gap: '1rem' }}>
          <div className="glass-card" style={{ padding: '0.6rem 1rem', display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
            <Users size={18} color="var(--primary)" />
            <div>
              <div style={{ fontSize: '1.1rem', fontWeight: 800, color: 'var(--text-main)', fontFamily: 'var(--font-mono)' }}>
                {userList.length} / 50
              </div>
              <div style={{ fontSize: '0.7rem', color: 'var(--text-dim)' }}>Licenses Used</div>
            </div>
          </div>

          <div className="glass-card" style={{ padding: '0.6rem 1rem', display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
            <HardDrive size={18} color="var(--accent-cyan)" />
            <div>
              <div style={{ fontSize: '1.1rem', fontWeight: 800, color: 'var(--accent-cyan)', fontFamily: 'var(--font-mono)' }}>
                142 / 500 GB
              </div>
              <div style={{ fontSize: '0.7rem', color: 'var(--text-dim)' }}>Audio KMS Vault</div>
            </div>
          </div>
        </div>
      </div>

      {adminNotification && (
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
          <span>{adminNotification}</span>
        </div>
      )}

      {/* Admin Sub-Navigation Tabs */}
      <div className="glass-panel" style={{ padding: '0.5rem', display: 'flex', gap: '0.4rem', flexWrap: 'wrap' }}>
        {[
          { id: 'users', label: 'Rep & User Management', icon: Users },
          { id: 'devices', label: 'Device Fleet & QR Pairing', icon: Smartphone },
          { id: 'recording', label: 'Call Recording & Vault', icon: Lock },
          { id: 'crm-rules', label: 'CRM Sync Automation', icon: Database },
          { id: 'privacy', label: 'Privacy & Work Schedule', icon: Clock },
          { id: 'export', label: 'Audit & Data Exports', icon: FileSpreadsheet },
        ].map(tab => {
          const Icon = tab.icon;
          const isActive = activeTab === tab.id;
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id as any)}
              className={isActive ? 'btn-primary' : 'btn-ghost'}
              style={{
                fontSize: '0.82rem',
                padding: '0.55rem 1rem',
                borderRadius: 'var(--radius-md)'
              }}
            >
              <Icon size={16} />
              <span>{tab.label}</span>
            </button>
          );
        })}
      </div>

      {/* TAB 1: USER MANAGEMENT */}
      {activeTab === 'users' && (
        <div className="glass-panel" style={{ padding: '1.5rem', display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '1rem' }}>
            <div>
              <h3 style={{ fontSize: '1.2rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>
                Sales Team Roster & Seat Allocations
              </h3>
              <p style={{ fontSize: '0.8rem', color: 'var(--text-dim)', marginTop: '2px' }}>
                Manage team members, roles, mobile dialer permissions, and corporate SIM assignment.
              </p>
            </div>

            <button
              onClick={() => setInviteModalOpen(true)}
              className="btn-primary"
              style={{ fontSize: '0.85rem', padding: '0.55rem 1.1rem' }}
            >
              <Plus size={16} />
              <span>Invite New Representative</span>
            </button>
          </div>

          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', minWidth: '750px' }}>
              <thead>
                <tr style={{ borderBottom: '1px solid var(--border-glass)', fontSize: '0.8rem', color: 'var(--text-dim)' }}>
                  <th style={{ padding: '0.85rem' }}>REPRESENTATIVE</th>
                  <th style={{ padding: '0.85rem' }}>ROLE</th>
                  <th style={{ padding: '0.85rem' }}>DEVICE & HARDWARE</th>
                  <th style={{ padding: '0.85rem' }}>SIM BINDING</th>
                  <th style={{ padding: '0.85rem' }}>STATUS</th>
                  <th style={{ padding: '0.85rem' }}>ACTIONS</th>
                </tr>
              </thead>
              <tbody>
                {userList.map(user => (
                  <tr key={user.id} style={{ borderBottom: '1px solid var(--border-subtle)', fontSize: '0.85rem' }}>
                    <td style={{ padding: '0.85rem' }}>
                      <div style={{ fontWeight: 700, color: 'var(--text-main)' }}>{user.name}</div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-dim)' }}>{user.email}</div>
                    </td>
                    <td style={{ padding: '0.85rem' }}>
                      <span className="glass-pill" style={{ fontSize: '0.75rem', background: 'var(--primary-subtle)', color: 'var(--primary)' }}>
                        {user.role}
                      </span>
                    </td>
                    <td style={{ padding: '0.85rem', color: 'var(--text-muted)' }}>
                      {user.device}
                    </td>
                    <td style={{ padding: '0.85rem' }}>
                      <span className="glass-pill" style={{
                        fontSize: '0.72rem',
                        color: user.sim.includes('SIM 1') ? 'var(--accent-emerald)' : 'var(--accent-amber)'
                      }}>
                        {user.sim}
                      </span>
                    </td>
                    <td style={{ padding: '0.85rem' }}>
                      <span className="glass-pill" style={{ color: 'var(--accent-emerald)', fontSize: '0.72rem' }}>
                        ● {user.status} ({user.lastActive})
                      </span>
                    </td>
                    <td style={{ padding: '0.85rem' }}>
                      <div style={{ display: 'flex', gap: '0.4rem' }}>
                        <button
                          onClick={() => setQrModalRep(user.name)}
                          className="btn-ghost"
                          style={{ padding: '0.35rem 0.65rem', fontSize: '0.75rem' }}
                          title="Generate MDM QR code for companion app pairing"
                        >
                          <QrCode size={14} /> QR
                        </button>
                        <button
                          onClick={() => handleDeleteUser(user.id, user.name)}
                          className="btn-ghost"
                          style={{ padding: '0.35rem 0.5rem', color: 'var(--accent-rose)' }}
                          title="Revoke user license"
                        >
                          <Trash2 size={14} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 2: DEVICE FLEET & QR PAIRING */}
      {activeTab === 'devices' && (
        <div className="glass-panel" style={{ padding: '1.5rem', display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
          <div>
            <h3 style={{ fontSize: '1.2rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>
              Companion App Mobile Device Fleet
            </h3>
            <p style={{ fontSize: '0.8rem', color: 'var(--text-dim)', marginTop: '2px' }}>
              Enrolled Android Knox & iOS CallKit hardware tokens. Reps scan the QR code to pair corporate phones.
            </p>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '1.25rem' }}>
            {reps.map(rep => (
              <div key={rep.id} className="glass-card" style={{ padding: '1.25rem' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '0.75rem' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                    <img src={rep.avatar} alt={rep.name} style={{ width: '42px', height: '42px', borderRadius: '50%', objectFit: 'cover' }} />
                    <div>
                      <h4 style={{ fontSize: '1rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>{rep.name}</h4>
                      <span style={{ fontSize: '0.75rem', color: 'var(--text-dim)' }}>{rep.deviceModel}</span>
                    </div>
                  </div>
                  <button
                    onClick={() => setQrModalRep(rep.name)}
                    className="btn-primary"
                    style={{ padding: '0.35rem 0.75rem', fontSize: '0.75rem' }}
                  >
                    <QrCode size={14} /> Show QR
                  </button>
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '0.4rem', fontSize: '0.8rem', background: 'var(--bg-surface-elevated)', padding: '0.85rem', borderRadius: 'var(--radius-sm)' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ color: 'var(--text-dim)' }}>OS Security:</span>
                    <span style={{ color: 'var(--accent-emerald)', fontWeight: 600 }}>{rep.osVersion}</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ color: 'var(--text-dim)' }}>Battery & Telemetry:</span>
                    <span style={{ color: 'var(--text-main)' }}>{rep.batteryLevel}% • Last ping {rep.lastSync}</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ color: 'var(--text-dim)' }}>MDM Knox State:</span>
                    <span style={{ color: 'var(--accent-cyan)' }}>Hardware Attested ✓</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* TAB 3: RECORDING & VAULT POLICIES */}
      {activeTab === 'recording' && (
        <div className="glass-panel" style={{ padding: '1.5rem', display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
          <div>
            <h3 style={{ fontSize: '1.2rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>
              Call Recording & Audio Storage Policies
            </h3>
            <p style={{ fontSize: '0.8rem', color: 'var(--text-dim)', marginTop: '2px' }}>
              Configure automatic call recording triggers, encryption keys, and cloud bucket destinations.
            </p>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '1.25rem' }}>
            {/* Recording Trigger Mode */}
            <div className="glass-card" style={{ padding: '1.25rem' }}>
              <h4 style={{ fontSize: '1rem', fontWeight: 700, marginBottom: '0.5rem', color: 'var(--text-main)' }}>
                Recording Capture Trigger
              </h4>
              <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginBottom: '1rem' }}>
                Determine which telephony events are recorded and saved to the encrypted repository.
              </p>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                {[
                  { id: 'all', title: 'Record All Calls (Inbound & Outbound)', desc: 'Recommended for full compliance' },
                  { id: 'outbound_only', title: 'Record Outbound Sales Calls Only', desc: 'Inbound calls logged without audio' },
                  { id: 'consent_only', title: 'Record Only with Verbal/Tone Consent', desc: 'Prompts two-party consent beep' },
                ].map(item => (
                  <label
                    key={item.id}
                    style={{
                      display: 'flex',
                      alignItems: 'flex-start',
                      gap: '0.75rem',
                      padding: '0.75rem',
                      borderRadius: 'var(--radius-sm)',
                      background: recordingMode === item.id ? 'var(--primary-subtle)' : 'var(--bg-surface-elevated)',
                      border: recordingMode === item.id ? '1px solid var(--primary)' : '1px solid var(--border-subtle)',
                      cursor: 'pointer'
                    }}
                  >
                    <input
                      type="radio"
                      name="recMode"
                      checked={recordingMode === item.id}
                      onChange={() => setRecordingMode(item.id as any)}
                      style={{ marginTop: '2px' }}
                    />
                    <div>
                      <div style={{ fontWeight: 600, fontSize: '0.85rem', color: 'var(--text-main)' }}>{item.title}</div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-dim)' }}>{item.desc}</div>
                    </div>
                  </label>
                ))}
              </div>
            </div>

            {/* Storage Vault Location */}
            <div className="glass-card" style={{ padding: '1.25rem' }}>
              <h4 style={{ fontSize: '1rem', fontWeight: 700, marginBottom: '0.5rem', color: 'var(--text-main)' }}>
                Audio Storage Destination
              </h4>
              <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginBottom: '1rem' }}>
                All recordings are encrypted via AES-256-GCM before transmission.
              </p>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                {[
                  { id: 'customer_kms', title: 'Customer AWS KMS Dedicated Vault', desc: 'Keys managed by your security team' },
                  { id: 'aws_s3', title: 'RingVia360 Cloud S3 (Multi-Region)', desc: 'Managed HIPAA & SOC2 Compliant Storage' },
                  { id: 'gcs', title: 'Google Cloud Storage Bucket', desc: 'Direct BigQuery ML Integration Pipeline' },
                ].map(item => (
                  <label
                    key={item.id}
                    style={{
                      display: 'flex',
                      alignItems: 'flex-start',
                      gap: '0.75rem',
                      padding: '0.75rem',
                      borderRadius: 'var(--radius-sm)',
                      background: storageProvider === item.id ? 'var(--primary-subtle)' : 'var(--bg-surface-elevated)',
                      border: storageProvider === item.id ? '1px solid var(--primary)' : '1px solid var(--border-subtle)',
                      cursor: 'pointer'
                    }}
                  >
                    <input
                      type="radio"
                      name="storageProv"
                      checked={storageProvider === item.id}
                      onChange={() => setStorageProvider(item.id as any)}
                      style={{ marginTop: '2px' }}
                    />
                    <div>
                      <div style={{ fontWeight: 600, fontSize: '0.85rem', color: 'var(--text-main)' }}>{item.title}</div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-dim)' }}>{item.desc}</div>
                    </div>
                  </label>
                ))}
              </div>
            </div>
          </div>

          {/* Encrypted Audio Vault Archive */}
          <div style={{ marginTop: '1rem', display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '1rem' }}>
              <div>
                <h4 style={{ fontSize: '1.05rem', fontWeight: 700, margin: 0, color: 'var(--text-main)', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Headphones size={18} color="var(--primary)" />
                  Enterprise Encrypted Call Recordings Archive
                  <span className="glass-pill" style={{ fontSize: '0.75rem', background: 'var(--primary-subtle)', color: 'var(--primary)' }}>
                    {calls.length} Verified Recordings
                  </span>
                </h4>
                <p style={{ fontSize: '0.8rem', color: 'var(--text-dim)', marginTop: '2px' }}>
                  Stream, inspect AI diarization transcripts, verify AES-256 encryption checksums, and export WAV audio.
                </p>
              </div>

              <div style={{ position: 'relative', width: '280px' }}>
                <Search size={15} color="var(--text-dim)" style={{ position: 'absolute', left: '10px', top: '10px' }} />
                <input
                  type="text"
                  placeholder="Filter recordings..."
                  value={recordingSearch}
                  onChange={e => setRecordingSearch(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '7px 10px 7px 32px',
                    background: 'var(--bg-surface-elevated)',
                    border: '1px solid var(--border-glass)',
                    borderRadius: 'var(--radius-sm)',
                    color: 'var(--text-main)',
                    fontSize: '0.82rem',
                    outline: 'none'
                  }}
                />
              </div>
            </div>

            <div style={{ overflowX: 'auto' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', minWidth: '780px' }}>
                <thead>
                  <tr style={{ borderBottom: '1px solid var(--border-glass)', fontSize: '0.78rem', color: 'var(--text-dim)' }}>
                    <th style={{ padding: '0.75rem' }}>TYPE</th>
                    <th style={{ padding: '0.75rem' }}>CONTACT / PROSPECT</th>
                    <th style={{ padding: '0.75rem' }}>REP / LINE</th>
                    <th style={{ padding: '0.75rem' }}>DURATION & DATE</th>
                    <th style={{ padding: '0.75rem' }}>ENCRYPTION VAULT</th>
                    <th style={{ padding: '0.75rem' }}>AI SENTIMENT</th>
                    <th style={{ padding: '0.75rem', textAlign: 'right' }}>RECORDING ACTIONS</th>
                  </tr>
                </thead>
                <tbody>
                  {calls
                    .filter(c =>
                      c.contactName.toLowerCase().includes(recordingSearch.toLowerCase()) ||
                      c.company.toLowerCase().includes(recordingSearch.toLowerCase()) ||
                      c.repName.toLowerCase().includes(recordingSearch.toLowerCase())
                    )
                    .map(call => {
                      const mins = Math.floor((call.duration || 0) / 60);
                      const secs = (call.duration || 0) % 60;
                      const durationStr = `${mins}:${secs < 10 ? '0' : ''}${secs}`;

                      return (
                        <tr key={call.id} style={{ borderBottom: '1px solid var(--border-subtle)', fontSize: '0.84rem' }}>
                          <td style={{ padding: '0.75rem' }}>
                            <span className={`glass-pill ${
                              call.direction === 'inbound' ? 'badge-inbound' :
                              call.direction === 'outbound' ? 'badge-outbound' : 'badge-missed'
                            }`} style={{ fontSize: '0.72rem' }}>
                              {call.direction === 'inbound' ? <ArrowDownLeft size={12} /> :
                               call.direction === 'outbound' ? <ArrowUpRight size={12} /> : null}
                              {call.direction.toUpperCase()}
                            </span>
                          </td>
                          <td style={{ padding: '0.75rem' }}>
                            <div style={{ fontWeight: 700, color: 'var(--text-main)' }}>{call.contactName}</div>
                            <div style={{ fontSize: '0.75rem', color: 'var(--text-dim)' }}>{call.company} • {call.phoneNumber}</div>
                          </td>
                          <td style={{ padding: '0.75rem' }}>
                            <div style={{ color: 'var(--text-main)', fontWeight: 600 }}>{call.repName}</div>
                            <div style={{ fontSize: '0.72rem', color: 'var(--accent-emerald)' }}>SIM 1 (Corporate)</div>
                          </td>
                          <td style={{ padding: '0.75rem' }}>
                            <div style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, color: 'var(--text-main)' }}>{durationStr}</div>
                            <div style={{ fontSize: '0.72rem', color: 'var(--text-dim)' }}>{call.timestamp}</div>
                          </td>
                          <td style={{ padding: '0.75rem' }}>
                            <span className="glass-pill" style={{ fontSize: '0.72rem', color: 'var(--accent-emerald)', gap: '4px' }}>
                              <Lock size={11} />
                              AES-256 Verified
                            </span>
                          </td>
                          <td style={{ padding: '0.75rem' }}>
                            <span className={`glass-pill ${
                              call.sentiment === 'positive' ? 'badge-sentiment-pos' :
                              call.sentiment === 'neutral' ? 'badge-sentiment-neu' : 'badge-sentiment-neg'
                            }`} style={{ fontSize: '0.72rem' }}>
                              {call.sentiment.toUpperCase()} ({call.sentimentScore}%)
                            </span>
                          </td>
                          <td style={{ padding: '0.75rem', textAlign: 'right' }}>
                            <div style={{ display: 'flex', gap: '0.4rem', justifyContent: 'flex-end' }}>
                              <button
                                onClick={() => setActiveAudioCall(call)}
                                className="btn-primary"
                                style={{ fontSize: '0.76rem', padding: '0.35rem 0.75rem', gap: '4px' }}
                                title="Listen to encrypted call recording with audio player"
                              >
                                <Play size={13} fill="#fff" />
                                <span>Listen</span>
                              </button>
                            </div>
                          </td>
                        </tr>
                      );
                    })}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* TAB 4: CRM SYNC AUTOMATION RULES */}
      {activeTab === 'crm-rules' && (
        <div className="glass-panel" style={{ padding: '1.5rem', display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
          <div>
            <h3 style={{ fontSize: '1.2rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>
              CRM Automation & Ingestion Rules
            </h3>
            <p style={{ fontSize: '0.8rem', color: 'var(--text-dim)', marginTop: '2px' }}>
              Define when and how mobile call logs and WhatsApp transcripts map into RingVia360 CRM & external pipelines.
            </p>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            <div className="glass-card" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '1.25rem' }}>
              <div>
                <h4 style={{ fontSize: '0.95rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>
                  Instant Zero-Click Sync Upon Call Completion
                </h4>
                <p style={{ fontSize: '0.8rem', color: 'var(--text-dim)', marginTop: '2px' }}>
                  If rep closes the wrap-up prompt, automatically commit call duration, recording link, and AI transcript.
                </p>
              </div>
              <input
                type="checkbox"
                checked={autoSyncOnWrapUp}
                onChange={e => setAutoSyncOnWrapUp(e.target.checked)}
                style={{ width: '20px', height: '20px', cursor: 'pointer' }}
              />
            </div>

            <div className="glass-card" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '1.25rem' }}>
              <div>
                <h4 style={{ fontSize: '0.95rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>
                  Auto-Create Lead if Phone Number is Not in CRM
                </h4>
                <p style={{ fontSize: '0.8rem', color: 'var(--text-dim)', marginTop: '2px' }}>
                  Prevents lost sales: creates a new Prospect Lead record if the inbound/outbound phone is not yet recognized.
                </p>
              </div>
              <input
                type="checkbox"
                checked={createLeadIfNotFound}
                onChange={e => setCreateLeadIfNotFound(e.target.checked)}
                style={{ width: '20px', height: '20px', cursor: 'pointer' }}
              />
            </div>
          </div>
        </div>
      )}

      {/* TAB 5: PRIVACY & WORK SCHEDULE */}
      {activeTab === 'privacy' && (
        <div className="glass-panel" style={{ padding: '1.5rem', display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
          <div>
            <h3 style={{ fontSize: '1.2rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>
              Work-Life Balance & Privacy Safeguards
            </h3>
            <p style={{ fontSize: '0.8rem', color: 'var(--text-dim)', marginTop: '2px' }}>
              Ensures mobile companion never tracks calls on personal SIM cards or outside enterprise business hours.
            </p>
          </div>

          <div className="glass-card" style={{ padding: '1.5rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
                <Clock size={20} color="var(--accent-cyan)" />
                <h4 style={{ fontSize: '1.05rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>
                  Enforce Working Hours (Mon–Fri 8:30 AM – 6:30 PM)
                </h4>
              </div>
              <input
                type="checkbox"
                checked={workHoursActive}
                onChange={e => setWorkHoursActive(e.target.checked)}
                style={{ width: '20px', height: '20px', cursor: 'pointer' }}
              />
            </div>
            <p style={{ fontSize: '0.82rem', color: 'var(--text-muted)', lineHeight: 1.5 }}>
              When enabled, calls made after 6:30 PM or on weekends are completely invisible to RingVia360 and will not be recorded or transmitted to CRM tasks.
            </p>
          </div>
        </div>
      )}

      {/* TAB 6: AUDIT & DATA EXPORT CENTER */}
      {activeTab === 'export' && (
        <div className="glass-panel" style={{ padding: '1.5rem', display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
          <div>
            <h3 style={{ fontSize: '1.2rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>
              Compliance Audit & Data Export Center
            </h3>
            <p style={{ fontSize: '0.8rem', color: 'var(--text-dim)', marginTop: '2px' }}>
              Download tamper-evident logs, call reports, or execute GDPR right-to-erasure workflows.
            </p>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '1.25rem' }}>
            <div className="glass-card" style={{ padding: '1.25rem' }}>
              <FileSpreadsheet size={24} color="var(--accent-emerald)" style={{ marginBottom: '0.5rem' }} />
              <h4 style={{ fontSize: '1rem', fontWeight: 700, margin: '0 0 0.35rem', color: 'var(--text-main)' }}>
                Export Call Activity Stream (CSV / Excel)
              </h4>
              <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginBottom: '1rem' }}>
                All call metadata, talk times, reps, and CRM sync IDs formatted for financial and sales operations.
              </p>
              <button
                onClick={() => notify('✓ Export generated! Downloading RingVia360_Activities_Q3.csv')}
                className="btn-primary"
                style={{ fontSize: '0.8rem', padding: '0.5rem 1rem' }}
              >
                <Download size={14} /> Download CSV
              </button>
            </div>

            <div className="glass-card" style={{ padding: '1.25rem' }}>
              <ShieldCheck size={24} color="var(--primary)" style={{ marginBottom: '0.5rem' }} />
              <h4 style={{ fontSize: '1rem', fontWeight: 700, margin: '0 0 0.35rem', color: 'var(--text-main)' }}>
                Download SHA-256 Audit Certificate
              </h4>
              <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginBottom: '1rem' }}>
                Cryptographically signed PDF verifying that zero audio was tampered with during the current period.
              </p>
              <button
                onClick={() => notify('✓ Cryptographic certificate generated with SHA-256 integrity stamp!')}
                className="btn-secondary"
                style={{ fontSize: '0.8rem', padding: '0.5rem 1rem' }}
              >
                <Download size={14} /> Download Certificate
              </button>
            </div>

            <div className="glass-card" style={{ padding: '1.25rem' }}>
              <Trash2 size={24} color="var(--accent-rose)" style={{ marginBottom: '0.5rem' }} />
              <h4 style={{ fontSize: '1rem', fontWeight: 700, margin: '0 0 0.35rem', color: 'var(--text-main)' }}>
                GDPR Right-to-be-Forgotten Purge
              </h4>
              <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginBottom: '1rem' }}>
                Completely erase all recordings and transcripts associated with a specific customer phone number.
              </p>
              <button
                onClick={() => notify('✓ Purge engine initialized. Enter phone number to verify token.')}
                className="btn-ghost"
                style={{ fontSize: '0.8rem', padding: '0.5rem 1rem', border: '1px solid var(--accent-rose)', color: 'var(--accent-rose)' }}
              >
                Initiate GDPR Erasure
              </button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL: INVITE USER */}
      {inviteModalOpen && (
        <div style={{
          position: 'fixed',
          inset: 0,
          background: 'rgba(5,7,15,0.85)',
          backdropFilter: 'blur(10px)',
          zIndex: 150,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          padding: '1rem'
        }}>
          <div className="glass-panel" style={{ width: '100%', maxWidth: '480px', padding: '1.75rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
              <h3 style={{ fontSize: '1.2rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>
                Invite Team Member
              </h3>
              <button onClick={() => setInviteModalOpen(false)} className="btn-ghost" style={{ padding: '4px' }}>
                <X size={18} />
              </button>
            </div>

            <form onSubmit={handleAddUser} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
              <div>
                <label style={{ fontSize: '0.75rem', color: 'var(--text-dim)', display: 'block', marginBottom: '4px' }}>
                  Full Name
                </label>
                <input
                  type="text"
                  placeholder="e.g. Rachel Cooper"
                  value={newUserName}
                  onChange={e => setNewUserName(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '10px',
                    borderRadius: '8px',
                    background: 'var(--bg-surface-elevated)',
                    border: '1px solid var(--border-glass)',
                    color: 'var(--text-main)',
                    fontSize: '0.85rem'
                  }}
                  required
                />
              </div>

              <div>
                <label style={{ fontSize: '0.75rem', color: 'var(--text-dim)', display: 'block', marginBottom: '4px' }}>
                  Corporate Email
                </label>
                <input
                  type="email"
                  placeholder="rachel.cooper@company.com"
                  value={newUserEmail}
                  onChange={e => setNewUserEmail(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '10px',
                    borderRadius: '8px',
                    background: 'var(--bg-surface-elevated)',
                    border: '1px solid var(--border-glass)',
                    color: 'var(--text-main)',
                    fontSize: '0.85rem'
                  }}
                  required
                />
              </div>

              <div>
                <label style={{ fontSize: '0.75rem', color: 'var(--text-dim)', display: 'block', marginBottom: '4px' }}>
                  Role & Dialer Permissions
                </label>
                <select
                  value={newUserRole}
                  onChange={e => setNewUserRole(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '10px',
                    borderRadius: '8px',
                    background: 'var(--bg-surface-elevated)',
                    border: '1px solid var(--border-glass)',
                    color: 'var(--text-main)',
                    fontSize: '0.85rem'
                  }}
                >
                  <option value="Sales Rep">Sales Representative (Automatic Dialer & Wrap-up)</option>
                  <option value="Team Lead">Team Lead / Sales Director (Team Analytics & Live Listen)</option>
                  <option value="Admin">Tenant Administrator (Full Fleet & Policy Control)</option>
                  <option value="Compliance Auditor">Compliance Auditor (Read-only recordings)</option>
                </select>
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.75rem', marginTop: '0.5rem' }}>
                <button type="button" onClick={() => setInviteModalOpen(false)} className="btn-secondary">
                  Cancel
                </button>
                <button type="submit" className="btn-primary">
                  <Mail size={16} /> Send MDM Invite
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* MODAL: QR PAIRING CODE */}
      {qrModalRep && (
        <div style={{
          position: 'fixed',
          inset: 0,
          background: 'rgba(5,7,15,0.85)',
          backdropFilter: 'blur(10px)',
          zIndex: 150,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          padding: '1rem'
        }}>
          <div className="glass-panel" style={{ width: '100%', maxWidth: '400px', padding: '2rem', textAlign: 'center' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
              <h3 style={{ fontSize: '1.2rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>
                Mobile Companion Pairing
              </h3>
              <button onClick={() => setQrModalRep(null)} className="btn-ghost" style={{ padding: '4px' }}>
                <X size={18} />
              </button>
            </div>

            <p style={{ fontSize: '0.82rem', color: 'var(--text-dim)', marginBottom: '1.5rem' }}>
              Scan this QR code with the RingVia360 mobile app on <strong>{qrModalRep}'s</strong> device to automatically configure corporate credentials, Cloud KMS encryption, and SIM line bindings.
            </p>

            {/* High Tech QR Code Box */}
            <div style={{
              width: '200px',
              height: '200px',
              margin: '0 auto 1.5rem',
              background: '#fff',
              borderRadius: '16px',
              padding: '16px',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              boxShadow: '0 0 35px var(--primary-glow)'
            }}>
              <QrCode size={160} color="#090a10" />
            </div>

            <div style={{ fontSize: '0.75rem', color: 'var(--accent-emerald)', fontWeight: 600 }}>
              ✓ Encrypted with Knox Zero-Touch Token
            </div>

            <button
              onClick={() => setQrModalRep(null)}
              className="btn-secondary"
              style={{ marginTop: '1.5rem', width: '100%' }}
            >
              Done
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
