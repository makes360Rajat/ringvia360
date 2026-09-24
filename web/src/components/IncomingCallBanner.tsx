import React from 'react';
import { Phone, PhoneOff, Radio } from 'lucide-react';
import { useApp } from '../context/AppContext';

export const IncomingCallBanner: React.FC = () => {
  const { incomingCallAlert, acceptIncomingCall, declineIncomingCall } = useApp();

  if (!incomingCallAlert) return null;

  return (
    <div style={{
      position: 'fixed',
      top: '20px',
      left: '50%',
      transform: 'translateX(-50%)',
      zIndex: 200,
      width: '92%',
      maxWidth: '640px',
      background: 'rgba(15, 23, 42, 0.94)',
      backdropFilter: 'blur(16px)',
      WebkitBackdropFilter: 'blur(16px)',
      border: '1px solid rgba(56, 189, 248, 0.4)',
      borderRadius: '24px',
      padding: '16px 20px',
      boxShadow: '0 20px 50px rgba(0, 0, 0, 0.7), 0 0 35px rgba(56, 189, 248, 0.3)',
      animation: 'slideDown 0.3s ease-out'
    }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '16px', flexWrap: 'wrap' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
          {/* Pulsing Phone Icon */}
          <div style={{
            width: '48px',
            height: '48px',
            borderRadius: '50%',
            background: 'linear-gradient(135deg, #06b6d4 0%, #3b82f6 100%)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            boxShadow: '0 0 20px rgba(6, 182, 212, 0.6)',
            animation: 'pulse 1.2s infinite'
          }}>
            <Phone size={24} color="#fff" />
          </div>

          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <span style={{
                fontSize: '0.72rem',
                fontWeight: 700,
                letterSpacing: '0.8px',
                color: '#38bdf8',
                background: 'rgba(56, 189, 248, 0.15)',
                padding: '2px 8px',
                borderRadius: '8px'
              }}>
                INCOMING CALL • SIM 1 (WORK)
              </span>
              <span style={{ fontSize: '0.72rem', color: '#94a3b8' }}>
                <Radio size={12} style={{ display: 'inline', verticalAlign: '-1px', marginRight: '3px' }} />
                Real-Time Telephony
              </span>
            </div>

            <div style={{ fontSize: '1.15rem', fontWeight: 800, color: '#f8fafc', marginTop: '2px' }}>
              {incomingCallAlert.contactName}
            </div>

            <div style={{ fontSize: '0.82rem', color: '#cbd5e1' }}>
              {incomingCallAlert.company} • {incomingCallAlert.phoneNumber}
              <span style={{ color: '#34d399', marginLeft: '8px', fontWeight: 600 }}>
                (${incomingCallAlert.dealValue.toLocaleString()} Opportunity)
              </span>
            </div>
          </div>
        </div>

        {/* Action Buttons: Decline (Red) & Accept (Green) */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <button
            onClick={declineIncomingCall}
            style={{
              padding: '10px 18px',
              borderRadius: '14px',
              background: 'rgba(244, 63, 94, 0.2)',
              border: '1px solid rgba(244, 63, 94, 0.4)',
              color: '#fb7185',
              fontWeight: 700,
              fontSize: '0.85rem',
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              cursor: 'pointer'
            }}
            title="Decline and open Missed Call wrap-up"
          >
            <PhoneOff size={16} />
            <span>Decline / Miss</span>
          </button>

          <button
            onClick={acceptIncomingCall}
            style={{
              padding: '10px 22px',
              borderRadius: '14px',
              background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
              border: 'none',
              color: '#fff',
              fontWeight: 700,
              fontSize: '0.85rem',
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              cursor: 'pointer',
              boxShadow: '0 4px 18px rgba(16, 185, 129, 0.5)'
            }}
          >
            <Phone size={16} />
            <span>Answer Call</span>
          </button>
        </div>
      </div>
    </div>
  );
};
