import React, { useState, useEffect } from 'react';
import { Sparkles, X, Check, Cloud, DollarSign, MessageSquare } from 'lucide-react';
import { useApp } from '../context/AppContext';

export const PostCallWrapUpModal: React.FC = () => {
  const { wrapUpModalCall, setWrapUpModalCall, submitWrapUpCall } = useApp();

  const [outcome, setOutcome] = useState('Demo Completed - Contract Requested');
  const [notes, setNotes] = useState('');
  const [dealValue, setDealValue] = useState('1850000');
  const [sentiment, setSentiment] = useState<'positive' | 'neutral' | 'negative'>('positive');
  const [crmType, setCrmType] = useState<'RingVia360' | 'HubSpot' | 'Zoho' | 'Custom'>('RingVia360');

  useEffect(() => {
    if (wrapUpModalCall) {
      setOutcome(wrapUpModalCall.outcome || (wrapUpModalCall.direction === 'missed' ? 'Missed Inbound Call - Follow-up Needed' : 'Demo Completed - Contract Requested'));
      setNotes(wrapUpModalCall.notes || '');
      setDealValue(String(wrapUpModalCall.dealValue || 1850000));
      setSentiment(wrapUpModalCall.sentiment || 'positive');
      setCrmType((wrapUpModalCall.crmType as any) || 'RingVia360');
    }
  }, [wrapUpModalCall]);

  if (!wrapUpModalCall) return null;

  const mins = Math.floor((wrapUpModalCall.duration || 0) / 60);
  const secs = (wrapUpModalCall.duration || 0) % 60;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    submitWrapUpCall({
      outcome,
      notes,
      dealValue: parseInt(dealValue, 10) || 0,
      sentiment,
      crmType
    });
  };

  return (
    <div style={{
      position: 'fixed',
      inset: 0,
      backgroundColor: 'rgba(5, 7, 15, 0.85)',
      backdropFilter: 'blur(14px)',
      WebkitBackdropFilter: 'blur(14px)',
      zIndex: 210,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      padding: '1rem'
    }}>
      <div style={{
        width: '100%',
        maxWidth: '520px',
        maxHeight: '90vh',
        background: '#0d111d',
        borderRadius: '28px',
        border: '1px solid rgba(255, 255, 255, 0.12)',
        boxShadow: '0 25px 70px rgba(0,0,0,0.9), 0 0 40px var(--primary-glow)',
        display: 'flex',
        flexDirection: 'column',
        overflow: 'hidden',
        color: '#f8fafc'
      }}>
        {/* Header */}
        <div style={{
          padding: '18px 24px 14px',
          borderBottom: '1px solid rgba(255,255,255,0.08)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span className="glass-pill" style={{
              background: 'rgba(124, 58, 237, 0.2)',
              color: 'var(--primary)',
              fontSize: '0.75rem',
              display: 'inline-flex',
              alignItems: 'center',
              gap: '4px'
            }}>
              <Sparkles size={13} />
              RingVia360 Instant Wrap-Up
            </span>
            <span style={{
              fontSize: '0.72rem',
              padding: '2px 8px',
              borderRadius: '8px',
              background: wrapUpModalCall.direction === 'inbound' ? 'rgba(56, 189, 248, 0.2)' :
                          wrapUpModalCall.direction === 'missed' ? 'rgba(244, 63, 94, 0.2)' : 'rgba(16, 185, 129, 0.2)',
              color: wrapUpModalCall.direction === 'inbound' ? '#38bdf8' :
                     wrapUpModalCall.direction === 'missed' ? '#fb7185' : '#34d399',
              fontWeight: 700,
              textTransform: 'uppercase'
            }}>
              {wrapUpModalCall.direction} Call
            </span>
          </div>

          <button
            onClick={() => setWrapUpModalCall(null)}
            style={{
              background: 'rgba(255,255,255,0.1)',
              border: 'none',
              borderRadius: '50%',
              width: '28px',
              height: '28px',
              color: '#94a3b8',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}
          >
            <X size={16} />
          </button>
        </div>

        {/* Body Form */}
        <form onSubmit={handleSubmit} style={{ padding: '20px 24px', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '16px' }}>
          <div>
            <h2 style={{ fontSize: '1.25rem', fontWeight: 800, margin: 0 }}>
              {wrapUpModalCall.contactName}
            </h2>
            <div style={{ fontSize: '0.82rem', color: '#94a3b8', marginTop: '4px' }}>
              {wrapUpModalCall.company} • {wrapUpModalCall.phoneNumber} • {mins}m {secs}s duration
            </div>
          </div>

          {/* Disposition / Outcome */}
          <div>
            <label style={{ fontSize: '0.78rem', color: '#cbd5e1', fontWeight: 600, display: 'block', marginBottom: '6px' }}>
              CALL DISPOSITION / STATUS
            </label>
            <select
              value={outcome}
              onChange={e => setOutcome(e.target.value)}
              style={{
                width: '100%',
                padding: '10px 12px',
                borderRadius: '12px',
                background: '#161927',
                border: '1px solid rgba(255,255,255,0.15)',
                color: '#fff',
                fontSize: '0.88rem',
                outline: 'none'
              }}
            >
              <option value="Demo Completed - Contract Requested">Demo Completed - Contract Requested</option>
              <option value="Inbound Inquiry Solved">Inbound Inquiry Solved</option>
              <option value="Connected - Follow-up Scheduled">Connected - Follow-up Scheduled</option>
              <option value="Missed Inbound Call - Follow-up Needed">Missed Inbound Call - Follow-up Needed</option>
              <option value="Left Voicemail">Left Voicemail</option>
              <option value="Gatekeeper Blocked">Gatekeeper Blocked</option>
              <option value="Price Objection Raised">Price Objection Raised</option>
            </select>
          </div>

          {/* Notes */}
          <div>
            <label style={{ fontSize: '0.78rem', color: '#cbd5e1', fontWeight: 600, display: 'block', marginBottom: '6px' }}>
              CALL NOTES (SYNCS TO CRM TASK)
            </label>
            <textarea
              value={notes}
              onChange={e => setNotes(e.target.value)}
              rows={3}
              placeholder="Enter meeting recap, next steps or customer requirements..."
              style={{
                width: '100%',
                padding: '10px 12px',
                borderRadius: '12px',
                background: '#161927',
                border: '1px solid rgba(255,255,255,0.15)',
                color: '#fff',
                fontSize: '0.85rem',
                resize: 'none',
                outline: 'none'
              }}
            />
          </div>

          {/* Deal Value & Target CRM Row */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
            <div>
              <label style={{ fontSize: '0.78rem', color: '#cbd5e1', fontWeight: 600, display: 'block', marginBottom: '6px' }}>
                DEAL VALUE (₹ INR)
              </label>
              <div style={{ position: 'relative' }}>
                <span style={{ position: 'absolute', left: '10px', top: '50%', transform: 'translateY(-50%)', color: '#10b981', fontWeight: 700, fontSize: '0.95rem' }}>₹</span>
                <input
                  type="number"
                  value={dealValue}
                  onChange={e => setDealValue(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '10px 10px 10px 28px',
                    borderRadius: '12px',
                    background: '#161927',
                    border: '1px solid rgba(255,255,255,0.15)',
                    color: '#fff',
                    fontSize: '0.88rem',
                    outline: 'none'
                  }}
                />
              </div>
            </div>

            <div>
              <label style={{ fontSize: '0.78rem', color: '#cbd5e1', fontWeight: 600, display: 'block', marginBottom: '6px' }}>
                DESTINATION CRM
              </label>
              <select
                value={crmType}
                onChange={e => setCrmType(e.target.value as any)}
                style={{
                  width: '100%',
                  padding: '10px 12px',
                  borderRadius: '12px',
                  background: '#161927',
                  border: '1px solid rgba(255,255,255,0.15)',
                  color: '#fff',
                  fontSize: '0.88rem',
                  outline: 'none'
                }}
              >
                <option value="RingVia360">RingVia360 Native CRM</option>
                <option value="HubSpot">HubSpot CRM</option>
                <option value="Zoho">Zoho CRM</option>
                <option value="Custom">Custom Webhook CRM</option>
              </select>
            </div>
          </div>

          {/* Buyer Sentiment */}
          <div>
            <label style={{ fontSize: '0.78rem', color: '#cbd5e1', fontWeight: 600, display: 'block', marginBottom: '6px' }}>
              BUYER SENTIMENT
            </label>
            <div style={{ display: 'flex', gap: '8px' }}>
              {(['positive', 'neutral', 'negative'] as const).map(s => (
                <button
                  type="button"
                  key={s}
                  onClick={() => setSentiment(s)}
                  style={{
                    flex: 1,
                    padding: '8px',
                    borderRadius: '10px',
                    border: sentiment === s ? '1px solid #fff' : '1px solid rgba(255,255,255,0.1)',
                    background:
                      s === 'positive' ? 'rgba(16, 185, 129, 0.2)' :
                      s === 'neutral' ? 'rgba(245, 158, 11, 0.2)' : 'rgba(244, 63, 94, 0.2)',
                    color:
                      s === 'positive' ? '#34d399' :
                      s === 'neutral' ? '#fbbf24' : '#fb7185',
                    fontSize: '0.8rem',
                    fontWeight: 600,
                    cursor: 'pointer',
                    textTransform: 'capitalize'
                  }}
                >
                  {s === 'negative' ? 'Risk / Objection' : s}
                </button>
              ))}
            </div>
          </div>

          {/* Save & Sync CTA */}
          <button
            type="submit"
            style={{
              marginTop: '8px',
              padding: '14px',
              borderRadius: '14px',
              background: 'linear-gradient(135deg, var(--primary) 0%, #38bdf8 100%)',
              border: 'none',
              color: '#fff',
              fontWeight: 700,
              fontSize: '0.95rem',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '8px',
              boxShadow: '0 6px 20px var(--primary-glow)'
            }}
          >
            <Check size={18} />
            Save & Sync to {crmType}
          </button>
        </form>
      </div>
    </div>
  );
};
