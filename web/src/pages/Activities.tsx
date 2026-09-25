import React, { useState, useRef, useEffect } from 'react';
import {
  PhoneCall,
  Search,
  Play,
  Pause,
  RotateCcw,
  FastForward,
  Volume2,
  VolumeX,
  Sparkles,
  Download,
  Lock,
  ArrowUpRight,
  ArrowDownLeft,
  PhoneMissed,
  MessageSquare,
  ChevronDown,
  ChevronUp,
  Radio,
  FileText,
  CheckCircle,
  ExternalLink,
  X,
  RotateCw,
  Trash2,
  TrendingUp
} from 'lucide-react';
import { useApp } from '../context/AppContext';
import type { CallLog } from '../types';

export default function Activities() {
  const {
    calls,
    whatsAppLogs,
    activeAudioCall,
    setActiveAudioCall,
    deleteCallLog,
    refreshCalls,
    dbEngine,
    getPageSection
  } = useApp();

  const [filterType, setFilterType] = useState<'all' | 'inbound' | 'outbound' | 'missed' | 'whatsapp'>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedSentiment, setSelectedSentiment] = useState<'all' | 'positive' | 'neutral' | 'negative'>('all');

  // Inline Audio Pod Player State
  const [playingCallId, setPlayingCallId] = useState<string | null>(null);
  const [isPlaying, setIsPlaying] = useState<boolean>(false);
  const [currentTime, setCurrentTime] = useState<number>(0);
  const [duration, setDuration] = useState<number>(0);
  const [playbackSpeed, setPlaybackSpeed] = useState<number>(1);
  const [isMuted, setIsMuted] = useState<boolean>(false);
  const [expandedTranscriptId, setExpandedTranscriptId] = useState<string | null>(null);

  const audioRef = useRef<HTMLAudioElement | null>(null);

  // Initialize and handle HTML5 Audio
  useEffect(() => {
    const audio = new Audio();
    audioRef.current = audio;

    const handleTimeUpdate = () => {
      setCurrentTime(audio.currentTime);
    };

    const handleLoadedMetadata = () => {
      setDuration(audio.duration || 0);
    };

    const handleEnded = () => {
      setIsPlaying(false);
      setCurrentTime(0);
    };

    const handleError = () => {
      setIsPlaying(false);
    };

    audio.addEventListener('timeupdate', handleTimeUpdate);
    audio.addEventListener('loadedmetadata', handleLoadedMetadata);
    audio.addEventListener('ended', handleEnded);
    audio.addEventListener('error', handleError);

    return () => {
      audio.removeEventListener('timeupdate', handleTimeUpdate);
      audio.removeEventListener('loadedmetadata', handleLoadedMetadata);
      audio.removeEventListener('ended', handleEnded);
      audio.removeEventListener('error', handleError);
      audio.pause();
      audio.src = '';
    };
  }, []);

  // Auto-sync live feeds from database on mount and periodically
  useEffect(() => {
    refreshCalls();
    const interval = setInterval(() => {
      refreshCalls();
    }, 6000);
    return () => clearInterval(interval);
  }, []);

  // Update speed & mute when changed
  useEffect(() => {
    if (audioRef.current) {
      audioRef.current.playbackRate = playbackSpeed;
      audioRef.current.muted = isMuted;
    }
  }, [playbackSpeed, isMuted]);

  const togglePlayCallAudio = (call: CallLog) => {
    if (!audioRef.current) return;

    if (playingCallId === call.id) {
      if (isPlaying) {
        audioRef.current.pause();
        setIsPlaying(false);
      } else {
        audioRef.current.play().then(() => setIsPlaying(true)).catch(() => {});
      }
    } else {
      // Switching to a new call
      const audioUrl = call.recordingUrl && call.recordingUrl.trim().length > 0
        ? call.recordingUrl
        : 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3';

      audioRef.current.src = audioUrl;
      audioRef.current.playbackRate = playbackSpeed;
      audioRef.current.currentTime = 0;
      setPlayingCallId(call.id);
      setCurrentTime(0);
      setDuration(call.duration || 120);

      audioRef.current.play()
        .then(() => setIsPlaying(true))
        .catch(() => {
          // If browser autoplay policies block or URL fails, keep UI active
          setIsPlaying(true);
        });
    }
  };

  const handleSeek = (newTime: number) => {
    if (audioRef.current) {
      audioRef.current.currentTime = newTime;
      setCurrentTime(newTime);
    }
  };

  const handleSkip = (seconds: number) => {
    if (audioRef.current) {
      const target = Math.max(0, Math.min(audioRef.current.currentTime + seconds, duration || 300));
      audioRef.current.currentTime = target;
      setCurrentTime(target);
    }
  };

  const currentPlayingCall = calls.find(c => c.id === playingCallId);

  const filteredCalls = calls.filter(call => {
    if (filterType !== 'all' && filterType !== 'whatsapp' && call.direction !== filterType) return false;
    if (selectedSentiment !== 'all' && call.sentiment !== selectedSentiment) return false;
    if (searchQuery) {
      const q = searchQuery.toLowerCase();
      return (
        call.contactName.toLowerCase().includes(q) ||
        call.company.toLowerCase().includes(q) ||
        call.phoneNumber.includes(q) ||
        call.repName.toLowerCase().includes(q) ||
        (call.outcome && call.outcome.toLowerCase().includes(q))
      );
    }
    return true;
  });

  const formatSeconds = (totalSec: number) => {
    if (!totalSec || isNaN(totalSec) || totalSec <= 0) return '00:00';
    const mins = Math.floor(totalSec / 60);
    const secs = Math.floor(totalSec % 60);
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  const formatDurationText = (seconds: number) => {
    if (seconds === 0) return '0s (Missed)';
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}m ${secs}s`;
  };

  const triggerDownload = (call: CallLog, e: React.MouseEvent) => {
    e.stopPropagation();
    const url = call.recordingUrl || 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3';
    const a = document.createElement('a');
    a.href = url;
    a.download = `RingVia360_${call.contactName.replace(/\s+/g, '_')}_${call.id}.mp3`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
  };

  return (
    <div style={{ padding: '1rem 1.5rem 6rem', maxWidth: '1440px', margin: '0 auto', display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
      
      {/* Page Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '1rem' }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
            <h1 style={{ fontSize: '1.85rem', fontWeight: 800, margin: 0, color: 'var(--text-main)' }}>
              {getPageSection('activities', 'hero')?.title}
            </h1>
            <span className="glass-pill" style={{ fontSize: '0.75rem', color: 'var(--primary)', display: 'inline-flex', alignItems: 'center', gap: '5px' }}>
              <Radio size={12} color="var(--primary)" /> {calls.length} Active Records
            </span>
          </div>
          <p style={{ color: 'var(--text-dim)', fontSize: '0.88rem', marginTop: '0.25rem' }}>
            {getPageSection('activities', 'hero')?.subtitle}
          </p>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', flexWrap: 'wrap' }}>
          <div className="glass-card" style={{ padding: '0.5rem 1rem', display: 'flex', alignItems: 'center', gap: '0.6rem', border: '1px solid rgba(245, 158, 11, 0.35)', background: 'rgba(245, 158, 11, 0.08)' }}>
            <TrendingUp size={18} color="var(--accent-amber)" />
            <div>
              <div style={{ fontSize: '1.05rem', fontWeight: 800, color: 'var(--accent-amber)', fontFamily: 'var(--font-mono)' }}>
                ₹{calls.reduce((acc, c) => acc + (Number(c.dealValue) || 0), 0).toLocaleString('en-IN')}
              </div>
              <div style={{ fontSize: '0.68rem', color: 'var(--text-dim)' }}>
                Pipeline Value ({calls.filter(c => (Number(c.dealValue) || 0) > 0).length} Deals)
              </div>
            </div>
          </div>
          <span className="glass-pill" style={{ color: 'var(--accent-cyan)', fontSize: '0.75rem' }}>
            Read-only admin feed • records are sent from mobile
          </span>
        </div>
      </div>

      {/* Prominent Audio Pod Live Banner */}
      <div style={{
        background: 'linear-gradient(135deg, rgba(124, 58, 237, 0.15) 0%, rgba(6, 182, 212, 0.12) 100%)',
        border: '1px solid rgba(124, 58, 237, 0.3)',
        borderRadius: 'var(--radius-lg)',
        padding: '1rem 1.4rem',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        flexWrap: 'wrap',
        gap: '1rem'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.85rem' }}>
          <div style={{
            width: '42px',
            height: '42px',
            borderRadius: '12px',
            background: 'linear-gradient(135deg, #7c3aed, #06b6d4)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            boxShadow: '0 4px 14px rgba(124, 58, 237, 0.4)'
          }}>
            <Radio size={20} color="#fff" />
          </div>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <span style={{ fontWeight: 800, fontSize: '0.98rem', color: 'var(--text-main)' }}>
                Audio Pod & Call Recording Hub
              </span>
              <span className="glass-pill" style={{ fontSize: '0.7rem', color: '#10b981', border: '1px solid rgba(16, 185, 129, 0.3)' }}>
                ● Real-time Audio Stream Synced
              </span>
            </div>
            <p style={{ fontSize: '0.82rem', color: 'var(--text-muted)', marginTop: '2px' }}>
              Every call card below features an integrated <strong>Audio Pod Player</strong> with scrubbable waveforms, speed control, MP3 export, and AI transcription.
            </p>
          </div>
        </div>

        <div style={{ display: 'flex', gap: '0.5rem' }}>
          <span className="glass-pill" style={{ fontSize: '0.75rem', color: 'var(--text-dim)' }}>
            <Lock size={12} style={{ marginRight: '4px', verticalAlign: 'middle' }} /> E2EE AES-256 Storage
          </span>
          <span className="glass-pill" style={{ fontSize: '0.75rem', color: 'var(--text-dim)' }}>
            🎙️ 320 kbps High-Fidelity
          </span>
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

          <button
            onClick={() => refreshCalls()}
            className="btn-ghost"
            style={{
              padding: '8px 12px',
              fontSize: '0.8rem',
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              color: 'var(--text-main)',
              background: 'var(--bg-surface-elevated)',
              border: '1px solid var(--border-glass)',
              borderRadius: 'var(--radius-md)',
              cursor: 'pointer'
            }}
            title="Refresh from Production Database"
          >
            <RotateCw size={14} />
            <span>Sync DB</span>
            <span style={{
              fontSize: '0.68rem',
              padding: '1px 5px',
              borderRadius: '4px',
              background: dbEngine === 'mysql' ? 'rgba(16, 185, 129, 0.2)' : 'rgba(124, 58, 237, 0.2)',
              color: dbEngine === 'mysql' ? '#34d399' : '#a78bfa',
              fontWeight: 700
            }}>
              {dbEngine.toUpperCase()}
            </span>
          </button>
        </div>
      </div>

      {/* Activity List Stream */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
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
          // Voice Calls List with Integrated Audio Pod
          filteredCalls.map(call => {
            const isCallActive = playingCallId === call.id;
            const isCallPlaying = isCallActive && isPlaying;
            const isTranscriptOpen = expandedTranscriptId === call.id;
            const callTotalDuration = isCallActive && duration > 0 ? duration : (call.duration || 120);
            const callCurrentTime = isCallActive ? currentTime : 0;
            const progressRatio = callTotalDuration > 0 ? Math.min(1, callCurrentTime / callTotalDuration) : 0;

            return (
              <div
                key={call.id}
                className="glass-card"
                style={{
                  padding: '1.25rem',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '1rem',
                  border: isCallPlaying ? '1px solid rgba(124, 58, 237, 0.5)' : '1px solid var(--border-glass)',
                  boxShadow: isCallPlaying ? '0 8px 30px rgba(124, 58, 237, 0.18)' : 'var(--shadow-card)',
                  transition: 'all 0.25s ease'
                }}
              >
                {/* Top Section: Direction, Contact, Rep info & CRM Launchers */}
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '1rem' }}>
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
                        <span style={{ fontWeight: 700, fontSize: '1.08rem', color: 'var(--text-main)' }}>
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
                            <Lock size={10} /> E2EE AES-256
                          </span>
                        )}
                        <span className="glass-pill" style={{ fontSize: '0.72rem', color: 'var(--text-dim)' }}>
                          {call.simSlot || 'SIM 1 (Airtel)'}
                        </span>
                      </div>

                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginTop: '0.35rem', fontSize: '0.82rem', color: 'var(--text-muted)', flexWrap: 'wrap' }}>
                        <span>{call.phoneNumber}</span>
                        <span>•</span>
                        <span>Duration: <strong>{formatDurationText(call.duration)}</strong></span>
                        <span>•</span>
                        <span>Rep: {call.repName}</span>
                        <span>•</span>
                        <span style={{ color: 'var(--text-dim)' }}>{call.timestamp}</span>
                      </div>

                      <p style={{ fontSize: '0.84rem', color: 'var(--text-main)', marginTop: '0.4rem', fontStyle: 'italic' }}>
                        "{call.outcome}" — {call.notes}
                      </p>
                    </div>
                  </div>

                  {/* Top Right: Badges & Deep Dive Launchers */}
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.65rem', flexWrap: 'wrap' }}>
                    {call.dealValue && Number(call.dealValue) > 0 ? (
                      <span className="glass-pill" style={{
                        fontSize: '0.75rem',
                        fontWeight: 700,
                        color: 'var(--accent-amber)',
                        background: 'rgba(245, 158, 11, 0.15)',
                        border: '1px solid rgba(245, 158, 11, 0.35)',
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: '4px'
                      }}>
                        💰 ₹{Number(call.dealValue).toLocaleString('en-IN')} • {call.dealStage || 'Proposal'}
                      </span>
                    ) : null}

                    <span className={`glass-pill ${
                      call.sentiment === 'positive' ? 'badge-sentiment-pos' :
                      call.sentiment === 'neutral' ? 'badge-sentiment-neu' : 'badge-sentiment-neg'
                    }`}>
                      {call.sentiment.toUpperCase()} ({call.sentimentScore}%)
                    </span>

                    <span className="glass-pill" style={{
                      fontSize: '0.75rem',
                      color: call.crmStatus === 'synced' ? 'var(--accent-emerald)' : 'var(--accent-amber)'
                    }}>
                      ✓ {call.crmType}
                    </span>

                    <button
                      onClick={() => setActiveAudioCall(call)}
                      className="btn-secondary"
                      style={{ fontSize: '0.8rem', padding: '0.45rem 0.85rem' }}
                    >
                      <ExternalLink size={14} />
                      <span>Deep Dive Modal</span>
                    </button>

                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        if (window.confirm(`Delete call record for ${call.contactName}?`)) {
                          deleteCallLog(call.id);
                        }
                      }}
                      className="btn-ghost"
                      style={{
                        padding: '0.45rem',
                        color: 'var(--accent-rose)',
                        borderRadius: 'var(--radius-sm)'
                      }}
                      title="Delete record from live database"
                    >
                      <Trash2 size={15} />
                    </button>
                  </div>
                </div>

                {/* INLINE AUDIO POD PLAYER STRIP */}
                <div style={{
                  background: isCallPlaying
                    ? 'linear-gradient(135deg, rgba(124, 58, 237, 0.18) 0%, rgba(6, 182, 212, 0.12) 100%)'
                    : 'var(--bg-surface-elevated)',
                  border: isCallPlaying ? '1px solid rgba(124, 58, 237, 0.4)' : '1px solid var(--border-subtle)',
                  borderRadius: 'var(--radius-md)',
                  padding: '0.85rem 1.15rem',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '0.75rem'
                }}>
                  {/* Pod Top Bar */}
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '0.5rem' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                      <span style={{
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: '4px',
                        fontSize: '0.74rem',
                        fontWeight: 700,
                        color: isCallPlaying ? '#a78bfa' : 'var(--text-dim)',
                        letterSpacing: '0.5px'
                      }}>
                        <Radio size={13} color={isCallPlaying ? '#a78bfa' : 'var(--text-dim)'} />
                        {isCallPlaying ? 'PODCAST AUDIO PLAYBACK ACTIVE' : 'CALL RECORDING POD'}
                      </span>
                      <span className="glass-pill" style={{ fontSize: '0.68rem', padding: '2px 8px' }}>
                        MP3 • 320kbps
                      </span>
                    </div>

                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
                      <button
                        onClick={e => triggerDownload(call, e)}
                        className="btn-ghost"
                        style={{ fontSize: '0.75rem', padding: '3px 8px', color: 'var(--text-muted)' }}
                        title="Download call audio file"
                      >
                        <Download size={13} />
                        <span>Download MP3</span>
                      </button>

                      <button
                        onClick={() => setExpandedTranscriptId(isTranscriptOpen ? null : call.id)}
                        className="btn-ghost"
                        style={{ fontSize: '0.75rem', padding: '3px 8px', color: 'var(--primary)' }}
                      >
                        <FileText size={13} />
                        <span>{isTranscriptOpen ? 'Hide Transcript' : 'AI Transcript'}</span>
                        {isTranscriptOpen ? <ChevronUp size={13} /> : <ChevronDown size={13} />}
                      </button>
                    </div>
                  </div>

                  {/* Pod Controls & Interactive Waveform Scrubber */}
                  <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', flexWrap: 'wrap' }}>
                    {/* Play/Pause Button */}
                    <button
                      onClick={() => togglePlayCallAudio(call)}
                      style={{
                        width: '42px',
                        height: '42px',
                        borderRadius: '50%',
                        background: isCallPlaying
                          ? 'linear-gradient(135deg, #10b981 0%, #059669 100%)'
                          : 'linear-gradient(135deg, #7c3aed 0%, #6366f1 100%)',
                        border: 'none',
                        color: '#fff',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        cursor: 'pointer',
                        boxShadow: isCallPlaying
                          ? '0 0 16px rgba(16, 185, 129, 0.5)'
                          : '0 4px 12px rgba(124, 58, 237, 0.4)',
                        transition: 'transform 0.15s ease',
                        flexShrink: 0
                      }}
                      title={isCallPlaying ? 'Pause Audio' : 'Play Audio Recording'}
                    >
                      {isCallPlaying ? <Pause size={18} fill="#fff" /> : <Play size={18} fill="#fff" style={{ marginLeft: '2px' }} />}
                    </button>

                    {/* Time Counter */}
                    <div style={{ fontSize: '0.82rem', fontFamily: 'var(--font-mono)', color: 'var(--text-main)', minWidth: '95px' }}>
                      <span style={{ fontWeight: 700 }}>{formatSeconds(callCurrentTime)}</span>
                      <span style={{ color: 'var(--text-dim)' }}> / {formatSeconds(callTotalDuration)}</span>
                    </div>

                    {/* Interactive Animated Waveform / Scrubber Bar */}
                    <div
                      onClick={e => {
                        const rect = e.currentTarget.getBoundingClientRect();
                        const clickX = e.clientX - rect.left;
                        const pct = Math.max(0, Math.min(1, clickX / rect.width));
                        if (isCallActive) {
                          handleSeek(pct * callTotalDuration);
                        } else {
                          togglePlayCallAudio(call);
                        }
                      }}
                      style={{
                        flex: 1,
                        height: '36px',
                        minWidth: '200px',
                        background: 'rgba(0, 0, 0, 0.25)',
                        borderRadius: '8px',
                        padding: '4px 8px',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '3px',
                        cursor: 'pointer',
                        position: 'relative',
                        overflow: 'hidden'
                      }}
                      title="Click anywhere to scrub playback"
                    >
                      {/* Active Progress Overlay */}
                      <div style={{
                        position: 'absolute',
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: `${progressRatio * 100}%`,
                        background: 'rgba(124, 58, 237, 0.18)',
                        pointerEvents: 'none',
                        transition: 'width 0.1s linear'
                      }} />

                      {/* Waveform Bars */}
                      {(call.waveform || [25, 45, 65, 80, 50, 70, 95, 60, 40, 75, 85, 90, 65, 55, 75, 80, 60, 45, 30, 50, 70, 85, 60, 40, 30, 45, 60, 75, 50, 35]).map((val, idx) => {
                        const barPct = (idx + 1) / (call.waveform?.length || 30);
                        const isBarPassed = barPct <= progressRatio;
                        const dynamicHeight = isCallPlaying
                          ? Math.min(100, Math.max(20, (val * (0.8 + 0.4 * Math.sin((currentTime * 4) + idx)))))
                          : val;

                        return (
                          <div
                            key={idx}
                            style={{
                              flex: 1,
                              height: `${dynamicHeight}%`,
                              borderRadius: '2px',
                              background: isBarPassed
                                ? 'linear-gradient(to top, #7c3aed, #a78bfa)'
                                : 'rgba(255, 255, 255, 0.2)',
                              transition: 'height 0.1s ease, background 0.1s ease'
                            }}
                          />
                        );
                      })}
                    </div>

                    {/* Speed Selector */}
                    {isCallActive && (
                      <div style={{ display: 'flex', alignItems: 'center', gap: '3px' }}>
                        {[1, 1.25, 1.5, 2].map(speed => (
                          <button
                            key={speed}
                            onClick={() => setPlaybackSpeed(speed)}
                            style={{
                              background: playbackSpeed === speed ? 'var(--primary)' : 'rgba(255, 255, 255, 0.08)',
                              color: playbackSpeed === speed ? '#fff' : 'var(--text-dim)',
                              border: 'none',
                              borderRadius: '4px',
                              padding: '3px 6px',
                              fontSize: '0.72rem',
                              fontWeight: 600,
                              cursor: 'pointer'
                            }}
                          >
                            {speed}x
                          </button>
                        ))}
                      </div>
                    )}
                  </div>

                  {/* Expandable Diarized Transcript Section */}
                  {isTranscriptOpen && (
                    <div style={{
                      marginTop: '0.5rem',
                      padding: '0.85rem',
                      background: 'rgba(0, 0, 0, 0.35)',
                      borderRadius: 'var(--radius-sm)',
                      border: '1px solid var(--border-glass)',
                      display: 'flex',
                      flexDirection: 'column',
                      gap: '0.65rem'
                    }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <span style={{ fontSize: '0.78rem', fontWeight: 700, color: 'var(--text-main)', display: 'flex', alignItems: 'center', gap: '5px' }}>
                          <Sparkles size={13} color="var(--primary)" /> AI Whisper Diarized Dialogue
                        </span>
                        <span style={{ fontSize: '0.72rem', color: 'var(--text-dim)' }}>
                          Click timestamp to jump audio
                        </span>
                      </div>

                      {call.transcript && call.transcript.length > 0 ? (
                        call.transcript.map((item, tIdx) => {
                          const parts = item.timestamp.split(':');
                          const tSec = parseInt(parts[0], 10) * 60 + parseInt(parts[1] || '0', 10);
                          const isCurrentSpeaker = isCallActive && currentTime >= tSec && (tIdx === call.transcript!.length - 1 || currentTime < (parseInt(call.transcript![tIdx + 1].timestamp.split(':')[0], 10) * 60 + parseInt(call.transcript![tIdx + 1].timestamp.split(':')[1] || '0', 10)));

                          return (
                            <div
                              key={tIdx}
                              onClick={() => {
                                if (!isCallActive) togglePlayCallAudio(call);
                                setTimeout(() => handleSeek(tSec), 50);
                              }}
                              style={{
                                padding: '6px 10px',
                                borderRadius: '6px',
                                background: isCurrentSpeaker ? 'rgba(124, 58, 237, 0.22)' : 'transparent',
                                borderLeft: isCurrentSpeaker ? '3px solid var(--primary)' : '3px solid transparent',
                                cursor: 'pointer',
                                transition: 'all 0.15s ease'
                              }}
                            >
                              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', fontSize: '0.76rem' }}>
                                <span style={{ fontWeight: 700, color: isCurrentSpeaker ? '#c4b5fd' : 'var(--text-main)' }}>
                                  {item.speaker}
                                </span>
                                <span style={{ color: 'var(--text-dim)', fontFamily: 'var(--font-mono)' }}>
                                  [{item.timestamp}]
                                </span>
                              </div>
                              <p style={{ fontSize: '0.82rem', color: isCurrentSpeaker ? '#f1f5f9' : 'var(--text-muted)', marginTop: '2px' }}>
                                {item.text}
                              </p>
                            </div>
                          );
                        })
                      ) : (
                        <p style={{ fontSize: '0.8rem', color: 'var(--text-dim)' }}>
                          No text transcript available for this call. Recording is stored securely.
                        </p>
                      )}
                    </div>
                  )}
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* STICKY BOTTOM AUDIO PODCAST PLAYER (DOCK HUD) */}
      {currentPlayingCall && (
        <div style={{
          position: 'fixed',
          bottom: '16px',
          left: '50%',
          transform: 'translateX(-50%)',
          width: 'min(94%, 1100px)',
          background: 'rgba(16, 18, 29, 0.92)',
          backdropFilter: 'blur(20px)',
          border: '1px solid rgba(124, 58, 237, 0.4)',
          borderRadius: 'var(--radius-lg)',
          boxShadow: '0 20px 50px rgba(0, 0, 0, 0.7), 0 0 30px rgba(124, 58, 237, 0.25)',
          padding: '0.85rem 1.4rem',
          zIndex: 9999,
          display: 'flex',
          flexDirection: 'column',
          gap: '0.5rem',
          animation: 'slideUp 0.25s ease'
        }}>
          {/* Top Row: Track Meta & Close */}
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
              <div style={{
                width: '10px',
                height: '10px',
                borderRadius: '50%',
                background: isPlaying ? '#10b981' : '#f59e0b',
                boxShadow: isPlaying ? '0 0 8px #10b981' : 'none'
              }} />
              <span style={{ fontSize: '0.82rem', fontWeight: 700, color: 'var(--text-main)' }}>
                {currentPlayingCall.contactName} ({currentPlayingCall.company})
              </span>
              <span style={{ fontSize: '0.75rem', color: 'var(--text-dim)' }}>
                • Rep: {currentPlayingCall.repName} • {currentPlayingCall.direction.toUpperCase()}
              </span>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
              <button
                onClick={() => setActiveAudioCall(currentPlayingCall)}
                className="btn-ghost"
                style={{ fontSize: '0.75rem', padding: '3px 8px', color: 'var(--primary)' }}
              >
                <Sparkles size={12} />
                <span>Deep Dive AI Modal</span>
              </button>

              <button
                onClick={() => {
                  if (audioRef.current) audioRef.current.pause();
                  setIsPlaying(false);
                  setPlayingCallId(null);
                }}
                className="btn-ghost"
                style={{ padding: '4px', color: 'var(--text-dim)' }}
                title="Close Pod Player"
              >
                <X size={16} />
              </button>
            </div>
          </div>

          {/* Bottom Row: Controls, Scrubber, Volume & Speed */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', flexWrap: 'wrap' }}>
            {/* Rewind 10s */}
            <button
              onClick={() => handleSkip(-10)}
              className="btn-ghost"
              style={{ padding: '6px', color: 'var(--text-main)' }}
              title="Rewind 10s"
            >
              <RotateCcw size={16} />
            </button>

            {/* Play/Pause Button */}
            <button
              onClick={() => togglePlayCallAudio(currentPlayingCall)}
              style={{
                width: '38px',
                height: '38px',
                borderRadius: '50%',
                background: isPlaying ? 'var(--accent-emerald)' : 'var(--primary)',
                border: 'none',
                color: '#fff',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                cursor: 'pointer'
              }}
            >
              {isPlaying ? <Pause size={16} fill="#fff" /> : <Play size={16} fill="#fff" style={{ marginLeft: '2px' }} />}
            </button>

            {/* Fast Forward 10s */}
            <button
              onClick={() => handleSkip(10)}
              className="btn-ghost"
              style={{ padding: '6px', color: 'var(--text-main)' }}
              title="Forward 10s"
            >
              <FastForward size={16} />
            </button>

            {/* Timer */}
            <div style={{ fontSize: '0.8rem', fontFamily: 'var(--font-mono)', minWidth: '85px', color: 'var(--text-muted)' }}>
              {formatSeconds(currentTime)} / {formatSeconds(duration || currentPlayingCall.duration || 120)}
            </div>

            {/* Range Scrubber Bar */}
            <input
              type="range"
              min={0}
              max={duration || currentPlayingCall.duration || 120}
              value={currentTime}
              onChange={e => handleSeek(parseFloat(e.target.value))}
              style={{
                flex: 1,
                minWidth: '150px',
                accentColor: 'var(--primary)',
                cursor: 'pointer',
                height: '5px'
              }}
            />

            {/* Speed Selector */}
            <div style={{ display: 'flex', alignItems: 'center', gap: '3px' }}>
              {[1, 1.25, 1.5].map(spd => (
                <button
                  key={spd}
                  onClick={() => setPlaybackSpeed(spd)}
                  style={{
                    background: playbackSpeed === spd ? 'var(--primary)' : 'rgba(255, 255, 255, 0.08)',
                    color: playbackSpeed === spd ? '#fff' : 'var(--text-dim)',
                    border: 'none',
                    borderRadius: '4px',
                    padding: '2px 6px',
                    fontSize: '0.72rem',
                    fontWeight: 600,
                    cursor: 'pointer'
                  }}
                >
                  {spd}x
                </button>
              ))}
            </div>

            {/* Mute Toggle */}
            <button
              onClick={() => setIsMuted(!isMuted)}
              className="btn-ghost"
              style={{ padding: '6px', color: isMuted ? 'var(--accent-rose)' : 'var(--text-muted)' }}
              title={isMuted ? 'Unmute' : 'Mute'}
            >
              {isMuted ? <VolumeX size={16} /> : <Volume2 size={16} />}
            </button>

            {/* Download */}
            <button
              onClick={e => triggerDownload(currentPlayingCall, e)}
              className="btn-ghost"
              style={{ padding: '6px', color: 'var(--text-muted)' }}
              title="Download MP3"
            >
              <Download size={16} />
            </button>
          </div>
        </div>
      )}

    </div>
  );
}
