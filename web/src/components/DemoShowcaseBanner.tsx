import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Sparkles,
  ShieldCheck,
  PhoneCall,
  Share2,
  TrendingUp,
  Cpu,
  LogIn,
  ArrowRight,
  Info,
  ChevronDown,
  ChevronUp,
  CheckCircle2
} from 'lucide-react';

export const DemoShowcaseBanner: React.FC = () => {
  const navigate = useNavigate();
  const [isDetailsOpen, setIsDetailsOpen] = useState(false);

  return (
    <div
      className="glass-card"
      style={{
        padding: '1.5rem 1.75rem',
        borderRadius: 'var(--radius-lg)',
        border: '1px solid rgba(124, 58, 237, 0.4)',
        background: 'linear-gradient(135deg, rgba(124, 58, 237, 0.12) 0%, rgba(15, 23, 42, 0.95) 50%, rgba(6, 182, 212, 0.08) 100%)',
        position: 'relative',
        overflow: 'hidden'
      }}
    >
      {/* Decorative ambient gradient backdrop */}
      <div
        style={{
          position: 'absolute',
          top: '-40px',
          right: '-40px',
          width: '240px',
          height: '240px',
          borderRadius: '50%',
          background: 'radial-gradient(circle, rgba(124, 58, 237, 0.25) 0%, transparent 70%)',
          filter: 'blur(30px)',
          pointerEvents: 'none'
        }}
      />

      <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem', position: 'relative', zIndex: 1 }}>
        {/* Top Header Row */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '1rem' }}>
          <div style={{ maxWidth: '820px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '0.45rem', flexWrap: 'wrap' }}>
              <span
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '5px',
                  padding: '4px 10px',
                  borderRadius: '20px',
                  background: 'rgba(124, 58, 237, 0.2)',
                  border: '1px solid rgba(124, 58, 237, 0.45)',
                  color: '#c084fc',
                  fontSize: '0.74rem',
                  fontWeight: 800,
                  letterSpacing: '0.5px'
                }}
              >
                <Sparkles size={12} /> INTERACTIVE PRODUCT EVALUATION
              </span>
              <span
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '5px',
                  padding: '4px 10px',
                  borderRadius: '20px',
                  background: 'rgba(16, 185, 129, 0.15)',
                  border: '1px solid rgba(16, 185, 129, 0.35)',
                  color: 'var(--accent-emerald)',
                  fontSize: '0.74rem',
                  fontWeight: 700
                }}
              >
                <ShieldCheck size={12} /> Sanitized Sample Data • Zero Private Telemetry Exposed
              </span>
            </div>

            <h2 style={{ fontSize: '1.45rem', fontWeight: 800, margin: '0 0 0.35rem 0', color: 'var(--text-main)', letterSpacing: '-0.3px' }}>
              Experience RingVia360 — Real-time Call & WhatsApp Telemetry for Modern Sales Teams
            </h2>

            <p style={{ color: 'var(--text-secondary)', fontSize: '0.88rem', lineHeight: 1.55, margin: 0 }}>
              You are exploring the live interactive product demonstration. Test audio recordings, examine automated Whisper AI transcripts, and observe seamless CRM synchronization with sample enterprise leads below.
            </p>
          </div>

          {/* Action CTAs */}
          <div style={{ display: 'flex', gap: '0.65rem', flexWrap: 'wrap', alignItems: 'center' }}>
            <button
              onClick={() => navigate('/signup')}
              className="btn-primary"
              style={{
                padding: '0.6rem 1.25rem',
                borderRadius: '8px',
                fontSize: '0.84rem',
                fontWeight: 700,
                display: 'inline-flex',
                alignItems: 'center',
                gap: '6px',
                boxShadow: '0 4px 14px var(--primary-glow)'
              }}
            >
              Start 14-Day Free Pilot <ArrowRight size={14} />
            </button>
            <button
              onClick={() => navigate('/login')}
              className="btn-secondary"
              style={{
                padding: '0.6rem 1.15rem',
                borderRadius: '8px',
                fontSize: '0.84rem',
                fontWeight: 600,
                display: 'inline-flex',
                alignItems: 'center',
                gap: '6px'
              }}
            >
              <LogIn size={14} /> Sign In
            </button>
            <button
              onClick={() => setIsDetailsOpen(!isDetailsOpen)}
              className="btn-ghost"
              style={{
                padding: '0.6rem 0.85rem',
                borderRadius: '8px',
                fontSize: '0.8rem',
                color: 'var(--text-muted)',
                display: 'inline-flex',
                alignItems: 'center',
                gap: '4px'
              }}
            >
              <Info size={14} />
              <span>{isDetailsOpen ? 'Hide Services Overview' : 'Our Services & Architecture'}</span>
              {isDetailsOpen ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
            </button>
          </div>
        </div>

        {/* 4 Core Pillars Overview Cards */}
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
            gap: '0.75rem',
            marginTop: '0.5rem'
          }}
        >
          {/* Service 1 */}
          <div
            style={{
              padding: '0.85rem 1rem',
              borderRadius: 'var(--radius-md)',
              background: 'rgba(255, 255, 255, 0.03)',
              border: '1px solid rgba(255, 255, 255, 0.07)'
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '7px', marginBottom: '0.25rem' }}>
              <PhoneCall size={15} color="var(--primary)" />
              <span style={{ fontWeight: 700, fontSize: '0.82rem', color: 'var(--text-main)' }}>
                Dual-SIM Telemetry
              </span>
            </div>
            <p style={{ margin: 0, fontSize: '0.74rem', color: 'var(--text-dim)', lineHeight: 1.45 }}>
              Hardware-enforced Knox & CallKit isolation. Only enterprise SIM calls are captured; personal SIM calls remain 100% private.
            </p>
          </div>

          {/* Service 2 */}
          <div
            style={{
              padding: '0.85rem 1rem',
              borderRadius: 'var(--radius-md)',
              background: 'rgba(255, 255, 255, 0.03)',
              border: '1px solid rgba(255, 255, 255, 0.07)'
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '7px', marginBottom: '0.25rem' }}>
              <Cpu size={15} color="var(--accent-cyan)" />
              <span style={{ fontWeight: 700, fontSize: '0.82rem', color: 'var(--text-main)' }}>
                Whisper AI Transcription
              </span>
            </div>
            <p style={{ margin: 0, fontSize: '0.74rem', color: 'var(--text-dim)', lineHeight: 1.45 }}>
              Automatic speech-to-text, speaker identification, and NLP sentiment analysis in 90+ regional and global languages.
            </p>
          </div>

          {/* Service 3 */}
          <div
            style={{
              padding: '0.85rem 1rem',
              borderRadius: 'var(--radius-md)',
              background: 'rgba(255, 255, 255, 0.03)',
              border: '1px solid rgba(255, 255, 255, 0.07)'
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '7px', marginBottom: '0.25rem' }}>
              <Share2 size={15} color="#10b981" />
              <span style={{ fontWeight: 700, fontSize: '0.82rem', color: 'var(--text-main)' }}>
                Automated CRM Sync
              </span>
            </div>
            <p style={{ margin: 0, fontSize: '0.74rem', color: 'var(--text-dim)', lineHeight: 1.45 }}>
              Two-way zero-delay sync attaching audio recordings, notes, and deal stages into Salesforce, HubSpot, Zoho, and RingVia360 CRM.
            </p>
          </div>

          {/* Service 4 */}
          <div
            style={{
              padding: '0.85rem 1rem',
              borderRadius: 'var(--radius-md)',
              background: 'rgba(255, 255, 255, 0.03)',
              border: '1px solid rgba(255, 255, 255, 0.07)'
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '7px', marginBottom: '0.25rem' }}>
              <TrendingUp size={15} color="var(--accent-amber)" />
              <span style={{ fontWeight: 700, fontSize: '0.82rem', color: 'var(--text-main)' }}>
                Pipeline Value Attribution
              </span>
            </div>
            <p style={{ margin: 0, fontSize: '0.74rem', color: 'var(--text-dim)', lineHeight: 1.45 }}>
              Correlates rep talk time and contact touchpoints directly to influenced pipeline value and closed-won revenue.
            </p>
          </div>
        </div>

        {/* Expandable Enterprise Capabilities Deep-Dive */}
        {isDetailsOpen && (
          <div
            style={{
              marginTop: '0.5rem',
              padding: '1.25rem',
              borderRadius: 'var(--radius-md)',
              background: 'rgba(0, 0, 0, 0.35)',
              border: '1px solid rgba(124, 58, 237, 0.25)',
              display: 'flex',
              flexDirection: 'column',
              gap: '0.75rem'
            }}
          >
            <div style={{ fontWeight: 700, fontSize: '0.9rem', color: 'var(--text-main)' }}>
              Why Leading Enterprise Sales Organizations Partner with RingVia360:
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '0.75rem' }}>
              <div style={{ display: 'flex', gap: '8px', fontSize: '0.8rem', color: 'var(--text-secondary)' }}>
                <CheckCircle2 size={16} color="var(--accent-emerald)" style={{ flexShrink: 0, marginTop: '2px' }} />
                <span><strong>No App Switching for Reps:</strong> Reps make and receive calls on their native mobile dialer. Zero manual data entry required.</span>
              </div>
              <div style={{ display: 'flex', gap: '8px', fontSize: '0.8rem', color: 'var(--text-secondary)' }}>
                <CheckCircle2 size={16} color="var(--accent-emerald)" style={{ flexShrink: 0, marginTop: '2px' }} />
                <span><strong>Zero-Leak Sovereign Workspaces:</strong> Multi-tenant database isolation ensures each customer organization owns their sovereign encryption keys.</span>
              </div>
              <div style={{ display: 'flex', gap: '8px', fontSize: '0.8rem', color: 'var(--text-secondary)' }}>
                <CheckCircle2 size={16} color="var(--accent-emerald)" style={{ flexShrink: 0, marginTop: '2px' }} />
                <span><strong>WhatsApp Business Telemetry:</strong> Automatically logs client WhatsApp outreach, message delivery rates, and response times.</span>
              </div>
              <div style={{ display: 'flex', gap: '8px', fontSize: '0.8rem', color: 'var(--text-secondary)' }}>
                <CheckCircle2 size={16} color="var(--accent-emerald)" style={{ flexShrink: 0, marginTop: '2px' }} />
                <span><strong>DPDP & GDPR Compliance:</strong> Granular consent disclaimers, automatic PII redaction, and audited data retention policies.</span>
              </div>
            </div>
            <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '0.5rem' }}>
              <button
                onClick={() => navigate('/contact')}
                className="btn-ghost"
                style={{ fontSize: '0.8rem', color: 'var(--primary)', textDecoration: 'underline' }}
              >
                Contact Enterprise Architecture Team for a Custom Evaluation →
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
