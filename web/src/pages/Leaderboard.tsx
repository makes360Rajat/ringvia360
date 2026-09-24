import React, { useState } from 'react';
import {
  Trophy,
  Award,
  Flame,
  Smartphone,
  Battery,
  Wifi,
  PhoneCall,
  Clock,
  TrendingUp,
  ShieldCheck,
  CheckCircle2,
  Plus,
  RefreshCw,
  X
} from 'lucide-react';
import { useApp } from '../context/AppContext';

export default function Leaderboard() {
  const { reps, addRep, dbEngine, refreshAllData } = useApp();
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [repName, setRepName] = useState('');
  const [repRole, setRepRole] = useState('Account Executive');
  const [repPhone, setRepPhone] = useState('+91 98200 12345');
  const [isRefreshing, setIsRefreshing] = useState(false);

  const handleAddRep = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!repName) return;
    await addRep({
      name: repName,
      role: repRole,
      phone: repPhone,
      callsToday: Math.floor(Math.random() * 20) + 15,
      talkTimeMinutes: Math.floor(Math.random() * 80) + 60,
      dealsClosed: Math.floor(Math.random() * 3) + 1,
      conversionRate: 24.5,
      rank: reps.length + 1,
      streakDays: 4,
      isOnline: true
    });
    setRepName('');
    setIsModalOpen(false);
  };

  const handleRefresh = async () => {
    setIsRefreshing(true);
    await refreshAllData();
    setTimeout(() => setIsRefreshing(false), 800);
  };

  return (
    <div style={{ padding: '1rem 1.5rem 4rem', maxWidth: '1440px', margin: '0 auto', display: 'flex', flexDirection: 'column', gap: '2rem' }}>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '1rem' }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
            <h1 style={{ fontSize: '1.85rem', fontWeight: 800, margin: 0, color: 'var(--text-main)' }}>
              Sales Team Performance & Device Fleet
            </h1>
            <span className="glass-pill" style={{ color: 'var(--accent-amber)', fontSize: '0.75rem' }}>
              <Trophy size={14} /> Season 4 Active
            </span>
          </div>
          <p style={{ color: 'var(--text-dim)', fontSize: '0.88rem', marginTop: '0.25rem' }}>
            Real-time rep rankings, call activity streaks, and live mobile device telemetry.
          </p>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', flexWrap: 'wrap' }}>
          <div className="glass-pill" style={{ color: 'var(--accent-emerald)', padding: '0.5rem 1rem' }}>
            <span className="live-dot" />
            <span>{reps.filter(r => r.isOnline).length} Reps Online • {dbEngine.toUpperCase()}</span>
          </div>

          <button
            onClick={handleRefresh}
            disabled={isRefreshing}
            className="btn-secondary"
            style={{ fontSize: '0.82rem', padding: '0.5rem 0.9rem' }}
          >
            <RefreshCw size={14} className={isRefreshing ? 'animate-spin' : ''} />
            <span>{isRefreshing ? 'Syncing...' : 'Sync DB'}</span>
          </button>

          <button
            onClick={() => setIsModalOpen(true)}
            className="btn-primary"
            style={{ fontSize: '0.82rem', padding: '0.5rem 0.9rem' }}
          >
            <Plus size={15} />
            <span>Add Sales Rep</span>
          </button>
        </div>
      </div>

      {isModalOpen && (
        <div style={{
          position: 'fixed',
          inset: 0,
          background: 'rgba(5, 7, 15, 0.75)',
          backdropFilter: 'blur(8px)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000,
          padding: '1rem'
        }}>
          <div className="glass-card" style={{ maxWidth: '440px', width: '100%', padding: '1.75rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem' }}>
              <h3 style={{ margin: 0, fontSize: '1.2rem', fontWeight: 700, color: 'var(--text-main)' }}>Enroll Sales Rep</h3>
              <button onClick={() => setIsModalOpen(false)} className="btn-ghost" style={{ padding: '4px' }}>
                <X size={18} />
              </button>
            </div>
            <form onSubmit={handleAddRep} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
              <div>
                <label style={{ display: 'block', fontSize: '0.75rem', color: 'var(--text-dim)', marginBottom: '4px' }}>Representative Name</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Vikram Deshmukh"
                  value={repName}
                  onChange={e => setRepName(e.target.value)}
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
                <label style={{ display: 'block', fontSize: '0.75rem', color: 'var(--text-dim)', marginBottom: '4px' }}>Role / Designation</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Senior Enterprise AE"
                  value={repRole}
                  onChange={e => setRepRole(e.target.value)}
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
                <label style={{ display: 'block', fontSize: '0.75rem', color: 'var(--text-dim)', marginBottom: '4px' }}>Corporate Airtel / Jio SIM Number</label>
                <input
                  type="text"
                  required
                  placeholder="+91 98200 11223"
                  value={repPhone}
                  onChange={e => setRepPhone(e.target.value)}
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
              <div style={{ display: 'flex', gap: '0.75rem', marginTop: '0.5rem' }}>
                <button type="button" onClick={() => setIsModalOpen(false)} className="btn-secondary" style={{ flex: 1, padding: '0.6rem' }}>
                  Cancel
                </button>
                <button type="submit" className="btn-primary" style={{ flex: 1, padding: '0.6rem' }}>
                  Save to Database
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Top 3 Podium Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '1.25rem' }}>
        {reps.slice(0, 3).map((rep, idx) => (
          <div
            key={rep.id}
            className="glass-card"
            style={{
              padding: '1.5rem',
              position: 'relative',
              overflow: 'hidden',
              borderTop: idx === 0 ? '4px solid #f59e0b' : idx === 1 ? '4px solid #94a3b8' : '4px solid #b45309'
            }}
          >
            {/* Rank Badge */}
            <div style={{
              position: 'absolute',
              top: '14px',
              right: '16px',
              fontSize: '1.6rem',
              fontWeight: 800,
              fontFamily: 'var(--font-mono)',
              color: idx === 0 ? '#f59e0b' : idx === 1 ? '#94a3b8' : '#b45309'
            }}>
              #{rep.rank}
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', marginBottom: '1.25rem' }}>
              <div style={{ position: 'relative' }}>
                <img
                  src={rep.avatar}
                  alt={rep.name}
                  style={{ width: '56px', height: '56px', borderRadius: '50%', objectFit: 'cover', border: '2px solid var(--border-highlight)' }}
                />
                <div style={{
                  position: 'absolute',
                  bottom: '2px',
                  right: '2px',
                  width: '12px',
                  height: '12px',
                  borderRadius: '50%',
                  backgroundColor: rep.isOnline ? '#10b981' : '#6b7280',
                  border: '2px solid #090a10'
                }} />
              </div>

              <div>
                <h3 style={{ fontSize: '1.15rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>
                  {rep.name}
                </h3>
                <span style={{ fontSize: '0.8rem', color: 'var(--text-dim)' }}>
                  {rep.role}
                </span>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem', marginTop: '4px', fontSize: '0.75rem', color: 'var(--accent-amber)' }}>
                  <Flame size={14} />
                  <span>{rep.streakDays}-Day Activity Streak</span>
                </div>
              </div>
            </div>

            {/* Performance Stats */}
            <div style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(3, 1fr)',
              gap: '0.5rem',
              padding: '0.85rem',
              background: 'var(--bg-surface-elevated)',
              borderRadius: 'var(--radius-md)',
              textAlign: 'center',
              marginBottom: '1rem'
            }}>
              <div>
                <div style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-main)', fontFamily: 'var(--font-mono)' }}>
                  {rep.callsToday}
                </div>
                <div style={{ fontSize: '0.7rem', color: 'var(--text-dim)' }}>Calls</div>
              </div>
              <div>
                <div style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--primary)', fontFamily: 'var(--font-mono)' }}>
                  {rep.talkTimeMinutes}m
                </div>
                <div style={{ fontSize: '0.7rem', color: 'var(--text-dim)' }}>Talk Time</div>
              </div>
              <div>
                <div style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--accent-emerald)', fontFamily: 'var(--font-mono)' }}>
                  {rep.dealsClosed}
                </div>
                <div style={{ fontSize: '0.7rem', color: 'var(--text-dim)' }}>Won Deals</div>
              </div>
            </div>

            {/* Badges */}
            <div style={{ display: 'flex', gap: '0.4rem', flexWrap: 'wrap' }}>
              {rep.badges.map((b, i) => (
                <span key={i} className="glass-pill" style={{ fontSize: '0.72rem', background: 'rgba(255,255,255,0.06)' }}>
                  <Award size={12} color="var(--accent-cyan)" />
                  {b}
                </span>
              ))}
            </div>
          </div>
        ))}
      </div>

      {/* Device Telemetry Table (Admin & Director Oversight) */}
      <div className="glass-panel" style={{ padding: '1.5rem' }}>
        <div style={{ marginBottom: '1.25rem' }}>
          <h3 style={{ fontSize: '1.15rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>
            Companion App Device Telemetry & MDM Sync
          </h3>
          <p style={{ fontSize: '0.8rem', color: 'var(--text-dim)', marginTop: '2px' }}>
            Ensures sales reps have battery, active connectivity, and native CallKit/Telephony permissions enabled.
          </p>
        </div>

        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', minWidth: '700px' }}>
            <thead>
              <tr style={{ borderBottom: '1px solid var(--border-glass)', fontSize: '0.8rem', color: 'var(--text-dim)' }}>
                <th style={{ padding: '0.85rem' }}>SALES REPRESENTATIVE</th>
                <th style={{ padding: '0.85rem' }}>HARDWARE DEVICE</th>
                <th style={{ padding: '0.85rem' }}>OS & SECURITY</th>
                <th style={{ padding: '0.85rem' }}>BATTERY & SYNC</th>
                <th style={{ padding: '0.85rem' }}>CONVERSION %</th>
                <th style={{ padding: '0.85rem' }}>STATUS</th>
              </tr>
            </thead>
            <tbody>
              {reps.map(rep => (
                <tr key={rep.id} style={{ borderBottom: '1px solid var(--border-subtle)', fontSize: '0.85rem' }}>
                  <td style={{ padding: '0.85rem' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                      <img src={rep.avatar} alt={rep.name} style={{ width: '36px', height: '36px', borderRadius: '50%', objectFit: 'cover' }} />
                      <div>
                        <div style={{ fontWeight: 700, color: 'var(--text-main)' }}>{rep.name}</div>
                        <div style={{ fontSize: '0.75rem', color: 'var(--text-dim)' }}>{rep.phone}</div>
                      </div>
                    </div>
                  </td>
                  <td style={{ padding: '0.85rem' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', color: 'var(--text-muted)' }}>
                      <Smartphone size={16} />
                      <span>{rep.deviceModel}</span>
                    </div>
                  </td>
                  <td style={{ padding: '0.85rem' }}>
                    <span className="glass-pill" style={{ fontSize: '0.75rem' }}>
                      <ShieldCheck size={12} color="var(--accent-emerald)" />
                      {rep.osVersion}
                    </span>
                  </td>
                  <td style={{ padding: '0.85rem' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '4px', color: rep.batteryLevel > 20 ? 'var(--accent-emerald)' : 'var(--accent-rose)' }}>
                        <Battery size={16} />
                        <span style={{ fontWeight: 600 }}>{rep.batteryLevel}%</span>
                      </div>
                      <span style={{ color: 'var(--text-dim)', fontSize: '0.75rem' }}>• {rep.lastSync}</span>
                    </div>
                  </td>
                  <td style={{ padding: '0.85rem', fontWeight: 700, color: 'var(--accent-emerald)', fontFamily: 'var(--font-mono)' }}>
                    {rep.conversionRate}%
                  </td>
                  <td style={{ padding: '0.85rem' }}>
                    <span className="glass-pill" style={{
                      color: rep.isOnline ? 'var(--accent-emerald)' : 'var(--text-dim)',
                      fontSize: '0.75rem'
                    }}>
                      {rep.isOnline ? '● Online & Tracking' : '○ Standby'}
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
