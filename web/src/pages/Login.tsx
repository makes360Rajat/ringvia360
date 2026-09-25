import React, { useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import {
  ShieldCheck,
  Lock,
  Mail,
  Building,
  User,
  Phone,
  ArrowRight,
  CheckCircle2,
  Sparkles,
  KeyRound,
  Crown,
  Briefcase,
  AlertCircle,
  UserPlus
} from 'lucide-react';
import { useApp } from '../context/AppContext';

export default function Login() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const { login, signup, toastMessage, getPageSection } = useApp();

  const [mode, setMode] = useState<'login' | 'signup'>(
    searchParams.get('mode') === 'signup' ? 'signup' : 'login'
  );

  // Login form state
  const [loginEmail, setLoginEmail] = useState('');
  const [loginPassword, setLoginPassword] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Signup form state
  const [signupRole, setSignupRole] = useState<'org_admin' | 'super_admin'>('org_admin');
  const [companyName, setCompanyName] = useState('');
  const [adminName, setAdminName] = useState('');
  const [signupEmail, setSignupEmail] = useState('');
  const [signupPassword, setSignupPassword] = useState('');
  const [signupPhone, setSignupPhone] = useState('+91 98200 12345');
  const [selectedPlan, setSelectedPlan] = useState('Pro Growth');

  const handleLoginSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMessage(null);
    setIsSubmitting(true);
    try {
      const success = await login(loginEmail, loginPassword);
      if (success) {
        const storedUser = localStorage.getItem('ringvia360_user');
        const role = storedUser ? JSON.parse(storedUser)?.role : null;
        if (role === 'super_admin') {
          navigate('/super-admin');
        } else {
          navigate('/admin');
        }
      } else {
        setErrorMessage('Invalid email or password. Please verify credentials or use a demo account.');
      }
    } catch (err: any) {
      setErrorMessage(err.message || 'Authentication failed. Please try again.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleSignupSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMessage(null);
    setIsSubmitting(true);
    try {
      const success = await signup({
        companyName: signupRole === 'super_admin' ? 'RingVia360 Platform' : companyName,
        name: adminName,
        email: signupEmail,
        password: signupPassword,
        phone: signupPhone,
        plan: signupRole === 'super_admin' ? 'enterprise' : selectedPlan,
        role: signupRole
      });
      if (success) {
        if (signupRole === 'super_admin') {
          navigate('/super-admin');
        } else {
          navigate('/admin');
        }
      } else {
        setErrorMessage('Signup failed. An account with this email may already exist.');
      }
    } catch (err: any) {
      setErrorMessage(err.message || 'Registration failed.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const selectDemoAccount = (email: string, pass: string = 'Password123!') => {
    setLoginEmail(email);
    setLoginPassword(pass);
    setErrorMessage(null);
  };

  return (
    <div style={{
      minHeight: 'calc(100vh - 120px)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      padding: '2rem 1.5rem 4rem',
      position: 'relative'
    }}>
      {/* Background radial glows */}
      <div style={{
        position: 'absolute',
        top: '15%',
        left: '50%',
        transform: 'translateX(-50%)',
        width: '600px',
        height: '400px',
        background: 'radial-gradient(circle, rgba(99, 102, 241, 0.15) 0%, rgba(6, 182, 212, 0.05) 50%, transparent 70%)',
        pointerEvents: 'none',
        zIndex: 0
      }} />

      <div style={{ maxWidth: '1040px', width: '100%', position: 'relative', zIndex: 1, display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(340px, 1fr))', gap: '2rem', alignItems: 'stretch' }}>
        
        {/* Left Column: Product Value & Demo Credentials */}
        <div className="glass-card" style={{ padding: '2.5rem', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem', marginBottom: '1.25rem' }}>
              <div style={{
                width: '42px',
                height: '42px',
                borderRadius: '12px',
                background: 'linear-gradient(135deg, var(--primary) 0%, #38bdf8 100%)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                boxShadow: '0 4px 14px var(--primary-glow)',
                color: '#fff'
              }}>
                <ShieldCheck size={22} />
              </div>
              <div>
                <h2 style={{ fontSize: '1.35rem', fontWeight: 800, margin: 0, color: 'var(--text-main)' }}>
                  RingVia<span style={{ color: 'var(--primary)' }}>360</span> Enterprise
                </h2>
                <span style={{ fontSize: '0.75rem', color: 'var(--accent-emerald)', fontWeight: 600 }}>
                  Multi-Tenant Sovereign SaaS Platform
                </span>
              </div>
            </div>

            <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem', lineHeight: 1.5, marginBottom: '1.75rem' }}>
              {getPageSection('login', 'hero')?.subtitle}
            </p>

            <h4 style={{ fontSize: '0.85rem', textTransform: 'uppercase', letterSpacing: '0.5px', color: 'var(--text-dim)', marginBottom: '0.75rem' }}>
              Instant Demo Access (Click to Fill):
            </h4>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.6rem', marginBottom: '1.5rem' }}>
              {/* Super Admin Preset */}
              <button
                type="button"
                onClick={() => {
                  setMode('login');
                  selectDemoAccount('superadmin@ringvia360.com');
                }}
                className="glass-panel"
                style={{
                  padding: '0.75rem 1rem',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  cursor: 'pointer',
                  border: loginEmail === 'superadmin@ringvia360.com' ? '1px solid var(--accent-amber)' : '1px solid var(--border-subtle)',
                  background: loginEmail === 'superadmin@ringvia360.com' ? 'rgba(245, 158, 11, 0.1)' : 'var(--bg-glass)'
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', textAlign: 'left' }}>
                  <Crown size={18} color="#f59e0b" />
                  <div>
                    <div style={{ fontSize: '0.85rem', fontWeight: 700, color: '#f59e0b' }}>
                      👑 Super Admin (Full SaaS Fleet)
                    </div>
                    <div style={{ fontSize: '0.72rem', color: 'var(--text-dim)' }}>
                      superadmin@ringvia360.com • Manages all customers
                    </div>
                  </div>
                </div>
                <ArrowRight size={14} color="#f59e0b" />
              </button>

              {/* Organization Admin Preset */}
              <button
                type="button"
                onClick={() => {
                  setMode('login');
                  selectDemoAccount('admin@ringvia360.com');
                }}
                className="glass-panel"
                style={{
                  padding: '0.75rem 1rem',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  cursor: 'pointer',
                  border: loginEmail === 'admin@ringvia360.com' ? '1px solid var(--primary)' : '1px solid var(--border-subtle)',
                  background: loginEmail === 'admin@ringvia360.com' ? 'rgba(99, 102, 241, 0.12)' : 'var(--bg-glass)'
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', textAlign: 'left' }}>
                  <Building size={18} color="var(--primary)" />
                  <div>
                    <div style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-main)' }}>
                      🏢 Admin (Enterprise Workspace)
                    </div>
                    <div style={{ fontSize: '0.72rem', color: 'var(--text-dim)' }}>
                      admin@ringvia360.com • Enterprise workspace & team telemetry
                    </div>
                  </div>
                </div>
                <ArrowRight size={14} color="var(--primary)" />
              </button>
            </div>
          </div>

          <div style={{ borderTop: '1px solid var(--border-subtle)', paddingTop: '1.25rem', display: 'flex', justifyContent: 'space-between', fontSize: '0.78rem', color: 'var(--text-dim)' }}>
            <span>🔒 AES-256 KMS Vault</span>
            <span>🇮🇳 Hosted on Indian Data Centers</span>
            <span>⚡ Zero-Click Sync</span>
          </div>
        </div>

        {/* Right Column: Interactive Login / Signup Form */}
        <div className="glass-card" style={{ padding: '2.5rem', display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
          {/* Mode Switcher Tabs */}
          <div style={{
            display: 'flex',
            background: 'var(--bg-surface-elevated)',
            borderRadius: '12px',
            padding: '4px',
            marginBottom: '1.75rem',
            border: '1px solid var(--border-glass)'
          }}>
            <button
              type="button"
              onClick={() => { setMode('login'); setErrorMessage(null); }}
              style={{
                flex: 1,
                padding: '0.65rem',
                borderRadius: '8px',
                border: 'none',
                background: mode === 'login' ? 'var(--primary)' : 'transparent',
                color: mode === 'login' ? '#fff' : 'var(--text-dim)',
                fontWeight: 700,
                fontSize: '0.85rem',
                cursor: 'pointer',
                transition: 'all 0.2s ease'
              }}
            >
              Sign In to Your Account
            </button>
            <button
              type="button"
              onClick={() => { setMode('signup'); setErrorMessage(null); }}
              style={{
                flex: 1,
                padding: '0.65rem',
                borderRadius: '8px',
                border: 'none',
                background: mode === 'signup' ? 'var(--primary)' : 'transparent',
                color: mode === 'signup' ? '#fff' : 'var(--text-dim)',
                fontWeight: 700,
                fontSize: '0.85rem',
                cursor: 'pointer',
                transition: 'all 0.2s ease'
              }}
            >
              Sign Up (Admin / Super Admin)
            </button>
          </div>

          {errorMessage && (
            <div style={{
              padding: '0.75rem 1rem',
              borderRadius: '8px',
              background: 'rgba(239, 68, 68, 0.15)',
              border: '1px solid rgba(239, 68, 68, 0.3)',
              color: '#f87171',
              fontSize: '0.85rem',
              display: 'flex',
              alignItems: 'center',
              gap: '0.5rem',
              marginBottom: '1.25rem'
            }}>
              <AlertCircle size={16} />
              <span>{errorMessage}</span>
            </div>
          )}

          {mode === 'login' ? (
            <form onSubmit={handleLoginSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
              <div>
                <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, color: 'var(--text-main)', marginBottom: '0.4rem' }}>
                  Work Email Address
                </label>
                <div style={{ position: 'relative' }}>
                  <Mail size={16} style={{ position: 'absolute', left: '14px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-dim)' }} />
                  <input
                    type="email"
                    required
                    placeholder="name@company.com"
                    value={loginEmail}
                    onChange={e => setLoginEmail(e.target.value)}
                    style={{
                      width: '100%',
                      padding: '0.75rem 1rem 0.75rem 2.6rem',
                      borderRadius: '10px',
                      border: '1px solid var(--border-glass)',
                      background: 'var(--bg-surface-elevated)',
                      color: 'var(--text-main)',
                      fontSize: '0.9rem'
                    }}
                  />
                </div>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, color: 'var(--text-main)', marginBottom: '0.4rem' }}>
                  Password
                </label>
                <div style={{ position: 'relative' }}>
                  <Lock size={16} style={{ position: 'absolute', left: '14px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-dim)' }} />
                  <input
                    type="password"
                    required
                    placeholder="••••••••••••"
                    value={loginPassword}
                    onChange={e => setLoginPassword(e.target.value)}
                    style={{
                      width: '100%',
                      padding: '0.75rem 1rem 0.75rem 2.6rem',
                      borderRadius: '10px',
                      border: '1px solid var(--border-glass)',
                      background: 'var(--bg-surface-elevated)',
                      color: 'var(--text-main)',
                      fontSize: '0.9rem'
                    }}
                  />
                </div>
              </div>

              <button
                type="submit"
                disabled={isSubmitting}
                className="btn-primary"
                style={{
                  padding: '0.85rem',
                  fontSize: '0.95rem',
                  fontWeight: 700,
                  marginTop: '0.5rem',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '0.5rem'
                }}
              >
                <KeyRound size={18} />
                <span>{isSubmitting ? 'Authenticating...' : 'Sign In Securely'}</span>
              </button>
            </form>
          ) : (
            <form onSubmit={handleSignupSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
              {/* Account Type / Role Toggle */}
              <div>
                <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 600, color: 'var(--text-main)', marginBottom: '0.35rem' }}>
                  Select Account Role / Privilege Level
                </label>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.6rem' }}>
                  <button
                    type="button"
                    onClick={() => setSignupRole('org_admin')}
                    style={{
                      padding: '0.65rem 0.75rem',
                      borderRadius: '8px',
                      border: signupRole === 'org_admin' ? '1px solid var(--primary)' : '1px solid var(--border-glass)',
                      background: signupRole === 'org_admin' ? 'rgba(99, 102, 241, 0.15)' : 'var(--bg-surface-elevated)',
                      color: signupRole === 'org_admin' ? '#fff' : 'var(--text-dim)',
                      fontSize: '0.8rem',
                      fontWeight: 700,
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      gap: '0.4rem',
                      transition: 'all 0.2s ease'
                    }}
                  >
                    <Building size={15} color="var(--primary)" />
                    <span>Company Admin</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => setSignupRole('super_admin')}
                    style={{
                      padding: '0.65rem 0.75rem',
                      borderRadius: '8px',
                      border: signupRole === 'super_admin' ? '1px solid #f59e0b' : '1px solid var(--border-glass)',
                      background: signupRole === 'super_admin' ? 'rgba(245, 158, 11, 0.15)' : 'var(--bg-surface-elevated)',
                      color: signupRole === 'super_admin' ? '#f59e0b' : 'var(--text-dim)',
                      fontSize: '0.8rem',
                      fontWeight: 700,
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      gap: '0.4rem',
                      transition: 'all 0.2s ease'
                    }}
                  >
                    <Crown size={15} color="#f59e0b" />
                    <span>Super Admin</span>
                  </button>
                </div>
              </div>

              {signupRole === 'super_admin' ? (
                <div style={{
                  padding: '0.75rem 1rem',
                  borderRadius: '8px',
                  background: 'rgba(245, 158, 11, 0.1)',
                  border: '1px solid rgba(245, 158, 11, 0.3)',
                  color: '#f59e0b',
                  fontSize: '0.8rem',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '0.5rem'
                }}>
                  <Crown size={16} />
                  <span>Sovereign Platform Fleet — Grants oversight across all tenant organizations & license tiers.</span>
                </div>
              ) : (
                <div>
                  <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 600, color: 'var(--text-main)', marginBottom: '0.3rem' }}>
                    Company / Organization Name
                  </label>
                  <div style={{ position: 'relative' }}>
                    <Building size={16} style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-dim)' }} />
                    <input
                      type="text"
                      required
                      placeholder="e.g. Reliance Retail Digital"
                      value={companyName}
                      onChange={e => setCompanyName(e.target.value)}
                      style={{
                        width: '100%',
                        padding: '0.65rem 0.85rem 0.65rem 2.4rem',
                        borderRadius: '8px',
                        border: '1px solid var(--border-glass)',
                        background: 'var(--bg-surface-elevated)',
                        color: 'var(--text-main)',
                        fontSize: '0.85rem'
                      }}
                    />
                  </div>
                </div>
              )}

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 600, color: 'var(--text-main)', marginBottom: '0.3rem' }}>
                    {signupRole === 'super_admin' ? 'Super Admin Name' : 'Admin Name'}
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="Rajesh Kumar"
                    value={adminName}
                    onChange={e => setAdminName(e.target.value)}
                    style={{
                      width: '100%',
                      padding: '0.65rem 0.85rem',
                      borderRadius: '8px',
                      border: '1px solid var(--border-glass)',
                      background: 'var(--bg-surface-elevated)',
                      color: 'var(--text-main)',
                      fontSize: '0.85rem'
                    }}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 600, color: 'var(--text-main)', marginBottom: '0.3rem' }}>
                    Corporate Phone
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="+91 98200 11223"
                    value={signupPhone}
                    onChange={e => setSignupPhone(e.target.value)}
                    style={{
                      width: '100%',
                      padding: '0.65rem 0.85rem',
                      borderRadius: '8px',
                      border: '1px solid var(--border-glass)',
                      background: 'var(--bg-surface-elevated)',
                      color: 'var(--text-main)',
                      fontSize: '0.85rem'
                    }}
                  />
                </div>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 600, color: 'var(--text-main)', marginBottom: '0.3rem' }}>
                  {signupRole === 'super_admin' ? 'Super Admin Work Email' : 'Admin Work Email'}
                </label>
                <input
                  type="email"
                  required
                  placeholder={signupRole === 'super_admin' ? 'director@ringvia360.com' : 'admin@company.com'}
                  value={signupEmail}
                  onChange={e => setSignupEmail(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '0.65rem 0.85rem',
                    borderRadius: '8px',
                    border: '1px solid var(--border-glass)',
                    background: 'var(--bg-surface-elevated)',
                    color: 'var(--text-main)',
                    fontSize: '0.85rem'
                  }}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 600, color: 'var(--text-main)', marginBottom: '0.3rem' }}>
                  Choose Password
                </label>
                <input
                  type="password"
                  required
                  placeholder="••••••••••••"
                  value={signupPassword}
                  onChange={e => setSignupPassword(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '0.65rem 0.85rem',
                    borderRadius: '8px',
                    border: '1px solid var(--border-glass)',
                    background: 'var(--bg-surface-elevated)',
                    color: 'var(--text-main)',
                    fontSize: '0.85rem'
                  }}
                />
              </div>

              {signupRole === 'org_admin' && (
                <div>
                  <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 600, color: 'var(--text-main)', marginBottom: '0.3rem' }}>
                    Subscription Tier
                  </label>
                  <select
                    value={selectedPlan}
                    onChange={e => setSelectedPlan(e.target.value)}
                    style={{
                      width: '100%',
                      padding: '0.65rem 0.85rem',
                      borderRadius: '8px',
                      border: '1px solid var(--border-glass)',
                      background: 'var(--bg-surface-elevated)',
                      color: 'var(--text-main)',
                      fontSize: '0.85rem'
                    }}
                  >
                    <option value="Starter">Starter — 10 members • ₹4,999/mo</option>
                    <option value="Growth">Growth — 20 members • ₹8,999/mo</option>
                    <option value="Pro Growth">Pro Growth — 50 members • ₹14,999/mo (Recommended)</option>
                    <option value="Enterprise Plus">Enterprise Plus — 120 members • ₹45,000/mo</option>
                  </select>
                </div>
              )}

              <button
                type="submit"
                disabled={isSubmitting}
                className="btn-primary"
                style={{
                  padding: '0.85rem',
                  fontSize: '0.92rem',
                  fontWeight: 700,
                  marginTop: '0.5rem',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '0.5rem',
                  background: signupRole === 'super_admin' ? 'linear-gradient(135deg, #f59e0b 0%, #d97706 100%)' : undefined
                }}
              >
                {signupRole === 'super_admin' ? <Crown size={18} /> : <UserPlus size={18} />}
                <span>
                  {isSubmitting
                    ? 'Provisioning Account...'
                    : (signupRole === 'super_admin' ? 'Create Super Admin Account' : 'Deploy Isolated Company Tenant')}
                </span>
              </button>
            </form>
          )}
        </div>
      </div>
    </div>
  );
}
