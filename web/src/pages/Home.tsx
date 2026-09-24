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
  Lock,
  Award
} from 'lucide-react';
import { useApp } from '../context/AppContext';

const ICON_MAP: Record<string, React.ReactNode> = {
  ShieldCheck: <ShieldCheck size={22} color="var(--accent-cyan)" />,
  Lock: <Lock size={22} color="#fb7185" />,
  Sparkles: <Sparkles size={22} color="var(--primary)" />,
  MessageCircle: <Zap size={22} color="#25d366" />,
  RefreshCw: <Share2 size={22} color="var(--accent-emerald)" />,
  Award: <Award size={22} color="#f59e0b" />,
};

export default function Home() {
  const { setIsSimulatorOpen, getPageSection } = useApp();

  // Fetch dynamic sections from DB (falls back to defaultSitePages in AppContext)
  const hero = getPageSection('home', 'hero');
  const stats = getPageSection('home', 'stats');
  const featuresHighlight = getPageSection('home', 'features_highlight');

  const heroData = hero?.data || {};
  const statsData = stats?.data || {};
  const featData = featuresHighlight?.data || {};

  const statItems: Array<{ value: string; label: string; desc: string }> = statsData.items || [
    { value: '99.8%', label: 'Automated Call Capture', desc: 'Zero manual rep logging required' },
    { value: '₹48.5L+', label: 'Daily Deal Volume Tracked', desc: 'Integrated CRM pipeline attribution' },
    { value: '45%', label: 'Productivity Increase', desc: 'Saved 1.5 hrs/rep/day in data entry' },
    { value: '100%', label: 'Knox E2EE Isolation', desc: 'Complete hardware privacy protection' }
  ];

  const featureCards: Array<{ icon: string; title: string; desc: string }> = featData.features || [
    { icon: 'ShieldCheck', title: 'Hardware Knox Dual-SIM Isolation', desc: 'Only business SIM activity is tracked. Personal SIM calls, SMS, and data remain 100% private.' },
    { icon: 'Lock', title: 'End-to-End Encrypted Call Audio', desc: 'All call recordings and transcripts are encrypted with AES-256 before leaving the mobile device.' },
    { icon: 'Sparkles', title: 'AI Sentiment & Waveform Pod', desc: 'Immediate post-call sentiment classification with interactive audio scrubbing.' },
    { icon: 'MessageCircle', title: 'Automated WhatsApp Dispatch', desc: 'Instantly dispatches corporate WhatsApp message templates with meeting links upon call wrap-up.' },
    { icon: 'RefreshCw', title: 'Bi-Directional CRM Sync', desc: 'Direct real-time webhooks sync to HubSpot, Zoho CRM, LeadSquared, and Freshsales.' }
  ];

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
          position: 'absolute', top: '-30%', left: '50%', transform: 'translateX(-50%)',
          width: '600px', height: '350px',
          background: 'radial-gradient(circle, var(--primary-glow) 0%, transparent 70%)',
          filter: 'blur(50px)', zIndex: 0, pointerEvents: 'none'
        }} />

        <div style={{ position: 'relative', zIndex: 1, maxWidth: '840px', margin: '0 auto' }}>
          {/* Badge */}
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: '0.5rem', marginBottom: '1.25rem' }} className="glass-pill">
            <Sparkles size={14} color="var(--primary)" />
            <span style={{ fontSize: '0.8rem', fontWeight: 600 }}>
              {heroData.badge || '⚡ ENTERPRISE TELEPHONY AUTOMATION 2026'}
            </span>
          </div>

          <h1 style={{
            fontSize: 'clamp(2.2rem, 5vw, 3.6rem)', fontWeight: 800,
            lineHeight: 1.15, letterSpacing: '-1.5px', color: 'var(--text-main)', marginBottom: '1.25rem'
          }}>
            {hero?.title ? (
              <span style={{
                background: 'linear-gradient(135deg, var(--primary) 0%, var(--accent-cyan) 100%)',
                WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent'
              }}>{hero.title}</span>
            ) : (
              <>
                Zero-Click Sales Activity Tracking,{' '}
                <span style={{
                  background: 'linear-gradient(135deg, var(--primary) 0%, var(--accent-cyan) 100%)',
                  WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent'
                }}>
                  Automated Calls, WhatsApp &amp; CRM Sync
                </span>
              </>
            )}
          </h1>

          <p style={{ fontSize: '1.1rem', color: 'var(--text-muted)', lineHeight: 1.6, maxWidth: '680px', margin: '0 auto 2rem' }}>
            {hero?.subtitle || 'Never ask sales reps to manually log another call or message. RingVia360 runs in the background of iOS and Android devices, encrypts audio, transcribes conversations with AI, and syncs directly to your CRM.'}
          </p>

          {hero?.body && (
            <p style={{ fontSize: '0.92rem', color: 'var(--text-dim)', lineHeight: 1.5, maxWidth: '600px', margin: '0 auto 1.5rem' }}>
              {hero.body}
            </p>
          )}

          {/* Trust Badge */}
          {heroData.trust_badge && (
            <div style={{ marginBottom: '1.5rem', fontSize: '0.82rem', color: 'var(--accent-emerald)', fontWeight: 600 }}>
              ✓ {heroData.trust_badge}
            </div>
          )}

          <div style={{ display: 'flex', justifyContent: 'center', gap: '1rem', flexWrap: 'wrap' }}>
            <Link to="/dashboard" className="btn-primary" style={{ padding: '0.85rem 1.8rem', fontSize: '1rem' }}>
              <TrendingUp size={18} />
              <span>{heroData.cta_primary || 'Open Executive Dashboard'}</span>
            </Link>
            <button
              onClick={() => setIsSimulatorOpen(true)}
              className="btn-secondary"
              style={{ padding: '0.85rem 1.6rem', fontSize: '1rem' }}
            >
              <Smartphone size={18} color="var(--accent-cyan)" />
              <span>{heroData.cta_secondary || 'Launch Mobile Dialer Simulator'}</span>
            </button>
            <Link to="/activities" className="btn-ghost" style={{ padding: '0.85rem 1.25rem' }}>
              <span>View Live Activity Stream</span>
              <ArrowRight size={16} />
            </Link>
          </div>
        </div>

        {/* Stats Ticker */}
        <div style={{
          marginTop: '3rem', paddingTop: '2rem',
          borderTop: '1px solid var(--border-subtle)',
          display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
          gap: '1.5rem', textAlign: 'center'
        }}>
          {statItems.map((stat, i) => (
            <div key={i}>
              <div style={{ fontSize: '1.8rem', fontWeight: 800, color: i === 0 ? 'var(--text-main)' : i === 1 ? 'var(--accent-emerald)' : i === 2 ? 'var(--accent-cyan)' : 'var(--primary)', fontFamily: 'var(--font-mono)' }}>
                {stat.value}
              </div>
              <div style={{ fontSize: '0.82rem', fontWeight: 600, color: 'var(--text-muted)', marginTop: '2px' }}>{stat.label}</div>
              <div style={{ fontSize: '0.72rem', color: 'var(--text-dim)', marginTop: '1px' }}>{stat.desc}</div>
            </div>
          ))}
        </div>
      </section>

      {/* Feature Highlights Grid */}
      <section>
        <div style={{ textAlign: 'center', marginBottom: '2.5rem' }}>
          <h2 style={{ fontSize: '2rem', fontWeight: 800, color: 'var(--text-main)' }}>
            {featuresHighlight?.title || 'Core Differentiators That Outperform Legacy Dialers'}
          </h2>
          <p style={{ color: 'var(--text-muted)', fontSize: '1rem', marginTop: '0.5rem' }}>
            {featuresHighlight?.subtitle || 'Enterprise compliance, automated CRM logging, and instant WhatsApp customer follow-up.'}
          </p>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '1.5rem' }}>
          {featureCards.map((feat, i) => (
            <div key={i} className="glass-card" style={{ padding: '1.75rem' }}>
              <div style={{
                width: '44px', height: '44px', borderRadius: '12px',
                background: 'var(--primary-subtle)',
                display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '1rem'
              }}>
                {ICON_MAP[feat.icon] || <Sparkles size={22} color="var(--primary)" />}
              </div>
              <h3 style={{ fontSize: '1.1rem', fontWeight: 700, marginBottom: '0.5rem', color: 'var(--text-main)' }}>
                {feat.title}
              </h3>
              <p style={{ fontSize: '0.88rem', color: 'var(--text-muted)', lineHeight: 1.55 }}>
                {feat.desc}
              </p>
            </div>
          ))}
        </div>
      </section>

      {/* Competitive Comparison Table */}
      <section className="glass-panel" style={{ padding: '2.5rem 2rem' }}>
        <div style={{ textAlign: 'center', marginBottom: '2rem' }}>
          <span className="glass-pill" style={{ color: 'var(--accent-cyan)' }}>Competitive Audit</span>
          <h2 style={{ fontSize: '1.8rem', fontWeight: 800, marginTop: '0.5rem', color: 'var(--text-main)' }}>
            Why Enterprise Teams Choose RingVia360
          </h2>
        </div>

        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', minWidth: '600px' }}>
            <thead>
              <tr style={{ borderBottom: '1px solid var(--border-glass)' }}>
                <th style={{ padding: '1rem', color: 'var(--text-dim)', fontSize: '0.85rem' }}>FEATURE CAPABILITY</th>
                <th style={{ padding: '1rem', color: 'var(--text-muted)', fontSize: '0.85rem' }}>LEGACY DIALERS</th>
                <th style={{ padding: '1rem', color: 'var(--primary)', fontSize: '0.85rem', fontWeight: 700 }}>RINGVIA360 ADVANCED</th>
              </tr>
            </thead>
            <tbody>
              {[
                { feature: 'Automatic Call & WhatsApp Logging', legacy: 'Basic mobile logger', rv: 'Zero-latency native background event engine' },
                { feature: 'Speech-to-Text Transcription', legacy: 'Third-party add-on', rv: 'Native Whisper AI diarization included' },
                { feature: 'AI Sentiment & Deal Health Scoring', legacy: 'Not available', rv: 'Automated deal risk & sentiment detection' },
                { feature: 'Dual-SIM Personal Privacy Isolation', legacy: 'Partial Android only', rv: 'Hardware-enforced SIM policy (iOS & Android)' },
                { feature: 'End-to-End Encryption (E2EE)', legacy: 'Server-side standard', rv: 'Client-side AES-256-GCM + Cloud KMS vault' },
                { feature: 'Two-Party Consent Enforcement', legacy: 'Manual rep note', rv: 'Automatic audio beep & consent compliance' },
                { feature: 'CRM Custom Field Mapping', legacy: 'Fixed templates', rv: 'Bi-directional visual schema mapper' },
                { feature: 'Interactive Rep Mobile Simulator', legacy: 'None', rv: 'Embedded in-browser test phone simulator' }
              ].map((row, idx) => (
                <tr key={idx} style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                  <td style={{ padding: '0.9rem 1rem', fontWeight: 600, color: 'var(--text-main)', fontSize: '0.88rem' }}>{row.feature}</td>
                  <td style={{ padding: '0.9rem 1rem', color: 'var(--text-dim)', fontSize: '0.84rem' }}>{row.legacy}</td>
                  <td style={{ padding: '0.9rem 1rem', color: 'var(--accent-emerald)', fontWeight: 600, fontSize: '0.86rem' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
                      <CheckCircle size={15} />
                      <span>{row.rv}</span>
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
