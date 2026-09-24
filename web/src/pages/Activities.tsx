import React, { useState } from 'react';
import {
  PhoneCall,
  Search,
  Filter,
  Play,
  Share2,
  CheckCircle,
  MessageSquare,
  Sparkles,
  Download,
  Lock,
  Plus,
  ArrowUpRight,
  ArrowDownLeft,
  PhoneMissed,
  PhoneIncoming
} from 'lucide-react';
import { useApp } from '../context/AppContext';
import type { CallLog } from '../types';

export default function Activities() {
  const {
    calls,
    whatsAppLogs,
    setActiveAudioCall,
    triggerCrmSync,
    triggerIncomingCall,
    startOutboundCallSession,
    setIsSimulatorOpen
  } = useApp();
  const [filterType, setFilterType] = useState<'all' | 'inbound' | 'outbound' | 'missed' | 'whatsapp'>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedSentiment, setSelectedSentiment] = useState<'all' | 'positive' | 'neutral' | 'negative'>('all');

  const filteredCalls = calls.filter(call => {
    if (filterType !== 'all' && filterType !== 'whatsapp' && call.direction !== filterType) return false;
    if (selectedSentiment !== 'all' && call.sentiment !== selectedSentiment) return false;
    if (searchQuery) {
      const q = searchQuery.toLowerCase();
      return (
        call.contactName.toLowerCase().includes(q) ||
        call.company.toLowerCase().includes(q) ||
        call.phoneNumber.includes(q) ||
        call.repName.toLowerCase().includes(q)
      );
    }
    return true;
  });

  const formatDuration = (seconds: number) => {
    if (seconds === 0) return '0s (Missed)';
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}m ${secs}s`;
  };

  return (
    <div style={{ padding: '1rem 1.5rem 4rem', maxWidth: '1440px', margin: '0 auto', display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
      {/* Page Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '1rem' }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
            <h1 style={{ fontSize: '1.85rem', fontWeight: 800, margin: 0, color: 'var(--text-main)' }}>
              Activity Feed & Call Recordings
            </h1>
            <span className="glass-pill" style={{ fontSize: '0.75rem', color: 'var(--primary)' }}>
              {calls.length} Logged Events
            </span>
          </div>
          <p style={{ color: 'var(--text-dim)', fontSize: '0.88rem', marginTop: '0.25rem' }}>
            Zero-latency mobile telemetry, automated CRM synchronization, and AI Whisper transcriptions.
          </p>
        </div>

        <div style={{ display: 'flex', gap: '0.6rem', flexWrap: 'wrap' }}>
          <button
            onClick={() => triggerIncomingCall({
              contactName: 'Chloe Bennett (Inbound Lead)',
              company: 'Stratos Data Systems',
              phoneNumber: '+1 (415) 890-4411',
              dealValue: 64000
            })}
            className="btn-primary"
            style={{
              fontSize: '0.82rem',
              padding: '0.55rem 1rem',
              background: 'linear-gradient(135deg, #06b6d4 0%, #3b82f6 100%)',
              border: 'none',
              boxShadow: '0 4px 14px rgba(6, 182, 212, 0.4)'
            }}
            title="Simulate receiving an inbound call from customer"
          >
            <PhoneIncoming size={14} />
            <span>Simulate Inbound Call</span>
          </button>

          <button
            onClick={() => startOutboundCallSession('+1 (415) 890-2341', 'Alexander Hayes', 'Apex Cloud Solutions')}
            className="btn-primary"
            style={{
              fontSize: '0.82rem',
              padding: '0.55rem 1rem',
              background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
              border: 'none',
              boxShadow: '0 4px 14px rgba(16, 185, 129, 0.4)'
            }}
            title="Start live outbound call session"
          >
            <PhoneCall size={14} />
            <span>Start Live Call</span>
          </button>

          <button
            onClick={() => setIsSimulatorOpen(true)}
            className="btn-secondary"
            style={{ fontSize: '0.82rem', padding: '0.55rem 1rem' }}
          >
            <span>Launch Phone Simulator</span>
          </button>
        </div>
      </div>

      {/* Filter & Search Bar */}
      <div className="glass-panel" style={{ padding: '0.85rem 1.25rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '1rem' }}>
        {/* Type Filter Buttons */}
        <div style={{ display: 'flex', gap: '0.4rem', flexWrap: 'wrap' }}>
          {(['all', 'inbound', 'outbound', 'missed', 'whatsapp'] as const).map(type => (
            <button
              key={type}
              onClick={() => setFilterType(type)}
              style={{
                background: filterType === type ? 'var(--primary)' : 'var(--bg-surface-elevated)',
                color: filterType === type ? '#fff' : 'var(--text-muted)',
                border: '1px solid var(--border-subtle)',
                borderRadius: 'var(--radius-sm)',
                padding: '6px 12px',
                fontSize: '0.8rem',
                fontWeight: 600,
                cursor: 'pointer',
                textTransform: 'capitalize'
              }}
            >
              {type}
            </button>
          ))}
        </div>

        {/* Search & Sentiment Dropdown */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', flex: 1, maxWidth: '500px', justifyContent: 'flex-end' }}>
          <div style={{
            position: 'relative',
            flex: 1,
            display: 'flex',
            alignItems: 'center'
          }}>
            <Search size={16} color="var(--text-dim)" style={{ position: 'absolute', left: '12px' }} />
            <input
              type="text"
              placeholder="Search contact, company, phone or rep..."
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
              style={{
                width: '100%',
                padding: '8px 12px 8px 36px',
                background: 'var(--bg-surface-elevated)',
                border: '1px solid var(--border-glass)',
                borderRadius: 'var(--radius-md)',
                color: 'var(--text-main)',
                fontSize: '0.85rem',
                outline: 'none'
              }}
            />
          </div>

          <select
            value={selectedSentiment}
            onChange={e => setSelectedSentiment(e.target.value as any)}
            style={{
              padding: '8px 12px',
              background: 'var(--bg-surface-elevated)',
              border: '1px solid var(--border-glass)',
              borderRadius: 'var(--radius-md)',
              color: 'var(--text-main)',
              fontSize: '0.82rem',
              cursor: 'pointer'
            }}
          >
            <option value="all">All Sentiments</option>
            <option value="positive">Positive Intent</option>
            <option value="neutral">Neutral Intent</option>
            <option value="negative">Objection / Risk</option>
          </select>
        </div>
      </div>

      {/* Activity List Stream */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '0.85rem' }}>
        {filterType === 'whatsapp' ? (
          // WhatsApp List
          whatsAppLogs.map(wa => (
            <div key={wa.id} className="glass-card" style={{ padding: '1.25rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '1rem' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                <div style={{
                  width: '42px',
                  height: '42px',
                  borderRadius: '12px',
                  background: 'rgba(37, 211, 102, 0.15)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center'
                }}>
                  <MessageSquare size={20} color="#25d366" />
                </div>
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
                    <span style={{ fontWeight: 700, fontSize: '1rem', color: 'var(--text-main)' }}>{wa.contactName}</span>
                    <span style={{ fontSize: '0.82rem', color: 'var(--text-dim)' }}>• {wa.company}</span>
                    <span className="glass-pill badge-whatsapp" style={{ fontSize: '0.72rem' }}>WhatsApp Business</span>
                  </div>
                  <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginTop: '4px' }}>
                    "{wa.lastMessage}"
                  </p>
                </div>
              </div>

              <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                <span style={{ fontSize: '0.78rem', color: 'var(--text-dim)' }}>{wa.timestamp}</span>
                <span className="glass-pill" style={{ color: 'var(--accent-emerald)', fontSize: '0.75rem' }}>
                  ✓ {wa.crmType} Synced
                </span>
              </div>
            </div>
          ))
        ) : (
          // Voice Calls List
          filteredCalls.map(call => (
            <div
              key={call.id}
              className="glass-card"
              style={{
                padding: '1.25rem',
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                flexWrap: 'wrap',
                gap: '1rem'
              }}
            >
              {/* Left Column: Direction, Contact, Rep info */}
              <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', flex: 1, minWidth: '320px' }}>
                <div style={{
                  width: '46px',
                  height: '46px',
                  borderRadius: '14px',
                  background:
                    call.direction === 'inbound' ? 'rgba(6, 182, 212, 0.15)' :
                    call.direction === 'outbound' ? 'rgba(16, 185, 129, 0.15)' : 'rgba(244, 63, 94, 0.15)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color:
                    call.direction === 'inbound' ? 'var(--accent-cyan)' :
                    call.direction === 'outbound' ? 'var(--accent-emerald)' : 'var(--accent-rose)'
                }}>
                  {call.direction === 'inbound' && <ArrowDownLeft size={22} />}
                  {call.direction === 'outbound' && <ArrowUpRight size={22} />}
                  {call.direction === 'missed' && <PhoneMissed size={22} />}
                </div>

                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem', flexWrap: 'wrap' }}>
                    <span style={{ fontWeight: 700, fontSize: '1.05rem', color: 'var(--text-main)' }}>
                      {call.contactName}
                    </span>
                    <span style={{ fontSize: '0.85rem', color: 'var(--text-dim)' }}>
                      {call.company}
                    </span>
                    <span className={`glass-pill ${
                      call.direction === 'inbound' ? 'badge-inbound' :
                      call.direction === 'outbound' ? 'badge-outbound' : 'badge-missed'
                    }`}>
                      {call.direction.toUpperCase()}
                    </span>
                    {call.isEncrypted && (
                      <span className="glass-pill" style={{ fontSize: '0.72rem', color: 'var(--accent-emerald)', gap: '2px' }}>
                        <Lock size={10} /> E2EE
                      </span>
                    )}
                  </div>

                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginTop: '0.35rem', fontSize: '0.82rem', color: 'var(--text-muted)' }}>
                    <span>{call.phoneNumber}</span>
                    <span>•</span>
                    <span>Duration: <strong>{formatDuration(call.duration)}</strong></span>
                    <span>•</span>
                    <span>Rep: {call.repName}</span>
                    <span>•</span>
                    <span style={{ color: 'var(--text-dim)' }}>{call.timestamp}</span>
                  </div>

                  <p style={{ fontSize: '0.82rem', color: 'var(--text-main)', marginTop: '0.35rem', fontStyle: 'italic' }}>
                    "{call.outcome}" — {call.notes}
                  </p>
                </div>
              </div>

              {/* Middle: Mini Waveform Preview & Sentiment */}
              <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                <div style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '2px',
                  height: '24px',
                  width: '90px'
                }}>
                  {(call.waveform?.slice(0, 14) || [30, 50, 80, 60, 40, 70, 90, 65, 45, 80, 60, 40, 30, 20]).map((h, i) => (
                    <div
                      key={i}
                      style={{
                        flex: 1,
                        height: `${h}%`,
                        background: 'var(--primary)',
                        borderRadius: '1px'
                      }}
                    />
                  ))}
                </div>

                <span className={`glass-pill ${
                  call.sentiment === 'positive' ? 'badge-sentiment-pos' :
                  call.sentiment === 'neutral' ? 'badge-sentiment-neu' : 'badge-sentiment-neg'
                }`}>
                  {call.sentiment.toUpperCase()} ({call.sentimentScore}%)
                </span>
              </div>

              {/* Right: CRM Sync Status & Audio Player Launcher */}
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.65rem' }}>
                <span className="glass-pill" style={{
                  fontSize: '0.75rem',
                  color: call.crmStatus === 'synced' ? 'var(--accent-emerald)' : 'var(--accent-amber)'
                }}>
                  ✓ {call.crmType}
                </span>

                <button
                  onClick={() => startOutboundCallSession(call.phoneNumber, call.contactName, call.company)}
                  className="btn-ghost"
                  style={{
                    fontSize: '0.8rem',
                    padding: '0.45rem 0.75rem',
                    color: '#34d399',
                    border: '1px solid rgba(16, 185, 129, 0.3)',
                    background: 'rgba(16, 185, 129, 0.1)',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '4px',
                    cursor: 'pointer'
                  }}
                  title={`Start call session with ${call.contactName}`}
                >
                  <PhoneCall size={14} />
                  <span>Call</span>
                </button>

                <button
                  onClick={() => setActiveAudioCall(call)}
                  className="btn-primary"
                  style={{ fontSize: '0.8rem', padding: '0.45rem 0.85rem' }}
                >
                  <Play size={14} fill="#fff" />
                  <span>Playback & AI Notes</span>
                </button>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}
