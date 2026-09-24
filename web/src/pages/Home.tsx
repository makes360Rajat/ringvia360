import React from 'react';
import { Link } from 'react-router-dom';
import {
  ShieldCheck,
  Zap,
  Sparkles,
  Smartphone,
  Share2,
  CheckCircle,
  ArrowRight,
  TrendingUp,
  Cpu,
  Lock,
  Headphones,
  Award
} from 'lucide-react';
import { useApp } from '../context/AppContext';

export default function Home() {
  const { setIsSimulatorOpen, calls } = useApp();

  return (
    <div style={{ padding: '1rem 1.5rem 4rem', maxWidth: '1280px', margin: '0 auto', display: 'flex', flexDirection: 'column', gap: '3.5rem' }}>
      {/* Hero Section */}
      <section className="glass-panel" style={{
        padding: '3.5rem 2rem',
        textAlign: 'center',
        position: 'relative',
        overflow: 'hidden',
        border: '1px solid var(--border-glass)',
        boxShadow: 'var(--shadow-glass)'
      }}>
        {/* Glowing Radial Backdrop */}
        <div style={{
          position: 'absolute',
          top: '-30%',
          left: '50%',
          transform: 'translateX(-50%)',
          width: '600px',
          height: '350px',
          background: 'radial-gradient(circle, var(--primary-glow) 0%, transparent 70%)',
          filter: 'blur(50px)',
          zIndex: 0,
          pointerEvents: 'none'
        }} />

        <div style={{ position: 'relative', zIndex: 1, maxWidth: '840px', margin: '0 auto' }}>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: '0.5rem', marginBottom: '1.25rem' }} className="glass-pill">
            <Sparkles size={14} color="var(--primary)" />
            <span style={{ fontSize: '0.8rem', fontWeight: 600 }}>Next-Gen Salestrail Alternative</span>
            <span style={{ color: 'var(--text-dim)' }}>•</span>
            <span style={{ color: 'var(--accent-emerald)', fontSize: '0.8rem' }}>AI & E2EE Powered</span>
          </div>

          <h1 style={{
            fontSize: 'clamp(2.4rem, 5vw, 3.8rem)',
            fontWeight: 800,
            lineHeight: 1.15,
            letterSpacing: '-1.5px',
            color: 'var(--text-main)',
            marginBottom: '1.25rem'
          }}>
            Zero-Click Sales Activity Tracking, <br />
            <span style={{
              background: 'linear-gradient(135deg, var(--primary) 0%, var(--accent-cyan) 100%)',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent'
            }}>
              Automated Calls, WhatsApp & CRM Sync
            </span>
          </h1>

          <p style={{
            fontSize: '1.15rem',
            color: 'var(--text-muted)',
            lineHeight: 1.6,
            maxWidth: '680px',
            margin: '0 auto 2.25rem'
          }}>
            Never ask sales reps to manually log another call or message. RingVia360 runs in the background of iOS and Android devices, encrypts audio, transcribes conversations with AI, and syncs directly to RingVia360 Cloud CRM, HubSpot, and custom webhooks.
          </p>

          <div style={{ display: 'flex', justifyContent: 'center', gap: '1rem', flexWrap: 'wrap' }}>
            <Link to="/dashboard" className="btn-primary" style={{ padding: '0.85rem 1.8rem', fontSize: '1rem' }}>
              <TrendingUp size={18} />
              <span>Open Executive Dashboard</span>
            </Link>

            <button
              onClick={() => setIsSimulatorOpen(true)}
              className="btn-secondary"
              style={{ padding: '0.85rem 1.6rem', fontSize: '1rem' }}
            >
              <Smartphone size={18} color="var(--accent-cyan)" />
              <span>Launch Mobile Dialer Simulator</span>
            </button>

            <Link to="/activities" className="btn-ghost" style={{ padding: '0.85rem 1.25rem' }}>
              <span>View Live Activity Stream</span>
              <ArrowRight size={16} />
            </Link>
          </div>
        </div>

        {/* Live Metrics Ticker Banner */}
        <div style={{
          marginTop: '3rem',
          paddingTop: '2rem',
          borderTop: '1px solid var(--border-subtle)',
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
          gap: '1.5rem',
          textAlign: 'center'
        }}>
          <div>
            <div style={{ fontSize: '1.8rem', fontWeight: 800, color: 'var(--text-main)', fontFamily: 'var(--font-mono)' }}>
              100%
            </div>
            <div style={{ fontSize: '0.82rem', color: 'var(--text-dim)', marginTop: '2px' }}>
              Zero Rep Manual Entry
            </div>
          </div>
          <div>
            <div style={{ fontSize: '1.8rem', fontWeight: 800, color: 'var(--accent-emerald)', fontFamily: 'var(--font-mono)' }}>
              &lt; 150ms
            </div>
            <div style={{ fontSize: '0.82rem', color: 'var(--text-dim)', marginTop: '2px' }}>
              Bi-directional CRM Sync
            </div>
          </div>
          <div>
            <div style={{ fontSize: '1.8rem', fontWeight: 800, color: 'var(--accent-cyan)', fontFamily: 'var(--font-mono)' }}>
              AES-256
            </div>
            <div style={{ fontSize: '0.82rem', color: 'var(--text-dim)', marginTop: '2px' }}>
              Hardware-backed E2EE
            </div>
          </div>
          <div>
            <div style={{ fontSize: '1.8rem', fontWeight: 800, color: 'var(--primary)', fontFamily: 'var(--font-mono)' }}>
              Dual-SIM
            </div>
            <div style={{ fontSize: '0.82rem', color: 'var(--text-dim)', marginTop: '2px' }}>
              Personal Call Isolation
            </div>
          </div>
        </div>
      </section>

      {/* Feature Highlights Grid */}
      <section>
        <div style={{ textAlign: 'center', marginBottom: '2.5rem' }}>
          <h2 style={{ fontSize: '2rem', fontWeight: 800, color: 'var(--text-main)' }}>
            Engineered Beyond Traditional Sales Loggers
          </h2>
          <p style={{ color: 'var(--text-muted)', fontSize: '1rem', marginTop: '0.5rem' }}>
            Built for enterprise security, rep adoption, and instant executive visibility.
          </p>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '1.5rem' }}>
          {/* Card 1 */}
          <div className="glass-card" style={{ padding: '1.75rem' }}>
            <div style={{
              width: '44px',
              height: '44px',
              borderRadius: '12px',
              background: 'rgba(6, 182, 212, 0.15)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              marginBottom: '1rem'
            }}>
              <Smartphone size={22} color="var(--accent-cyan)" />
            </div>
            <h3 style={{ fontSize: '1.2rem', fontWeight: 700, marginBottom: '0.5rem', color: 'var(--text-main)' }}>
              Native Background Telephony SDK
            </h3>
            <p style={{ fontSize: '0.9rem', color: 'var(--text-muted)', lineHeight: 1.5 }}>
              Runs seamlessly on Android Knox and iOS CallKit. Detects inbound, outbound, and missed calls with zero battery drain and complete dual-SIM privacy separation.
            </p>
          </div>

          {/* Card 2 */}
          <div className="glass-card" style={{ padding: '1.75rem' }}>
            <div style={{
              width: '44px',
              height: '44px',
              borderRadius: '12px',
              background: 'rgba(37, 211, 102, 0.15)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              marginBottom: '1rem'
            }}>
              <Zap size={22} color="#25d366" />
            </div>
            <h3 style={{ fontSize: '1.2rem', fontWeight: 700, marginBottom: '0.5rem', color: 'var(--text-main)' }}>
              WhatsApp Business Intelligence
            </h3>
            <p style={{ fontSize: '0.9rem', color: 'var(--text-muted)', lineHeight: 1.5 }}>
              Track text message volume, attachments, response times, and client sentiment without disrupting the rep’s chat experience or sharing personal conversations.
            </p>
          </div>

          {/* Card 3 */}
          <div className="glass-card" style={{ padding: '1.75rem' }}>
            <div style={{
              width: '44px',
              height: '44px',
              borderRadius: '12px',
              background: 'var(--primary-subtle)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              marginBottom: '1rem'
            }}>
              <Sparkles size={22} color="var(--primary)" />
            </div>
            <h3 style={{ fontSize: '1.2rem', fontWeight: 700, marginBottom: '0.5rem', color: 'var(--text-main)' }}>
              AI Transcripts & Deal Sentiment
            </h3>
            <p style={{ fontSize: '0.9rem', color: 'var(--text-muted)', lineHeight: 1.5 }}>
              Powered by Whisper & Gemini AI: turns recordings into instant transcripts, extracts action items, detects buyer hesitation, and updates deal health scores.
            </p>
          </div>

          {/* Card 4 */}
          <div className="glass-card" style={{ padding: '1.75rem' }}>
            <div style={{
              width: '44px',
              height: '44px',
              borderRadius: '12px',
              background: 'rgba(16, 185, 129, 0.15)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              marginBottom: '1rem'
            }}>
              <Share2 size={22} color="var(--accent-emerald)" />
            </div>
            <h3 style={{ fontSize: '1.2rem', fontWeight: 700, marginBottom: '0.5rem', color: 'var(--text-main)' }}>
              Universal CRM Sync Pipeline
            </h3>
            <p style={{ fontSize: '0.9rem', color: 'var(--text-muted)', lineHeight: 1.5 }}>
              Plug-and-play connectors for RingVia360 CRM, HubSpot, Zoho, and real-time Webhooks with guaranteed delivery, automated retry queues, and flexible field mapping.
            </p>
          </div>

          {/* Card 5 */}
          <div className="glass-card" style={{ padding: '1.75rem' }}>
            <div style={{
              width: '44px',
              height: '44px',
              borderRadius: '12px',
              background: 'rgba(244, 63, 94, 0.15)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              marginBottom: '1rem'
            }}>
              <Lock size={22} color="#fb7185" />
            </div>
            <h3 style={{ fontSize: '1.2rem', fontWeight: 700, marginBottom: '0.5rem', color: 'var(--text-main)' }}>
              Bank-Grade E2EE & Compliance
            </h3>
            <p style={{ fontSize: '0.9rem', color: 'var(--text-muted)', lineHeight: 1.5 }}>
              End-to-end encrypted audio storage, Cloud KMS master keys, two-party consent beep automation, and GDPR right-to-erasure workflows out of the box.
            </p>
          </div>

          {/* Card 6 */}
          <div className="glass-card" style={{ padding: '1.75rem' }}>
            <div style={{
              width: '44px',
              height: '44px',
              borderRadius: '12px',
              background: 'rgba(245, 158, 11, 0.15)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              marginBottom: '1rem'
            }}>
              <Award size={22} color="#f59e0b" />
            </div>
            <h3 style={{ fontSize: '1.2rem', fontWeight: 700, marginBottom: '0.5rem', color: 'var(--text-main)' }}>
              Gamified Rep Leaderboard
            </h3>
            <p style={{ fontSize: '0.9rem', color: 'var(--text-muted)', lineHeight: 1.5 }}>
              Inspire healthy competition with activity streak counters, conversion velocity trophies, and live device telemetry for sales directors.
            </p>
          </div>
        </div>
      </section>

      {/* Salestrail vs RingVia360 Feature Matrix */}
      <section className="glass-panel" style={{ padding: '2.5rem 2rem' }}>
        <div style={{ textAlign: 'center', marginBottom: '2rem' }}>
          <span className="glass-pill" style={{ color: 'var(--accent-cyan)' }}>Competitive Audit</span>
          <h2 style={{ fontSize: '1.8rem', fontWeight: 800, marginTop: '0.5rem' }}>
            Why Enterprise Teams Choose RingVia360 over Salestrail
          </h2>
        </div>

        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', minWidth: '600px' }}>
            <thead>
              <tr style={{ borderBottom: '1px solid var(--border-glass)' }}>
                <th style={{ padding: '1rem', color: 'var(--text-dim)', fontSize: '0.85rem' }}>FEATURE CAPABILITY</th>
                <th style={{ padding: '1rem', color: 'var(--text-muted)', fontSize: '0.85rem' }}>SALESTRAIL</th>
                <th style={{ padding: '1rem', color: 'var(--primary)', fontSize: '0.85rem', fontWeight: 700 }}>RINGVIA360 ADVANCED</th>
              </tr>
            </thead>
            <tbody>
              {[
                { feature: 'Automatic Call & WhatsApp Logging', salestrail: 'Basic mobile logger', ringvia: 'Zero-latency native background event engine' },
                { feature: 'Speech-to-Text Transcription', salestrail: 'Third-party add-on', ringvia: 'Native Whisper AI diarization included' },
                { feature: 'AI Sentiment & Deal Health Scoring', salestrail: 'Not available', ringvia: 'Automated deal risk & sentiment detection' },
                { feature: 'Dual-SIM Personal Privacy Isolation', salestrail: 'Partial Android only', ringvia: 'Hardware-enforced SIM policy (iOS & Android)' },
                { feature: 'End-to-End Encryption (E2EE)', salestrail: 'Server-side standard', ringvia: 'Client-side AES-256-GCM + Cloud KMS vault' },
                { feature: 'Two-Party Consent Enforcement', salestrail: 'Manual rep note', ringvia: 'Automatic audio beep & consent compliance' },
                { feature: 'CRM Custom Field Mapping', salestrail: 'Fixed templates', ringvia: 'Bi-directional visual schema mapper' },
                { feature: 'Interactive Rep Mobile Simulator', salestrail: 'None', ringvia: 'Embedded in-browser test phone simulator' }
              ].map((row, idx) => (
                <tr key={idx} style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                  <td style={{ padding: '1rem', fontWeight: 600, color: 'var(--text-main)', fontSize: '0.9rem' }}>
                    {row.feature}
                  </td>
                  <td style={{ padding: '1rem', color: 'var(--text-dim)', fontSize: '0.85rem' }}>
                    {row.salestrail}
                  </td>
                  <td style={{ padding: '1rem', color: 'var(--accent-emerald)', fontWeight: 600, fontSize: '0.88rem' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
                      <CheckCircle size={16} />
                      <span>{row.ringvia}</span>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
