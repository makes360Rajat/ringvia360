import React from 'react';
import { PhoneOff, Mic, Shield, Radio } from 'lucide-react';
import { useApp } from '../context/AppContext';

export const LiveInCallBar: React.FC = () => {
  const { activeCallSession, endActiveCallSession } = useApp();

  if (!activeCallSession) return null;

  const formatTimer = (sec: number) => {
    const mins = Math.floor(sec / 60);
    const secs = sec % 60;
    return `${mins < 10 ? '0' : ''}${mins}:${secs < 10 ? '0' : ''}${secs}`;
  };

  return (
    <div style={{
      position: 'fixed',
      bottom: '24px',
      left: '50%',
      transform: 'translateX(-50%)',
      zIndex: 180,
      width: '92%',
      maxWidth: '680px',
      background: 'rgba(9, 10, 16, 0.95)',
      backdropFilter: 'blur(16px)',
      WebkitBackdropFilter: 'blur(16px)',
      border: '1px solid rgba(16, 185, 129, 0.4)',
      borderRadius: '24px',
      padding: '14px 22px',
      boxShadow: '0 20px 60px rgba(0, 0, 0, 0.8), 0 0 35px rgba(16, 185, 129, 0.25)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      gap: '16px',
      flexWrap: 'wrap'
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
        <div style={{
          width: '42px',
          height: '42px',
          borderRadius: '50%',
          background: 'rgba(16, 185, 129, 0.2)',
          border: '1px solid rgba(16, 185, 129, 0.5)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          color: '#34d399'
        }}>
          <Mic size={20} />
        </div>

        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: '5px',
              fontSize: '0.72rem',
              color: '#34d399',
              fontWeight: 700
            }}>
              <span className="live-dot" />
              RECORDING & ENCRYPTION ACTIVE
            </span>
            <span style={{ fontSize: '0.7rem', color: '#94a3b8' }}>
              <Shield size={12} style={{ display: 'inline', verticalAlign: '-1px' }} /> AES-256
            </span>
          </div>

          <div style={{ fontSize: '1.05rem', fontWeight: 800, color: '#f8fafc', marginTop: '2px' }}>
            {activeCallSession.direction === 'inbound' ? 'Inbound from ' : 'Call with '}
            {activeCallSession.contactName}
          </div>

          <div style={{ fontSize: '0.78rem', color: '#94a3b8' }}>
            {activeCallSession.company} • {activeCallSession.phoneNumber}
          </div>
        </div>
      </div>

      <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
        {/* Timer */}
        <div style={{
          fontFamily: 'monospace',
          fontSize: '1.35rem',
          fontWeight: 800,
          color: 'var(--accent-cyan)',
          letterSpacing: '1px'
        }}>
          {formatTimer(activeCallSession.duration)}
        </div>

        {/* End Call Button */}
        <button
          onClick={endActiveCallSession}
          style={{
            padding: '10px 20px',
            borderRadius: '14px',
            background: 'linear-gradient(135deg, #f43f5e 0%, #e11d48 100%)',
            border: 'none',
            color: '#fff',
            fontWeight: 700,
            fontSize: '0.85rem',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            cursor: 'pointer',
            boxShadow: '0 4px 18px rgba(244, 63, 94, 0.4)'
          }}
        >
          <PhoneOff size={16} />
          <span>End Call & Wrap-Up</span>
        </button>
      </div>
    </div>
  );
};
