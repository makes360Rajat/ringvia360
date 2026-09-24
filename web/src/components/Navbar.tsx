import React from 'react';
import { NavLink } from 'react-router-dom';
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
  Settings
} from 'lucide-react';
import { useApp } from '../context/AppContext';

export const Navbar: React.FC = () => {
  const {
    theme,
    setTheme,
    accent,
    setAccent,
    selectedRole,
    setSelectedRole,
    setIsSimulatorOpen,
    triggerIncomingCall,
    calls
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
          <span>Admin</span>
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
      </div>
    </header>
  );
};
