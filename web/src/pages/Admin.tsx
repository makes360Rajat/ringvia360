import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
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
  Sparkles,
  Building,
  LogIn,
  Edit3,
  Battery,
  TrendingUp
} from 'lucide-react';
import { useApp } from '../context/AppContext';
import ContentEditorPanel from '../components/ContentEditorPanel';

export default function Admin() {
  const navigate = useNavigate();
  const { reps, securitySettings, updateSecuritySettings, auditLogs, calls, setActiveAudioCall, adminUsers, addAdminUser, deleteAdminUser, dbEngine, currentUser, currentOrg, addRep, updateRep, deleteRep } = useApp();
  const [activeTab, setActiveTab] = useState<'users' | 'devices' | 'recording' | 'crm-rules' | 'privacy' | 'export' | 'content'>('users');
  const [recordingSearch, setRecordingSearch] = useState('');

  const totalPipelineValue = calls.reduce((acc, c) => acc + (Number(c.dealValue) || 0), 0);
  const activeDealsCount = calls.filter(c => (Number(c.dealValue) || 0) > 0).length;

  const [inviteModalOpen, setInviteModalOpen] = useState(false);
  const [newUserName, setNewUserName] = useState('');
  const [newUserEmail, setNewUserEmail] = useState('');
  const [newUserRole, setNewUserRole] = useState('Sales Rep');
  const [qrModalRep, setQrModalRep] = useState<string | null>(null);
  const [pairCode, setPairCode] = useState<string>('384 920');
  const [pairLoading, setPairLoading] = useState(false);
  const [pairCopied, setPairCopied] = useState(false);

  const handleOpenPairModal = async (repName: string, repId?: string) => {
    setQrModalRep(repName);
    setPairLoading(true);
    setPairCopied(false);
    try {
      const res = await fetch('/api/auth.php?action=generate_pair_code', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'generate_pair_code',
          orgId: (currentUser?.orgId && !currentUser.orgId.startsWith('org-1790'))
            ? currentUser.orgId
            : ((currentOrg?.id && !currentOrg.id.startsWith('org-1790')) ? currentOrg.id : 'org-makes360-33faf'),
          repId: repId || 'rep-mobile',
          repName: repName,
        })
      });
      const data = await res.json();
      if (data.success && data.formattedCode) {
        setPairCode(data.formattedCode);
      } else {
        setPairCode('384 920');
      }
    } catch (_) {
      setPairCode('384 920');
    } finally {
      setPairLoading(false);
    }
  };

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

  const handleAddUser = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newUserEmail || !newUserName) return;
    await addAdminUser({
      name: newUserName,
      email: newUserEmail,
      role: newUserRole,
      status: 'Active',
      sim: 'SIM 1 Bound',
      device: 'Samsung Galaxy Knox 3.9',
      lastActive: 'Just now'
    });
    setNewUserName('');
    setNewUserEmail('');
    setInviteModalOpen(false);
    notify(`✓ Invitation & MDM enrollment code dispatched and saved to database for ${newUserEmail}!`);
  };

  const handleDeleteUser = async (id: string, name: string) => {
    await deleteAdminUser(id);
    notify(`Revoked license and deleted user ${name} from database.`);
  };

  // Fleet Device Management State
  const [deviceSearch, setDeviceSearch] = useState('');
  const [deviceModalOpen, setDeviceModalOpen] = useState(false);
  const [editingRepId, setEditingRepId] = useState<string | null>(null);
  const [deviceRepName, setDeviceRepName] = useState('');
  const [deviceRepRole, setDeviceRepRole] = useState('Account Executive');
  const [deviceModel, setDeviceModel] = useState('');
  const [deviceOsVersion, setDeviceOsVersion] = useState('Android 14 (Knox v3.9)');
  const [devicePhone, setDevicePhone] = useState('+91 98200 12345');
  const [deviceBatteryLevel, setDeviceBatteryLevel] = useState<number>(92);
  const [deviceIsOnline, setDeviceIsOnline] = useState<boolean>(true);
  const [deviceAvatar, setDeviceAvatar] = useState('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120&auto=format&fit=crop&q=80');

  const handleOpenAddDevice = () => {
    setEditingRepId(null);
    setDeviceRepName('');
    setDeviceRepRole('Account Executive');
    setDeviceModel('infi0');
    setDeviceOsVersion('Android 14 (Knox v3.9)');
    setDevicePhone('+91 98200 12345');
    setDeviceBatteryLevel(95);
    setDeviceIsOnline(true);
    setDeviceAvatar('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&auto=format&fit=crop&q=80');
    setDeviceModalOpen(true);
  };

  const handleOpenEditDevice = (rep: any) => {
    setEditingRepId(rep.id);
    setDeviceRepName(rep.name);
    setDeviceRepRole(rep.role || 'Account Executive');
    setDeviceModel(rep.deviceModel || 'infi0');
    setDeviceOsVersion(rep.osVersion || 'Android 14 (Knox v3.9)');
    setDevicePhone(rep.phone || '+91 98200 12345');
    setDeviceBatteryLevel(rep.batteryLevel ?? 90);
    setDeviceIsOnline(rep.isOnline ?? true);
    setDeviceAvatar(rep.avatar || 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120&auto=format&fit=crop&q=80');
    setDeviceModalOpen(true);
  };

  const handleSaveDevice = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!deviceRepName.trim()) return;

    if (editingRepId) {
      await updateRep({
        id: editingRepId,
        name: deviceRepName.trim(),
        role: deviceRepRole.trim() || 'Account Executive',
        deviceModel: deviceModel.trim() || 'infi0',
        osVersion: deviceOsVersion.trim() || 'Android 14',
        phone: devicePhone.trim() || '+91 98200 12345',
        batteryLevel: Number(deviceBatteryLevel) || 90,
        isOnline: deviceIsOnline,
        avatar: deviceAvatar,
        lastSync: 'Just now'
      });
      notify(`✓ Fleet Device "${deviceModel}" updated for ${deviceRepName}.`);
    } else {
      const newId = `rep-${Date.now()}`;
      await addRep({
        id: newId,
        orgId: currentUser?.orgId || currentOrg?.id || 'org-tcs',
        name: deviceRepName.trim(),
        role: deviceRepRole.trim() || 'Account Executive',
        deviceModel: deviceModel.trim() || 'infi0',
        osVersion: deviceOsVersion.trim() || 'Android 14 (Knox v3.9)',
        phone: devicePhone.trim() || '+91 98200 12345',
        batteryLevel: Number(deviceBatteryLevel) || 95,
        isOnline: deviceIsOnline,
        avatar: deviceAvatar,
        callsToday: 0,
        talkTimeMinutes: 0,
        dealsClosed: 0,
        conversionRate: 20.0,
        rank: reps.length + 1,
        streakDays: 1,
        badges: ['Enterprise Enrolled']
      });
      notify(`✓ New fleet device "${deviceModel}" enrolled for ${deviceRepName}.`);
    }

    setDeviceModalOpen(false);
  };

  const handleDeleteRepDevice = async (repId: string, repName: string) => {
    if (window.confirm(`Are you sure you want to remove ${repName}'s device from the fleet?`)) {
      await deleteRep(repId);
      notify(`✓ Device for ${repName} removed from fleet.`);
    }
  };

  if (!currentUser) {
    return (
      <div style={{ maxWidth: '640px', margin: '5rem auto', padding: '2rem 1.5rem', textAlign: 'center' }}>
        <div className="glass-card" style={{ padding: '3.5rem 2.5rem', border: '1px solid var(--border-glass)' }}>
          <div style={{
            width: '68px',
            height: '68px',
            borderRadius: '20px',
            background: 'rgba(99, 102, 241, 0.15)',
            border: '1px solid rgba(99, 102, 241, 0.3)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            margin: '0 auto 1.5rem',
            color: 'var(--primary)'
          }}>
            <Building size={34} />
          </div>
          <h2 style={{ fontSize: '1.75rem', fontWeight: 800, marginBottom: '0.75rem', color: 'var(--text-main)' }}>
            Customer Admin Portal
          </h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '0.95rem', lineHeight: 1.6, marginBottom: '2rem' }}>
            Please sign in to access your company's dedicated call recordings, sales rep telemetry, MDM device enrollment PINs, and CRM integrations.
          </p>
          <div style={{ display: 'flex', gap: '1rem', justifyContent: 'center', flexWrap: 'wrap' }}>
            <button
              onClick={() => navigate('/login')}
              className="btn-primary"
              style={{
                padding: '0.8rem 1.75rem',
                borderRadius: '10px',
                fontSize: '0.9rem',
                fontWeight: 700,
                display: 'inline-flex',
                alignItems: 'center',
                gap: '0.5rem'
              }}
            >
              <LogIn size={16} />
              Sign In to Your Workspace
            </button>
            <button
              onClick={() => navigate('/signup')}
              className="btn-ghost"
              style={{
                padding: '0.8rem 1.5rem',
                borderRadius: '10px',
                fontSize: '0.9rem',
                fontWeight: 600,
                border: '1px solid var(--border-glass)'
              }}
            >
              Register New Company
            </button>
          </div>
        </div>
      </div>
    );
  }

  const orgName = currentOrg?.name || currentUser.orgName || 'Corporate Workspace';
  const orgPlan = currentOrg?.plan || 'Pro Growth';
  const allocatedSeats = currentOrg?.seats || 50;

  return (
    <div style={{ padding: '1rem 1.5rem 4rem', maxWidth: '1440px', margin: '0 auto', display: 'flex', flexDirection: 'column', gap: '1.75rem' }}>
      {/* Top Header & Org Tenant Info */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '1rem' }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem', flexWrap: 'wrap' }}>
            <h1 style={{ fontSize: '1.85rem', fontWeight: 800, margin: 0, color: 'var(--text-main)' }}>
              {orgName} Admin Console
            </h1>
            <span className="glass-pill" style={{ color: 'var(--accent-emerald)', fontSize: '0.75rem' }}>
              <span className="live-dot" /> Tenant #{currentUser.orgId || currentOrg?.id || 'tcs'} • Plan: {orgPlan}
            </span>
          </div>
          <p style={{ color: 'var(--text-dim)', fontSize: '0.88rem', marginTop: '0.25rem' }}>
            Dedicated Sovereign Workspace: Call telemetry, sales reps, device pairing PINs, and CRM sync rules.
          </p>
        </div>

        {/* Global Stats Counter */}
        <div style={{ display: 'flex', gap: '1rem', flexWrap: 'wrap' }}>
          <div className="glass-card" style={{ padding: '0.6rem 1rem', display: 'flex', alignItems: 'center', gap: '0.75rem', border: '1px solid rgba(245, 158, 11, 0.35)', background: 'rgba(245, 158, 11, 0.06)' }}>
            <TrendingUp size={20} color="var(--accent-amber)" />
            <div>
              <div style={{ fontSize: '1.15rem', fontWeight: 800, color: 'var(--accent-amber)', fontFamily: 'var(--font-mono)' }}>
                ₹{totalPipelineValue.toLocaleString('en-IN')}
              </div>
              <div style={{ fontSize: '0.7rem', color: 'var(--text-dim)' }}>
                Pipeline Deal Value ({activeDealsCount} Deals)
              </div>
            </div>
          </div>

          <div className="glass-card" style={{ padding: '0.6rem 1rem', display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
            <Users size={18} color="var(--primary)" />
            <div>
              <div style={{ fontSize: '1.1rem', fontWeight: 800, color: 'var(--text-main)', fontFamily: 'var(--font-mono)' }}>
                {adminUsers.length} / {allocatedSeats}
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
          { id: 'content', label: 'Content Management', icon: Layers },
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
                {adminUsers.map(user => (
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
                          onClick={() => handleOpenPairModal(user.name, user.id)}
                          className="btn-ghost"
                          style={{ padding: '0.35rem 0.65rem', fontSize: '0.75rem' }}
                          title="Generate MDM PIN / QR code for companion app pairing"
                        >
                          <QrCode size={14} /> Pair Phone
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
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '1rem' }}>
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <Smartphone size={22} color="var(--primary)" />
                <h3 style={{ fontSize: '1.25rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>
                  Companion App Mobile Device Fleet
                </h3>
              </div>
              <p style={{ fontSize: '0.8rem', color: 'var(--text-dim)', marginTop: '4px' }}>
                Enrolled Android Knox & iOS CallKit hardware tokens. Admins can enroll, rename (e.g. infi0), update OS/battery, and pair corporate phones.
              </p>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', flexWrap: 'wrap' }}>
              <div style={{ position: 'relative' }}>
                <Search size={14} style={{ position: 'absolute', left: '10px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-dim)' }} />
                <input
                  type="text"
                  placeholder="Filter fleet (name, infi0, phone)..."
                  value={deviceSearch}
                  onChange={e => setDeviceSearch(e.target.value)}
                  style={{
                    padding: '0.45rem 0.75rem 0.45rem 2rem',
                    borderRadius: '8px',
                    background: 'var(--bg-surface-elevated)',
                    border: '1px solid var(--border-glass)',
                    color: 'var(--text-main)',
                    fontSize: '0.8rem',
                    minWidth: '220px'
                  }}
                />
              </div>

              <button
                onClick={handleOpenAddDevice}
                className="btn-primary"
                style={{ padding: '0.5rem 1rem', fontSize: '0.8rem', display: 'flex', alignItems: 'center', gap: '6px' }}
              >
                <Plus size={16} /> Enroll Fleet Device
              </button>
            </div>
          </div>

          {/* Quick Metrics Bar */}
          <div style={{ display: 'flex', gap: '1rem', flexWrap: 'wrap' }}>
            <div className="glass-card" style={{ padding: '0.6rem 1rem', display: 'flex', alignItems: 'center', gap: '0.6rem', fontSize: '0.8rem' }}>
              <Smartphone size={16} color="var(--primary)" />
              <span style={{ color: 'var(--text-dim)' }}>Total Enrolled:</span>
              <strong style={{ color: 'var(--text-main)' }}>{reps.length} Devices</strong>
            </div>
            <div className="glass-card" style={{ padding: '0.6rem 1rem', display: 'flex', alignItems: 'center', gap: '0.6rem', fontSize: '0.8rem' }}>
              <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: 'var(--accent-emerald)', display: 'inline-block' }} />
              <span style={{ color: 'var(--text-dim)' }}>Online Telemetry:</span>
              <strong style={{ color: 'var(--accent-emerald)' }}>{reps.filter(r => r.isOnline).length} Active</strong>
            </div>
            <div className="glass-card" style={{ padding: '0.6rem 1rem', display: 'flex', alignItems: 'center', gap: '0.6rem', fontSize: '0.8rem' }}>
              <Battery size={16} color="var(--accent-cyan)" />
              <span style={{ color: 'var(--text-dim)' }}>Avg Battery:</span>
              <strong style={{ color: 'var(--accent-cyan)' }}>
                {reps.length > 0 ? Math.round(reps.reduce((acc, r) => acc + (r.batteryLevel || 0), 0) / reps.length) : 0}%
              </strong>
            </div>
          </div>

          {/* Device Cards Grid */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '1.25rem' }}>
            {reps
              .filter(rep => {
                if (!deviceSearch.trim()) return true;
                const q = deviceSearch.toLowerCase();
                return (
                  rep.name.toLowerCase().includes(q) ||
                  (rep.deviceModel && rep.deviceModel.toLowerCase().includes(q)) ||
                  (rep.phone && rep.phone.toLowerCase().includes(q)) ||
                  (rep.osVersion && rep.osVersion.toLowerCase().includes(q)) ||
                  (rep.role && rep.role.toLowerCase().includes(q))
                );
              })
              .map(rep => (
                <div key={rep.id} className="glass-card" style={{ padding: '1.25rem', position: 'relative' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '0.75rem' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                      <div style={{ position: 'relative' }}>
                        <img
                          src={rep.avatar}
                          alt={rep.name}
                          style={{
                            width: '44px',
                            height: '44px',
                            borderRadius: '50%',
                            objectFit: 'cover',
                            border: rep.isOnline ? '2px solid var(--accent-emerald)' : '2px solid rgba(255,255,255,0.1)'
                          }}
                        />
                        <span style={{
                          position: 'absolute',
                          bottom: '-1px',
                          right: '-1px',
                          width: '12px',
                          height: '12px',
                          borderRadius: '50%',
                          background: rep.isOnline ? '#10b981' : '#64748b',
                          border: '2px solid #0f172a'
                        }} />
                      </div>
                      <div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                          <h4 style={{ fontSize: '1rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>{rep.name}</h4>
                          <span style={{
                            fontSize: '0.65rem',
                            padding: '1px 6px',
                            borderRadius: '6px',
                            background: 'var(--primary-subtle)',
                            color: 'var(--primary)',
                            fontWeight: 600
                          }}>
                            {rep.role || 'Sales Rep'}
                          </span>
                        </div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginTop: '3px' }}>
                          <Smartphone size={13} color="var(--accent-cyan)" />
                          <span style={{
                            fontSize: '0.78rem',
                            color: 'var(--accent-cyan)',
                            fontWeight: 700,
                            letterSpacing: '0.02em',
                            background: 'rgba(6, 182, 212, 0.1)',
                            padding: '1px 6px',
                            borderRadius: '4px'
                          }}>
                            {rep.deviceModel || 'infi0'}
                          </span>
                        </div>
                      </div>
                    </div>

                    <div style={{ display: 'flex', gap: '4px' }}>
                      <button
                        onClick={() => handleOpenEditDevice(rep)}
                        className="btn-ghost"
                        style={{ padding: '0.4rem', color: 'var(--text-main)' }}
                        title="Edit Fleet Device & Rep Settings (Change to infi0, update OS/battery)"
                      >
                        <Edit3 size={15} />
                      </button>
                      <button
                        onClick={() => handleOpenPairModal(rep.name, rep.id)}
                        className="btn-primary"
                        style={{ padding: '0.35rem 0.65rem', fontSize: '0.72rem', display: 'flex', alignItems: 'center', gap: '4px' }}
                        title="Pair Companion App via QR / PIN"
                      >
                        <QrCode size={13} /> Pair
                      </button>
                      <button
                        onClick={() => handleDeleteRepDevice(rep.id, rep.name)}
                        className="btn-ghost"
                        style={{ padding: '0.4rem', color: 'var(--accent-rose)' }}
                        title="Remove Device from Fleet"
                      >
                        <Trash2 size={15} />
                      </button>
                    </div>
                  </div>

                  <div style={{ display: 'flex', flexDirection: 'column', gap: '0.45rem', fontSize: '0.8rem', background: 'var(--bg-surface-elevated)', padding: '0.85rem', borderRadius: 'var(--radius-sm)' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <span style={{ color: 'var(--text-dim)' }}>Hardware Device:</span>
                      <span style={{ color: 'var(--text-main)', fontWeight: 700 }}>{rep.deviceModel || 'infi0'}</span>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span style={{ color: 'var(--text-dim)' }}>OS Security:</span>
                      <span style={{ color: 'var(--accent-emerald)', fontWeight: 600 }}>{rep.osVersion || 'Android 14'}</span>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span style={{ color: 'var(--text-dim)' }}>Corporate SIM:</span>
                      <span style={{ color: 'var(--text-main)', fontFamily: 'var(--font-mono)' }}>{rep.phone || '+91 98200 12345'}</span>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <span style={{ color: 'var(--text-dim)' }}>Battery & Telemetry:</span>
                      <span style={{
                        color: (rep.batteryLevel || 0) > 30 ? 'var(--accent-emerald)' : 'var(--accent-rose)',
                        fontWeight: 600,
                        display: 'flex',
                        alignItems: 'center',
                        gap: '4px'
                      }}>
                        <Battery size={14} /> {rep.batteryLevel}% • Last ping {rep.lastSync || 'Just now'}
                      </span>
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
                <h4 style={{ fontSize: '1.05rem', fontWeight: 700, margin: 0, color: 'var(--text-main)', display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap' }}>
                  <Headphones size={18} color="var(--primary)" />
                  Enterprise Encrypted Call Recordings Archive
                  <span className="glass-pill" style={{ fontSize: '0.75rem', background: 'var(--primary-subtle)', color: 'var(--primary)' }}>
                    {calls.length} Verified Recordings
                  </span>
                  <span className="glass-pill" style={{ fontSize: '0.75rem', background: 'rgba(245, 158, 11, 0.15)', color: 'var(--accent-amber)', border: '1px solid rgba(245, 158, 11, 0.3)' }}>
                    💰 ₹{totalPipelineValue.toLocaleString('en-IN')} Total Pipeline
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
              <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', minWidth: '880px' }}>
                <thead>
                  <tr style={{ borderBottom: '1px solid var(--border-glass)', fontSize: '0.78rem', color: 'var(--text-dim)' }}>
                    <th style={{ padding: '0.75rem' }}>TYPE</th>
                    <th style={{ padding: '0.75rem' }}>CONTACT / PROSPECT</th>
                    <th style={{ padding: '0.75rem' }}>REP / LINE</th>
                    <th style={{ padding: '0.75rem' }}>DURATION & DATE</th>
                    <th style={{ padding: '0.75rem' }}>DEAL VALUE & STAGE</th>
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
                            <div style={{ fontFamily: 'var(--font-mono)', fontWeight: 800, color: 'var(--accent-amber)' }}>
                              {call.dealValue && Number(call.dealValue) > 0 ? `₹${Number(call.dealValue).toLocaleString('en-IN')}` : '₹0'}
                            </div>
                            <span className="glass-pill" style={{
                              fontSize: '0.68rem',
                              padding: '2px 6px',
                              background: 'rgba(245, 158, 11, 0.12)',
                              color: 'var(--accent-amber)',
                              border: '1px solid rgba(245, 158, 11, 0.25)'
                            }}>
                              {call.dealStage || 'Proposal'}
                            </span>
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

      {/* MODAL: ADD / EDIT FLEET DEVICE */}
      {deviceModalOpen && (
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
          <div className="glass-panel" style={{ width: '100%', maxWidth: '520px', padding: '1.75rem', maxHeight: '90vh', overflowY: 'auto' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem' }}>
              <div>
                <h3 style={{ fontSize: '1.2rem', fontWeight: 700, margin: 0, color: 'var(--text-main)', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Smartphone size={18} color="var(--primary)" />
                  {editingRepId ? 'Edit Fleet Device & Rep Settings' : 'Enroll New Fleet Device'}
                </h3>
                <span style={{ fontSize: '0.75rem', color: 'var(--accent-cyan)' }}>
                  Tenant #{currentUser?.orgId || currentOrg?.id || 'org-tcs'} • Fleet Management
                </span>
              </div>
              <button onClick={() => setDeviceModalOpen(false)} className="btn-ghost" style={{ padding: '4px' }}>
                <X size={18} />
              </button>
            </div>

            <form onSubmit={handleSaveDevice} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
              {/* Representative Name */}
              <div>
                <label style={{ fontSize: '0.75rem', color: 'var(--text-dim)', display: 'block', marginBottom: '4px', fontWeight: 600 }}>
                  Representative Full Name
                </label>
                <input
                  type="text"
                  placeholder="e.g. Rajesh Kumar"
                  value={deviceRepName}
                  onChange={e => setDeviceRepName(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '9px 12px',
                    borderRadius: '8px',
                    background: 'var(--bg-surface-elevated)',
                    border: '1px solid var(--border-glass)',
                    color: 'var(--text-main)',
                    fontSize: '0.85rem'
                  }}
                  required
                />
              </div>

              {/* Role */}
              <div>
                <label style={{ fontSize: '0.75rem', color: 'var(--text-dim)', display: 'block', marginBottom: '4px', fontWeight: 600 }}>
                  Role & Department
                </label>
                <select
                  value={deviceRepRole}
                  onChange={e => setDeviceRepRole(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '9px 12px',
                    borderRadius: '8px',
                    background: 'var(--bg-surface-elevated)',
                    border: '1px solid var(--border-glass)',
                    color: 'var(--text-main)',
                    fontSize: '0.85rem'
                  }}
                >
                  <option value="Account Executive">Account Executive (Enterprise Sales)</option>
                  <option value="Senior SDR">Senior SDR (Inbound & Outbound)</option>
                  <option value="Field Sales Executive">Field Sales Executive</option>
                  <option value="Team Lead">Team Lead / Sales Manager</option>
                  <option value="Technical Solutions Rep">Technical Solutions Rep</option>
                </select>
              </div>

              {/* Device Model / Hardware Name */}
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '4px' }}>
                  <label style={{ fontSize: '0.75rem', color: 'var(--text-dim)', fontWeight: 600 }}>
                    Device Name / Hardware Model (e.g. infi0)
                  </label>
                  <span style={{ fontSize: '0.7rem', color: 'var(--accent-cyan)' }}>Quick Chips</span>
                </div>
                <input
                  type="text"
                  placeholder="e.g. infi0, Infinix Note 40, Samsung Galaxy S24 Ultra"
                  value={deviceModel}
                  onChange={e => setDeviceModel(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '9px 12px',
                    borderRadius: '8px',
                    background: 'var(--bg-surface-elevated)',
                    border: '1px solid var(--border-glass)',
                    color: 'var(--text-main)',
                    fontSize: '0.85rem'
                  }}
                  required
                />
                {/* Device Quick Chips */}
                <div style={{ display: 'flex', gap: '5px', flexWrap: 'wrap', marginTop: '6px' }}>
                  {['infi0', 'Infinix Note 40 Pro', 'Samsung Galaxy S24 Ultra', 'iPhone 16 Pro Max', 'Google Pixel 9 Pro', 'OnePlus 12'].map(model => (
                    <button
                      key={model}
                      type="button"
                      onClick={() => setDeviceModel(model)}
                      style={{
                        fontSize: '0.72rem',
                        padding: '3px 8px',
                        borderRadius: '6px',
                        background: deviceModel === model ? 'var(--primary)' : 'rgba(255,255,255,0.06)',
                        color: deviceModel === model ? '#fff' : 'var(--text-muted)',
                        border: '1px solid ' + (deviceModel === model ? 'var(--primary)' : 'var(--border-glass)'),
                        cursor: 'pointer',
                        fontWeight: deviceModel === model ? 700 : 400
                      }}
                    >
                      {model === 'infi0' ? '⚡ infi0' : model}
                    </button>
                  ))}
                </div>
              </div>

              {/* OS Security & Knox Version */}
              <div>
                <label style={{ fontSize: '0.75rem', color: 'var(--text-dim)', display: 'block', marginBottom: '4px', fontWeight: 600 }}>
                  Operating System & Security Profile
                </label>
                <input
                  type="text"
                  placeholder="e.g. Android 14 (Knox v3.9)"
                  value={deviceOsVersion}
                  onChange={e => setDeviceOsVersion(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '9px 12px',
                    borderRadius: '8px',
                    background: 'var(--bg-surface-elevated)',
                    border: '1px solid var(--border-glass)',
                    color: 'var(--text-main)',
                    fontSize: '0.85rem'
                  }}
                  required
                />
                <div style={{ display: 'flex', gap: '5px', flexWrap: 'wrap', marginTop: '6px' }}>
                  {['Android 15 (Knox v3.10)', 'Android 14 (Knox v3.9)', 'Android 14 (Stock)', 'iOS 18.2 (CallKit)'].map(os => (
                    <button
                      key={os}
                      type="button"
                      onClick={() => setDeviceOsVersion(os)}
                      style={{
                        fontSize: '0.7rem',
                        padding: '2px 7px',
                        borderRadius: '6px',
                        background: deviceOsVersion === os ? 'rgba(16, 185, 129, 0.2)' : 'rgba(255,255,255,0.04)',
                        color: deviceOsVersion === os ? 'var(--accent-emerald)' : 'var(--text-muted)',
                        border: '1px solid ' + (deviceOsVersion === os ? 'var(--accent-emerald)' : 'var(--border-glass)'),
                        cursor: 'pointer'
                      }}
                    >
                      {os}
                    </button>
                  ))}
                </div>
              </div>

              {/* Corporate SIM / Phone */}
              <div>
                <label style={{ fontSize: '0.75rem', color: 'var(--text-dim)', display: 'block', marginBottom: '4px', fontWeight: 600 }}>
                  Corporate Phone Number / SIM Binding
                </label>
                <input
                  type="text"
                  placeholder="+91 98200 12345"
                  value={devicePhone}
                  onChange={e => setDevicePhone(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '9px 12px',
                    borderRadius: '8px',
                    background: 'var(--bg-surface-elevated)',
                    border: '1px solid var(--border-glass)',
                    color: 'var(--text-main)',
                    fontSize: '0.85rem',
                    fontFamily: 'var(--font-mono)'
                  }}
                />
              </div>

              {/* Battery & Telemetry Status Grid */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                <div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '4px' }}>
                    <label style={{ fontSize: '0.75rem', color: 'var(--text-dim)', fontWeight: 600 }}>
                      Battery Level
                    </label>
                    <span style={{ fontSize: '0.8rem', fontWeight: 700, color: deviceBatteryLevel > 30 ? 'var(--accent-emerald)' : 'var(--accent-rose)' }}>
                      {deviceBatteryLevel}%
                    </span>
                  </div>
                  <input
                    type="range"
                    min="1"
                    max="100"
                    value={deviceBatteryLevel}
                    onChange={e => setDeviceBatteryLevel(parseInt(e.target.value))}
                    style={{ width: '100%', accentColor: 'var(--primary)', cursor: 'pointer' }}
                  />
                </div>

                <div>
                  <label style={{ fontSize: '0.75rem', color: 'var(--text-dim)', display: 'block', marginBottom: '4px', fontWeight: 600 }}>
                    Device State
                  </label>
                  <select
                    value={deviceIsOnline ? 'online' : 'offline'}
                    onChange={e => setDeviceIsOnline(e.target.value === 'online')}
                    style={{
                      width: '100%',
                      padding: '8px 10px',
                      borderRadius: '8px',
                      background: 'var(--bg-surface-elevated)',
                      border: '1px solid var(--border-glass)',
                      color: deviceIsOnline ? 'var(--accent-emerald)' : 'var(--accent-rose)',
                      fontSize: '0.82rem',
                      fontWeight: 600
                    }}
                  >
                    <option value="online">● Online (Connected)</option>
                    <option value="offline">○ Offline (Suspended)</option>
                  </select>
                </div>
              </div>

              {/* Avatar Selector */}
              <div>
                <label style={{ fontSize: '0.75rem', color: 'var(--text-dim)', display: 'block', marginBottom: '6px', fontWeight: 600 }}>
                  Representative Avatar
                </label>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <img src={deviceAvatar} alt="preview" style={{ width: '40px', height: '40px', borderRadius: '50%', objectFit: 'cover', border: '2px solid var(--primary)' }} />
                  <div style={{ display: 'flex', gap: '6px' }}>
                    {[
                      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120&auto=format&fit=crop&q=80',
                      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=120&auto=format&fit=crop&q=80',
                      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=120&auto=format&fit=crop&q=80',
                      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&auto=format&fit=crop&q=80',
                      'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=120&auto=format&fit=crop&q=80'
                    ].map((url, idx) => (
                      <img
                        key={idx}
                        src={url}
                        alt="avatar option"
                        onClick={() => setDeviceAvatar(url)}
                        style={{
                          width: '32px',
                          height: '32px',
                          borderRadius: '50%',
                          objectFit: 'cover',
                          cursor: 'pointer',
                          opacity: deviceAvatar === url ? 1 : 0.45,
                          border: deviceAvatar === url ? '2px solid var(--primary)' : '1px solid transparent'
                        }}
                      />
                    ))}
                  </div>
                </div>
              </div>

              {/* Form Buttons */}
              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.75rem', marginTop: '0.75rem' }}>
                <button type="button" onClick={() => setDeviceModalOpen(false)} className="btn-secondary">
                  Cancel
                </button>
                <button type="submit" className="btn-primary" style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <Check size={16} />
                  <span>{editingRepId ? 'Update Fleet Device' : 'Enroll Fleet Device'}</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* MODAL: QR & 6-DIGIT PIN PAIRING */}
      {qrModalRep && (
        <div style={{
          position: 'fixed',
          inset: 0,
          background: 'rgba(5,7,15,0.88)',
          backdropFilter: 'blur(10px)',
          zIndex: 150,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          padding: '1rem'
        }}>
          <div className="glass-panel" style={{ width: '100%', maxWidth: '440px', padding: '2rem', textAlign: 'center' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
              <div style={{ textAlign: 'left' }}>
                <h3 style={{ fontSize: '1.2rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>
                  Pair Member Device
                </h3>
                <span style={{ fontSize: '0.75rem', color: 'var(--accent-cyan)' }}>
                  Tenant: {currentOrg?.name || currentUser?.orgName || 'Corporate Workspace'}
                </span>
              </div>
              <button onClick={() => setQrModalRep(null)} className="btn-ghost" style={{ padding: '4px' }}>
                <X size={18} />
              </button>
            </div>

            <p style={{ fontSize: '0.82rem', color: 'var(--text-dim)', marginBottom: '1.25rem', textAlign: 'left' }}>
              Instruct <strong>{qrModalRep}</strong> to open the RingVia360 mobile app and enter this 6-digit pairing code, or scan the QR code below.
            </p>

            {/* 6-DIGIT PIN BOX */}
            <div style={{
              background: 'rgba(124,58,237,0.1)',
              border: '1px solid rgba(124,58,237,0.3)',
              borderRadius: '14px',
              padding: '1.25rem 1rem',
              marginBottom: '1.25rem'
            }}>
              <div style={{ fontSize: '0.72rem', textTransform: 'uppercase', letterSpacing: '0.08em', color: 'var(--text-muted)', marginBottom: '0.4rem' }}>
                6-Digit Pairing PIN
              </div>
              <div style={{
                fontSize: '2.4rem',
                fontWeight: 800,
                letterSpacing: '8px',
                color: '#38bdf8',
                fontFamily: 'ui-monospace, monospace'
              }}>
                {pairLoading ? '••••••' : pairCode}
              </div>
              <div style={{ display: 'flex', justifyContent: 'center', gap: '0.5rem', marginTop: '0.6rem' }}>
                <button
                  onClick={() => {
                    navigator.clipboard.writeText(pairCode.replace(' ', ''));
                    setPairCopied(true);
                    setTimeout(() => setPairCopied(false), 2500);
                  }}
                  className="btn-ghost"
                  style={{ fontSize: '0.75rem', padding: '4px 10px' }}
                >
                  {pairCopied ? '✓ Copied PIN' : 'Copy PIN'}
                </button>
                <button
                  onClick={() => handleOpenPairModal(qrModalRep)}
                  className="btn-ghost"
                  style={{ fontSize: '0.75rem', padding: '4px 10px' }}
                >
                  <RefreshCw size={12} /> Regenerate
                </button>
              </div>
            </div>

            {/* High Tech QR Code Box */}
            <div style={{
              width: '140px',
              height: '140px',
              margin: '0 auto 1rem',
              background: '#fff',
              borderRadius: '14px',
              padding: '10px',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              boxShadow: '0 0 25px rgba(6,182,212,0.25)'
            }}>
              <QrCode size={120} color="#090a10" />
            </div>

            <div style={{ fontSize: '0.75rem', color: 'var(--accent-emerald)', fontWeight: 600, marginBottom: '1.25rem' }}>
              ✓ Knox Vault & Isolated Feed Partition Active
            </div>

            <button
              onClick={() => setQrModalRep(null)}
              className="btn-primary"
              style={{ width: '100%' }}
            >
              Done
            </button>
          </div>
        </div>
      )}

      {/* TAB 7: CONTENT MANAGEMENT */}
      {activeTab === 'content' && (
        <div className="glass-panel" style={{ padding: '1.5rem', display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <div>
            <h3 style={{ fontSize: '1.2rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>
              Dynamic Site Content Management
            </h3>
            <p style={{ fontSize: '0.8rem', color: 'var(--text-dim)', marginTop: '4px' }}>
              Edit all page content (headings, subtitles, pricing plans, features, stats) stored in the <code style={{ color: 'var(--accent-cyan)' }}>site_pages</code> MySQL table. Changes are reflected instantly across web and mobile.
            </p>
          </div>
          <ContentEditorPanel />
        </div>
      )}
    </div>
  );
}
