import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Crown,
  Building,
  Users,
  CreditCard,
  PhoneCall,
  ShieldCheck,
  Plus,
  RefreshCw,
  Eye,
  CheckCircle2,
  XCircle,
  ExternalLink,
  Search,
  Database,
  Lock,
  ArrowRight,
  TrendingUp,
  Sliders,
  DollarSign,
  Play,
  Headphones,
  Smartphone,
  Battery,
  Sparkles,
  AlertCircle,
  FileText,
  ChevronRight,
  X,
  ArrowUpRight,
  ArrowDownLeft,
  PhoneIncoming,
  PhoneOutgoing,
  PhoneMissed,
  Check,
  Activity,
  Layers,
  Zap,
  Key
} from 'lucide-react';
import { useApp } from '../context/AppContext';
import type { TenantOrganization, CallLog } from '../types';
import ContentEditorPanel from '../components/ContentEditorPanel';

export default function SuperAdmin() {
  const navigate = useNavigate();
  const {
    currentUser,
    activeTenantId,
    switchTenant,
    superAdminOverview,
    fetchSuperAdminOverview,
    manageTenantStatus,
    signup,
    dbEngine,
    setActiveAudioCall
  } = useApp();

  const [isLoading, setIsLoading] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [createModalOpen, setCreateModalOpen] = useState(false);

  // In-Depth Org Review Modal State
  const [selectedOrgForReview, setSelectedOrgForReview] = useState<TenantOrganization | null>(null);
  const [reviewModalOpen, setReviewModalOpen] = useState(false);
  const [orgDetailsLoading, setOrgDetailsLoading] = useState(false);
  const [orgDetailsData, setOrgDetailsData] = useState<{
    organization: any;
    metrics: {
      totalCalls: number;
      connectedCalls: number;
      totalTalkTimeMinutes: number;
      totalPipelineValue: number;
      repCount: number;
      userCount: number;
    };
    calls: any[];
    reps: any[];
    users: any[];
  } | null>(null);
  const [reviewTab, setReviewTab] = useState<'calls' | 'reps' | 'users' | 'security'>('calls');
  const [callSearchTerm, setCallSearchTerm] = useState('');
  const [expandedCallId, setExpandedCallId] = useState<string | null>(null);

  // New tenant form
  const [newCompanyName, setNewCompanyName] = useState('');
  const [newAdminName, setNewAdminName] = useState('');
  const [newAdminEmail, setNewAdminEmail] = useState('');
  const [newPassword, setNewPassword] = useState('Password123!');
  const [newPhone, setNewPhone] = useState('+91 98200 12345');
  const [newPlan, setNewPlan] = useState('Pro Growth');
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    fetchSuperAdminOverview();
  }, []);

  const handleRefresh = async () => {
    setIsLoading(true);
    await fetchSuperAdminOverview();
    setIsLoading(false);
  };

  const openOrgReview = async (tenant: TenantOrganization) => {
    setSelectedOrgForReview(tenant);
    setReviewModalOpen(true);
    setOrgDetailsLoading(true);
    setReviewTab('calls');
    setCallSearchTerm('');
    setExpandedCallId(null);
    try {
      const res = await fetch(`/api/auth.php?action=superadmin_org_details&org_id=${encodeURIComponent(tenant.id)}`);
      const data = await res.json();
      if (data.success && data.data) {
        setOrgDetailsData(data.data);
      }
    } catch (err) {
      console.error('Failed to load org details:', err);
    } finally {
      setOrgDetailsLoading(false);
    }
  };

  const handleEnterWorkspace = async (orgId: string) => {
    await switchTenant(orgId);
    navigate('/admin');
  };

  const handlePlayCallAudio = (c: any) => {
    let waveform: number[] = [35, 50, 70, 85, 65, 45, 80, 95, 75, 60, 50, 65, 80, 90, 85, 70, 55, 45, 60, 75];
    if (c.waveform) {
      if (Array.isArray(c.waveform)) {
        waveform = c.waveform;
      } else if (typeof c.waveform === 'string') {
        try {
          waveform = JSON.parse(c.waveform);
        } catch (_) {}
      }
    }

    let transcript: any[] = [];
    if (c.transcript) {
      if (Array.isArray(c.transcript)) {
        transcript = c.transcript;
      } else if (typeof c.transcript === 'string') {
        try {
          transcript = JSON.parse(c.transcript);
        } catch (_) {}
      }
    }

    const mappedCall: CallLog = {
      id: c.id || `call-${Date.now()}`,
      contactName: c.contact_name || c.contactName || 'Corporate Contact',
      phoneNumber: c.phone_number || c.phoneNumber || '+91 98200 00000',
      company: c.company || selectedOrgForReview?.name || 'Client Org',
      direction: (c.direction as any) || 'outbound',
      duration: Number(c.duration) || 0,
      timestamp: c.timestamp || 'Recent',
      repName: c.rep_name || c.repName || 'Sales Rep',
      repAvatar: c.rep_avatar || c.repAvatar || 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120&auto=format&fit=crop&q=80',
      repId: c.rep_id || c.repId || 'rep-1',
      recordingUrl: c.recording_url || c.recordingUrl || 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
      waveform: waveform,
      transcript: transcript,
      sentiment: (c.sentiment as any) || 'positive',
      sentimentScore: Number(c.sentiment_score || c.sentimentScore || 85),
      outcome: c.outcome || 'Call Completed',
      notes: c.notes || '',
      crmStatus: (c.crm_status as any) || 'synced',
      crmType: (c.crm_type as any) || 'RingVia360',
      dealValue: Number(c.deal_value || c.dealValue || 0),
      dealStage: c.deal_stage || c.dealStage || 'Proposal',
      tags: Array.isArray(c.tags) ? c.tags : ['SuperAdminAudit', 'E2EE'],
      keyActionItems: Array.isArray(c.key_action_items) ? c.key_action_items : [],
      isEncrypted: Boolean(c.is_encrypted !== 0),
      simSlot: c.sim_slot || 'SIM 1'
    };

    setActiveAudioCall(mappedCall);
  };

  const handleCreateTenant = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    try {
      const ok = await signup({
        companyName: newCompanyName,
        name: newAdminName,
        email: newAdminEmail,
        password: newPassword,
        phone: newPhone,
        plan: newPlan
      });
      if (ok) {
        setCreateModalOpen(false);
        setNewCompanyName('');
        setNewAdminName('');
        setNewAdminEmail('');
        await fetchSuperAdminOverview();
      }
    } finally {
      setIsSubmitting(false);
    }
  };

  const defaultTenants: TenantOrganization[] = [
    {
      id: 'org-tcs',
      name: 'Tata Consultancy Services',
      slug: 'tcs',
      plan: 'Enterprise Plus',
      seats: 120,
      monthly_price_inr: 45000,
      status: 'active',
      owner_email: 'aarav.sharma@tcs.com',
      call_count: 4,
      user_count: 2,
      total_deal_value: 115000,
      rep_count: 4
    },
    {
      id: 'org-makes360-33faf',
      name: 'RingVia360 Enterprise',
      slug: 'makes360',
      plan: 'Growth Pro',
      seats: 25,
      monthly_price_inr: 14999,
      status: 'active',
      owner_email: 'rajat@makes360.in',
      call_count: 5,
      user_count: 2,
      total_deal_value: 1923415,
      rep_count: 4
    },
    {
      id: 'org-infosys',
      name: 'Infosys Technologies',
      slug: 'infosys',
      plan: 'Pro Growth',
      seats: 50,
      monthly_price_inr: 22000,
      status: 'active',
      owner_email: 'priya.patel@infosys.com',
      call_count: 0,
      user_count: 1,
      total_deal_value: 0,
      rep_count: 0
    }
  ];

  const tenants = superAdminOverview?.tenants && superAdminOverview.tenants.length > 0
    ? superAdminOverview.tenants
    : defaultTenants;

  const filteredTenants = tenants.filter(t =>
    t.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    t.slug.toLowerCase().includes(searchTerm.toLowerCase()) ||
    (t.owner_email && t.owner_email.toLowerCase().includes(searchTerm.toLowerCase()))
  );

  const totalMrr = tenants.reduce((acc, t) => acc + Number(t.monthly_price_inr || 14999), 0);
  const totalSeats = tenants.reduce((acc, t) => acc + (t.seats || 50), 0);
  const activeCount = tenants.filter(t => t.status === 'active').length;
  const totalCapturedCalls = tenants.reduce((acc, t) => acc + Number(t.call_count || 0), 0);
  const totalPipelineSum = tenants.reduce((acc, t) => acc + Number(t.total_deal_value || 0), 0);

  if (currentUser?.role !== 'super_admin') {
    return (
      <div style={{ maxWidth: '640px', margin: '5rem auto', padding: '2rem 1.5rem', textAlign: 'center' }}>
        <div className="glass-card" style={{ padding: '3.5rem 2.5rem', border: '1px solid rgba(234, 179, 8, 0.3)' }}>
          <div style={{
            width: '68px',
            height: '68px',
            borderRadius: '20px',
            background: 'rgba(234, 179, 8, 0.15)',
            border: '1px solid rgba(234, 179, 8, 0.4)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            margin: '0 auto 1.5rem',
            color: '#eab308'
          }}>
            <Crown size={34} />
          </div>
          <h2 style={{ fontSize: '1.75rem', fontWeight: 800, marginBottom: '0.75rem', color: 'var(--text-main)' }}>
            Super Admin Authority Required
          </h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '0.95rem', lineHeight: 1.6, marginBottom: '2rem' }}>
            The Global SaaS Management console contains sovereign cross-tenant client telemetry, billing tier controls, and company lifecycle administration. Please authenticate with Super Admin credentials.
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
                gap: '0.5rem',
                background: 'linear-gradient(135deg, #eab308 0%, #f97316 100%)',
                color: '#000',
                border: 'none',
                boxShadow: '0 4px 14px rgba(234, 179, 8, 0.3)'
              }}
            >
              <Crown size={16} />
              Sign In as Super Admin
            </button>
            <button
              onClick={() => navigate('/admin')}
              className="btn-ghost"
              style={{
                padding: '0.8rem 1.5rem',
                borderRadius: '10px',
                fontSize: '0.9rem',
                fontWeight: 600,
                border: '1px solid var(--border-glass)'
              }}
            >
              Go to Customer Admin
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div style={{ maxWidth: '1440px', margin: '0 auto', padding: '2rem 1.5rem 5rem' }}>
      {/* Super Admin Top Header */}
      <div style={{
        display: 'flex',
        flexWrap: 'wrap',
        justifyContent: 'space-between',
        alignItems: 'center',
        gap: '1.25rem',
        marginBottom: '2rem',
        paddingBottom: '1.5rem',
        borderBottom: '1px solid var(--border-subtle)'
      }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '0.5rem', flexWrap: 'wrap' }}>
            <span style={{
              background: 'linear-gradient(135deg, rgba(234, 179, 8, 0.2), rgba(249, 115, 22, 0.2))',
              border: '1px solid rgba(234, 179, 8, 0.4)',
              color: '#eab308',
              padding: '0.35rem 0.85rem',
              borderRadius: '999px',
              fontSize: '0.8rem',
              fontWeight: 700,
              display: 'inline-flex',
              alignItems: 'center',
              gap: '0.4rem'
            }}>
              <Crown size={14} /> PLATFORM SUPER ADMIN
            </span>

            <span style={{
              background: 'rgba(16, 185, 129, 0.1)',
              border: '1px solid rgba(16, 185, 129, 0.25)',
              color: 'var(--accent-emerald)',
              padding: '0.3rem 0.75rem',
              borderRadius: '999px',
              fontSize: '0.75rem',
              fontWeight: 600,
              display: 'inline-flex',
              alignItems: 'center',
              gap: '0.35rem'
            }}>
              <Database size={13} /> {dbEngine.toUpperCase()} MULTI-TENANT SOVEREIGN ISOLATION
            </span>

            <span style={{
              background: 'rgba(59, 130, 246, 0.1)',
              border: '1px solid rgba(59, 130, 246, 0.25)',
              color: '#60a5fa',
              padding: '0.3rem 0.75rem',
              borderRadius: '999px',
              fontSize: '0.75rem',
              fontWeight: 600,
              display: 'inline-flex',
              alignItems: 'center',
              gap: '0.35rem'
            }}>
              <Activity size={13} /> {totalCapturedCalls} CALLS RECORDED
            </span>
          </div>
          <h1 style={{ fontSize: '2.1rem', fontWeight: 800, margin: 0, letterSpacing: '-0.02em' }}>
            Tenant & Customer Platform Management
          </h1>
          <p style={{ color: 'var(--text-secondary)', margin: '0.35rem 0 0', fontSize: '0.95rem' }}>
            Inspect every organization's sovereign call logs, audio waveforms, Whisper AI transcripts, sales reps telemetry, and Knox mobile devices.
          </p>
        </div>

        <div style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap' }}>
          <button
            onClick={handleRefresh}
            disabled={isLoading}
            style={{
              padding: '0.65rem 1.1rem',
              background: 'var(--bg-glass)',
              border: '1px solid var(--border-subtle)',
              borderRadius: '10px',
              color: 'var(--text-primary)',
              fontSize: '0.85rem',
              fontWeight: 600,
              display: 'inline-flex',
              alignItems: 'center',
              gap: '0.5rem',
              cursor: 'pointer'
            }}
          >
            <RefreshCw size={15} className={isLoading ? 'spin' : ''} />
            Refresh Platform
          </button>

          <button
            onClick={() => setCreateModalOpen(true)}
            style={{
              padding: '0.65rem 1.25rem',
              background: 'linear-gradient(135deg, var(--accent-primary), var(--accent-hover))',
              border: 'none',
              borderRadius: '10px',
              color: '#ffffff',
              fontSize: '0.85rem',
              fontWeight: 700,
              display: 'inline-flex',
              alignItems: 'center',
              gap: '0.5rem',
              cursor: 'pointer',
              boxShadow: '0 4px 14px rgba(99, 102, 241, 0.35)'
            }}
          >
            <Plus size={16} />
            Onboard New Customer Tenant
          </button>
        </div>
      </div>

      {/* Active Perspective Banner */}
      <div style={{
        background: activeTenantId === 'all'
          ? 'linear-gradient(135deg, rgba(234, 179, 8, 0.08), rgba(249, 115, 22, 0.04))'
          : 'linear-gradient(135deg, rgba(99, 102, 241, 0.12), rgba(168, 85, 247, 0.06))',
        border: activeTenantId === 'all'
          ? '1px solid rgba(234, 179, 8, 0.3)'
          : '1px solid rgba(99, 102, 241, 0.35)',
        borderRadius: '14px',
        padding: '1.1rem 1.5rem',
        marginBottom: '2rem',
        display: 'flex',
        flexWrap: 'wrap',
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: '1rem'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.85rem' }}>
          <div style={{
            width: '42px',
            height: '42px',
            borderRadius: '10px',
            background: activeTenantId === 'all' ? 'rgba(234, 179, 8, 0.2)' : 'rgba(99, 102, 241, 0.2)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: activeTenantId === 'all' ? '#eab308' : 'var(--accent-primary)'
          }}>
            {activeTenantId === 'all' ? <Crown size={22} /> : <Building size={22} />}
          </div>
          <div>
            <div style={{ fontSize: '0.8rem', textTransform: 'uppercase', letterSpacing: '0.05em', color: 'var(--text-tertiary)', fontWeight: 600 }}>
              Current Active View Perspective
            </div>
            <div style={{ fontSize: '1.05rem', fontWeight: 700, color: 'var(--text-primary)' }}>
              {activeTenantId === 'all'
                ? '🌐 Global Super Admin Fleet Overview (Full Cross-Tenant Auditing Enabled)'
                : `🏢 Scoped to Tenant Workspace: ${tenants.find(t => t.id === activeTenantId)?.name || activeTenantId}`}
            </div>
          </div>
        </div>

        <div style={{ display: 'flex', gap: '0.75rem', alignItems: 'center', flexWrap: 'wrap' }}>
          {activeTenantId !== 'all' && (
            <button
              onClick={() => switchTenant('all')}
              style={{
                padding: '0.55rem 1rem',
                background: 'rgba(234, 179, 8, 0.15)',
                border: '1px solid rgba(234, 179, 8, 0.4)',
                borderRadius: '8px',
                color: '#eab308',
                fontSize: '0.8rem',
                fontWeight: 700,
                cursor: 'pointer'
              }}
            >
              Reset to Global Super Admin View
            </button>
          )}

          <button
            onClick={() => navigate('/admin')}
            style={{
              padding: '0.55rem 1rem',
              background: 'var(--bg-glass)',
              border: '1px solid var(--border-subtle)',
              borderRadius: '8px',
              color: 'var(--text-primary)',
              fontSize: '0.8rem',
              fontWeight: 600,
              display: 'inline-flex',
              alignItems: 'center',
              gap: '0.4rem',
              cursor: 'pointer'
            }}
          >
            Enter Organization Workspace <ExternalLink size={13} />
          </button>
        </div>
      </div>

      {/* Platform Metric KPI Cards */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
        gap: '1.25rem',
        marginBottom: '2.5rem'
      }}>
        <div className="glass-panel" style={{ padding: '1.35rem 1.5rem', borderRadius: '14px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem' }}>
            <span style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', fontWeight: 600 }}>Total Organizations</span>
            <span style={{ padding: '0.35rem', borderRadius: '8px', background: 'rgba(99, 102, 241, 0.15)', color: 'var(--accent-primary)' }}>
              <Building size={18} />
            </span>
          </div>
          <div style={{ fontSize: '2rem', fontWeight: 800 }}>{tenants.length}</div>
          <div style={{ fontSize: '0.8rem', color: 'var(--accent-emerald)', marginTop: '0.35rem', display: 'flex', alignItems: 'center', gap: '0.3rem' }}>
            <CheckCircle2 size={13} /> {activeCount} active sovereign tenants
          </div>
        </div>

        <div className="glass-panel" style={{ padding: '1.35rem 1.5rem', borderRadius: '14px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem' }}>
            <span style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', fontWeight: 600 }}>Total Captured Calls</span>
            <span style={{ padding: '0.35rem', borderRadius: '8px', background: 'rgba(59, 130, 246, 0.15)', color: '#3b82f6' }}>
              <PhoneCall size={18} />
            </span>
          </div>
          <div style={{ fontSize: '2rem', fontWeight: 800 }}>{totalCapturedCalls}</div>
          <div style={{ fontSize: '0.8rem', color: 'var(--accent-cyan)', marginTop: '0.35rem' }}>
            Live audio & AI transcripts recorded
          </div>
        </div>

        <div className="glass-panel" style={{ padding: '1.35rem 1.5rem', borderRadius: '14px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem' }}>
            <span style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', fontWeight: 600 }}>Pipeline Deal Volume</span>
            <span style={{ padding: '0.35rem', borderRadius: '8px', background: 'rgba(245, 158, 11, 0.15)', color: 'var(--accent-amber)' }}>
              <TrendingUp size={18} />
            </span>
          </div>
          <div style={{ fontSize: '1.75rem', fontWeight: 800, color: 'var(--accent-amber)' }}>
            ₹{totalPipelineSum.toLocaleString('en-IN')}
          </div>
          <div style={{ fontSize: '0.8rem', color: 'var(--text-tertiary)', marginTop: '0.35rem' }}>
            Across all customer CRM deals
          </div>
        </div>

        <div className="glass-panel" style={{ padding: '1.35rem 1.5rem', borderRadius: '14px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem' }}>
            <span style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', fontWeight: 600 }}>Platform MRR</span>
            <span style={{ padding: '0.35rem', borderRadius: '8px', background: 'rgba(16, 185, 129, 0.15)', color: 'var(--accent-emerald)' }}>
              <DollarSign size={18} />
            </span>
          </div>
          <div style={{ fontSize: '1.75rem', fontWeight: 800 }}>₹{totalMrr.toLocaleString('en-IN')}</div>
          <div style={{ fontSize: '0.8rem', color: 'var(--text-tertiary)', marginTop: '0.35rem' }}>
            {totalSeats} licensed Knox seats
          </div>
        </div>
      </div>

      {/* Tenant Directory Table */}
      <div className="glass-panel" style={{ borderRadius: '16px', overflow: 'hidden', border: '1px solid var(--border-subtle)' }}>
        <div style={{
          padding: '1.25rem 1.5rem',
          borderBottom: '1px solid var(--border-subtle)',
          display: 'flex',
          flexWrap: 'wrap',
          justifyContent: 'space-between',
          alignItems: 'center',
          gap: '1rem'
        }}>
          <div>
            <h2 style={{ fontSize: '1.25rem', fontWeight: 700, margin: 0 }}>Customer Organization Accounts</h2>
            <p style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', margin: '0.2rem 0 0' }}>
              Click <strong>"Review All Data"</strong> to audit calls, recordings, and rep telemetry, or <strong>"Enter Workspace"</strong> to manage directly as Super Admin.
            </p>
          </div>

          <div style={{ position: 'relative', width: '280px' }}>
            <Search size={15} style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-tertiary)' }} />
            <input
              type="text"
              placeholder="Search companies, admins..."
              value={searchTerm}
              onChange={e => setSearchTerm(e.target.value)}
              style={{
                width: '100%',
                padding: '0.55rem 0.85rem 0.55rem 2.25rem',
                background: 'rgba(255, 255, 255, 0.04)',
                border: '1px solid var(--border-subtle)',
                borderRadius: '8px',
                color: 'var(--text-primary)',
                fontSize: '0.85rem'
              }}
            />
          </div>
        </div>

        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '0.88rem' }}>
            <thead>
              <tr style={{ background: 'rgba(255, 255, 255, 0.02)', borderBottom: '1px solid var(--border-subtle)', color: 'var(--text-secondary)' }}>
                <th style={{ padding: '0.9rem 1.25rem', fontWeight: 600 }}>Company & Tenant</th>
                <th style={{ padding: '0.9rem 1.25rem', fontWeight: 600 }}>Plan & Pricing</th>
                <th style={{ padding: '0.9rem 1.25rem', fontWeight: 600 }}>Telemetry & Calls</th>
                <th style={{ padding: '0.9rem 1.25rem', fontWeight: 600 }}>Pipeline Deal Value</th>
                <th style={{ padding: '0.9rem 1.25rem', fontWeight: 600 }}>Customer Admin</th>
                <th style={{ padding: '0.9rem 1.25rem', fontWeight: 600 }}>Status</th>
                <th style={{ padding: '0.9rem 1.25rem', fontWeight: 600, textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredTenants.map(tenant => {
                const isSelected = activeTenantId === tenant.id;
                const callCount = Number(tenant.call_count ?? 0);
                const repCount = Number(tenant.rep_count ?? 0);
                const dealValue = Number(tenant.total_deal_value ?? 0);

                return (
                  <tr
                    key={tenant.id}
                    style={{
                      borderBottom: '1px solid var(--border-subtle)',
                      background: isSelected ? 'rgba(99, 102, 241, 0.06)' : 'transparent',
                      transition: 'background 0.15s ease'
                    }}
                  >
                    <td style={{ padding: '1rem 1.25rem' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                        <div style={{
                          width: '40px',
                          height: '40px',
                          borderRadius: '10px',
                          background: 'linear-gradient(135deg, rgba(99, 102, 241, 0.2), rgba(168, 85, 247, 0.2))',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          fontWeight: 700,
                          color: 'var(--accent-primary)'
                        }}>
                          {tenant.name.substring(0, 2).toUpperCase()}
                        </div>
                        <div>
                          <div style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: '0.95rem' }}>{tenant.name}</div>
                          <div style={{ fontSize: '0.75rem', color: 'var(--text-tertiary)', fontFamily: 'monospace' }}>
                            ID: {tenant.id} • slug: ringvia360.com/{tenant.slug}
                          </div>
                        </div>
                      </div>
                    </td>

                    <td style={{ padding: '1rem 1.25rem' }}>
                      <div style={{ fontWeight: 600, color: 'var(--text-primary)' }}>{tenant.plan}</div>
                      <div style={{ fontSize: '0.78rem', color: 'var(--accent-emerald)', fontWeight: 600 }}>
                        ₹{Number(tenant.monthly_price_inr || 14999).toLocaleString('en-IN')} / mo
                      </div>
                    </td>

                    <td style={{ padding: '1rem 1.25rem' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', fontWeight: 700, color: callCount > 0 ? 'var(--accent-cyan)' : 'var(--text-dim)' }}>
                        <PhoneCall size={14} />
                        {callCount} Calls Captured
                      </div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-tertiary)', marginTop: '0.15rem' }}>
                        {repCount} Reps Enrolled ({tenant.seats} Seats)
                      </div>
                    </td>

                    <td style={{ padding: '1rem 1.25rem' }}>
                      <div style={{ fontWeight: 800, color: dealValue > 0 ? 'var(--accent-amber)' : 'var(--text-dim)', fontSize: '0.92rem' }}>
                        ₹{dealValue.toLocaleString('en-IN')}
                      </div>
                      <div style={{ fontSize: '0.72rem', color: 'var(--text-tertiary)' }}>
                        Sovereign Pipeline
                      </div>
                    </td>

                    <td style={{ padding: '1rem 1.25rem' }}>
                      <div style={{ color: 'var(--text-primary)', fontWeight: 500, fontSize: '0.85rem' }}>{tenant.owner_email || 'admin@' + (tenant.slug || 'company') + '.com'}</div>
                      <div style={{ fontSize: '0.72rem', color: 'var(--text-tertiary)' }}>{tenant.user_count ? `${tenant.user_count} Admins/Staff` : 'Primary Owner'}</div>
                    </td>

                    <td style={{ padding: '1rem 1.25rem' }}>
                      <span style={{
                        padding: '0.25rem 0.65rem',
                        borderRadius: '999px',
                        fontSize: '0.75rem',
                        fontWeight: 700,
                        background: tenant.status === 'active' ? 'rgba(16, 185, 129, 0.15)' : 'rgba(239, 68, 68, 0.15)',
                        color: tenant.status === 'active' ? 'var(--accent-emerald)' : 'var(--accent-rose)',
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: '0.3rem'
                      }}>
                        {tenant.status === 'active' ? <CheckCircle2 size={12} /> : <XCircle size={12} />}
                        {tenant.status === 'active' ? 'Active' : 'Suspended'}
                      </span>
                    </td>

                    <td style={{ padding: '1rem 1.25rem', textAlign: 'right' }}>
                      <div style={{ display: 'inline-flex', gap: '0.5rem', alignItems: 'center' }}>
                        {/* Review All Data Button */}
                        <button
                          onClick={() => openOrgReview(tenant)}
                          style={{
                            padding: '0.45rem 0.85rem',
                            background: 'rgba(234, 179, 8, 0.15)',
                            border: '1px solid rgba(234, 179, 8, 0.4)',
                            borderRadius: '8px',
                            color: '#eab308',
                            fontSize: '0.78rem',
                            fontWeight: 700,
                            display: 'inline-flex',
                            alignItems: 'center',
                            gap: '0.35rem',
                            cursor: 'pointer'
                          }}
                          title="Open comprehensive review modal with all calls, transcripts, reps, and admins"
                        >
                          <Eye size={13} />
                          Review All Data
                        </button>

                        {/* Enter Workspace Button */}
                        <button
                          onClick={() => handleEnterWorkspace(tenant.id)}
                          style={{
                            padding: '0.45rem 0.85rem',
                            background: isSelected ? 'var(--accent-primary)' : 'rgba(99, 102, 241, 0.15)',
                            border: '1px solid rgba(99, 102, 241, 0.3)',
                            borderRadius: '8px',
                            color: isSelected ? '#ffffff' : 'var(--accent-primary)',
                            fontSize: '0.78rem',
                            fontWeight: 700,
                            display: 'inline-flex',
                            alignItems: 'center',
                            gap: '0.35rem',
                            cursor: 'pointer'
                          }}
                        >
                          <ArrowRight size={13} />
                          {isSelected ? 'In Workspace' : 'Enter Workspace'}
                        </button>

                        <button
                          onClick={() => {
                            const next = tenant.status === 'active' ? 'suspended' : 'active';
                            manageTenantStatus(tenant.id, next);
                          }}
                          style={{
                            padding: '0.45rem 0.65rem',
                            background: 'var(--bg-glass)',
                            border: '1px solid var(--border-subtle)',
                            borderRadius: '8px',
                            color: tenant.status === 'active' ? 'var(--accent-rose)' : 'var(--accent-emerald)',
                            fontSize: '0.78rem',
                            fontWeight: 600,
                            cursor: 'pointer'
                          }}
                        >
                          {tenant.status === 'active' ? 'Suspend' : 'Activate'}
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

      {/* SUPER ADMIN IN-DEPTH ORGANIZATION AUDIT & REVIEW MODAL */}
      {reviewModalOpen && selectedOrgForReview && (
        <div style={{
          position: 'fixed',
          inset: 0,
          background: 'rgba(0, 0, 0, 0.85)',
          backdropFilter: 'blur(10px)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 9999,
          padding: '1.5rem'
        }}>
          <div className="glass-panel" style={{
            width: '100%',
            maxWidth: '1100px',
            maxHeight: '90vh',
            display: 'flex',
            flexDirection: 'column',
            borderRadius: '20px',
            border: '1px solid rgba(234, 179, 8, 0.4)',
            background: 'var(--bg-elevated)',
            boxShadow: '0 25px 60px rgba(0,0,0,0.7)',
            overflow: 'hidden'
          }}>
            {/* Modal Header */}
            <div style={{
              padding: '1.25rem 1.75rem',
              borderBottom: '1px solid var(--border-subtle)',
              background: 'linear-gradient(135deg, rgba(234, 179, 8, 0.12), rgba(99, 102, 241, 0.08))',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              flexWrap: 'wrap',
              gap: '1rem'
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.85rem' }}>
                <div style={{
                  width: '46px',
                  height: '46px',
                  borderRadius: '12px',
                  background: 'linear-gradient(135deg, #eab308, #f97316)',
                  color: '#000',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontWeight: 900,
                  fontSize: '1.1rem',
                  boxShadow: '0 4px 14px rgba(234, 179, 8, 0.35)'
                }}>
                  {selectedOrgForReview.name.substring(0, 2).toUpperCase()}
                </div>
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', flexWrap: 'wrap' }}>
                    <span style={{
                      background: '#eab308',
                      color: '#000',
                      padding: '0.2rem 0.5rem',
                      borderRadius: '5px',
                      fontSize: '0.7rem',
                      fontWeight: 800
                    }}>
                      SUPER ADMIN AUDIT
                    </span>
                    <h3 style={{ fontSize: '1.35rem', fontWeight: 800, margin: 0, color: 'var(--text-main)' }}>
                      {selectedOrgForReview.name}
                    </h3>
                    <code style={{ fontSize: '0.75rem', background: 'rgba(0,0,0,0.3)', padding: '0.15rem 0.5rem', borderRadius: '4px', color: 'var(--accent-cyan)' }}>
                      {selectedOrgForReview.id}
                    </code>
                  </div>
                  <div style={{ fontSize: '0.8rem', color: 'var(--text-secondary)', marginTop: '0.25rem' }}>
                    Plan: <strong style={{ color: 'var(--text-main)' }}>{selectedOrgForReview.plan}</strong> • Rate: <strong style={{ color: 'var(--accent-emerald)' }}>₹{Number(selectedOrgForReview.monthly_price_inr || 14999).toLocaleString('en-IN')}/mo</strong> • Owner: {selectedOrgForReview.owner_email || 'admin@' + (selectedOrgForReview.slug || 'company') + '.com'}
                  </div>
                </div>
              </div>

              <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                <button
                  onClick={() => handleEnterWorkspace(selectedOrgForReview.id)}
                  style={{
                    padding: '0.6rem 1.2rem',
                    background: 'linear-gradient(135deg, var(--accent-primary), var(--accent-hover))',
                    border: 'none',
                    borderRadius: '10px',
                    color: '#ffffff',
                    fontSize: '0.85rem',
                    fontWeight: 700,
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '0.45rem',
                    cursor: 'pointer',
                    boxShadow: '0 4px 14px rgba(99, 102, 241, 0.35)'
                  }}
                >
                  <ArrowRight size={15} />
                  Enter Live Workspace as Super Admin
                </button>
                <button
                  onClick={() => setReviewModalOpen(false)}
                  style={{
                    background: 'rgba(255,255,255,0.06)',
                    border: '1px solid var(--border-subtle)',
                    color: 'var(--text-secondary)',
                    borderRadius: '10px',
                    width: '36px',
                    height: '36px',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    cursor: 'pointer'
                  }}
                >
                  <X size={18} />
                </button>
              </div>
            </div>

            {/* Quick Metrics KPI Bar */}
            {orgDetailsData && (
              <div style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
                gap: '1rem',
                padding: '1rem 1.75rem',
                borderBottom: '1px solid var(--border-subtle)',
                background: 'rgba(0, 0, 0, 0.25)'
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.65rem' }}>
                  <div style={{ padding: '0.45rem', borderRadius: '8px', background: 'rgba(59, 130, 246, 0.15)', color: '#3b82f6' }}>
                    <PhoneCall size={18} />
                  </div>
                  <div>
                    <div style={{ fontSize: '1.25rem', fontWeight: 800 }}>{orgDetailsData.metrics.totalCalls}</div>
                    <div style={{ fontSize: '0.72rem', color: 'var(--text-secondary)' }}>Total Calls Logged</div>
                  </div>
                </div>

                <div style={{ display: 'flex', alignItems: 'center', gap: '0.65rem' }}>
                  <div style={{ padding: '0.45rem', borderRadius: '8px', background: 'rgba(16, 185, 129, 0.15)', color: 'var(--accent-emerald)' }}>
                    <CheckCircle2 size={18} />
                  </div>
                  <div>
                    <div style={{ fontSize: '1.25rem', fontWeight: 800 }}>{orgDetailsData.metrics.connectedCalls}</div>
                    <div style={{ fontSize: '0.72rem', color: 'var(--text-secondary)' }}>Connected Calls</div>
                  </div>
                </div>

                <div style={{ display: 'flex', alignItems: 'center', gap: '0.65rem' }}>
                  <div style={{ padding: '0.45rem', borderRadius: '8px', background: 'rgba(234, 179, 8, 0.15)', color: '#eab308' }}>
                    <Headphones size={18} />
                  </div>
                  <div>
                    <div style={{ fontSize: '1.25rem', fontWeight: 800 }}>{orgDetailsData.metrics.totalTalkTimeMinutes}m</div>
                    <div style={{ fontSize: '0.72rem', color: 'var(--text-secondary)' }}>Talk Time Minutes</div>
                  </div>
                </div>

                <div style={{ display: 'flex', alignItems: 'center', gap: '0.65rem' }}>
                  <div style={{ padding: '0.45rem', borderRadius: '8px', background: 'rgba(245, 158, 11, 0.15)', color: 'var(--accent-amber)' }}>
                    <TrendingUp size={18} />
                  </div>
                  <div>
                    <div style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--accent-amber)' }}>
                      ₹{orgDetailsData.metrics.totalPipelineValue.toLocaleString('en-IN')}
                    </div>
                    <div style={{ fontSize: '0.72rem', color: 'var(--text-secondary)' }}>Pipeline Deal Value</div>
                  </div>
                </div>

                <div style={{ display: 'flex', alignItems: 'center', gap: '0.65rem' }}>
                  <div style={{ padding: '0.45rem', borderRadius: '8px', background: 'rgba(168, 85, 247, 0.15)', color: '#c084fc' }}>
                    <Smartphone size={18} />
                  </div>
                  <div>
                    <div style={{ fontSize: '1.25rem', fontWeight: 800 }}>{orgDetailsData.reps.length} Reps</div>
                    <div style={{ fontSize: '0.72rem', color: 'var(--text-secondary)' }}>Knox Field Fleet</div>
                  </div>
                </div>

                <div style={{ display: 'flex', alignItems: 'center', gap: '0.65rem' }}>
                  <div style={{ padding: '0.45rem', borderRadius: '8px', background: 'rgba(99, 102, 241, 0.15)', color: 'var(--accent-primary)' }}>
                    <Users size={18} />
                  </div>
                  <div>
                    <div style={{ fontSize: '1.25rem', fontWeight: 800 }}>{orgDetailsData.users.length} Users</div>
                    <div style={{ fontSize: '0.72rem', color: 'var(--text-secondary)' }}>Customer Admins/Staff</div>
                  </div>
                </div>
              </div>
            )}

            {/* Navigation Tabs */}
            <div style={{
              display: 'flex',
              gap: '0.5rem',
              padding: '0.75rem 1.75rem',
              borderBottom: '1px solid var(--border-subtle)',
              background: 'rgba(255, 255, 255, 0.02)',
              overflowX: 'auto'
            }}>
              <button
                onClick={() => setReviewTab('calls')}
                style={{
                  padding: '0.55rem 1rem',
                  borderRadius: '8px',
                  border: reviewTab === 'calls' ? '1px solid var(--accent-primary)' : '1px solid transparent',
                  background: reviewTab === 'calls' ? 'rgba(99, 102, 241, 0.15)' : 'none',
                  color: reviewTab === 'calls' ? 'var(--accent-primary)' : 'var(--text-secondary)',
                  fontSize: '0.85rem',
                  fontWeight: 700,
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '0.45rem',
                  cursor: 'pointer'
                }}
              >
                <PhoneCall size={15} />
                Sovereign Calls & AI Transcripts ({orgDetailsData?.calls.length ?? 0})
              </button>

              <button
                onClick={() => setReviewTab('reps')}
                style={{
                  padding: '0.55rem 1rem',
                  borderRadius: '8px',
                  border: reviewTab === 'reps' ? '1px solid var(--accent-primary)' : '1px solid transparent',
                  background: reviewTab === 'reps' ? 'rgba(99, 102, 241, 0.15)' : 'none',
                  color: reviewTab === 'reps' ? 'var(--accent-primary)' : 'var(--text-secondary)',
                  fontSize: '0.85rem',
                  fontWeight: 700,
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '0.45rem',
                  cursor: 'pointer'
                }}
              >
                <Smartphone size={15} />
                Field Reps & Knox Telemetry ({orgDetailsData?.reps.length ?? 0})
              </button>

              <button
                onClick={() => setReviewTab('users')}
                style={{
                  padding: '0.55rem 1rem',
                  borderRadius: '8px',
                  border: reviewTab === 'users' ? '1px solid var(--accent-primary)' : '1px solid transparent',
                  background: reviewTab === 'users' ? 'rgba(99, 102, 241, 0.15)' : 'none',
                  color: reviewTab === 'users' ? 'var(--accent-primary)' : 'var(--text-secondary)',
                  fontSize: '0.85rem',
                  fontWeight: 700,
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '0.45rem',
                  cursor: 'pointer'
                }}
              >
                <Users size={15} />
                Admins & Users ({orgDetailsData?.users.length ?? 0})
              </button>

              <button
                onClick={() => setReviewTab('security')}
                style={{
                  padding: '0.55rem 1rem',
                  borderRadius: '8px',
                  border: reviewTab === 'security' ? '1px solid var(--accent-primary)' : '1px solid transparent',
                  background: reviewTab === 'security' ? 'rgba(99, 102, 241, 0.15)' : 'none',
                  color: reviewTab === 'security' ? 'var(--accent-primary)' : 'var(--text-secondary)',
                  fontSize: '0.85rem',
                  fontWeight: 700,
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '0.45rem',
                  cursor: 'pointer'
                }}
              >
                <ShieldCheck size={15} />
                Security & KMS Partitioning
              </button>
            </div>

            {/* Modal Body / Tab Content */}
            <div style={{ flex: 1, overflowY: 'auto', padding: '1.5rem 1.75rem' }}>
              {orgDetailsLoading ? (
                <div style={{ padding: '4rem 2rem', textAlign: 'center', color: 'var(--text-secondary)' }}>
                  <RefreshCw size={32} className="spin" style={{ margin: '0 auto 1rem', color: '#eab308' }} />
                  <div style={{ fontSize: '1.1rem', fontWeight: 700, color: 'var(--text-primary)' }}>
                    Auditing Sovereign Database Records...
                  </div>
                  <div style={{ fontSize: '0.85rem', marginTop: '0.35rem' }}>
                    Decrypting E2EE audio pointers, sales rep Knox telemetry, and MySQL relations.
                  </div>
                </div>
              ) : !orgDetailsData ? (
                <div style={{ padding: '3rem 1.5rem', textAlign: 'center', color: 'var(--text-secondary)' }}>
                  No data could be retrieved for this organization.
                </div>
              ) : (
                <>
                  {/* TAB 1: CALLS & TRANSCRIPTS */}
                  {reviewTab === 'calls' && (
                    <div>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem', flexWrap: 'wrap', gap: '0.75rem' }}>
                        <div style={{ fontSize: '0.9rem', color: 'var(--text-secondary)' }}>
                          Showing <strong>{orgDetailsData.calls.length}</strong> recorded calls for <strong>{selectedOrgForReview.name}</strong>.
                        </div>

                        <div style={{ position: 'relative', width: '260px' }}>
                          <Search size={14} style={{ position: 'absolute', left: '10px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-tertiary)' }} />
                          <input
                            type="text"
                            placeholder="Filter by contact, rep, deal..."
                            value={callSearchTerm}
                            onChange={e => setCallSearchTerm(e.target.value)}
                            style={{
                              width: '100%',
                              padding: '0.45rem 0.75rem 0.45rem 2rem',
                              background: 'rgba(255, 255, 255, 0.05)',
                              border: '1px solid var(--border-subtle)',
                              borderRadius: '7px',
                              color: 'var(--text-primary)',
                              fontSize: '0.8rem'
                            }}
                          />
                        </div>
                      </div>

                      {orgDetailsData.calls.length === 0 ? (
                        <div style={{ padding: '3rem 1rem', textAlign: 'center', border: '1px dashed var(--border-subtle)', borderRadius: '12px' }}>
                          <PhoneCall size={28} style={{ color: 'var(--text-tertiary)', marginBottom: '0.5rem' }} />
                          <div style={{ fontWeight: 600, color: 'var(--text-secondary)' }}>No call logs found for this organization.</div>
                          <div style={{ fontSize: '0.8rem', color: 'var(--text-tertiary)', marginTop: '0.25rem' }}>
                            When sales reps make or receive calls with the RingVia360 mobile app, records will appear here in real-time.
                          </div>
                        </div>
                      ) : (
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '0.85rem' }}>
                          {orgDetailsData.calls
                            .filter(c => {
                              const q = callSearchTerm.toLowerCase();
                              return (
                                (c.contact_name || '').toLowerCase().includes(q) ||
                                (c.phone_number || '').includes(q) ||
                                (c.rep_name || '').toLowerCase().includes(q) ||
                                (c.outcome || '').toLowerCase().includes(q) ||
                                (c.deal_stage || '').toLowerCase().includes(q)
                              );
                            })
                            .map((call, idx) => {
                              const isExpanded = expandedCallId === call.id;
                              let transcriptArray: any[] = [];
                              if (call.transcript) {
                                if (Array.isArray(call.transcript)) transcriptArray = call.transcript;
                                else if (typeof call.transcript === 'string') {
                                  try { transcriptArray = JSON.parse(call.transcript); } catch (_) {}
                                }
                              }

                              const dealVal = Number(call.deal_value || 0);

                              return (
                                <div
                                  key={call.id || idx}
                                  style={{
                                    border: '1px solid var(--border-subtle)',
                                    borderRadius: '12px',
                                    padding: '1.1rem 1.25rem',
                                    background: 'rgba(255, 255, 255, 0.02)',
                                    display: 'flex',
                                    flexDirection: 'column',
                                    gap: '0.75rem'
                                  }}
                                >
                                  {/* Call Row Main Info */}
                                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '0.75rem' }}>
                                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.85rem' }}>
                                      <div style={{
                                        width: '38px',
                                        height: '38px',
                                        borderRadius: '10px',
                                        background: call.direction === 'inbound'
                                          ? 'rgba(16, 185, 129, 0.15)'
                                          : call.direction === 'missed'
                                            ? 'rgba(239, 68, 68, 0.15)'
                                            : 'rgba(59, 130, 246, 0.15)',
                                        color: call.direction === 'inbound'
                                          ? 'var(--accent-emerald)'
                                          : call.direction === 'missed'
                                            ? 'var(--accent-rose)'
                                            : '#3b82f6',
                                        display: 'flex',
                                        alignItems: 'center',
                                        justifyContent: 'center'
                                      }}>
                                        {call.direction === 'inbound' ? <PhoneIncoming size={18} /> : call.direction === 'missed' ? <PhoneMissed size={18} /> : <PhoneOutgoing size={18} />}
                                      </div>

                                      <div>
                                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', flexWrap: 'wrap' }}>
                                          <span style={{ fontWeight: 800, fontSize: '0.98rem', color: 'var(--text-main)' }}>
                                            {call.contact_name || 'Corporate Customer'}
                                          </span>
                                          <span style={{ fontSize: '0.8rem', color: 'var(--text-tertiary)', fontFamily: 'monospace' }}>
                                            {call.phone_number}
                                          </span>
                                          <span style={{
                                            padding: '0.15rem 0.5rem',
                                            borderRadius: '999px',
                                            fontSize: '0.7rem',
                                            fontWeight: 700,
                                            background: call.sentiment === 'positive' ? 'rgba(16, 185, 129, 0.15)' : 'rgba(234, 179, 8, 0.15)',
                                            color: call.sentiment === 'positive' ? 'var(--accent-emerald)' : '#eab308'
                                          }}>
                                            AI Sentiment {call.sentiment_score ?? 88}%
                                          </span>
                                        </div>

                                        <div style={{ fontSize: '0.78rem', color: 'var(--text-secondary)', marginTop: '0.2rem', display: 'flex', alignItems: 'center', gap: '0.75rem', flexWrap: 'wrap' }}>
                                          <span>Rep: <strong>{call.rep_name || 'Field Agent'}</strong></span>
                                          <span>•</span>
                                          <span>Duration: <strong>{call.duration}s</strong></span>
                                          <span>•</span>
                                          <span>{call.timestamp || 'Just now'}</span>
                                          {call.sim_slot && (
                                            <>
                                              <span>•</span>
                                              <span style={{ color: 'var(--accent-cyan)' }}>{call.sim_slot}</span>
                                            </>
                                          )}
                                        </div>
                                      </div>
                                    </div>

                                    {/* Deal & Actions */}
                                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', flexWrap: 'wrap' }}>
                                      {dealVal > 0 && (
                                        <div style={{ textAlign: 'right' }}>
                                          <div style={{ fontSize: '1rem', fontWeight: 800, color: 'var(--accent-amber)' }}>
                                            ₹{dealVal.toLocaleString('en-IN')}
                                          </div>
                                          <div style={{ fontSize: '0.7rem', color: 'var(--text-tertiary)' }}>
                                            {call.deal_stage || 'Proposal'}
                                          </div>
                                        </div>
                                      )}

                                      {/* Play Audio Button */}
                                      <button
                                        onClick={() => handlePlayCallAudio(call)}
                                        style={{
                                          padding: '0.45rem 0.9rem',
                                          background: 'linear-gradient(135deg, rgba(99, 102, 241, 0.2), rgba(168, 85, 247, 0.2))',
                                          border: '1px solid rgba(99, 102, 241, 0.4)',
                                          borderRadius: '8px',
                                          color: 'var(--accent-primary)',
                                          fontSize: '0.78rem',
                                          fontWeight: 700,
                                          display: 'inline-flex',
                                          alignItems: 'center',
                                          gap: '0.4rem',
                                          cursor: 'pointer'
                                        }}
                                        title="Play recording with dynamic audio player, waveform, and AI analysis"
                                      >
                                        <Play size={13} fill="currentColor" />
                                        Play Audio & Waveform
                                      </button>

                                      {/* Transcript Toggle Button */}
                                      {transcriptArray.length > 0 && (
                                        <button
                                          onClick={() => setExpandedCallId(isExpanded ? null : call.id)}
                                          style={{
                                            padding: '0.45rem 0.75rem',
                                            background: 'var(--bg-glass)',
                                            border: '1px solid var(--border-subtle)',
                                            borderRadius: '8px',
                                            color: 'var(--text-secondary)',
                                            fontSize: '0.78rem',
                                            fontWeight: 600,
                                            display: 'inline-flex',
                                            alignItems: 'center',
                                            gap: '0.35rem',
                                            cursor: 'pointer'
                                          }}
                                        >
                                          <FileText size={13} />
                                          {isExpanded ? 'Hide Transcript' : 'AI Transcript'}
                                        </button>
                                      )}
                                    </div>
                                  </div>

                                  {/* Call Notes & Outcome */}
                                  {call.notes && (
                                    <div style={{
                                      fontSize: '0.82rem',
                                      color: 'var(--text-secondary)',
                                      background: 'rgba(0,0,0,0.2)',
                                      padding: '0.5rem 0.75rem',
                                      borderRadius: '6px',
                                      borderLeft: '3px solid var(--accent-primary)'
                                    }}>
                                      <strong style={{ color: 'var(--text-main)' }}>Summary:</strong> {call.notes}
                                    </div>
                                  )}

                                  {/* Expanded AI Whisper Transcript Section */}
                                  {isExpanded && transcriptArray.length > 0 && (
                                    <div style={{
                                      marginTop: '0.35rem',
                                      background: 'rgba(0,0,0,0.4)',
                                      border: '1px solid var(--border-subtle)',
                                      borderRadius: '8px',
                                      padding: '0.85rem'
                                    }}>
                                      <div style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--accent-cyan)', marginBottom: '0.5rem', display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
                                        <Sparkles size={13} /> WHISPER AI TRANSCRIPTION TURNS
                                      </div>
                                      <div style={{ display: 'flex', flexDirection: 'column', gap: '0.45rem' }}>
                                        {transcriptArray.map((turn, tIdx) => (
                                          <div key={tIdx} style={{ fontSize: '0.8rem', display: 'flex', gap: '0.65rem' }}>
                                            <span style={{ color: 'var(--accent-primary)', fontWeight: 700, minWidth: '120px' }}>
                                              {turn.speaker} [{turn.timestamp || '00:00'}]:
                                            </span>
                                            <span style={{ color: 'var(--text-primary)', flex: 1 }}>{turn.text}</span>
                                          </div>
                                        ))}
                                      </div>
                                    </div>
                                  )}
                                </div>
                              );
                            })}
                        </div>
                      )}
                    </div>
                  )}

                  {/* TAB 2: REPS & KNOX TELEMETRY */}
                  {reviewTab === 'reps' && (
                    <div>
                      <div style={{ marginBottom: '1.25rem', fontSize: '0.9rem', color: 'var(--text-secondary)' }}>
                        Knox MDM Attestation & Mobile Fleet for <strong>{selectedOrgForReview.name}</strong>.
                      </div>

                      {orgDetailsData.reps.length === 0 ? (
                        <div style={{ padding: '3rem 1rem', textAlign: 'center', border: '1px dashed var(--border-subtle)', borderRadius: '12px' }}>
                          <Smartphone size={28} style={{ color: 'var(--text-tertiary)', marginBottom: '0.5rem' }} />
                          <div style={{ fontWeight: 600, color: 'var(--text-secondary)' }}>No sales reps enrolled under this tenant yet.</div>
                          <div style={{ fontSize: '0.8rem', color: 'var(--text-tertiary)', marginTop: '0.25rem' }}>
                            Admins can onboard reps and bind Knox MDM devices via the Admin console.
                          </div>
                        </div>
                      ) : (
                        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '1rem' }}>
                          {orgDetailsData.reps.map(rep => {
                            const battery = Number(rep.battery_level ?? 90);
                            const isOnline = Boolean(rep.is_online);

                            return (
                              <div
                                key={rep.id}
                                style={{
                                  border: '1px solid var(--border-subtle)',
                                  borderRadius: '12px',
                                  padding: '1.25rem',
                                  background: 'rgba(255, 255, 255, 0.02)',
                                  display: 'flex',
                                  flexDirection: 'column',
                                  gap: '0.75rem'
                                }}
                              >
                                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                                  <img
                                    src={rep.avatar || 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120&auto=format&fit=crop&q=80'}
                                    alt={rep.name}
                                    style={{ width: '42px', height: '42px', borderRadius: '10px', objectFit: 'cover' }}
                                  />
                                  <div style={{ flex: 1 }}>
                                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                                      <span style={{ fontWeight: 700, fontSize: '0.95rem', color: 'var(--text-main)' }}>
                                        {rep.name}
                                      </span>
                                      <span style={{
                                        width: '8px',
                                        height: '8px',
                                        borderRadius: '50%',
                                        background: isOnline ? 'var(--accent-emerald)' : 'var(--text-dim)'
                                      }} />
                                    </div>
                                    <div style={{ fontSize: '0.78rem', color: 'var(--text-tertiary)' }}>{rep.role || 'Sales Rep'}</div>
                                  </div>
                                </div>

                                <div style={{ fontSize: '0.8rem', color: 'var(--text-secondary)', display: 'flex', flexDirection: 'column', gap: '0.35rem' }}>
                                  <div>Phone: <strong>{rep.phone || '+91 98200 12345'}</strong></div>
                                  <div>Device: <strong>{rep.device_model || 'Samsung Knox v3.9'}</strong></div>
                                  <div>OS: <span style={{ color: 'var(--accent-cyan)' }}>{rep.os_version || 'Android 14 (Attested)'}</span></div>
                                </div>

                                <div style={{
                                  display: 'flex',
                                  alignItems: 'center',
                                  justifyContent: 'space-between',
                                  padding: '0.5rem 0.75rem',
                                  borderRadius: '8px',
                                  background: 'rgba(0,0,0,0.25)',
                                  fontSize: '0.78rem'
                                }}>
                                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
                                    <Battery size={14} style={{ color: battery > 30 ? 'var(--accent-emerald)' : 'var(--accent-rose)' }} />
                                    <span>Battery: <strong>{battery}%</strong></span>
                                  </div>
                                  <div>
                                    Today's Calls: <strong style={{ color: 'var(--text-main)' }}>{rep.calls_today ?? 0}</strong>
                                  </div>
                                </div>
                              </div>
                            );
                          })}
                        </div>
                      )}
                    </div>
                  )}

                  {/* TAB 3: ADMINS & USERS */}
                  {reviewTab === 'users' && (
                    <div>
                      <div style={{ marginBottom: '1.25rem', fontSize: '0.9rem', color: 'var(--text-secondary)' }}>
                        Registered customer administrative accounts and personnel for <strong>{selectedOrgForReview.name}</strong>.
                      </div>

                      {orgDetailsData.users.length === 0 ? (
                        <div style={{ padding: '3rem 1rem', textAlign: 'center', border: '1px dashed var(--border-subtle)', borderRadius: '12px' }}>
                          <Users size={28} style={{ color: 'var(--text-tertiary)', marginBottom: '0.5rem' }} />
                          <div style={{ fontWeight: 600, color: 'var(--text-secondary)' }}>No separate user records found.</div>
                        </div>
                      ) : (
                        <div style={{ overflowX: 'auto' }}>
                          <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '0.85rem' }}>
                            <thead>
                              <tr style={{ background: 'rgba(255, 255, 255, 0.03)', borderBottom: '1px solid var(--border-subtle)', color: 'var(--text-secondary)' }}>
                                <th style={{ padding: '0.75rem 1rem' }}>User / Admin</th>
                                <th style={{ padding: '0.75rem 1rem' }}>Corporate Email</th>
                                <th style={{ padding: '0.75rem 1rem' }}>System Role</th>
                                <th style={{ padding: '0.75rem 1rem' }}>Phone</th>
                                <th style={{ padding: '0.75rem 1rem' }}>Account Status</th>
                                <th style={{ padding: '0.75rem 1rem' }}>Created At</th>
                              </tr>
                            </thead>
                            <tbody>
                              {orgDetailsData.users.map(u => (
                                <tr key={u.id} style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                                  <td style={{ padding: '0.85rem 1rem', fontWeight: 700, color: 'var(--text-main)' }}>
                                    {u.name}
                                  </td>
                                  <td style={{ padding: '0.85rem 1rem', color: 'var(--accent-primary)', fontFamily: 'monospace' }}>
                                    {u.email}
                                  </td>
                                  <td style={{ padding: '0.85rem 1rem' }}>
                                    <span style={{
                                      padding: '0.2rem 0.5rem',
                                      borderRadius: '4px',
                                      background: u.role === 'org_admin' ? 'rgba(234, 179, 8, 0.15)' : 'rgba(99, 102, 241, 0.15)',
                                      color: u.role === 'org_admin' ? '#eab308' : 'var(--accent-primary)',
                                      fontSize: '0.75rem',
                                      fontWeight: 700
                                    }}>
                                      {u.role}
                                    </span>
                                  </td>
                                  <td style={{ padding: '0.85rem 1rem', color: 'var(--text-secondary)' }}>
                                    {u.phone || '—'}
                                  </td>
                                  <td style={{ padding: '0.85rem 1rem' }}>
                                    <span style={{ color: 'var(--accent-emerald)', fontWeight: 600 }}>
                                      {u.status || 'Active'}
                                    </span>
                                  </td>
                                  <td style={{ padding: '0.85rem 1rem', color: 'var(--text-tertiary)', fontSize: '0.78rem' }}>
                                    {u.created_at || '—'}
                                  </td>
                                </tr>
                              ))}
                            </tbody>
                          </table>
                        </div>
                      )}
                    </div>
                  )}

                  {/* TAB 4: SECURITY & KMS PARTITIONING */}
                  {reviewTab === 'security' && (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
                      <div className="glass-panel" style={{ padding: '1.25rem', borderRadius: '12px', border: '1px solid rgba(16, 185, 129, 0.3)' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.65rem', marginBottom: '0.5rem' }}>
                          <ShieldCheck size={20} color="var(--accent-emerald)" />
                          <h4 style={{ fontSize: '1.05rem', fontWeight: 800, margin: 0, color: 'var(--text-main)' }}>
                            Sovereign Data Partitioning & Isolation
                          </h4>
                        </div>
                        <p style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', lineHeight: 1.6, margin: 0 }}>
                          This tenant operates under strict multi-tenant isolation. All queries execute with mandatory <code style={{ color: 'var(--accent-cyan)' }}>WHERE org_id = '{selectedOrgForReview.id}'</code> schema partitions. Cross-tenant leakage is cryptographically prevented.
                        </p>
                      </div>

                      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))', gap: '1rem' }}>
                        <div style={{ padding: '1rem', borderRadius: '10px', background: 'rgba(255,255,255,0.03)', border: '1px solid var(--border-subtle)' }}>
                          <div style={{ fontSize: '0.8rem', color: 'var(--text-tertiary)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>KMS Key Alias</div>
                          <div style={{ fontSize: '0.95rem', fontWeight: 700, color: 'var(--accent-cyan)', marginTop: '0.3rem', fontFamily: 'monospace' }}>
                            arn:aws:kms:ringvia:org-{selectedOrgForReview.slug || 'corp'}
                          </div>
                        </div>

                        <div style={{ padding: '1rem', borderRadius: '10px', background: 'rgba(255,255,255,0.03)', border: '1px solid var(--border-subtle)' }}>
                          <div style={{ fontSize: '0.8rem', color: 'var(--text-tertiary)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Audio Vault Encryption</div>
                          <div style={{ fontSize: '0.95rem', fontWeight: 700, color: 'var(--accent-emerald)', marginTop: '0.3rem' }}>
                            AES-256 E2EE (Customer Kept Keys)
                          </div>
                        </div>

                        <div style={{ padding: '1rem', borderRadius: '10px', background: 'rgba(255,255,255,0.03)', border: '1px solid var(--border-subtle)' }}>
                          <div style={{ fontSize: '0.8rem', color: 'var(--text-tertiary)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>MDM Hardware Attestation</div>
                          <div style={{ fontSize: '0.95rem', fontWeight: 700, color: '#eab308', marginTop: '0.3rem' }}>
                            Samsung Knox 3.9 Enforced
                          </div>
                        </div>
                      </div>
                    </div>
                  )}
                </>
              )}
            </div>

            {/* Modal Footer */}
            <div style={{
              padding: '1rem 1.75rem',
              borderTop: '1px solid var(--border-subtle)',
              background: 'rgba(0, 0, 0, 0.4)',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              flexWrap: 'wrap',
              gap: '0.75rem'
            }}>
              <div style={{ fontSize: '0.8rem', color: 'var(--text-secondary)' }}>
                Authenticated as Super Admin • Inspected Tenant: <code style={{ color: '#eab308' }}>{selectedOrgForReview.id}</code>
              </div>

              <div style={{ display: 'flex', gap: '0.75rem' }}>
                <button
                  type="button"
                  onClick={() => setReviewModalOpen(false)}
                  style={{
                    padding: '0.55rem 1.1rem',
                    background: 'none',
                    border: '1px solid var(--border-subtle)',
                    borderRadius: '8px',
                    color: 'var(--text-secondary)',
                    cursor: 'pointer',
                    fontSize: '0.85rem'
                  }}
                >
                  Close Audit Review
                </button>

                <button
                  type="button"
                  onClick={() => handleEnterWorkspace(selectedOrgForReview.id)}
                  style={{
                    padding: '0.55rem 1.25rem',
                    background: 'linear-gradient(135deg, var(--accent-primary), var(--accent-hover))',
                    border: 'none',
                    borderRadius: '8px',
                    color: '#ffffff',
                    fontWeight: 700,
                    cursor: 'pointer',
                    fontSize: '0.85rem',
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '0.45rem'
                  }}
                >
                  <ArrowRight size={15} />
                  Enter Live Workspace
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Onboard New Tenant Modal */}
      {createModalOpen && (
        <div style={{
          position: 'fixed',
          inset: 0,
          background: 'rgba(0, 0, 0, 0.75)',
          backdropFilter: 'blur(8px)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 9999,
          padding: '1rem'
        }}>
          <div className="glass-panel" style={{
            width: '100%',
            maxWidth: '520px',
            borderRadius: '18px',
            padding: '2rem',
            border: '1px solid var(--border-subtle)',
            background: 'var(--bg-elevated)',
            boxShadow: '0 20px 40px rgba(0,0,0,0.5)'
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
                <span style={{ padding: '0.4rem', borderRadius: '8px', background: 'rgba(99, 102, 241, 0.15)', color: 'var(--accent-primary)' }}>
                  <Building size={20} />
                </span>
                <h3 style={{ fontSize: '1.25rem', fontWeight: 800, margin: 0 }}>Onboard New Customer Tenant</h3>
              </div>
              <button
                onClick={() => setCreateModalOpen(false)}
                style={{ background: 'none', border: 'none', color: 'var(--text-tertiary)', cursor: 'pointer', fontSize: '1.2rem' }}
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleCreateTenant}>
              <div style={{ marginBottom: '1rem' }}>
                <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, color: 'var(--text-secondary)', marginBottom: '0.35rem' }}>
                  Company / Organization Name
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Mahindra & Mahindra Ltd"
                  value={newCompanyName}
                  onChange={e => setNewCompanyName(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '0.65rem 0.85rem',
                    background: 'rgba(255, 255, 255, 0.05)',
                    border: '1px solid var(--border-subtle)',
                    borderRadius: '8px',
                    color: 'var(--text-primary)',
                    fontSize: '0.85rem'
                  }}
                />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.85rem', marginBottom: '1rem' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, color: 'var(--text-secondary)', marginBottom: '0.35rem' }}>
                    Customer Admin Name
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Suresh Menon"
                    value={newAdminName}
                    onChange={e => setNewAdminName(e.target.value)}
                    style={{
                      width: '100%',
                      padding: '0.65rem 0.85rem',
                      background: 'rgba(255, 255, 255, 0.05)',
                      border: '1px solid var(--border-subtle)',
                      borderRadius: '8px',
                      color: 'var(--text-primary)',
                      fontSize: '0.85rem'
                    }}
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, color: 'var(--text-secondary)', marginBottom: '0.35rem' }}>
                    Admin Corporate Email
                  </label>
                  <input
                    type="email"
                    required
                    placeholder="suresh@mahindra.com"
                    value={newAdminEmail}
                    onChange={e => setNewAdminEmail(e.target.value)}
                    style={{
                      width: '100%',
                      padding: '0.65rem 0.85rem',
                      background: 'rgba(255, 255, 255, 0.05)',
                      border: '1px solid var(--border-subtle)',
                      borderRadius: '8px',
                      color: 'var(--text-primary)',
                      fontSize: '0.85rem'
                    }}
                  />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.85rem', marginBottom: '1rem' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, color: 'var(--text-secondary)', marginBottom: '0.35rem' }}>
                    Default Password
                  </label>
                  <input
                    type="password"
                    required
                    value={newPassword}
                    onChange={e => setNewPassword(e.target.value)}
                    style={{
                      width: '100%',
                      padding: '0.65rem 0.85rem',
                      background: 'rgba(255, 255, 255, 0.05)',
                      border: '1px solid var(--border-subtle)',
                      borderRadius: '8px',
                      color: 'var(--text-primary)',
                      fontSize: '0.85rem'
                    }}
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, color: 'var(--text-secondary)', marginBottom: '0.35rem' }}>
                    Corporate Plan
                  </label>
                  <select
                    value={newPlan}
                    onChange={e => setNewPlan(e.target.value)}
                    style={{
                      width: '100%',
                      padding: '0.65rem 0.85rem',
                      background: 'var(--bg-elevated)',
                      border: '1px solid var(--border-subtle)',
                      borderRadius: '8px',
                      color: 'var(--text-primary)',
                      fontSize: '0.85rem'
                    }}
                  >
                    <option value="Starter">Starter (₹4,999/mo - 10 seats)</option>
                    <option value="Pro Growth">Pro Growth (₹14,999/mo - 50 seats)</option>
                    <option value="Enterprise Plus">Enterprise Plus (₹45,000/mo - 120 seats)</option>
                    <option value="Enterprise Banking">Enterprise Banking (₹85,000/mo - 200 seats)</option>
                  </select>
                </div>
              </div>

              <div style={{
                background: 'rgba(99, 102, 241, 0.08)',
                border: '1px solid rgba(99, 102, 241, 0.2)',
                borderRadius: '10px',
                padding: '0.85rem',
                fontSize: '0.8rem',
                color: 'var(--text-secondary)',
                marginBottom: '1.25rem',
                display: 'flex',
                alignItems: 'center',
                gap: '0.5rem'
              }}>
                <ShieldCheck size={16} color="var(--accent-primary)" />
                Auto-generates dedicated organization schema, tenant secret keys, and Knox MDM bindings.
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.75rem' }}>
                <button
                  type="button"
                  onClick={() => setCreateModalOpen(false)}
                  style={{
                    padding: '0.6rem 1rem',
                    background: 'none',
                    border: '1px solid var(--border-subtle)',
                    borderRadius: '8px',
                    color: 'var(--text-secondary)',
                    cursor: 'pointer'
                  }}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting}
                  style={{
                    padding: '0.6rem 1.25rem',
                    background: 'linear-gradient(135deg, var(--accent-primary), var(--accent-hover))',
                    border: 'none',
                    borderRadius: '8px',
                    color: '#ffffff',
                    fontWeight: 700,
                    cursor: 'pointer'
                  }}
                >
                  {isSubmitting ? 'Provisioning Tenant...' : 'Provision Tenant Account'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* GLOBAL CONTENT MANAGEMENT — Super Admin Only */}
      <div style={{ marginTop: '0.5rem' }}>
        <div style={{ marginBottom: '1rem' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.25rem' }}>
            <Database size={18} color="var(--primary)" />
            <h2 style={{ fontSize: '1.4rem', fontWeight: 800, margin: 0, color: 'var(--text-main)' }}>
              Global Site Content Management
            </h2>
          </div>
          <p style={{ fontSize: '0.82rem', color: 'var(--text-dim)' }}>
            Super admin controls — edit, add, or reset all page content stored in the <code style={{ color: 'var(--accent-cyan)' }}>site_pages</code> MySQL table. Changes apply globally across all pages.
          </p>
        </div>
        <div className="glass-panel" style={{ padding: '1.25rem' }}>
          <ContentEditorPanel />
        </div>
      </div>
    </div>
  );
}
