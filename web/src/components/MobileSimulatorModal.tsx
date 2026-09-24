import React, { useState, useEffect } from 'react';
import {
  X,
  Phone,
  PhoneOff,
  Mic,
  MessageSquare,
  Shield,
  Check,
  Sparkles,
  Send,
  Smartphone,
  Signal,
  Wifi,
  Battery,
  PhoneIncoming,
  Radio,
  ExternalLink
} from 'lucide-react';
import { useApp } from '../context/AppContext';

export const MobileSimulatorModal: React.FC = () => {
  const { isSimulatorOpen, setIsSimulatorOpen, simulateNewCall, simulateWhatsAppMessage, playDtmfTone } = useApp();
  const [activeTab, setActiveTab] = useState<'dialer' | 'ringing' | 'in-call' | 'post-call' | 'whatsapp'>('dialer');
  const [dialNumber, setDialNumber] = useState('+91 98201 43210');
  const [contactName, setContactName] = useState('Aarav Sharma');
  const [companyName, setCompanyName] = useState('Tata Consultancy Services');
  const [callDuration, setCallDuration] = useState(0);
  const [callDirection, setCallDirection] = useState<'outbound' | 'inbound'>('outbound');
  const [simSlot, setSimSlot] = useState<'SIM 1 (Airtel)' | 'SIM 2 (Jio)'>('SIM 1 (Airtel)');

  // Post-call wrap-up form state
  const [outcome, setOutcome] = useState('Demo Completed - Contract Requested');
  const [callNotes, setCallNotes] = useState('Client requested 50 licenses pilot. Confirmed E2EE compliance and RingVia360 cloud sync.');
  const [sentiment, setSentiment] = useState<'positive' | 'neutral' | 'negative'>('positive');
  const [dealValue, setDealValue] = useState('1850000');

  // WhatsApp form state
  const [waText, setWaText] = useState('Hi Aarav, just sent over the RingVia360 portal access link!');

  // Timer for active call
  useEffect(() => {
    let interval: any;
    if (activeTab === 'in-call') {
      interval = setInterval(() => {
        setCallDuration(prev => prev + 1);
      }, 1000);
    }
    return () => clearInterval(interval);
  }, [activeTab]);

  if (!isSimulatorOpen) return null;

  const startCall = (dir: 'outbound' | 'inbound' = 'outbound') => {
    setCallDirection(dir);
    if (dir === 'inbound') {
      playDtmfTone('1');
      setContactName('Priya Patel');
      setCompanyName('Infosys Technologies');
      setDialNumber('+91 98111 22334');
      setActiveTab('ringing');
    } else {
      playDtmfTone('3');
      setCallDuration(1);
      setActiveTab('in-call');
    }
  };

  const answerCall = () => {
    playDtmfTone('5');
    setCallDuration(1);
    setActiveTab('in-call');
  };

  const declineCall = () => {
    setCallDuration(0);
    setOutcome('Missed Inbound Call - Follow-up Needed');
    setCallNotes('Customer reached out via corporate SIM 1 line. Call declined/missed.');
    setActiveTab('post-call');
  };

  const launchRealNativeCall = () => {
    playDtmfTone('9');
    const clean = dialNumber.replace(/[^0-9+]/g, '');
    try {
      window.location.href = `tel:${clean}`;
    } catch (_) {}
    // Also initiate in-app tracking
    setCallDirection('outbound');
    setCallDuration(1);
    setActiveTab('in-call');
  };

  const endCall = () => {
    setActiveTab('post-call');
  };

  const submitPostCall = () => {
    simulateNewCall({
      contactName: contactName || 'Prospect Contact',
      phoneNumber: dialNumber || '+1 (415) 555-0199',
      company: companyName || 'Enterprise Partner',
      direction: callDirection,
      duration: Math.max(callDuration, 45),
      outcome,
      notes: callNotes,
      sentiment,
      dealValue: parseInt(dealValue, 10) || 12000,
      dealStage: outcome.includes('Contract') ? 'Closed Won' : 'Proposal'
    });
    setActiveTab('dialer');
    setCallDuration(0);
    setIsSimulatorOpen(false);
  };

  const sendWhatsApp = () => {
    if (!waText.trim()) return;
    simulateWhatsAppMessage({
      contactName: contactName || 'Key Account',
      phoneNumber: dialNumber,
      company: companyName,
      lastMessage: waText,
      sentiment: 'positive'
    });
    setWaText('');
    setIsSimulatorOpen(false);
  };

  const formatTimer = (sec: number) => {
    const mins = Math.floor(sec / 60);
    const secs = sec % 60;
    return `${mins < 10 ? '0' : ''}${mins}:${secs < 10 ? '0' : ''}${secs}`;
  };

  return (
    <div style={{
      position: 'fixed',
      inset: 0,
      backgroundColor: 'rgba(5, 7, 15, 0.82)',
      backdropFilter: 'blur(12px)',
      WebkitBackdropFilter: 'blur(12px)',
      zIndex: 120,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      padding: '1rem'
    }}>
      {/* Phone Hardware Shell */}
      <div style={{
        width: '380px',
        height: '750px',
        maxHeight: '94vh',
        background: '#090a10',
        borderRadius: '48px',
        border: '10px solid #232738',
        boxShadow: '0 30px 80px rgba(0,0,0,0.9), 0 0 50px var(--primary-glow)',
        display: 'flex',
        flexDirection: 'column',
        position: 'relative',
        overflow: 'hidden',
        color: '#f8fafc'
      }}>
        {/* Dynamic Island / Speaker Notch */}
        <div style={{
          position: 'absolute',
          top: '10px',
          left: '50%',
          transform: 'translateX(-50%)',
          width: '120px',
          height: '24px',
          background: '#000',
          borderRadius: '20px',
          zIndex: 50,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: '8px'
        }}>
          <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#1c1c1e' }} />
          <div style={{ width: '40px', height: '4px', borderRadius: '4px', background: '#1c1c1e' }} />
        </div>

        {/* Status Bar */}
        <div style={{
          padding: '12px 24px 8px',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          fontSize: '0.75rem',
          fontWeight: 600,
          color: '#cbd5e1',
          zIndex: 40
        }}>
          <span>9:41</span>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <Signal size={13} />
            <Wifi size={13} />
            <Battery size={15} />
          </div>
        </div>

        {/* Companion App Sub-Bar: SIM Selector & Close Button */}
        <div style={{
          padding: '4px 16px 8px',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          borderBottom: '1px solid rgba(255,255,255,0.08)'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <button
              onClick={() => setSimSlot(simSlot.includes('1') ? 'SIM 2 (Jio)' : 'SIM 1 (Airtel)')}
              style={{
                fontSize: '0.68rem',
                padding: '2px 8px',
                borderRadius: '12px',
                background: simSlot.includes('1') ? 'rgba(16, 185, 129, 0.2)' : 'rgba(239, 68, 68, 0.2)',
                color: simSlot.includes('1') ? '#34d399' : '#f87171',
                border: '1px solid rgba(255,255,255,0.1)',
                cursor: 'pointer'
              }}
              title="Click to toggle SIM card line"
            >
              {simSlot}
            </button>
            <span style={{ fontSize: '0.65rem', color: '#94a3b8' }}>E2EE Active</span>
          </div>

          <button
            onClick={() => setIsSimulatorOpen(false)}
            style={{
              background: 'rgba(255,255,255,0.1)',
              border: 'none',
              borderRadius: '50%',
              width: '24px',
              height: '24px',
              color: '#fff',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              cursor: 'pointer'
            }}
          >
            <X size={14} />
          </button>
        </div>

        {/* Simulator Screen Contents */}
        <div style={{
          flex: 1,
          overflowY: 'auto',
          padding: '16px',
          display: 'flex',
          flexDirection: 'column'
        }}>
          {/* TAB 1: DIALER */}
          {activeTab === 'dialer' && (
            <div style={{ display: 'flex', flexDirection: 'column', height: '100%', justifyContent: 'space-between' }}>
              <div>
                <div style={{ textAlign: 'center', margin: '16px 0 20px' }}>
                  <span style={{ fontSize: '0.75rem', color: '#94a3b8', textTransform: 'uppercase' }}>
                    RingVia360 Mobile Companion
                  </span>
                  <input
                    type="text"
                    value={dialNumber}
                    onChange={e => setDialNumber(e.target.value)}
                    style={{
                      width: '100%',
                      background: 'transparent',
                      border: 'none',
                      color: '#fff',
                      fontSize: '1.45rem',
                      fontWeight: 700,
                      textAlign: 'center',
                      marginTop: '8px',
                      outline: 'none',
                      fontFamily: 'var(--font-mono)'
                    }}
                  />
                  <div style={{ fontSize: '0.85rem', color: 'var(--primary)', marginTop: '4px' }}>
                    {contactName} • {companyName}
                  </div>
                </div>

                {/* Dial Pad Grid */}
                <div style={{
                  display: 'grid',
                  gridTemplateColumns: 'repeat(3, 1fr)',
                  gap: '12px',
                  maxWidth: '260px',
                  margin: '0 auto'
                }}>
                  {['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'].map(key => (
                    <button
                      key={key}
                      onClick={() => {
                        playDtmfTone(key);
                        setDialNumber(prev => prev + key);
                      }}
                      style={{
                        height: '56px',
                        borderRadius: '50%',
                        background: 'rgba(255, 255, 255, 0.08)',
                        border: '1px solid rgba(255, 255, 255, 0.05)',
                        color: '#fff',
                        fontSize: '1.25rem',
                        fontWeight: 600,
                        cursor: 'pointer',
                        transition: 'background 0.15s ease'
                      }}
                    >
                      {key}
                    </button>
                  ))}
                </div>
              </div>

              {/* Bottom Quick Triggers */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', marginTop: '16px' }}>
                <div style={{ display: 'flex', gap: '8px', justifyContent: 'center', alignItems: 'center' }}>
                  {/* Outbound Simulated Call */}
                  <button
                    onClick={() => startCall('outbound')}
                    style={{
                      width: '56px',
                      height: '56px',
                      borderRadius: '50%',
                      background: '#10b981',
                      border: 'none',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      cursor: 'pointer',
                      boxShadow: '0 8px 20px rgba(16, 185, 129, 0.4)'
                    }}
                    title="Start Tracked Call (In-App)"
                  >
                    <Phone size={24} color="#fff" />
                  </button>

                  {/* Simulate Inbound Ringing Call */}
                  <button
                    onClick={() => startCall('inbound')}
                    style={{
                      width: '56px',
                      height: '56px',
                      borderRadius: '50%',
                      background: 'linear-gradient(135deg, #06b6d4 0%, #3b82f6 100%)',
                      border: 'none',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      cursor: 'pointer',
                      boxShadow: '0 8px 20px rgba(6, 182, 212, 0.4)'
                    }}
                    title="Simulate Inbound Call from Customer"
                  >
                    <PhoneIncoming size={22} color="#fff" />
                  </button>

                  {/* Real Phone Call (tel:) */}
                  <button
                    onClick={launchRealNativeCall}
                    style={{
                      width: '56px',
                      height: '56px',
                      borderRadius: '50%',
                      background: 'rgba(255, 255, 255, 0.12)',
                      border: '1px solid rgba(255, 255, 255, 0.2)',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      cursor: 'pointer',
                      color: '#38bdf8'
                    }}
                    title="Launch Real Phone Call (tel:)"
                  >
                    <ExternalLink size={20} />
                  </button>

                  {/* WhatsApp */}
                  <button
                    onClick={() => setActiveTab('whatsapp')}
                    style={{
                      width: '56px',
                      height: '56px',
                      borderRadius: '50%',
                      background: '#25d366',
                      border: 'none',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      cursor: 'pointer',
                      boxShadow: '0 8px 20px rgba(37, 211, 102, 0.4)'
                    }}
                    title="Simulate WhatsApp Activity"
                  >
                    <MessageSquare size={22} color="#fff" />
                  </button>
                </div>
                <div style={{ textAlign: 'center', fontSize: '0.72rem', color: '#94a3b8' }}>
                  Tap Green for In-App Call • Cyan for Inbound • External for Real Phone (tel:)
                </div>
              </div>
            </div>
          )}

          {/* TAB: INCOMING RINGING SCREEN */}
          {activeTab === 'ringing' && (
            <div style={{
              display: 'flex',
              flexDirection: 'column',
              height: '100%',
              justifyContent: 'space-between',
              alignItems: 'center',
              textAlign: 'center',
              padding: '24px 0'
            }}>
              <div>
                <div style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '6px',
                  padding: '4px 12px',
                  borderRadius: '16px',
                  background: 'rgba(6, 182, 212, 0.15)',
                  border: '1px solid rgba(6, 182, 212, 0.3)',
                  color: '#38bdf8',
                  fontSize: '0.75rem',
                  fontWeight: 700,
                  marginBottom: '16px'
                }}>
                  <Radio size={12} />
                  INCOMING CALL • SIM 1 (WORK)
                </div>

                <div style={{
                  width: '96px',
                  height: '96px',
                  borderRadius: '50%',
                  margin: '0 auto 16px',
                  border: '3px solid #06b6d4',
                  boxShadow: '0 0 30px rgba(6, 182, 212, 0.5)',
                  backgroundImage: 'url("https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=140&auto=format&fit=crop&q=80")',
                  backgroundSize: 'cover'
                }} />

                <h2 style={{ fontSize: '1.4rem', fontWeight: 800, margin: 0 }}>{contactName}</h2>
                <p style={{ fontSize: '0.85rem', color: '#94a3b8', marginTop: '4px' }}>{companyName}</p>
                <p style={{ fontSize: '0.9rem', color: '#cbd5e1', fontFamily: 'var(--font-mono)' }}>{dialNumber}</p>
                <div style={{
                  marginTop: '10px',
                  fontSize: '0.72rem',
                  padding: '3px 10px',
                  background: 'rgba(16, 185, 129, 0.15)',
                  color: '#34d399',
                  borderRadius: '8px',
                  display: 'inline-block'
                }}>
                  ₹18,50,000 Opportunity in RingVia360 CRM
                </div>
              </div>

              {/* Accept and Decline Controls */}
              <div style={{ display: 'flex', gap: '36px', alignItems: 'center' }}>
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '8px' }}>
                  <button
                    onClick={declineCall}
                    style={{
                      width: '64px',
                      height: '64px',
                      borderRadius: '50%',
                      background: '#f43f5e',
                      border: 'none',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      cursor: 'pointer',
                      boxShadow: '0 8px 24px rgba(244, 63, 94, 0.4)'
                    }}
                    title="Decline / Missed Call"
                  >
                    <PhoneOff size={26} color="#fff" />
                  </button>
                  <span style={{ fontSize: '0.75rem', color: '#94a3b8' }}>Decline</span>
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '8px' }}>
                  <button
                    onClick={answerCall}
                    style={{
                      width: '64px',
                      height: '64px',
                      borderRadius: '50%',
                      background: '#10b981',
                      border: 'none',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      cursor: 'pointer',
                      boxShadow: '0 8px 24px rgba(16, 185, 129, 0.5)'
                    }}
                    title="Accept Call"
                  >
                    <Phone size={26} color="#fff" />
                  </button>
                  <span style={{ fontSize: '0.75rem', color: '#34d399', fontWeight: 600 }}>Accept</span>
                </div>
              </div>
            </div>
          )}

          {/* TAB 2: IN-CALL SCREEN */}
          {activeTab === 'in-call' && (
            <div style={{
              display: 'flex',
              flexDirection: 'column',
              height: '100%',
              justifyContent: 'space-between',
              alignItems: 'center',
              textAlign: 'center',
              padding: '20px 0'
            }}>
              <div>
                <div style={{
                  width: '90px',
                  height: '90px',
                  borderRadius: '50%',
                  margin: '0 auto 16px',
                  border: '3px solid var(--accent-emerald)',
                  boxShadow: '0 0 25px rgba(16, 185, 129, 0.4)',
                  backgroundImage: 'url("https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=120&auto=format&fit=crop&q=80")',
                  backgroundSize: 'cover'
                }} />
                <h2 style={{ fontSize: '1.35rem', fontWeight: 700, margin: 0 }}>{contactName}</h2>
                <p style={{ fontSize: '0.85rem', color: '#94a3b8', marginTop: '4px' }}>{companyName}</p>
                <div style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '6px',
                  marginTop: '12px',
                  padding: '4px 12px',
                  borderRadius: '16px',
                  background: 'rgba(16, 185, 129, 0.15)',
                  color: '#34d399',
                  fontSize: '0.78rem'
                }}>
                  <span className="live-dot" />
                  <span>Call Recording Active • {formatTimer(callDuration)}</span>
                </div>
              </div>

              {/* Call Controls Mockup */}
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '16px', width: '100%', maxWidth: '240px' }}>
                {['Mute', 'Keypad', 'Audio', 'Add Call', 'FaceTime', 'Contacts'].map((action, i) => (
                  <div key={i} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '6px' }}>
                    <div style={{
                      width: '50px',
                      height: '50px',
                      borderRadius: '50%',
                      background: 'rgba(255,255,255,0.1)',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontSize: '0.75rem'
                    }}>
                      <Mic size={18} />
                    </div>
                    <span style={{ fontSize: '0.7rem', color: '#cbd5e1' }}>{action}</span>
                  </div>
                ))}
              </div>

              {/* End Call Button */}
              <button
                onClick={endCall}
                style={{
                  width: '68px',
                  height: '68px',
                  borderRadius: '50%',
                  background: '#f43f5e',
                  border: 'none',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  cursor: 'pointer',
                  boxShadow: '0 8px 24px rgba(244, 63, 94, 0.5)'
                }}
              >
                <PhoneOff size={28} color="#fff" />
              </button>
            </div>
          )}

          {/* TAB 3: POST-CALL WRAP-UP (Salestrail Flagship Workflow) */}
          {activeTab === 'post-call' && (
            <div style={{ display: 'flex', flexDirection: 'column', height: '100%', gap: '12px', overflowY: 'auto' }}>
              <div style={{ textAlign: 'center', borderBottom: '1px solid rgba(255,255,255,0.1)', paddingBottom: '10px' }}>
                <span className="glass-pill" style={{ background: 'rgba(124, 58, 237, 0.2)', color: 'var(--primary)' }}>
                  <Sparkles size={12} /> Post-Call Wrap-up
                </span>
                <h3 style={{ fontSize: '1.1rem', margin: '6px 0 2px' }}>Call with {contactName}</h3>
                <span style={{ fontSize: '0.75rem', color: '#94a3b8' }}>
                  Duration: {formatTimer(callDuration)} • Auto-Recorded
                </span>
              </div>

              {/* Outcome Selector */}
              <div>
                <label style={{ fontSize: '0.75rem', color: '#94a3b8', display: 'block', marginBottom: '4px' }}>
                  Call Disposition / Outcome
                </label>
                <select
                  value={outcome}
                  onChange={e => setOutcome(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '8px',
                    borderRadius: '8px',
                    background: '#1a1d2d',
                    border: '1px solid rgba(255,255,255,0.15)',
                    color: '#fff',
                    fontSize: '0.85rem'
                  }}
                >
                  <option value="Demo Completed - Contract Requested">Demo Completed - Contract Requested</option>
                  <option value="Follow-up Meeting Scheduled">Follow-up Meeting Scheduled</option>
                  <option value="Left Voicemail">Left Voicemail</option>
                  <option value="Gatekeeper Blocked">Gatekeeper Blocked</option>
                  <option value="Price Objection Raised">Price Objection Raised</option>
                </select>
              </div>

              {/* Quick Notes */}
              <div>
                <label style={{ fontSize: '0.75rem', color: '#94a3b8', display: 'block', marginBottom: '4px' }}>
                  Call Notes (Syncs to CRM Task)
                </label>
                <textarea
                  value={callNotes}
                  onChange={e => setCallNotes(e.target.value)}
                  rows={3}
                  style={{
                    width: '100%',
                    padding: '8px',
                    borderRadius: '8px',
                    background: '#1a1d2d',
                    border: '1px solid rgba(255,255,255,0.15)',
                    color: '#fff',
                    fontSize: '0.85rem',
                    resize: 'none'
                  }}
                />
              </div>

              {/* Deal Pipeline Value */}
              <div>
                <label style={{ fontSize: '0.75rem', color: '#94a3b8', display: 'block', marginBottom: '4px' }}>
                  Pipeline Deal Amount (₹ INR)
                </label>
                <input
                  type="number"
                  value={dealValue}
                  onChange={e => setDealValue(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '8px',
                    borderRadius: '8px',
                    background: '#1a1d2d',
                    border: '1px solid rgba(255,255,255,0.15)',
                    color: '#fff',
                    fontSize: '0.85rem'
                  }}
                />
              </div>

              {/* Sentiment Selector */}
              <div>
                <label style={{ fontSize: '0.75rem', color: '#94a3b8', display: 'block', marginBottom: '4px' }}>
                  Client Sentiment
                </label>
                <div style={{ display: 'flex', gap: '8px' }}>
                  {(['positive', 'neutral', 'negative'] as const).map(s => (
                    <button
                      key={s}
                      onClick={() => setSentiment(s)}
                      style={{
                        flex: 1,
                        padding: '6px',
                        borderRadius: '6px',
                        border: sentiment === s ? '1px solid #fff' : '1px solid transparent',
                        background:
                          s === 'positive' ? 'rgba(16, 185, 129, 0.2)' :
                          s === 'neutral' ? 'rgba(245, 158, 11, 0.2)' : 'rgba(244, 63, 94, 0.2)',
                        color:
                          s === 'positive' ? '#34d399' :
                          s === 'neutral' ? '#fbbf24' : '#fb7185',
                        fontSize: '0.75rem',
                        cursor: 'pointer',
                        textTransform: 'capitalize'
                      }}
                    >
                      {s}
                    </button>
                  ))}
                </div>
              </div>

              {/* Save & Push CTA */}
              <button
                onClick={submitPostCall}
                style={{
                  marginTop: 'auto',
                  padding: '12px',
                  borderRadius: '12px',
                  background: 'linear-gradient(135deg, var(--primary) 0%, #38bdf8 100%)',
                  border: 'none',
                  color: '#fff',
                  fontWeight: 700,
                  fontSize: '0.9rem',
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '8px',
                  boxShadow: '0 4px 18px var(--primary-glow)'
                }}
              >
                <Check size={18} />
                Save & Push to RingVia360
              </button>
            </div>
          )}

          {/* TAB 4: WHATSAPP SIMULATOR */}
          {activeTab === 'whatsapp' && (
            <div style={{ display: 'flex', flexDirection: 'column', height: '100%', justifyContent: 'space-between' }}>
              <div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', paddingBottom: '12px', borderBottom: '1px solid rgba(255,255,255,0.1)' }}>
                  <button onClick={() => setActiveTab('dialer')} className="btn-ghost" style={{ padding: '4px' }}>
                    ← Back
                  </button>
                  <div>
                    <h3 style={{ fontSize: '0.95rem', margin: 0 }}>{contactName}</h3>
                    <span style={{ fontSize: '0.7rem', color: '#25d366' }}>WhatsApp Business Active</span>
                  </div>
                </div>

                <div style={{ padding: '16px 0', display: 'flex', flexDirection: 'column', gap: '10px' }}>
                  <div style={{
                    alignSelf: 'flex-start',
                    background: '#1f2937',
                    padding: '8px 12px',
                    borderRadius: '12px 12px 12px 2px',
                    maxWidth: '85%',
                    fontSize: '0.82rem'
                  }}>
                    Hi Sarah! Could you confirm if the RingVia360 companion app supports dual-SIM?
                  </div>
                  <div style={{
                    alignSelf: 'flex-end',
                    background: '#065f46',
                    padding: '8px 12px',
                    borderRadius: '12px 12px 2px 12px',
                    maxWidth: '85%',
                    fontSize: '0.82rem'
                  }}>
                    Yes Alexander! Dual-SIM is natively supported. Only calls and chats from SIM 1 (Work) are logged.
                  </div>
                </div>
              </div>

              {/* Chat Input */}
              <div style={{ display: 'flex', gap: '8px', alignItems: 'center', paddingTop: '10px', borderTop: '1px solid rgba(255,255,255,0.1)' }}>
                <input
                  type="text"
                  placeholder="Type message to sync to CRM..."
                  value={waText}
                  onChange={e => setWaText(e.target.value)}
                  style={{
                    flex: 1,
                    padding: '10px',
                    borderRadius: '20px',
                    background: '#1a1d2d',
                    border: '1px solid rgba(255,255,255,0.15)',
                    color: '#fff',
                    fontSize: '0.82rem',
                    outline: 'none'
                  }}
                  onKeyDown={e => e.key === 'Enter' && sendWhatsApp()}
                />
                <button
                  onClick={sendWhatsApp}
                  style={{
                    width: '38px',
                    height: '38px',
                    borderRadius: '50%',
                    background: '#25d366',
                    border: 'none',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    cursor: 'pointer'
                  }}
                >
                  <Send size={16} color="#fff" />
                </button>
              </div>
            </div>
          )}
        </div>

        {/* Phone Bottom Home Bar */}
        <div style={{
          height: '24px',
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center'
        }}>
          <div style={{ width: '130px', height: '4px', borderRadius: '4px', background: 'rgba(255,255,255,0.3)' }} />
        </div>
      </div>
    </div>
  );
};
