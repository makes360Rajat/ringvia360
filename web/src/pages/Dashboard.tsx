import React, { useState } from 'react';
import {
  PhoneCall,
  Clock,
  CheckCircle2,
  MessageSquare,
  DollarSign,
  TrendingUp,
  Sparkles,
  Play,
  Share2,
  AlertTriangle,
  ArrowUpRight,
  Filter,
  RefreshCw,
  Smartphone
} from 'lucide-react';
import { useApp } from '../context/AppContext';

export default function Dashboard() {
  const { calls, reps, setActiveAudioCall, setIsSimulatorOpen, simulateNewCall } = useApp();
  const [timeRange, setTimeRange] = useState<'today' | 'week' | 'month'>('today');

  const totalCalls = calls.length + 1485;
  const totalDurationMinutes = Math.round(calls.reduce((acc, c) => acc + c.duration, 0) / 60) + 4320;
  const connectedCalls = calls.filter(c => c.duration > 0).length;
  const connectRate = Math.round((connectedCalls / Math.max(1, calls.length)) * 100);

  return (
    <div style={{ padding: '1rem 1.5rem 4rem', maxWidth: '1440px', margin: '0 auto', display: 'flex', flexDirection: 'column', gap: '1.75rem' }}>
      {/* Top Header & Range Filter */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '1rem' }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <h1 style={{ fontSize: '1.85rem', fontWeight: 800, margin: 0, color: 'var(--text-main)' }}>
              Executive Sales Intelligence
            </h1>
            <span className="glass-pill" style={{ color: 'var(--accent-emerald)', fontSize: '0.75rem' }}>
              <span className="live-dot" /> Live Telemetry
            </span>
          </div>
          <p style={{ color: 'var(--text-dim)', fontSize: '0.88rem', marginTop: '0.25rem' }}>
            Real-time call logs, WhatsApp outreach, and CRM pipeline progression across 34 reps.
          </p>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', flexWrap: 'wrap' }}>
          {/* Time Filter */}
          <div style={{ display: 'flex', background: 'var(--bg-surface-elevated)', padding: '3px', borderRadius: 'var(--radius-md)', border: '1px solid var(--border-glass)' }}>
            {(['today', 'week', 'month'] as const).map(range => (
              <button
                key={range}
                onClick={() => setTimeRange(range)}
                style={{
                  background: timeRange === range ? 'var(--primary)' : 'transparent',
                  color: timeRange === range ? '#fff' : 'var(--text-muted)',
                  border: 'none',
                  borderRadius: 'var(--radius-sm)',
                  padding: '6px 14px',
                  fontSize: '0.8rem',
                  fontWeight: 600,
                  cursor: 'pointer',
                  textTransform: 'capitalize'
                }}
              >
                {range}
              </button>
            ))}
          </div>

          <button
            onClick={() => simulateNewCall({
              direction: 'inbound',
              contactName: 'Victoria Sterling (Inbound Lead)',
              company: 'Vanguard Logistics',
              outcome: 'Inbound Qualified - Demo Booked',
              dealValue: 64000
            })}
            className="btn-primary"
            style={{ fontSize: '0.82rem', padding: '0.55rem 1rem' }}
          >
            <RefreshCw size={14} />
            <span>Simulate Inbound Call</span>
          </button>

          <button
            onClick={() => setIsSimulatorOpen(true)}
            className="btn-secondary"
            style={{ fontSize: '0.82rem', padding: '0.55rem 1rem' }}
          >
            <Smartphone size={14} color="var(--accent-cyan)" />
            <span>Mobile Companion</span>
          </button>
        </div>
      </div>

      {/* KPI Cards Grid */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(210px, 1fr))', gap: '1rem' }}>
        {/* Metric 1 */}
        <div className="glass-card" style={{ padding: '1.25rem' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', color: 'var(--text-dim)', marginBottom: '0.5rem' }}>
            <span style={{ fontSize: '0.78rem', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Total Calls Logged</span>
            <PhoneCall size={18} color="var(--primary)" />
          </div>
          <div style={{ fontSize: '1.8rem', fontWeight: 800, color: 'var(--text-main)', fontFamily: 'var(--font-mono)' }}>
            {totalCalls.toLocaleString()}
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem', marginTop: '0.4rem', fontSize: '0.75rem', color: 'var(--accent-emerald)' }}>
            <ArrowUpRight size={14} />
            <span>+18.4% vs last {timeRange}</span>
          </div>
        </div>

        {/* Metric 2 */}
        <div className="glass-card" style={{ padding: '1.25rem' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', color: 'var(--text-dim)', marginBottom: '0.5rem' }}>
            <span style={{ fontSize: '0.78rem', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Talk Time</span>
            <Clock size={18} color="var(--accent-cyan)" />
          </div>
          <div style={{ fontSize: '1.8rem', fontWeight: 800, color: 'var(--text-main)', fontFamily: 'var(--font-mono)' }}>
            {(totalDurationMinutes / 60).toFixed(1)} hrs
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem', marginTop: '0.4rem', fontSize: '0.75rem', color: 'var(--text-muted)' }}>
            <span>Avg 4m 12s per connected call</span>
          </div>
        </div>

        {/* Metric 3 */}
        <div className="glass-card" style={{ padding: '1.25rem' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', color: 'var(--text-dim)', marginBottom: '0.5rem' }}>
            <span style={{ fontSize: '0.78rem', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Connection Rate</span>
            <CheckCircle2 size={18} color="var(--accent-emerald)" />
          </div>
          <div style={{ fontSize: '1.8rem', fontWeight: 800, color: 'var(--accent-emerald)', fontFamily: 'var(--font-mono)' }}>
            {connectRate}%
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem', marginTop: '0.4rem', fontSize: '0.75rem', color: 'var(--accent-emerald)' }}>
            <ArrowUpRight size={14} />
            <span>+5.1% above industry avg</span>
          </div>
        </div>

        {/* Metric 4 */}
        <div className="glass-card" style={{ padding: '1.25rem' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', color: 'var(--text-dim)', marginBottom: '0.5rem' }}>
            <span style={{ fontSize: '0.78rem', textTransform: 'uppercase', letterSpacing: '0.5px' }}>WhatsApp Outreach</span>
            <MessageSquare size={18} color="#25d366" />
          </div>
          <div style={{ fontSize: '1.8rem', fontWeight: 800, color: 'var(--text-main)', fontFamily: 'var(--font-mono)' }}>
            342
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem', marginTop: '0.4rem', fontSize: '0.75rem', color: '#25d366' }}>
            <ArrowUpRight size={14} />
            <span>94% read rate within 10m</span>
          </div>
        </div>

        {/* Metric 5 */}
        <div className="glass-card" style={{ padding: '1.25rem' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', color: 'var(--text-dim)', marginBottom: '0.5rem' }}>
            <span style={{ fontSize: '0.78rem', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Deals Influenced</span>
            <DollarSign size={18} color="var(--accent-amber)" />
          </div>
          <div style={{ fontSize: '1.8rem', fontWeight: 800, color: 'var(--accent-amber)', fontFamily: 'var(--font-mono)' }}>
            $584,000
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem', marginTop: '0.4rem', fontSize: '0.75rem', color: 'var(--accent-emerald)' }}>
            <ArrowUpRight size={14} />
            <span>12 Closed Won this month</span>
          </div>
        </div>

        {/* Metric 6 */}
        <div className="glass-card" style={{ padding: '1.25rem' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', color: 'var(--text-dim)', marginBottom: '0.5rem' }}>
            <span style={{ fontSize: '0.78rem', textTransform: 'uppercase', letterSpacing: '0.5px' }}>AI Sentiment Score</span>
            <Sparkles size={18} color="var(--primary)" />
          </div>
          <div style={{ fontSize: '1.8rem', fontWeight: 800, color: 'var(--primary)', fontFamily: 'var(--font-mono)' }}>
            89%
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem', marginTop: '0.4rem', fontSize: '0.75rem', color: 'var(--text-muted)' }}>
            <span>Whisper NLP analysis</span>
          </div>
        </div>
      </div>

      {/* Main Charts & Analytics Row */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(420px, 1fr))', gap: '1.5rem' }}>
        {/* Hourly Call Volume Area Chart */}
        <div className="glass-panel" style={{ padding: '1.5rem', display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <h3 style={{ fontSize: '1.1rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>
                Peak Calling Activity by Hour
              </h3>
              <p style={{ fontSize: '0.78rem', color: 'var(--text-dim)', marginTop: '2px' }}>
                Golden connect windows: 10:00 AM - 11:30 AM & 2:30 PM - 4:00 PM
              </p>
            </div>
            <span className="glass-pill" style={{ color: 'var(--accent-cyan)', fontSize: '0.72rem' }}>
              Live Telemetry
            </span>
          </div>

          {/* SVG Smooth Area Chart */}
          <div style={{ width: '100%', height: '220px', position: 'relative' }}>
            <svg viewBox="0 0 500 200" style={{ width: '100%', height: '100%', overflow: 'visible' }}>
              <defs>
                <linearGradient id="callGradient" x1="0%" y1="0%" x2="0%" y2="100%">
                  <stop offset="0%" stopColor="var(--primary)" stopOpacity="0.45" />
                  <stop offset="100%" stopColor="var(--primary)" stopOpacity="0.0" />
                </linearGradient>
                <linearGradient id="waGradient" x1="0%" y1="0%" x2="0%" y2="100%">
                  <stop offset="0%" stopColor="#10b981" stopOpacity="0.35" />
                  <stop offset="100%" stopColor="#10b981" stopOpacity="0.0" />
                </linearGradient>
              </defs>

              {/* Grid Lines */}
              <line x1="0" y1="40" x2="500" y2="40" stroke="var(--border-subtle)" strokeDasharray="4" />
              <line x1="0" y1="90" x2="500" y2="90" stroke="var(--border-subtle)" strokeDasharray="4" />
              <line x1="0" y1="140" x2="500" y2="140" stroke="var(--border-subtle)" strokeDasharray="4" />
              <line x1="0" y1="180" x2="500" y2="180" stroke="var(--border-subtle)" />

              {/* Area 1: Calls */}
              <path
                d="M 0 160 Q 50 140 100 80 T 200 45 T 300 110 T 400 35 T 500 90 L 500 180 L 0 180 Z"
                fill="url(#callGradient)"
              />
              <path
                d="M 0 160 Q 50 140 100 80 T 200 45 T 300 110 T 400 35 T 500 90"
                fill="none"
                stroke="var(--primary)"
                strokeWidth="3"
              />

              {/* Area 2: WhatsApp */}
              <path
                d="M 0 170 Q 60 150 120 120 T 220 90 T 320 80 T 420 60 T 500 120 L 500 180 L 0 180 Z"
                fill="url(#waGradient)"
              />
              <path
                d="M 0 170 Q 60 150 120 120 T 220 90 T 320 80 T 420 60 T 500 120"
                fill="none"
                stroke="#10b981"
                strokeWidth="2"
              />

              {/* Marker points */}
              <circle cx="200" cy="45" r="5" fill="var(--primary)" stroke="#fff" strokeWidth="2" />
              <circle cx="400" cy="35" r="5" fill="var(--primary)" stroke="#fff" strokeWidth="2" />
            </svg>

            {/* X-Axis labels */}
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.72rem', color: 'var(--text-dim)', marginTop: '8px' }}>
              <span>8 AM</span>
              <span>10 AM</span>
              <span>12 PM</span>
              <span>2 PM</span>
              <span>4 PM</span>
              <span>6 PM</span>
            </div>
          </div>

          <div style={{ display: 'flex', gap: '1.25rem', justifyContent: 'center', fontSize: '0.78rem' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              <div style={{ width: '10px', height: '10px', borderRadius: '2px', background: 'var(--primary)' }} />
              <span style={{ color: 'var(--text-muted)' }}>Voice Calls</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              <div style={{ width: '10px', height: '10px', borderRadius: '2px', background: '#10b981' }} />
              <span style={{ color: 'var(--text-muted)' }}>WhatsApp Chats</span>
            </div>
          </div>
        </div>

        {/* Call Disposition & AI Coaching Widget */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          {/* Disposition Breakdown */}
          <div className="glass-panel" style={{ padding: '1.25rem' }}>
            <h3 style={{ fontSize: '1rem', fontWeight: 700, margin: '0 0 0.85rem', color: 'var(--text-main)' }}>
              Call Dispositions & Outcomes
            </h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
              {[
                { label: 'Demo Booked / Qualified', count: 48, pct: 42, color: 'var(--accent-emerald)' },
                { label: 'Follow-up Scheduled', count: 32, pct: 28, color: 'var(--accent-cyan)' },
                { label: 'Gatekeeper Reached', count: 18, pct: 16, color: 'var(--accent-amber)' },
                { label: 'Voicemail / No Answer', count: 16, pct: 14, color: 'var(--text-dim)' }
              ].map((item, idx) => (
                <div key={idx}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.8rem', marginBottom: '4px' }}>
                    <span style={{ color: 'var(--text-muted)' }}>{item.label}</span>
                    <span style={{ fontWeight: 600, color: 'var(--text-main)' }}>{item.count} calls ({item.pct}%)</span>
                  </div>
                  <div style={{ height: '6px', background: 'var(--border-subtle)', borderRadius: '3px', overflow: 'hidden' }}>
                    <div style={{ width: `${item.pct}%`, height: '100%', background: item.color, borderRadius: '3px' }} />
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* AI Sales Coach Alerts */}
          <div className="glass-panel" style={{ padding: '1.25rem', borderLeft: '4px solid var(--accent-amber)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.5rem' }}>
              <Sparkles size={16} color="var(--accent-amber)" />
              <h4 style={{ margin: 0, fontSize: '0.9rem', fontWeight: 700, color: 'var(--text-main)' }}>
                AI Proactive Coaching Signals
              </h4>
            </div>
            <p style={{ fontSize: '0.82rem', color: 'var(--text-muted)', lineHeight: 1.45 }}>
              ⚡ <strong>Objection Alert:</strong> 3 calls this morning flagged price hesitation regarding annual commitments. RingVia360 auto-dispatched the <em>Q3 ROI Battlecard</em> to reps.
            </p>
          </div>
        </div>
      </div>

      {/* Live Recent Activity Feed Preview */}
      <div className="glass-panel" style={{ padding: '1.5rem' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem' }}>
          <div>
            <h3 style={{ fontSize: '1.15rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>
              Live Telemetry Feed (Real-Time Ingestion)
            </h3>
            <p style={{ fontSize: '0.8rem', color: 'var(--text-dim)', marginTop: '2px' }}>
              Click any call to open the encrypted audio recording player and AI Whisper transcript.
            </p>
          </div>
          <span className="glass-pill" style={{ color: 'var(--accent-emerald)', fontSize: '0.75rem' }}>
            <span className="live-dot" /> Cloud Telemetry Connected
          </span>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
          {calls.slice(0, 4).map(call => (
            <div
              key={call.id}
              onClick={() => setActiveAudioCall(call)}
              className="glass-card glass-card-interactive"
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                padding: '0.9rem 1.25rem',
                gap: '1rem',
                flexWrap: 'wrap'
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                <span className={`glass-pill ${
                  call.direction === 'inbound' ? 'badge-inbound' :
                  call.direction === 'outbound' ? 'badge-outbound' : 'badge-missed'
                }`}>
                  {call.direction.toUpperCase()}
                </span>

                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                    <span style={{ fontWeight: 700, fontSize: '0.95rem', color: 'var(--text-main)' }}>
                      {call.contactName}
                    </span>
                    <span style={{ fontSize: '0.8rem', color: 'var(--text-dim)' }}>
                      • {call.company}
                    </span>
                  </div>
                  <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)', marginTop: '2px' }}>
                    Rep: {call.repName} • Duration: {Math.floor(call.duration / 60)}m {call.duration % 60}s • {call.outcome}
                  </div>
                </div>
              </div>

              <div style={{ display: 'flex', alignItems: 'center', gap: '0.85rem' }}>
                <span className={`glass-pill ${
                  call.sentiment === 'positive' ? 'badge-sentiment-pos' :
                  call.sentiment === 'neutral' ? 'badge-sentiment-neu' : 'badge-sentiment-neg'
                }`}>
                  {call.sentiment.toUpperCase()} ({call.sentimentScore}%)
                </span>

                <span className="glass-pill" style={{ fontSize: '0.75rem', color: 'var(--accent-emerald)' }}>
                  ✓ {call.crmType}
                </span>

                <button
                  className="btn-ghost"
                  style={{
                    padding: '0.35rem 0.65rem',
                    background: 'var(--primary-subtle)',
                    color: 'var(--primary)',
                    borderRadius: 'var(--radius-sm)',
                    fontSize: '0.75rem',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '4px'
                  }}
                >
                  <Play size={12} fill="var(--primary)" /> Listen
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
