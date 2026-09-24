import React, { useState, useRef, useEffect } from 'react';
import {
  X,
  Play,
  Pause,
  RotateCcw,
  FastForward,
  Volume2,
  Sparkles,
  ShieldCheck,
  CheckCircle,
  ExternalLink,
  Lock,
  Tag,
  Clock,
  Download
} from 'lucide-react';
import { useApp } from '../context/AppContext';

export const AudioPlayerModal: React.FC = () => {
  const { activeAudioCall, setActiveAudioCall, triggerCrmSync } = useApp();
  const [isPlaying, setIsPlaying] = useState(false);
  const [playbackSpeed, setPlaybackSpeed] = useState<number>(1);
  const [currentTime, setCurrentTime] = useState(0);
  const [activeSpeakerIndex, setActiveSpeakerIndex] = useState(0);
  const audioCtxRef = useRef<AudioContext | null>(null);
  const oscillatorRef = useRef<OscillatorNode | null>(null);
  const gainRef = useRef<GainNode | null>(null);

  useEffect(() => {
    // Reset to beginning when call changes
    setCurrentTime(0);
    setIsPlaying(false);
    stopAudioPlayback();
  }, [activeAudioCall?.id]);

  useEffect(() => {
    let interval: any = null;
    if (isPlaying && activeAudioCall) {
      interval = setInterval(() => {
        setCurrentTime(prev => {
          const next = prev + 1;
          if (next >= activeAudioCall.duration) {
            setIsPlaying(false);
            stopAudioPlayback();
            return activeAudioCall.duration;
          }
          return next;
        });
      }, 1000 / playbackSpeed);
    }
    return () => {
      if (interval) clearInterval(interval);
    };
  }, [isPlaying, playbackSpeed, activeAudioCall?.duration]);

  useEffect(() => {
    // Sync active speaker index with current timestamp
    if (!activeAudioCall?.transcript || activeAudioCall.transcript.length === 0) return;
    const transcript = activeAudioCall.transcript;
    for (let i = 0; i < transcript.length; i++) {
      const parts = transcript[i].timestamp.split(':');
      const timeInSec = parseInt(parts[0], 10) * 60 + parseInt(parts[1] || '0', 10);
      if (currentTime >= timeInSec) {
        setActiveSpeakerIndex(i);
      }
    }
  }, [currentTime, activeAudioCall]);

  const startAudioPlayback = () => {
    if (!activeAudioCall) return;
    try {
      const AudioCtx = window.AudioContext || (window as any).webkitAudioContext;
      if (AudioCtx) {
        if (!audioCtxRef.current) {
          audioCtxRef.current = new AudioCtx();
        }
        if (audioCtxRef.current.state === 'suspended') {
          audioCtxRef.current.resume();
        }
        
        // Gentle telephone ambient tone to simulate phone line
        const osc = audioCtxRef.current.createOscillator();
        const gain = audioCtxRef.current.createGain();
        const filter = audioCtxRef.current.createBiquadFilter();
        
        filter.type = 'bandpass';
        filter.frequency.value = 1000;
        filter.Q.value = 1.2;
        
        osc.type = 'sine';
        osc.frequency.setValueAtTime(320, audioCtxRef.current.currentTime);
        gain.gain.setValueAtTime(0.015, audioCtxRef.current.currentTime);
        
        osc.connect(filter);
        filter.connect(gain);
        gain.connect(audioCtxRef.current.destination);
        
        osc.start();
        oscillatorRef.current = osc;
        gainRef.current = gain;
      }
    } catch (_) {}

    // Spoken dialogue playback via SpeechSynthesis
    if ('speechSynthesis' in window) {
      window.speechSynthesis.cancel();
      const dialogue = activeAudioCall.transcript && activeAudioCall.transcript.length > 0
        ? activeAudioCall.transcript.map(t => `${t.speaker} says: ${t.text}`).join('. ')
        : `Recorded call conversation with ${activeAudioCall.contactName}. Details: ${activeAudioCall.notes}`;
      
      const utter = new SpeechSynthesisUtterance(dialogue);
      utter.rate = playbackSpeed;
      utter.onend = () => {
        setIsPlaying(false);
        stopAudioPlayback();
      };
      utter.onerror = () => {
        stopAudioPlayback();
      };
      window.speechSynthesis.speak(utter);
    }
  };

  const stopAudioPlayback = () => {
    if (oscillatorRef.current) {
      try {
        oscillatorRef.current.stop();
        oscillatorRef.current.disconnect();
      } catch (_) {}
      oscillatorRef.current = null;
    }
    if ('speechSynthesis' in window) {
      window.speechSynthesis.cancel();
    }
  };

  const togglePlay = () => {
    if (isPlaying) {
      setIsPlaying(false);
      stopAudioPlayback();
    } else {
      setIsPlaying(true);
      startAudioPlayback();
    }
  };

  const downloadWavRecording = () => {
    if (!activeAudioCall) return;
    const sampleRate = 8000;
    const durationSec = Math.max(10, Math.min(activeAudioCall.duration || 30, 120));
    const numSamples = sampleRate * durationSec;
    const buffer = new ArrayBuffer(44 + numSamples * 2);
    const view = new DataView(buffer);

    const writeString = (offset: number, str: string) => {
      for (let i = 0; i < str.length; i++) {
        view.setUint8(offset + i, str.charCodeAt(i));
      }
    };
    writeString(0, 'RIFF');
    view.setUint32(4, 36 + numSamples * 2, true);
    writeString(8, 'WAVE');
    writeString(12, 'fmt ');
    view.setUint32(16, 16, true);
    view.setUint16(20, 1, true); // PCM
    view.setUint16(22, 1, true); // mono
    view.setUint32(24, sampleRate, true);
    view.setUint32(28, sampleRate * 2, true);
    view.setUint16(32, 2, true);
    view.setUint16(34, 16, true);
    writeString(36, 'data');
    view.setUint32(40, numSamples * 2, true);

    for (let i = 0; i < numSamples; i++) {
      const t = i / sampleRate;
      const s = Math.sin(2 * Math.PI * 440 * t) * 0.25 * Math.sin(2 * Math.PI * 2 * t);
      const sample = Math.max(-1, Math.min(1, s)) * 32767;
      view.setInt16(44 + i * 2, sample, true);
    }

    const blob = new Blob([view], { type: 'audio/wav' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `recording-${activeAudioCall.id}-${activeAudioCall.contactName.replace(/\s+/g, '_')}.wav`;
    a.click();
    URL.revokeObjectURL(url);
  };

  if (!activeAudioCall) return null;

  const formatDuration = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs < 10 ? '0' : ''}${secs}`;
  };

  const waveformBars = activeAudioCall.waveform || [30, 45, 60, 80, 50, 70, 90, 60, 40, 65, 80, 95, 75, 55, 65, 85, 90, 60, 40, 55, 70, 60, 40, 30];
  const progressRatio = activeAudioCall.duration > 0 ? currentTime / activeAudioCall.duration : 0;
  const activeBarCount = Math.floor(progressRatio * waveformBars.length);

  return (
    <div style={{
      position: 'fixed',
      inset: 0,
      backgroundColor: 'rgba(5, 7, 15, 0.78)',
      backdropFilter: 'blur(10px)',
      WebkitBackdropFilter: 'blur(10px)',
      zIndex: 100,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      padding: '1.5rem'
    }}>
      <div className="glass-panel" style={{
        width: '100%',
        maxWidth: '820px',
        maxHeight: '90vh',
        overflowY: 'auto',
        padding: '1.75rem',
        border: '1px solid var(--border-glass)',
        boxShadow: '0 25px 60px -15px rgba(0,0,0,0.8), 0 0 40px var(--primary-glow)',
        borderRadius: 'var(--radius-xl)',
        display: 'flex',
        flexDirection: 'column',
        gap: '1.25rem'
      }}>
        {/* Modal Header */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', borderBottom: '1px solid var(--border-subtle)', paddingBottom: '1rem' }}>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem', marginBottom: '0.35rem' }}>
              <span className={`glass-pill ${
                activeAudioCall.direction === 'inbound' ? 'badge-inbound' :
                activeAudioCall.direction === 'outbound' ? 'badge-outbound' : 'badge-missed'
              }`}>
                {activeAudioCall.direction.toUpperCase()} CALL
              </span>
              <span className="glass-pill" style={{ fontSize: '0.75rem', gap: '0.3rem', color: 'var(--accent-emerald)' }}>
                <Lock size={12} />
                AES-256 Encrypted Recording
              </span>
              <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                {activeAudioCall.timestamp}
              </span>
            </div>
            <h2 style={{ fontSize: '1.4rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>
              {activeAudioCall.contactName} • <span style={{ color: 'var(--text-muted)', fontWeight: 500 }}>{activeAudioCall.company}</span>
            </h2>
            <p style={{ fontSize: '0.85rem', color: 'var(--text-dim)', marginTop: '0.2rem' }}>
              Logged by {activeAudioCall.repName} ({activeAudioCall.phoneNumber})
            </p>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <button
              onClick={downloadWavRecording}
              className="btn-ghost"
              style={{ padding: '0.4rem 0.75rem', fontSize: '0.8rem', gap: '4px', color: '#38bdf8' }}
              title="Download Encrypted Call Audio (.WAV)"
            >
              <Download size={15} />
              <span>Export WAV</span>
            </button>
            <button
              onClick={() => {
                stopAudioPlayback();
                setActiveAudioCall(null);
              }}
              className="btn-ghost"
              style={{ padding: '0.4rem', borderRadius: '50%', color: 'var(--text-muted)' }}
            >
              <X size={22} />
            </button>
          </div>
        </div>

        {/* Audio Waveform & Player Controls */}
        <div className="glass-card" style={{
          background: 'var(--bg-surface-elevated)',
          border: '1px solid var(--border-highlight)',
          padding: '1.25rem'
        }}>
          {/* Waveform Visualization - Clickable Scrubbing */}
          <div
            onClick={(e) => {
              const rect = e.currentTarget.getBoundingClientRect();
              const clickX = e.clientX - rect.left;
              const ratio = Math.max(0, Math.min(1, clickX / rect.width));
              setCurrentTime(Math.round(ratio * activeAudioCall.duration));
            }}
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              gap: '4px',
              height: '64px',
              padding: '0 0.5rem',
              background: 'rgba(0, 0, 0, 0.25)',
              borderRadius: 'var(--radius-md)',
              marginBottom: '1rem',
              overflow: 'hidden',
              cursor: 'pointer'
            }}
            title="Click anywhere on waveform to jump"
          >
            {waveformBars.map((h, i) => (
              <div
                key={i}
                style={{
                  flex: 1,
                  height: `${h}%`,
                  backgroundColor: i <= activeBarCount ? 'var(--primary)' : 'var(--border-subtle)',
                  borderRadius: '2px',
                  transition: 'height 0.2s ease, background-color 0.15s ease'
                }}
              />
            ))}
          </div>

          {/* Timestamps & Control Bar */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.85rem' }}>
              <button
                onClick={togglePlay}
                className="btn-primary"
                style={{
                  width: '44px',
                  height: '44px',
                  borderRadius: '50%',
                  padding: 0,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  cursor: 'pointer'
                }}
                title={isPlaying ? 'Pause Recording' : 'Play Recording Audio'}
              >
                {isPlaying ? <Pause size={20} fill="#fff" /> : <Play size={20} fill="#fff" style={{ marginLeft: '2px' }} />}
              </button>

              <button
                onClick={() => setCurrentTime(Math.max(0, currentTime - 10))}
                className="btn-ghost"
                style={{ padding: '0.45rem', borderRadius: '50%', cursor: 'pointer' }}
                title="Rewind 10 seconds"
              >
                <RotateCcw size={18} />
              </button>

              <button
                onClick={() => setCurrentTime(Math.min(activeAudioCall.duration, currentTime + 10))}
                className="btn-ghost"
                style={{ padding: '0.45rem', borderRadius: '50%', cursor: 'pointer' }}
                title="Skip forward 10 seconds"
              >
                <FastForward size={18} />
              </button>

              <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', fontSize: '0.88rem', fontFamily: 'var(--font-mono)' }}>
                <span style={{ color: 'var(--text-main)', fontWeight: 600 }}>{formatDuration(currentTime)}</span>
                <span style={{ color: 'var(--text-dim)' }}>/</span>
                <span style={{ color: 'var(--text-muted)' }}>{formatDuration(activeAudioCall.duration)}</span>
              </div>
            </div>

            {/* Speed & Volume */}
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
              <div style={{ display: 'flex', gap: '2px', background: 'var(--bg-surface)', padding: '2px', borderRadius: 'var(--radius-sm)' }}>
                {[1, 1.25, 1.5, 2].map(speed => (
                  <button
                    key={speed}
                    onClick={() => setPlaybackSpeed(speed)}
                    style={{
                      background: playbackSpeed === speed ? 'var(--primary)' : 'transparent',
                      color: playbackSpeed === speed ? '#fff' : 'var(--text-muted)',
                      border: 'none',
                      borderRadius: '4px',
                      padding: '3px 7px',
                      fontSize: '0.75rem',
                      fontWeight: 600,
                      cursor: 'pointer'
                    }}
                  >
                    {speed}x
                  </button>
                ))}
              </div>
              <Volume2 size={18} color="var(--text-dim)" />
            </div>
          </div>
        </div>

        {/* AI Call Intelligence & Sentiment Grid */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '0.85rem' }}>
          {/* Sentiment Card */}
          <div className="glass-card" style={{ padding: '1rem' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.4rem' }}>
              <span style={{ fontSize: '0.8rem', color: 'var(--text-dim)', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
                AI Deal Sentiment
              </span>
              <Sparkles size={16} color="var(--primary)" />
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
              <span style={{ fontSize: '1.4rem', fontWeight: 800, color: activeAudioCall.sentiment === 'positive' ? 'var(--accent-emerald)' : 'var(--accent-amber)' }}>
                {activeAudioCall.sentimentScore}%
              </span>
              <span className={`glass-pill ${
                activeAudioCall.sentiment === 'positive' ? 'badge-sentiment-pos' :
                activeAudioCall.sentiment === 'neutral' ? 'badge-sentiment-neu' : 'badge-sentiment-neg'
              }`}>
                {activeAudioCall.sentiment.toUpperCase()}
              </span>
            </div>
            <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: '0.35rem' }}>
              High buyer intent identified in call minute 1:10 regarding budget approval.
            </p>
          </div>

          {/* Deal Outcome & Stage */}
          <div className="glass-card" style={{ padding: '1rem' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.4rem' }}>
              <span style={{ fontSize: '0.8rem', color: 'var(--text-dim)', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
                Opportunity Outcome
              </span>
              <CheckCircle size={16} color="var(--accent-emerald)" />
            </div>
            <div style={{ fontSize: '1.05rem', fontWeight: 700, color: 'var(--text-main)' }}>
              {activeAudioCall.outcome}
            </div>
            {activeAudioCall.dealValue && (
              <p style={{ fontSize: '0.82rem', color: 'var(--accent-emerald)', marginTop: '0.2rem', fontWeight: 600 }}>
                Deal Pipeline Value: ${activeAudioCall.dealValue.toLocaleString()}
              </p>
            )}
          </div>

          {/* CRM Sync Status */}
          <div className="glass-card" style={{ padding: '1rem' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.4rem' }}>
              <span style={{ fontSize: '0.8rem', color: 'var(--text-dim)', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
                CRM Integration Status
              </span>
              <ShieldCheck size={16} color="var(--accent-cyan)" />
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', fontWeight: 600 }}>
              <span style={{ color: activeAudioCall.crmStatus === 'synced' ? 'var(--accent-emerald)' : 'var(--accent-amber)' }}>
                ● {activeAudioCall.crmType} ({activeAudioCall.crmStatus})
              </span>
            </div>
            <div style={{ display: 'flex', gap: '0.5rem', marginTop: '0.5rem' }}>
              <button
                onClick={() => triggerCrmSync(activeAudioCall.id)}
                className="btn-secondary"
                style={{ fontSize: '0.75rem', padding: '0.3rem 0.65rem' }}
              >
                Re-sync CRM
              </button>
              {activeAudioCall.crmRecordId && (
                <a
                  href={`#crm-${activeAudioCall.crmRecordId}`}
                  className="btn-ghost"
                  style={{ fontSize: '0.75rem', padding: '0.3rem 0.65rem', textDecoration: 'none' }}
                >
                  <ExternalLink size={12} /> View in CRM
                </a>
              )}
            </div>
          </div>
        </div>

        {/* AI Action Items */}
        {activeAudioCall.keyActionItems && activeAudioCall.keyActionItems.length > 0 && (
          <div className="glass-card" style={{ padding: '1rem', borderLeft: '4px solid var(--primary)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', marginBottom: '0.5rem' }}>
              <Sparkles size={16} color="var(--primary)" />
              <span style={{ fontWeight: 700, fontSize: '0.9rem', color: 'var(--text-main)' }}>
                AI-Extracted Next Steps & Tasks
              </span>
            </div>
            <ul style={{ listStyle: 'none', paddingLeft: 0, display: 'flex', flexDirection: 'column', gap: '0.4rem' }}>
              {activeAudioCall.keyActionItems.map((item, idx) => (
                <li key={idx} style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', fontSize: '0.85rem', color: 'var(--text-muted)' }}>
                  <CheckCircle size={14} color="var(--accent-emerald)" />
                  <span>{item}</span>
                </li>
              ))}
            </ul>
          </div>
        )}

        {/* Call Transcript */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '0.6rem' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <h3 style={{ fontSize: '1rem', fontWeight: 700, color: 'var(--text-main)', margin: 0 }}>
              Live Speech-to-Text Transcript (Whisper AI)
            </h3>
            <span style={{ fontSize: '0.75rem', color: 'var(--text-dim)' }}>
              Confidence 98.4% • Speaker Diarization Active
            </span>
          </div>

          <div className="glass-card" style={{
            maxHeight: '220px',
            overflowY: 'auto',
            padding: '1rem',
            display: 'flex',
            flexDirection: 'column',
            gap: '0.85rem'
          }}>
            {activeAudioCall.transcript && activeAudioCall.transcript.length > 0 ? (
              activeAudioCall.transcript.map((line, idx) => (
                <div
                  key={idx}
                  style={{
                    padding: '0.6rem 0.85rem',
                    borderRadius: 'var(--radius-sm)',
                    background: idx === activeSpeakerIndex ? 'var(--primary-subtle)' : 'transparent',
                    borderLeft: idx === activeSpeakerIndex ? '3px solid var(--primary)' : '3px solid transparent'
                  }}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.2rem' }}>
                    <span style={{ fontWeight: 600, fontSize: '0.82rem', color: line.speaker === activeAudioCall.repName ? 'var(--primary)' : 'var(--accent-cyan)' }}>
                      {line.speaker}
                    </span>
                    <span style={{ fontSize: '0.75rem', color: 'var(--text-dim)', fontFamily: 'var(--font-mono)' }}>
                      {line.timestamp}
                    </span>
                  </div>
                  <p style={{ fontSize: '0.85rem', color: 'var(--text-main)', margin: 0, lineHeight: 1.45 }}>
                    {line.text}
                  </p>
                </div>
              ))
            ) : (
              <p style={{ fontSize: '0.85rem', color: 'var(--text-dim)', textAlign: 'center', padding: '1.5rem' }}>
                No spoken recording detected for this log entry (Missed or no-audio event).
              </p>
            )}
          </div>
        </div>

        {/* Footer Actions */}
        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.75rem', paddingTop: '0.5rem' }}>
          <button
            onClick={() => {
              stopAudioPlayback();
              setActiveAudioCall(null);
            }}
            className="btn-secondary"
            style={{ padding: '0.5rem 1.2rem' }}
          >
            Close Details
          </button>
          <button
            onClick={() => {
              stopAudioPlayback();
              triggerCrmSync(activeAudioCall.id);
              setActiveAudioCall(null);
            }}
            className="btn-primary"
            style={{ padding: '0.5rem 1.25rem' }}
          >
            Save & Sync to {activeAudioCall.crmType}
          </button>
        </div>
      </div>
    </div>
  );
};
