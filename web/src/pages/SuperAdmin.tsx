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
  DollarSign
} from 'lucide-react';
import { useApp } from '../context/AppContext';
import type { TenantOrganization } from '../types';
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
    dbEngine
  } = useApp();

  const [isLoading, setIsLoading] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [createModalOpen, setCreateModalOpen] = useState(false);

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
      call_count: 142,
      user_count: 18
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
      call_count: 89,
      user_count: 12
    },
    {
      id: 'org-hdfc',
      name: 'HDFC Bank Commercial',
      slug: 'hdfc',
      plan: 'Enterprise Banking',
      seats: 200,
      monthly_price_inr: 85000,
      status: 'active',
      owner_email: 'vikram.malhotra@hdfcbank.com',
      call_count: 320,
      user_count: 45
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

  const totalMrr = tenants.reduce((acc, t) => acc + (t.monthly_price_inr || 14999), 0);
  const totalSeats = tenants.reduce((acc, t) => acc + (t.seats || 50), 0);
  const activeCount = tenants.filter(t => t.status === 'active').length;

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
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '0.5rem' }}>
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
              <Database size={13} /> {dbEngine.toUpperCase()} MULTI-TENANT ISOLATION
            </span>
          </div>
          <h1 style={{ fontSize: '2.1rem', fontWeight: 800, margin: 0, letterSpacing: '-0.02em' }}>
            Tenant & Customer Platform Management
          </h1>
          <p style={{ color: 'var(--text-secondary)', margin: '0.35rem 0 0', fontSize: '0.95rem' }}>
            Manage commercial client organizations, cross-tenant security partitions, licenses, and revenue metrics.
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
                ? '🌐 Global Super Admin Overview (Cross-Tenant Platform Aggregation)'
                : `🏢 Scoped to Tenant Workspace: ${tenants.find(t => t.id === activeTenantId)?.name || activeTenantId}`}
            </div>
          </div>
        </div>

        <div style={{ display: 'flex', gap: '0.75rem', alignItems: 'center' }}>
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
            onClick={() => navigate('/dashboard')}
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
            Open Analytics Dashboard <ExternalLink size={13} />
          </button>
        </div>
      </div>

      {/* Platform Metric KPI Cards */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))',
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
            <CheckCircle2 size={13} /> {activeCount} active customer accounts
          </div>
        </div>

        <div className="glass-panel" style={{ padding: '1.35rem 1.5rem', borderRadius: '14px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem' }}>
            <span style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', fontWeight: 600 }}>Total Platform MRR</span>
            <span style={{ padding: '0.35rem', borderRadius: '8px', background: 'rgba(16, 185, 129, 0.15)', color: 'var(--accent-emerald)' }}>
              <TrendingUp size={18} />
            </span>
          </div>
          <div style={{ fontSize: '2rem', fontWeight: 800 }}>₹{totalMrr.toLocaleString('en-IN')}</div>
          <div style={{ fontSize: '0.8rem', color: 'var(--text-tertiary)', marginTop: '0.35rem' }}>
            Recurring SaaS subscription run-rate
          </div>
        </div>

        <div className="glass-panel" style={{ padding: '1.35rem 1.5rem', borderRadius: '14px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem' }}>
            <span style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', fontWeight: 600 }}>Licensed Fleet Seats</span>
            <span style={{ padding: '0.35rem', borderRadius: '8px', background: 'rgba(234, 179, 8, 0.15)', color: '#eab308' }}>
              <Users size={18} />
            </span>
          </div>
          <div style={{ fontSize: '2rem', fontWeight: 800 }}>{totalSeats}</div>
          <div style={{ fontSize: '0.8rem', color: 'var(--text-tertiary)', marginTop: '0.35rem' }}>
            Provisioned sales rep mobile licenses
          </div>
        </div>

        <div className="glass-panel" style={{ padding: '1.35rem 1.5rem', borderRadius: '14px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem' }}>
            <span style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', fontWeight: 600 }}>Data Isolation Architecture</span>
            <span style={{ padding: '0.35rem', borderRadius: '8px', background: 'rgba(59, 130, 246, 0.15)', color: '#3b82f6' }}>
              <ShieldCheck size={18} />
            </span>
          </div>
          <div style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-primary)', marginTop: '0.25rem' }}>
            Zero Cross-Tenant Leakage
          </div>
          <div style={{ fontSize: '0.8rem', color: 'var(--text-secondary)', marginTop: '0.35rem' }}>
            E2EE AES-256 scoped by org_id partition
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
              Each account operates in strict data isolation. Click "Inspect Workspace" to navigate directly into that customer's portal.
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
                <th style={{ padding: '0.9rem 1.25rem', fontWeight: 600 }}>Fleet Seats</th>
                <th style={{ padding: '0.9rem 1.25rem', fontWeight: 600 }}>Customer Admin</th>
                <th style={{ padding: '0.9rem 1.25rem', fontWeight: 600 }}>Status</th>
                <th style={{ padding: '0.9rem 1.25rem', fontWeight: 600, textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredTenants.map(tenant => {
                const isSelected = activeTenantId === tenant.id;
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
                          width: '38px',
                          height: '38px',
                          borderRadius: '8px',
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
                          <div style={{ fontWeight: 700, color: 'var(--text-primary)' }}>{tenant.name}</div>
                          <div style={{ fontSize: '0.75rem', color: 'var(--text-tertiary)', fontFamily: 'monospace' }}>
                            ID: {tenant.id} • slug: ringvia360.com/{tenant.slug}
                          </div>
                        </div>
                      </div>
                    </td>

                    <td style={{ padding: '1rem 1.25rem' }}>
                      <div style={{ fontWeight: 600, color: 'var(--text-primary)' }}>{tenant.plan}</div>
                      <div style={{ fontSize: '0.78rem', color: 'var(--accent-emerald)', fontWeight: 600 }}>
                        ₹{(tenant.monthly_price_inr || 14999).toLocaleString('en-IN')} / mo
                      </div>
                    </td>

                    <td style={{ padding: '1rem 1.25rem' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', fontWeight: 600 }}>
                        <Users size={14} style={{ color: 'var(--accent-primary)' }} />
                        {tenant.seats} reps
                      </div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-tertiary)' }}>
                        Android Knox fleet
                      </div>
                    </td>

                    <td style={{ padding: '1rem 1.25rem' }}>
                      <div style={{ color: 'var(--text-primary)', fontWeight: 500 }}>{tenant.owner_email}</div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-tertiary)' }}>Primary Owner</div>
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
                        <button
                          onClick={async () => {
                            await switchTenant(tenant.id);
                            navigate('/admin');
                          }}
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
                          <Eye size={13} />
                          {isSelected ? 'Viewing Now' : 'Inspect Workspace'}
                        </button>

                        <button
                          onClick={() => {
                            const next = tenant.status === 'active' ? 'suspended' : 'active';
                            manageTenantStatus(tenant.id, next);
                          }}
                          style={{
                            padding: '0.45rem 0.75rem',
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
