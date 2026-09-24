import React from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import {
  PhoneCall,
  LayoutDashboard,
  Activity,
  Trophy,
  Share2,
  ShieldCheck,
  Smartphone,
  PhoneIncoming,
  Sun,
  Moon,
  Zap,
  Settings,
  Crown,
  Building,
  LogOut,
  LogIn,
  User
} from 'lucide-react';
import { useApp } from '../context/AppContext';

export const Navbar: React.FC = () => {
  const navigate = useNavigate();
  const {
    theme,
    setTheme,
    accent,
    setAccent,
    selectedRole,
    setSelectedRole,
    setIsSimulatorOpen,
    triggerIncomingCall,
    calls,
    currentUser,
    currentOrg,
    activeTenantId,
    logout,
    switchTenant
  } = useApp();

  const activeCallsCount = calls.filter(c => c.timestamp.includes('now') || c.timestamp.includes('min')).length;

  return (
    <header className="glass-panel" style={{
      position: 'sticky',
      top: '12px',
      zIndex: 50,
      margin: '12px 16px 20px',
      padding: '0.65rem 1.25rem',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      gap: '1rem',
      borderRadius: 'var(--radius-lg)'
    }}>
      {/* Brand Logo & Live Signal */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '0.85rem' }}>
        <div style={{
          width: '38px',
          height: '38px',
          borderRadius: '12px',
          background: 'linear-gradient(135deg, var(--primary) 0%, #38bdf8 100%)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          boxShadow: '0 4px 14px var(--primary-glow)',
          color: '#fff'
        }}>
          <PhoneCall size={20} strokeWidth={2.4} />
        </div>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
            <span style={{ fontWeight: 800, fontSize: '1.1rem', letterSpacing: '-0.4px', color: 'var(--text-main)' }}>
              RingVia<span style={{ color: 'var(--primary)' }}>360</span>
            </span>
            <span className="glass-pill" style={{
              fontSize: '0.65rem',
              padding: '0.15rem 0.5rem',
              color: 'var(--accent-emerald)',
              borderColor: 'rgba(16, 185, 129, 0.3)',
              background: 'rgba(16, 185, 129, 0.1)'
            }}>
              PRO
            </span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem', fontSize: '0.72rem', color: 'var(--text-dim)' }}>
            <span className="live-dot" />
            <span>Telemetry Active • E2EE</span>
          </div>
        </div>
      </div>

      {/* Nav Links */}
      <nav style={{ display: 'flex', alignItems: 'center', gap: '0.35rem', flexWrap: 'wrap' }}>
        <NavLink
          to="/"
          className={({ isActive }) => `btn-ghost ${isActive ? 'btn-primary' : ''}`}
          style={({ isActive }) => ({
            padding: '0.45rem 0.85rem',
            borderRadius: 'var(--radius-md)',
            color: isActive ? '#fff' : 'var(--text-muted)'
          })}
        >
          <Zap size={16} />
          <span>Home</span>
        </NavLink>

        <NavLink
          to="/dashboard"
          className={({ isActive }) => `btn-ghost ${isActive ? 'btn-primary' : ''}`}
          style={({ isActive }) => ({
            padding: '0.45rem 0.85rem',
            borderRadius: 'var(--radius-md)',
            color: isActive ? '#fff' : 'var(--text-muted)'
          })}
        >
          <LayoutDashboard size={16} />
          <span>Dashboard</span>
        </NavLink>

        <NavLink
          to="/activities"
          className={({ isActive }) => `btn-ghost ${isActive ? 'btn-primary' : ''}`}
          style={({ isActive }) => ({
            padding: '0.45rem 0.85rem',
            borderRadius: 'var(--radius-md)',
            color: isActive ? '#fff' : 'var(--text-muted)',
            position: 'relative'
          })}
        >
          <Activity size={16} />
          <span>Live Feed</span>
          {activeCallsCount > 0 && (
            <span style={{
              position: 'absolute',
              top: '2px',
              right: '2px',
              background: 'var(--accent-emerald)',
              color: '#000',
              fontWeight: 800,
              fontSize: '0.65rem',
              borderRadius: '999px',
              padding: '0.1rem 0.35rem',
              lineHeight: 1
            }}>
              {activeCallsCount}
            </span>
          )}
        </NavLink>

        <NavLink
          to="/leaderboard"
          className={({ isActive }) => `btn-ghost ${isActive ? 'btn-primary' : ''}`}
          style={({ isActive }) => ({
            padding: '0.45rem 0.85rem',
            borderRadius: 'var(--radius-md)',
            color: isActive ? '#fff' : 'var(--text-muted)'
          })}
        >
          <Trophy size={16} />
          <span>Team & Reps</span>
        </NavLink>

        <NavLink
          to="/crm-sync"
          className={({ isActive }) => `btn-ghost ${isActive ? 'btn-primary' : ''}`}
          style={({ isActive }) => ({
            padding: '0.45rem 0.85rem',
            borderRadius: 'var(--radius-md)',
            color: isActive ? '#fff' : 'var(--text-muted)'
          })}
        >
          <Share2 size={16} />
          <span>CRM Hub</span>
        </NavLink>

        <NavLink
          to="/security"
          className={({ isActive }) => `btn-ghost ${isActive ? 'btn-primary' : ''}`}
          style={({ isActive }) => ({
            padding: '0.45rem 0.85rem',
            borderRadius: 'var(--radius-md)',
            color: isActive ? '#fff' : 'var(--text-muted)'
          })}
        >
          <ShieldCheck size={16} />
          <span>Security Vault</span>
        </NavLink>

        <NavLink
          to="/admin"
          className={({ isActive }) => `btn-ghost ${isActive ? 'btn-primary' : ''}`}
          style={({ isActive }) => ({
            padding: '0.45rem 0.85rem',
            borderRadius: 'var(--radius-md)',
            color: isActive ? '#fff' : 'var(--text-muted)'
          })}
        >
          <Settings size={16} />
          <span>Customer Admin</span>
        </NavLink>

        <NavLink
          to="/super-admin"
          className={({ isActive }) => `btn-ghost ${isActive ? 'btn-primary' : ''}`}
          style={({ isActive }) => ({
            padding: '0.45rem 0.85rem',
            borderRadius: 'var(--radius-md)',
            color: isActive ? '#fff' : '#eab308',
            background: isActive ? 'linear-gradient(135deg, #eab308 0%, #f97316 100%)' : 'rgba(234, 179, 8, 0.1)',
            border: '1px solid rgba(234, 179, 8, 0.3)',
            display: 'inline-flex',
            alignItems: 'center',
            gap: '0.4rem',
            fontWeight: 700
          })}
        >
          <Crown size={15} />
          <span>Super Admin</span>
        </NavLink>
      </nav>

      {/* Action Hub & Utilities */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
        {/* Test Incoming Call Trigger */}
        <button
          onClick={() => triggerIncomingCall()}
          className="btn-ghost"
          style={{
            padding: '0.45rem 0.85rem',
            fontSize: '0.8rem',
            borderRadius: 'var(--radius-md)',
            background: 'rgba(56, 189, 248, 0.12)',
            border: '1px solid rgba(56, 189, 248, 0.35)',
            color: '#38bdf8',
            display: 'flex',
            alignItems: 'center',
            gap: '6px',
            cursor: 'pointer'
          }}
          title="Simulate an incoming customer call arriving on the system"
        >
          <PhoneIncoming size={15} />
          <span>Test Inbound Call</span>
        </button>

        {/* Mobile App Simulator Launcher */}
        <button
          onClick={() => setIsSimulatorOpen(true)}
          className="btn-primary"
          style={{
            padding: '0.45rem 0.95rem',
            fontSize: '0.82rem',
            borderRadius: 'var(--radius-md)',
            background: 'linear-gradient(135deg, #06b6d4 0%, #3b82f6 100%)',
            boxShadow: '0 4px 14px rgba(6, 182, 212, 0.35)'
          }}
          title="Open interactive Mobile Companion app dialer simulator"
        >
          <Smartphone size={16} />
          <span>Mobile Simulator</span>
        </button>

        {/* Role Toggle */}
        <button
          onClick={() => setSelectedRole(selectedRole === 'admin' ? 'rep' : 'admin')}
          className="glass-pill"
          style={{
            cursor: 'pointer',
            padding: '0.35rem 0.75rem',
            fontSize: '0.78rem',
            color: 'var(--text-main)'
          }}
          title="Switch view between Director/Admin and Rep"
        >
          {selectedRole === 'admin' ? '👔 Director View' : '🎧 Sales Rep'}
        </button>

        {/* Accent Color Chooser */}
        <div style={{ display: 'flex', gap: '4px' }}>
          {(['violet', 'emerald', 'cyan', 'amber'] as const).map(c => (
            <button
              key={c}
              onClick={() => setAccent(c)}
              style={{
                width: '18px',
                height: '18px',
                borderRadius: '50%',
                border: accent === c ? '2px solid #fff' : '1px solid rgba(255,255,255,0.2)',
                background:
                  c === 'violet' ? '#7c3aed' :
                  c === 'emerald' ? '#059669' :
                  c === 'cyan' ? '#0891b2' : '#d97706',
                cursor: 'pointer',
                transition: 'transform 0.15s ease'
              }}
              title={`Switch accent color to ${c}`}
            />
          ))}
        </div>

        {/* Dark/Light Mode */}
        <button
          onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
          className="btn-ghost"
          style={{ padding: '0.4rem', borderRadius: '50%' }}
          title={`Switch to ${theme === 'dark' ? 'light' : 'dark'} mode`}
        >
          {theme === 'dark' ? <Sun size={18} color="#f59e0b" /> : <Moon size={18} color="#6366f1" />}
        </button>

        {/* Workspace Partition Badge */}
        <div
          onClick={() => navigate('/super-admin')}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '0.4rem',
            padding: '0.35rem 0.65rem',
            borderRadius: 'var(--radius-md)',
            background: activeTenantId === 'all' ? 'rgba(234, 179, 8, 0.12)' : 'rgba(99, 102, 241, 0.12)',
            border: activeTenantId === 'all' ? '1px solid rgba(234, 179, 8, 0.3)' : '1px solid rgba(99, 102, 241, 0.3)',
            fontSize: '0.76rem',
            fontWeight: 700,
            color: activeTenantId === 'all' ? '#eab308' : 'var(--accent-primary)',
            cursor: 'pointer'
          }}
          title="Current Workspace Scope - Click to inspect in Super Admin"
        >
          {activeTenantId === 'all' ? <Crown size={13} /> : <Building size={13} />}
          <span style={{ maxWidth: '100px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
            {activeTenantId === 'all' ? 'All Tenants' : (currentOrg?.name || activeTenantId)}
          </span>
        </div>

        {/* User Account / Profile & Sign In */}
        {currentUser ? (
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '0.45rem',
            padding: '0.3rem 0.6rem',
            borderRadius: 'var(--radius-md)',
            background: 'rgba(255, 255, 255, 0.05)',
            border: '1px solid var(--border-subtle)',
            fontSize: '0.78rem'
          }}>
            {currentUser.avatar ? (
              <img
                src={currentUser.avatar}
                alt={currentUser.name}
                style={{ width: '22px', height: '22px', borderRadius: '50%', objectFit: 'cover' }}
              />
            ) : (
              <User size={15} />
            )}
            <span style={{ fontWeight: 600, maxWidth: '90px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {currentUser.name.split(' ')[0]}
            </span>
            <button
              onClick={() => {
                logout();
                navigate('/login');
              }}
              style={{
                background: 'none',
                border: 'none',
                color: 'var(--text-muted)',
                cursor: 'pointer',
                padding: '2px',
                display: 'flex',
                alignItems: 'center'
              }}
              title="Sign Out"
            >
              <LogOut size={13} />
            </button>
          </div>
        ) : (
          <NavLink
            to="/login"
            style={{
              padding: '0.45rem 0.85rem',
              borderRadius: 'var(--radius-md)',
              background: 'linear-gradient(135deg, var(--primary) 0%, #38bdf8 100%)',
              color: '#fff',
              fontWeight: 700,
              fontSize: '0.78rem',
              display: 'flex',
              alignItems: 'center',
              gap: '4px',
              textDecoration: 'none'
            }}
          >
            <LogIn size={14} />
            <span>Sign In</span>
          </NavLink>
        )}
      </div>
    </header>
  );
};
