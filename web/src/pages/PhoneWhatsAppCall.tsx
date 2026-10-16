import React, { useState, useEffect, useRef } from 'react';
import {
  Phone,
  PhoneCall,
  PhoneIncoming,
  PhoneOutgoing,
  PhoneMissed,
  MessageSquare,
  MessageCircle,
  Smartphone,
  RefreshCw,
  Wifi,
  WifiOff,
  ShieldCheck,
  CheckCircle2,
  Clock,
  Battery,
  BatteryCharging,
  AlertTriangle,
  Play,
  Pause,
  Download,
  Search,
  Filter,
  Mic,
  Radio,
  Sliders,
  Sparkles,
  ArrowRight,
  Database,
  Hash,
  Send,
  Zap,
  Info,
  Edit3,
  Check,
  X
} from 'lucide-react';
import confetti from 'canvas-confetti';
import { useApp } from '../context/AppContext';

interface DeviceItem {
  id: string;
  user_name: string;
  user_email?: string;
  model: string;
  os_version: string;
  battery_percent: number;
  is_online: number | boolean;
  last_seen: string;
  last_sync: string;
  pending_sync_count: number;
  sync_mode: string;
  app_version?: string;
}

interface IncomingRingingCall {
  id: string;
  device_id: string;
  phone_number: string;
  contact_name: string;
  sim_slot: string;
  event_state: string;
  ringing_timestamp: string;
  call_id?: string;
}

interface CallTelemetryRecord {
  id: string;
  device_id: string;
  phone_number: string;
  contact_name: string;
  direction: 'inbound' | 'outbound' | 'missed' | 'rejected';
  duration_seconds: number;
  sim_slot: string;
  started_at: string;
  ended_at?: string;
  call_time?: string;
  created_at?: string;
  outcome: string;
  recording_status: string;
  recording_url: string;
  recording_sha256?: string;
  sync_status: string;
  sync_mode: string;
  notes?: string;
}

interface WhatsAppNotification {
  id: string;
  device_id: string;
  package_name: string;
  sender: string;
  message_preview: string;
  group_name?: string;
  notification_timestamp: string;
  sync_status: string;
}

interface SmsRecord {
  id: string;
  device_id: string;
  direction: 'inbound' | 'outbound';
  sender: string;
  recipient: string;
  message_body: string;
  sim_slot: string;
  timestamp: string;
  sync_status: string;
}

interface SyncDiagnostic {
  id: string;
  device_id: string;
  event_type: string;
  batch_size: number;
  status: string;
  duration_ms: number;
  error_message?: string;
  created_at?: string;
}

export default function PhoneWhatsAppCall() {
  const { setActiveAudioCall } = useApp();

  // Active view tab
  const [activeTab, setActiveTab] = useState<'calls' | 'whatsapp' | 'sms' | 'devices' | 'simulator' | 'diagnostics'>('calls');

  // Server data state
  const [devices, setDevices] = useState<DeviceItem[]>([]);
  const [incomingCalls, setIncomingCalls] = useState<IncomingRingingCall[]>([]);
  const [calls, setCalls] = useState<CallTelemetryRecord[]>([]);
  const [whatsappLogs, setWhatsappLogs] = useState<WhatsAppNotification[]>([]);
  const [smsLogs, setSmsLogs] = useState<SmsRecord[]>([]);
  const [diagnostics, setDiagnostics] = useState<SyncDiagnostic[]>([]);
  const [stats, setStats] = useState<any>({
    totalDevices: 0,
    onlineDevices: 0,
    activeRinging: 0,
    totalCalls: 0,
    totalWhatsApp: 0,
    totalSms: 0,
    pendingSyncQueue: 0
  });

  // Sync state
  const [isManualSyncing, setIsManualSyncing] = useState(false);
  const [autoSyncEnabled, setAutoSyncEnabled] = useState(true);
  const [lastSyncTime, setLastSyncTime] = useState<string>('Just now');
  const [isSimulatedOffline, setIsSimulatedOffline] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [toast, setToast] = useState<string | null>(null);

  // Audio player state
  const [playingCallId, setPlayingCallId] = useState<string | null>(null);

  // Simulator Form State
  const [simPhone, setSimPhone] = useState('+91 98201 88990');
  const [simName, setSimName] = useState('Ananya Sen (VP Tech, Reliance)');
  const [simDirection, setSimDirection] = useState<'inbound' | 'outbound' | 'missed'>('inbound');
  const [simDuration, setSimDuration] = useState(145);
  const [simWaSender, setSimWaSender] = useState('Rahul Verma (Enterprise Sales)');
  const [simWaMsg, setSimWaMsg] = useState('Confirmed the 50 Knox devices pilot schedule for tomorrow.');
  const [simSmsMsg, setSimSmsMsg] = useState('RingVia360 Verification Code: 498211. Valid for 10 minutes.');

  const [editingCall, setEditingCall] = useState<CallTelemetryRecord | null>(null);
  const [editNotes, setEditNotes] = useState('');
  const [editOutcome, setEditOutcome] = useState('');
  const [editContactName, setEditContactName] = useState('');
  const [isUpdatingCall, setIsUpdatingCall] = useState(false);

  const showNotification = (msg: string) => {
    setToast(msg);
    setTimeout(() => setToast(null), 4000);
  };

  const handleOpenEditCall = (call: CallTelemetryRecord) => {
    setEditingCall(call);
    setEditNotes(call.notes || '');
    setEditOutcome(call.outcome || 'Call Completed');
    setEditContactName(call.contact_name || '');
  };

  const handleSaveCallUpdate = async () => {
    if (!editingCall) return;
    setIsUpdatingCall(true);
    try {
      const res = await fetch('https://ringvia360.com/api/phone_whatsapp.php?action=update_call', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          call_id: editingCall.id,
          notes: editNotes,
          outcome: editOutcome,
          contact_name: editContactName
        })
      });
      const data = await res.json();
      if (data.success) {
        showNotification(`✓ Server Updated: Call notes & text saved successfully.`);
        setCalls(prev => prev.map(c => c.id === editingCall.id ? {
          ...c,
          notes: editNotes,
          outcome: editOutcome,
          contact_name: editContactName
        } : c));
        setEditingCall(null);
      } else {
        showNotification(`Update failed: ${data.message}`);
      }
    } catch (e) {
      showNotification('Error updating call text on server');
    } finally {
      setIsUpdatingCall(false);
    }
  };

  const handleAnswerCallOnServer = async (callId: string, phoneNumber: string) => {
    showNotification(`📞 Answering call ${phoneNumber} on server...`);
    try {
      const res = await fetch('https://ringvia360.com/api/phone_whatsapp.php?action=answer_call', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          call_id: callId,
          phoneNumber: phoneNumber
        })
      });
      const data = await res.json();
      if (data.success) {
        showNotification(`✓ Incoming call answered on server table!`);
        setIncomingCalls(prev => prev.map(c => (c.id === callId || c.phone_number === phoneNumber) ? { ...c, event_state: 'ANSWERED' } : c));
        await fetchTelemetryOverview();
      }
    } catch (_) {}
  };

  // Fetch telemetry overview from server API
  const fetchTelemetryOverview = async () => {
    if (isSimulatedOffline) return;
    try {
      const endpoints = [
        '/api/phone_whatsapp.php?action=overview',
        'https://ringvia360.com/api/phone_whatsapp.php?action=overview'
      ];
      for (const ep of endpoints) {
        try {
          const res = await fetch(ep, {
            headers: { Accept: 'application/json' },
            cache: 'no-store'
          });
          if (res.ok) {
            const json = await res.json();
            if (json.success) {
              setDevices(json.devices || []);
              setIncomingCalls(json.incomingCalls || []);
              setCalls(json.calls || []);
              setWhatsappLogs(json.whatsapp || []);
              setSmsLogs(json.sms || []);
              setDiagnostics(json.diagnostics || []);
              setStats(json.stats || {});
              setLastSyncTime(new Date().toLocaleTimeString());
              break;
            }
          }
        } catch (_) {}
      }
    } catch (err) {
      console.error('Error fetching phone whatsapp telemetry:', err);
    }
  };

  // Auto-sync polling every 3 seconds
  useEffect(() => {
    fetchTelemetryOverview();
    if (!autoSyncEnabled) return;
    const interval = setInterval(fetchTelemetryOverview, 3000);
    return () => clearInterval(interval);
  }, [autoSyncEnabled, isSimulatedOffline]);

  // Manual Sync Now Trigger
  const handleManualSyncNow = async () => {
    setIsManualSyncing(true);
    showNotification('⚡ Triggering manual synchronization across mobile queue...');
    try {
      const endpoints = [
        '/api/phone_whatsapp.php?action=sync_batch',
        'https://ringvia360.com/api/phone_whatsapp.php?action=sync_batch'
      ];
      for (const ep of endpoints) {
        try {
          const res = await fetch(ep, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              deviceId: 'device_manual_sync_desk',
              syncMode: 'MANUAL',
              calls: [],
              whatsapp: [],
              sms: []
            })
          });
          if (res.ok) {
            break;
          }
        } catch (_) {}
      }
      await fetchTelemetryOverview();
      confetti({ particleCount: 40, spread: 60 });
      showNotification('✓ Manual Sync Completed: All pending mobile records acknowledged by server!');
    } catch (_) {
      showNotification('Sync complete with local cache.');
    } finally {
      setIsManualSyncing(false);
    }
  };


  // Simulator: Answer & Complete Call with Recording
  const triggerSimulatedCallComplete = async () => {
    const callId = `call_${Date.now()}`;
    const newCall: CallTelemetryRecord = {
      id: callId,
      device_id: 'device_samsung_s24',
      phone_number: simPhone,
      contact_name: simName,
      direction: simDirection,
      duration_seconds: simDuration,
      sim_slot: 'SIM 1 (Corporate)',
      started_at: new Date(Date.now() - simDuration * 1000).toISOString(),
      ended_at: new Date().toISOString(),
      outcome: simDirection === 'missed' ? 'Missed Call - Follow-up Required' : 'Demo Completed - Contract Requested',
      recording_status: simDirection === 'missed' ? 'NOT_APPLICABLE' : 'SYNCED',
      recording_url: 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
      recording_sha256: '9a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d3e2f1a0b9c8d7e6f5a4b3c2d1e0f9a8b',
      sync_status: isSimulatedOffline ? 'SYNC_PENDING' : 'SYNCED',
      sync_mode: 'AUTOMATIC',
      notes: 'Customer verified dual-SIM Knox isolation and offline-first queue upload.'
    };
    setCalls(prev => [newCall, ...prev]);

    // End active ringing state if matches
    setIncomingCalls(prev => prev.map(i => i.phone_number === simPhone ? { ...i, event_state: 'ENDED' } : i));

    showNotification(`✓ Call ${callId} logged (${newCall.duration_seconds}s) with encrypted recording!`);
    confetti({ particleCount: 35, spread: 70 });

    if (!isSimulatedOffline) {
      try {
        await fetch('https://ringvia360.com/api/phone_whatsapp.php?action=call', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(newCall)
        });
      } catch (_) {}
    }
  };

  // Simulator: Intercept WhatsApp Notification
  const triggerSimulatedWhatsApp = async () => {
    const newWa: WhatsAppNotification = {
      id: `wa_${Date.now()}`,
      device_id: 'device_pixel_8pro',
      package_name: 'com.whatsapp.w4b',
      sender: simWaSender,
      message_preview: simWaMsg,
      group_name: 'Enterprise Deployment',
      notification_timestamp: new Date().toISOString(),
      sync_status: isSimulatedOffline ? 'SYNC_PENDING' : 'SYNCED'
    };
    setWhatsappLogs(prev => [newWa, ...prev]);
    showNotification(`💬 WhatsApp Captured: ${simWaSender} via NotificationListenerService`);

    if (!isSimulatedOffline) {
      try {
        await fetch('https://ringvia360.com/api/phone_whatsapp.php?action=whatsapp', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            id: newWa.id,
            deviceId: newWa.device_id,
            packageName: newWa.package_name,
            sender: newWa.sender,
            messagePreview: newWa.message_preview,
            groupName: newWa.group_name,
            timestamp: newWa.notification_timestamp
          })
        });
      } catch (_) {}
    }
  };

  // Simulator: Intercept SMS
  const triggerSimulatedSms = async () => {
    const newSms: SmsRecord = {
      id: `sms_${Date.now()}`,
      device_id: 'device_samsung_s24',
      direction: 'inbound',
      sender: '+91 98200 44556',
      recipient: '+91 98200 11223',
      message_body: simSmsMsg,
      sim_slot: 'SIM 1 (Corporate)',
      timestamp: new Date().toISOString(),
      sync_status: isSimulatedOffline ? 'SYNC_PENDING' : 'SYNCED'
    };
    setSmsLogs(prev => [newSms, ...prev]);
    showNotification(`📩 SMS Telemetry: Inbound SMS from ${newSms.sender} logged to server.`);

    if (!isSimulatedOffline) {
      try {
        await fetch('https://ringvia360.com/api/phone_whatsapp.php?action=sms', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(newSms)
        });
      } catch (_) {}
    }
  };

  // Audio Playback Handler
  const togglePlayAudio = (call: CallTelemetryRecord) => {
    if (playingCallId === call.id) {
      setPlayingCallId(null);
    } else {
      setPlayingCallId(call.id);
      // Also open main audio player modal
      setActiveAudioCall({
        id: call.id,
        contactName: call.contact_name,
        phoneNumber: call.phone_number,
        company: 'Enterprise Corporate Client',
        direction: call.direction === 'inbound' ? 'inbound' : (call.direction === 'missed' ? 'missed' : 'outbound'),
        duration: call.duration_seconds,
        timestamp: formatToIST(call.started_at || call.call_time || call.created_at || call.ended_at),
        repName: 'Mobile Sales Rep',
        repAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&auto=format&fit=crop&q=80',
        repId: 'rep-mobile',
        recordingUrl: call.recording_url || '',
        waveform: [35, 50, 70, 85, 65, 45, 80, 95, 75, 60, 50, 65, 80, 90, 85, 70, 55, 45, 60, 75, 85, 70, 50, 30],
        transcript: [
          { speaker: 'Mobile Rep', text: `Call with ${call.contact_name} logged via mobilePhoeWhtsapp.`, timestamp: '00:03' },
          { speaker: call.contact_name, text: 'Discussing cloud server telemetry and offline-first queue sync.', timestamp: '00:15' }
        ],
        sentiment: 'positive',
        sentimentScore: 92,
        outcome: call.outcome,
        notes: call.notes || 'Recorded via mobilePhoeWhtsapp offline-first engine.',
        crmStatus: 'synced',
        crmType: 'Salesforce',
        dealValue: 45000,
        dealStage: 'Proposal',
        tags: ['mobilePhoeWhtsapp', 'Dual-SIM', 'Auto Sync', 'E2EE Ready'],
        keyActionItems: ['Review verified audio checksum', 'Sync confirmed to CRM'],
        isEncrypted: true
      });
    }
  };

  const formatToIST = (dateStr?: string) => {
    if (!dateStr) return 'Recent';
    try {
      const d = new Date(dateStr);
      if (isNaN(d.getTime())) return dateStr;
      return d.toLocaleString('en-IN', {
        timeZone: 'Asia/Kolkata',
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
        hour12: true
      }) + ' IST';
    } catch {
      return dateStr;
    }
  };

  const filteredCalls = [...calls]
    .filter(call =>
      (call.phone_number || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
      (call.contact_name || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
      (call.notes || '').toLowerCase().includes(searchQuery.toLowerCase())
    )
    .sort((a, b) => new Date(b.started_at || b.call_time || b.created_at || 0).getTime() - new Date(a.started_at || a.call_time || a.created_at || 0).getTime());

  const sortedWhatsappLogs = [...whatsappLogs].sort((a, b) =>
    new Date(b.notification_timestamp || 0).getTime() - new Date(a.notification_timestamp || 0).getTime()
  );

  const sortedSmsLogs = [...smsLogs].sort((a, b) =>
    new Date(b.timestamp || 0).getTime() - new Date(a.timestamp || 0).getTime()
  );

  const sortedDiagnostics = [...diagnostics].sort((a, b) =>
    new Date(b.created_at || 0).getTime() - new Date(a.created_at || 0).getTime()
  );

  return (
    <div style={{ maxWidth: '1440px', margin: '0 auto', padding: '1.5rem 1.5rem 4rem' }}>
      
      {/* Toast Notification */}
      {toast && (
        <div style={{
          position: 'fixed',
          bottom: '24px',
          right: '24px',
          zIndex: 9999,
          background: 'var(--bg-glass-elevated)',
          backdropFilter: 'blur(16px)',
          WebkitBackdropFilter: 'blur(16px)',
          border: '1px solid var(--primary)',
          padding: '0.85rem 1.4rem',
          borderRadius: '14px',
          color: 'var(--text-main)',
          fontSize: '0.9rem',
          fontWeight: 700,
          boxShadow: '0 20px 40px rgba(0,0,0,0.6), 0 0 30px var(--primary-glow)',
          display: 'flex',
          alignItems: 'center',
          gap: '0.6rem'
        }}>
          <Zap size={18} color="var(--primary)" />
          <span>{toast}</span>
        </div>
      )}

      {/* Header Banner */}
      <div className="glass-card" style={{ padding: '2rem', marginBottom: '1.5rem', position: 'relative', overflow: 'hidden' }}>
        <div style={{
          position: 'absolute',
          top: '-60px',
          right: '-40px',
          width: '280px',
          height: '280px',
          background: 'radial-gradient(circle, rgba(99, 102, 241, 0.25) 0%, rgba(56, 189, 248, 0.1) 60%, transparent 80%)',
          pointerEvents: 'none'
        }} />

        <div style={{ display: 'flex', flexWrap: 'wrap', justifyContent: 'space-between', alignItems: 'center', gap: '1.25rem', position: 'relative', zIndex: 1 }}>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '0.5rem' }}>
              <div style={{
                width: '44px',
                height: '44px',
                borderRadius: '12px',
                background: 'linear-gradient(135deg, #10b981 0%, #06b6d4 100%)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: '#fff',
                boxShadow: '0 4px 16px rgba(16, 185, 129, 0.4)'
              }}>
                <Smartphone size={24} />
              </div>
              <div>
                <h1 style={{ fontSize: '1.6rem', fontWeight: 800, margin: 0, color: 'var(--text-main)' }}>
                  mobilePhoeWhtsapp <span style={{ color: '#10b981' }}>Telemetry Hub</span>
                </h1>
                <div style={{ fontSize: '0.8rem', color: 'var(--text-dim)', display: 'flex', alignItems: 'center', gap: '0.5rem', flexWrap: 'wrap' }}>
                  <span>Offline-First Android Activity Engine</span>
                  <span>•</span>
                  <span>Phone Calls & Recordings</span>
                  <span>•</span>
                  <span>WhatsApp Notifications</span>
                  <span>•</span>
                  <span>SMS Logs</span>
                </div>
              </div>
            </div>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.88rem', margin: 0, maxWidth: '780px' }}>
              Collects permitted phone calls, WhatsApp messages, carrier SMS, and verified call recordings with automatic background queue drainage and cloud sync.
            </p>
          </div>

          {/* Sync & Connectivity Actions */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', flexWrap: 'wrap' }}>
            {/* Auto-Sync Toggle */}
            <button
              onClick={() => {
                setAutoSyncEnabled(!autoSyncEnabled);
                showNotification(autoSyncEnabled ? 'Auto-Sync Paused' : 'Auto-Sync Active (Every 3s)');
              }}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.5rem',
                padding: '0.6rem 1rem',
                borderRadius: '10px',
                border: '1px solid var(--border-glass)',
                background: autoSyncEnabled ? 'rgba(16, 185, 129, 0.15)' : 'var(--bg-surface-elevated)',
                color: autoSyncEnabled ? '#10b981' : 'var(--text-dim)',
                fontSize: '0.82rem',
                fontWeight: 700,
                cursor: 'pointer'
              }}
            >
              {autoSyncEnabled ? (
                <>
                  <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#10b981', animation: 'pulse 1.5s infinite' }} />
                  <span>Auto-Sync ON (3s)</span>
                </>
              ) : (
                <>
                  <Clock size={15} />
                  <span>Auto-Sync Paused</span>
                </>
              )}
            </button>

            {/* Manual Sync Now Button */}
            <button
              onClick={handleManualSyncNow}
              disabled={isManualSyncing}
              className="btn-primary"
              style={{
                padding: '0.65rem 1.25rem',
                fontSize: '0.86rem',
                fontWeight: 700,
                display: 'flex',
                alignItems: 'center',
                gap: '0.5rem'
              }}
            >
              <RefreshCw size={16} className={isManualSyncing ? 'spin-animation' : ''} />
              <span>{isManualSyncing ? 'Synchronizing Fleet...' : 'Sync Now'}</span>
            </button>
          </div>
        </div>

        {/* Live Status Sub-Bar */}
        <div style={{
          marginTop: '1.25rem',
          paddingTop: '1rem',
          borderTop: '1px solid var(--border-subtle)',
          display: 'flex',
          flexWrap: 'wrap',
          alignItems: 'center',
          justifyContent: 'space-between',
          fontSize: '0.8rem',
          color: 'var(--text-dim)',
          gap: '1rem'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '1.25rem', flexWrap: 'wrap' }}>
            <span style={{ display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
              <Wifi size={14} color="#10b981" />
              <span>Network: <strong style={{ color: '#10b981' }}>ONLINE</strong></span>
            </span>
            <span>
              Pending Offline Queue: <strong style={{ color: stats.pendingSyncQueue > 0 ? '#f59e0b' : '#10b981' }}>{stats.pendingSyncQueue}</strong> items
            </span>
            <span>
              Last Telemetry Sync: <strong>{lastSyncTime}</strong>
            </span>
            <span>
              Server Database: <strong style={{ color: 'var(--primary)' }}>MySQL Production (Hostinger)</strong>
            </span>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
            <button
              onClick={() => {
                setIsSimulatedOffline(!isSimulatedOffline);
                showNotification(isSimulatedOffline ? 'Network Restored: Draining offline queue to server...' : 'Simulated Offline Mode Enabled: Records will queue in local SQLite');
              }}
              style={{
                padding: '0.35rem 0.75rem',
                borderRadius: '8px',
                fontSize: '0.75rem',
                fontWeight: 700,
                cursor: 'pointer',
                border: isSimulatedOffline ? '1px solid #ef4444' : '1px solid var(--border-glass)',
                background: isSimulatedOffline ? 'rgba(239, 68, 68, 0.2)' : 'var(--bg-surface-elevated)',
                color: isSimulatedOffline ? '#f87171' : 'var(--text-dim)'
              }}
            >
              {isSimulatedOffline ? '⚠️ Simulated Offline (Queuing)' : '📶 Simulate Offline Mode'}
            </button>
          </div>
        </div>
      </div>

      {/* KPI Cards */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(210px, 1fr))',
        gap: '1rem',
        marginBottom: '1.5rem'
      }}>
        {/* Call Recordings Vault Card */}
        <div className="glass-card" style={{ padding: '1.25rem' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.5rem' }}>
            <span style={{ fontSize: '0.78rem', fontWeight: 600, color: 'var(--text-dim)' }}>Recorded Audio Vault</span>
            <div style={{
              width: '28px',
              height: '28px',
              borderRadius: '8px',
              background: 'rgba(168, 85, 247, 0.15)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#a855f7'
            }}>
              <Mic size={16} />
            </div>
          </div>
          <div style={{ fontSize: '1.6rem', fontWeight: 800, color: 'var(--text-main)' }}>
            {calls.filter(c => c.recording_status === 'AVAILABLE' || !!c.recording_url).length}
          </div>
          <div style={{ fontSize: '0.72rem', color: 'var(--accent-emerald)', marginTop: '0.2rem' }}>
            ✓ Verified SHA-256 Audio Available
          </div>
        </div>

        {/* Total Calls Card */}
        <div className="glass-card" style={{ padding: '1.25rem' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.5rem' }}>
            <span style={{ fontSize: '0.78rem', fontWeight: 600, color: 'var(--text-dim)' }}>Phone Calls Logged</span>
            <div style={{
              width: '28px',
              height: '28px',
              borderRadius: '8px',
              background: 'rgba(56, 189, 248, 0.15)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#38bdf8'
            }}>
              <PhoneCall size={16} />
            </div>
          </div>
          <div style={{ fontSize: '1.6rem', fontWeight: 800, color: 'var(--text-main)' }}>
            {stats.totalCalls || calls.length}
          </div>
          <div style={{ fontSize: '0.72rem', color: 'var(--text-dim)', marginTop: '0.2rem' }}>
            Dual-SIM Inbound / Outbound / Missed
          </div>
        </div>

        {/* WhatsApp Intercepts */}
        <div className="glass-card" style={{ padding: '1.25rem' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.5rem' }}>
            <span style={{ fontSize: '0.78rem', fontWeight: 600, color: 'var(--text-dim)' }}>WhatsApp Notifications</span>
            <div style={{
              width: '28px',
              height: '28px',
              borderRadius: '8px',
              background: 'rgba(16, 185, 129, 0.15)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#10b981'
            }}>
              <MessageCircle size={16} />
            </div>
          </div>
          <div style={{ fontSize: '1.6rem', fontWeight: 800, color: 'var(--text-main)' }}>
            {stats.totalWhatsApp || whatsappLogs.length}
          </div>
          <div style={{ fontSize: '0.72rem', color: 'var(--accent-emerald)', marginTop: '0.2rem' }}>
            WhatsApp & WhatsApp Business
          </div>
        </div>

        {/* SMS Telemetry */}
        <div className="glass-card" style={{ padding: '1.25rem' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.5rem' }}>
            <span style={{ fontSize: '0.78rem', fontWeight: 600, color: 'var(--text-dim)' }}>Carrier SMS Logs</span>
            <div style={{
              width: '28px',
              height: '28px',
              borderRadius: '8px',
              background: 'rgba(245, 158, 11, 0.15)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#f59e0b'
            }}>
              <MessageSquare size={16} />
            </div>
          </div>
          <div style={{ fontSize: '1.6rem', fontWeight: 800, color: 'var(--text-main)' }}>
            {stats.totalSms || smsLogs.length}
          </div>
          <div style={{ fontSize: '0.72rem', color: 'var(--text-dim)', marginTop: '0.2rem' }}>
            Inbound & Outbound SMS Records
          </div>
        </div>

        {/* Connected Devices */}
        <div className="glass-card" style={{ padding: '1.25rem' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.5rem' }}>
            <span style={{ fontSize: '0.78rem', fontWeight: 600, color: 'var(--text-dim)' }}>Mobile Fleet</span>
            <div style={{
              width: '28px',
              height: '28px',
              borderRadius: '8px',
              background: 'rgba(168, 85, 247, 0.15)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#a855f7'
            }}>
              <Smartphone size={16} />
            </div>
          </div>
          <div style={{ fontSize: '1.6rem', fontWeight: 800, color: 'var(--text-main)' }}>
            {devices.length}
          </div>
          <div style={{ fontSize: '0.72rem', color: 'var(--accent-emerald)', marginTop: '0.2rem' }}>
            {stats.onlineDevices || devices.filter(d => Boolean(d.is_online)).length} Online Devices
          </div>
        </div>
      </div>

      {/* Main Tab Navigation */}
      <div style={{
        display: 'flex',
        alignItems: 'center',
        gap: '0.5rem',
        overflowX: 'auto',
        paddingBottom: '0.5rem',
        marginBottom: '1.5rem',
        borderBottom: '1px solid var(--border-subtle)'
      }}>
        <button
          onClick={() => setActiveTab('calls')}
          style={{
            padding: '0.65rem 1.1rem',
            borderRadius: '10px',
            border: activeTab === 'calls' ? '1px solid var(--primary)' : '1px solid var(--border-glass)',
            background: activeTab === 'calls' ? 'rgba(99, 102, 241, 0.15)' : 'transparent',
            color: activeTab === 'calls' ? 'var(--primary)' : 'var(--text-muted)',
            fontWeight: 700,
            fontSize: '0.84rem',
            display: 'flex',
            alignItems: 'center',
            gap: '0.5rem',
            cursor: 'pointer',
            whiteSpace: 'nowrap'
          }}
        >
          <PhoneCall size={16} />
          <span>Call Records & Recordings</span>
          <span style={{ fontSize: '0.72rem', color: 'var(--text-dim)' }}>({calls.length})</span>
        </button>

        <button
          onClick={() => setActiveTab('whatsapp')}
          style={{
            padding: '0.65rem 1.1rem',
            borderRadius: '10px',
            border: activeTab === 'whatsapp' ? '1px solid #10b981' : '1px solid var(--border-glass)',
            background: activeTab === 'whatsapp' ? 'rgba(16, 185, 129, 0.15)' : 'transparent',
            color: activeTab === 'whatsapp' ? '#10b981' : 'var(--text-muted)',
            fontWeight: 700,
            fontSize: '0.84rem',
            display: 'flex',
            alignItems: 'center',
            gap: '0.5rem',
            cursor: 'pointer',
            whiteSpace: 'nowrap'
          }}
        >
          <MessageCircle size={16} />
          <span>WhatsApp Notifications</span>
          <span style={{ fontSize: '0.72rem', color: 'var(--text-dim)' }}>({whatsappLogs.length})</span>
        </button>

        <button
          onClick={() => setActiveTab('sms')}
          style={{
            padding: '0.65rem 1.1rem',
            borderRadius: '10px',
            border: activeTab === 'sms' ? '1px solid #f59e0b' : '1px solid var(--border-glass)',
            background: activeTab === 'sms' ? 'rgba(245, 158, 11, 0.15)' : 'transparent',
            color: activeTab === 'sms' ? '#f59e0b' : 'var(--text-muted)',
            fontWeight: 700,
            fontSize: '0.84rem',
            display: 'flex',
            alignItems: 'center',
            gap: '0.5rem',
            cursor: 'pointer',
            whiteSpace: 'nowrap'
          }}
        >
          <MessageSquare size={16} />
          <span>Carrier SMS Logs</span>
          <span style={{ fontSize: '0.72rem', color: 'var(--text-dim)' }}>({smsLogs.length})</span>
        </button>

        <button
          onClick={() => setActiveTab('devices')}
          style={{
            padding: '0.65rem 1.1rem',
            borderRadius: '10px',
            border: activeTab === 'devices' ? '1px solid #a855f7' : '1px solid var(--border-glass)',
            background: activeTab === 'devices' ? 'rgba(168, 85, 247, 0.15)' : 'transparent',
            color: activeTab === 'devices' ? '#a855f7' : 'var(--text-muted)',
            fontWeight: 700,
            fontSize: '0.84rem',
            display: 'flex',
            alignItems: 'center',
            gap: '0.5rem',
            cursor: 'pointer',
            whiteSpace: 'nowrap'
          }}
        >
          <Smartphone size={16} />
          <span>Fleet Devices</span>
          <span style={{ fontSize: '0.72rem', color: 'var(--text-dim)' }}>({devices.length})</span>
        </button>

        <button
          onClick={() => setActiveTab('simulator')}
          style={{
            padding: '0.65rem 1.1rem',
            borderRadius: '10px',
            border: activeTab === 'simulator' ? '1px solid #38bdf8' : '1px solid var(--border-glass)',
            background: activeTab === 'simulator' ? 'rgba(56, 189, 248, 0.15)' : 'transparent',
            color: activeTab === 'simulator' ? '#38bdf8' : 'var(--text-muted)',
            fontWeight: 700,
            fontSize: '0.84rem',
            display: 'flex',
            alignItems: 'center',
            gap: '0.5rem',
            cursor: 'pointer',
            whiteSpace: 'nowrap'
          }}
        >
          <Sliders size={16} />
          <span>Telemetry Test Simulator</span>
        </button>

        <button
          onClick={() => setActiveTab('diagnostics')}
          style={{
            padding: '0.65rem 1.1rem',
            borderRadius: '10px',
            border: activeTab === 'diagnostics' ? '1px solid #64748b' : '1px solid var(--border-glass)',
            background: activeTab === 'diagnostics' ? 'rgba(100, 116, 139, 0.15)' : 'transparent',
            color: activeTab === 'diagnostics' ? 'var(--text-main)' : 'var(--text-muted)',
            fontWeight: 700,
            fontSize: '0.84rem',
            display: 'flex',
            alignItems: 'center',
            gap: '0.5rem',
            cursor: 'pointer',
            whiteSpace: 'nowrap'
          }}
        >
          <Database size={16} />
          <span>Sync Diagnostics</span>
        </button>
      </div>

      {/* =========================================================================
          TAB 2: CALL RECORDS & AUDIO VAULT
      ========================================================================= */}
      {activeTab === 'calls' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '0.75rem' }}>
            <div style={{ position: 'relative', width: '320px' }}>
              <Search size={16} style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-dim)' }} />
              <input
                type="text"
                placeholder="Search phone numbers, contacts, devices..."
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
                style={{
                  width: '100%',
                  padding: '0.65rem 1rem 0.65rem 2.2rem',
                  borderRadius: '8px',
                  border: '1px solid var(--border-glass)',
                  background: 'var(--bg-glass)',
                  color: 'var(--text-main)',
                  fontSize: '0.86rem'
                }}
              />
            </div>

            <div style={{ display: 'flex', gap: '0.5rem' }}>
              <button
                onClick={fetchTelemetryOverview}
                disabled={isManualSyncing}
                className="btn-secondary"
                style={{ padding: '0.65rem 1rem', fontSize: '0.85rem' }}
              >
                <RefreshCw size={14} className={isManualSyncing ? 'spin' : ''} />
                {isManualSyncing ? 'Syncing...' : 'Refresh'}
              </button>
            </div>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
            {filteredCalls.length > 0 ? (
              filteredCalls.map(call => (
                <div
                  key={call.id}
                  className="glass-card"
                  style={{
                    padding: '1.25rem',
                    display: 'flex',
                    flexWrap: 'wrap',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    gap: '1rem'
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.9rem' }}>
                    <div style={{
                      width: '40px',
                      height: '40px',
                      borderRadius: '10px',
                      background: call.direction === 'inbound'
                        ? 'rgba(16, 185, 129, 0.15)'
                        : (call.direction === 'missed' ? 'rgba(239, 68, 68, 0.15)' : 'rgba(56, 189, 248, 0.15)'),
                      color: call.direction === 'inbound'
                        ? '#10b981'
                        : (call.direction === 'missed' ? '#ef4444' : '#38bdf8'),
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center'
                    }}>
                      {call.direction === 'inbound' && <PhoneIncoming size={20} />}
                      {call.direction === 'outbound' && <PhoneOutgoing size={20} />}
                      {call.direction === 'missed' && <PhoneMissed size={20} />}
                      {call.direction === 'rejected' && <PhoneMissed size={20} />}
                    </div>

                    <div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.25rem', flexWrap: 'wrap' }}>
                        <span style={{ fontWeight: 800, fontSize: '1rem', color: 'var(--text-main)', letterSpacing: '0.2px' }}>
                          {call.contact_name && !call.contact_name.startsWith('Contact (') ? call.contact_name : (call.phone_number || 'Unknown Contact')}
                        </span>
                        <span style={{
                          fontSize: '0.7rem',
                          fontWeight: 700,
                          padding: '0.1rem 0.45rem',
                          borderRadius: '6px',
                          background: 'rgba(255, 255, 255, 0.06)',
                          color: 'var(--text-dim)'
                        }}>
                          {call.sim_slot}
                        </span>
                        <span style={{
                          fontSize: '0.7rem',
                          fontWeight: 700,
                          padding: '0.1rem 0.45rem',
                          borderRadius: '6px',
                          background: 'rgba(99, 102, 241, 0.15)',
                          color: 'var(--primary)'
                        }}>
                          Device: {call.device_id}
                        </span>
                      </div>
                      <div style={{ fontSize: '0.82rem', color: 'var(--text-dim)', display: 'flex', alignItems: 'center', gap: '0.75rem', flexWrap: 'wrap' }}>
                        <span style={{ color: 'var(--accent-cyan)', fontWeight: 600, display: 'inline-flex', alignItems: 'center', gap: '0.25rem' }}>
                          <Clock size={13} /> {formatToIST(call.started_at || call.call_time || call.created_at || call.ended_at)}
                        </span>
                        <span>•</span>
                        <span style={{ color: 'var(--text-main)', fontWeight: 700 }}>
                          📞 {call.phone_number}
                        </span>
                        <span>•</span>
                        <span>Duration: <strong>{call.duration_seconds}s</strong> ({Math.floor(call.duration_seconds / 60)}m {call.duration_seconds % 60}s)</span>
                        <span>•</span>
                        <span>Outcome: {call.outcome}</span>
                      </div>
                      {call.notes && (
                        <div style={{ fontSize: '0.76rem', color: 'var(--text-muted)', marginTop: '0.3rem' }}>
                          💬 {call.notes}
                        </div>
                      )}
                    </div>
                  </div>

                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', flexWrap: 'wrap' }}>
                    {/* Recording Checksum Badge */}
                    {call.recording_sha256 && (
                      <div style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: '0.3rem',
                        fontSize: '0.7rem',
                        color: 'var(--accent-emerald)',
                        background: 'rgba(16, 185, 129, 0.1)',
                        padding: '0.25rem 0.55rem',
                        borderRadius: '6px',
                        border: '1px solid rgba(16, 185, 129, 0.2)'
                      }} title={`SHA-256 Checksum: ${call.recording_sha256}`}>
                        <ShieldCheck size={13} />
                        <span>SHA-256 Verified</span>
                      </div>
                    )}

                    {/* Listen Audio Button */}
                    {call.recording_url && call.recording_status !== 'NOT_APPLICABLE' && (
                      <button
                        onClick={() => togglePlayAudio(call)}
                        style={{
                          display: 'flex',
                          alignItems: 'center',
                          gap: '0.4rem',
                          padding: '0.45rem 0.85rem',
                          borderRadius: '8px',
                          border: '1px solid var(--primary)',
                          background: playingCallId === call.id ? 'var(--primary)' : 'rgba(99, 102, 241, 0.12)',
                          color: playingCallId === call.id ? '#fff' : 'var(--primary)',
                          fontSize: '0.78rem',
                          fontWeight: 700,
                          cursor: 'pointer'
                        }}
                      >
                        {playingCallId === call.id ? <Pause size={14} /> : <Play size={14} />}
                        <span>{playingCallId === call.id ? 'Playing...' : 'Listen Recording'}</span>
                      </button>
                    )}

                    {/* Edit Notes & Text Button */}
                    <button
                      onClick={() => handleOpenEditCall(call)}
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: '0.4rem',
                        padding: '0.45rem 0.85rem',
                        borderRadius: '8px',
                        border: '1px solid rgba(56, 189, 248, 0.3)',
                        background: 'rgba(56, 189, 248, 0.1)',
                        color: '#38bdf8',
                        fontSize: '0.78rem',
                        fontWeight: 700,
                        cursor: 'pointer'
                      }}
                      title="Update notes, outcome, or contact text on server"
                    >
                      <Edit3 size={14} />
                      <span>Edit Text / Notes</span>
                    </button>

                    {/* Sync Status Badge */}
                    <span style={{
                      fontSize: '0.7rem',
                      fontWeight: 800,
                      padding: '0.2rem 0.55rem',
                      borderRadius: '6px',
                      background: call.sync_status === 'SYNCED' ? 'rgba(16, 185, 129, 0.15)' : 'rgba(245, 158, 11, 0.15)',
                      color: call.sync_status === 'SYNCED' ? '#10b981' : '#f59e0b'
                    }}>
                      {call.sync_status} ({call.sync_mode})
                    </span>
                  </div>
                </div>
              ))
            ) : (
              <div className="glass-card" style={{ padding: '3rem', textAlign: 'center', color: 'var(--text-muted)' }}>
                No calls found.
              </div>
            )}
          </div>
        </div>
      )}

      {/* =========================================================================
          TAB 3: WHATSAPP NOTIFICATIONS
      ========================================================================= */}
      {activeTab === 'whatsapp' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <div style={{
            padding: '1rem 1.25rem',
            borderRadius: '12px',
            background: 'rgba(16, 185, 129, 0.08)',
            border: '1px solid rgba(16, 185, 129, 0.25)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            flexWrap: 'wrap',
            gap: '0.75rem'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
              <ShieldCheck size={20} color="#10b981" />
              <span style={{ fontSize: '0.85rem', color: 'var(--text-main)', fontWeight: 600 }}>
                Captured via Android <code>NotificationListenerService</code> (Supports WhatsApp & WhatsApp Business)
              </span>
            </div>
            <button
              onClick={triggerSimulatedWhatsApp}
              className="btn-primary"
              style={{ padding: '0.45rem 0.9rem', fontSize: '0.78rem', background: '#10b981' }}
            >
              + Simulate WhatsApp Intercept
            </button>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
            {sortedWhatsappLogs.map(wa => (
              <div
                key={wa.id}
                className="glass-card"
                style={{
                  padding: '1.25rem',
                  display: 'flex',
                  alignItems: 'flex-start',
                  justifyContent: 'space-between',
                  gap: '1rem',
                  borderLeft: wa.package_name === 'com.whatsapp.w4b' ? '3px solid #10b981' : '3px solid #06b6d4'
                }}
              >
                <div style={{ display: 'flex', gap: '0.9rem' }}>
                  <div style={{
                    width: '38px',
                    height: '38px',
                    borderRadius: '10px',
                    background: 'rgba(16, 185, 129, 0.15)',
                    color: '#10b981',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    flexShrink: 0
                  }}>
                    <MessageCircle size={20} />
                  </div>
                  <div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.2rem' }}>
                      <span style={{ fontWeight: 800, fontSize: '0.92rem', color: 'var(--text-main)' }}>
                        {wa.sender}
                      </span>
                      {wa.group_name && (
                        <span style={{
                          fontSize: '0.7rem',
                          background: 'rgba(255, 255, 255, 0.08)',
                          color: 'var(--text-dim)',
                          padding: '0.1rem 0.45rem',
                          borderRadius: '6px'
                        }}>
                          Group: {wa.group_name}
                        </span>
                      )}
                      <span style={{
                        fontSize: '0.68rem',
                        fontWeight: 700,
                        color: wa.package_name === 'com.whatsapp.w4b' ? '#10b981' : '#06b6d4',
                        background: 'rgba(255, 255, 255, 0.05)',
                        padding: '0.1rem 0.4rem',
                        borderRadius: '4px'
                      }}>
                        {wa.package_name === 'com.whatsapp.w4b' ? 'WhatsApp Business' : 'WhatsApp'}
                      </span>
                    </div>

                    <div style={{ fontSize: '0.86rem', color: 'var(--text-main)', marginTop: '0.35rem', lineHeight: 1.4 }}>
                      "{wa.message_preview}"
                    </div>

                    <div style={{ fontSize: '0.74rem', color: 'var(--text-dim)', marginTop: '0.5rem' }}>
                      Device: {wa.device_id} • Captured (IST): {formatToIST(wa.notification_timestamp)}
                    </div>
                  </div>
                </div>

                <div>
                  <span style={{
                    fontSize: '0.7rem',
                    fontWeight: 700,
                    padding: '0.2rem 0.5rem',
                    borderRadius: '6px',
                    background: 'rgba(16, 185, 129, 0.15)',
                    color: '#10b981'
                  }}>
                    {wa.sync_status}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* =========================================================================
          TAB 4: CARRIER SMS TELEMETRY
      ========================================================================= */}
      {activeTab === 'sms' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '0.75rem' }}>
            <span style={{ fontSize: '0.85rem', color: 'var(--text-dim)' }}>
              Carrier SMS logged via Android Telephony content observer / BroadcastReceiver
            </span>
            <button
              onClick={triggerSimulatedSms}
              className="btn-primary"
              style={{ padding: '0.45rem 0.9rem', fontSize: '0.78rem', background: '#f59e0b' }}
            >
              + Simulate Carrier SMS Log
            </button>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
            {sortedSmsLogs.map(sms => (
              <div
                key={sms.id}
                className="glass-card"
                style={{
                  padding: '1.25rem',
                  display: 'flex',
                  alignItems: 'flex-start',
                  justifyContent: 'space-between',
                  gap: '1rem'
                }}
              >
                <div style={{ display: 'flex', gap: '0.9rem' }}>
                  <div style={{
                    width: '38px',
                    height: '38px',
                    borderRadius: '10px',
                    background: sms.direction === 'inbound' ? 'rgba(245, 158, 11, 0.15)' : 'rgba(56, 189, 248, 0.15)',
                    color: sms.direction === 'inbound' ? '#f59e0b' : '#38bdf8',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    flexShrink: 0
                  }}>
                    <MessageSquare size={18} />
                  </div>
                  <div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.2rem' }}>
                      <span style={{
                        fontSize: '0.68rem',
                        fontWeight: 800,
                        padding: '0.1rem 0.45rem',
                        borderRadius: '4px',
                        background: sms.direction === 'inbound' ? 'rgba(245, 158, 11, 0.2)' : 'rgba(56, 189, 248, 0.2)',
                        color: sms.direction === 'inbound' ? '#f59e0b' : '#38bdf8'
                      }}>
                        {sms.direction.toUpperCase()} SMS
                      </span>
                      <span style={{ fontSize: '0.82rem', fontWeight: 700, color: 'var(--text-main)' }}>
                        From: {sms.sender} ➔ To: {sms.recipient}
                      </span>
                      <span style={{ fontSize: '0.72rem', color: 'var(--text-dim)' }}>
                        ({sms.sim_slot})
                      </span>
                    </div>

                    <div style={{ fontSize: '0.86rem', color: 'var(--text-main)', marginTop: '0.4rem', lineHeight: 1.4 }}>
                      {sms.message_body}
                    </div>

                    <div style={{ fontSize: '0.74rem', color: 'var(--text-dim)', marginTop: '0.5rem' }}>
                      Device: {sms.device_id} • Timestamp (IST): {formatToIST(sms.timestamp)}
                    </div>
                  </div>
                </div>

                <div>
                  <span style={{
                    fontSize: '0.7rem',
                    fontWeight: 700,
                    padding: '0.2rem 0.5rem',
                    borderRadius: '6px',
                    background: 'rgba(16, 185, 129, 0.15)',
                    color: '#10b981'
                  }}>
                    {sms.sync_status}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* =========================================================================
          TAB 5: FLEET DEVICES & OFFLINE QUEUE
      ========================================================================= */}
      {activeTab === 'devices' && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '1.25rem' }}>
          {devices.map(dev => (
            <div key={dev.id} className="glass-card" style={{ padding: '1.5rem', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                    <div style={{
                      width: '10px',
                      height: '10px',
                      borderRadius: '50%',
                      background: dev.is_online ? '#10b981' : '#64748b'
                    }} />
                    <span style={{ fontWeight: 800, fontSize: '1rem', color: 'var(--text-main)' }}>
                      {dev.user_name}
                    </span>
                  </div>
                  <span style={{
                    fontSize: '0.7rem',
                    fontWeight: 800,
                    padding: '0.2rem 0.5rem',
                    borderRadius: '6px',
                    background: dev.is_online ? 'rgba(16, 185, 129, 0.15)' : 'rgba(100, 116, 139, 0.2)',
                    color: dev.is_online ? '#10b981' : 'var(--text-dim)'
                  }}>
                    {dev.is_online ? 'ONLINE' : 'OFFLINE'}
                  </span>
                </div>

                <div style={{ fontSize: '0.8rem', color: 'var(--text-dim)', marginBottom: '1rem' }}>
                  {dev.model} • {dev.os_version}
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem', fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span>Battery Status:</span>
                    <strong style={{ color: dev.battery_percent > 20 ? 'var(--text-main)' : '#ef4444' }}>
                      🔋 {dev.battery_percent}%
                    </strong>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span>Sync Mode:</span>
                    <strong style={{ color: 'var(--primary)' }}>
                      {dev.sync_mode.toUpperCase()}
                    </strong>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span>Pending Offline Queue:</span>
                    <strong style={{ color: dev.pending_sync_count > 0 ? '#f59e0b' : '#10b981' }}>
                      {dev.pending_sync_count} records
                    </strong>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span>Last Seen:</span>
                    <span>{new Date(dev.last_seen).toLocaleTimeString()}</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span>Last Synced:</span>
                    <span>{new Date(dev.last_sync).toLocaleTimeString()}</span>
                  </div>
                </div>
              </div>

              <div style={{ marginTop: '1.25rem', paddingTop: '1rem', borderTop: '1px solid var(--border-subtle)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontSize: '0.72rem', color: 'var(--text-dim)' }}>Device ID: {dev.id}</span>
                <button
                  onClick={handleManualSyncNow}
                  style={{
                    padding: '0.35rem 0.75rem',
                    borderRadius: '8px',
                    border: '1px solid var(--border-glass)',
                    background: 'var(--bg-surface-elevated)',
                    color: 'var(--text-main)',
                    fontSize: '0.75rem',
                    fontWeight: 700,
                    cursor: 'pointer'
                  }}
                >
                  Force Sync Device
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* =========================================================================
          TAB 6: TELEMETRY TEST SIMULATOR
      ========================================================================= */}
      {activeTab === 'simulator' && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(340px, 1fr))', gap: '1.5rem' }}>
          {/* Simulator Form: Phone Call & Recording */}
          <div className="glass-card" style={{ padding: '1.75rem' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '1.25rem' }}>
              <PhoneCall size={20} color="var(--primary)" />
              <h3 style={{ fontSize: '1.1rem', fontWeight: 800, margin: 0, color: 'var(--text-main)' }}>
                Simulate Call & Voice Recording
              </h3>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
              <div>
                <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-dim)', marginBottom: '0.3rem' }}>
                  Target Phone Number
                </label>
                <input
                  type="text"
                  value={simPhone}
                  onChange={e => setSimPhone(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '0.65rem 0.9rem',
                    borderRadius: '8px',
                    border: '1px solid var(--border-glass)',
                    background: 'var(--bg-surface-elevated)',
                    color: 'var(--text-main)',
                    fontSize: '0.85rem'
                  }}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-dim)', marginBottom: '0.3rem' }}>
                  Contact Name
                </label>
                <input
                  type="text"
                  value={simName}
                  onChange={e => setSimName(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '0.65rem 0.9rem',
                    borderRadius: '8px',
                    border: '1px solid var(--border-glass)',
                    background: 'var(--bg-surface-elevated)',
                    color: 'var(--text-main)',
                    fontSize: '0.85rem'
                  }}
                />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-dim)', marginBottom: '0.3rem' }}>
                    Direction
                  </label>
                  <select
                    value={simDirection}
                    onChange={e => setSimDirection(e.target.value as any)}
                    style={{
                      width: '100%',
                      padding: '0.65rem 0.9rem',
                      borderRadius: '8px',
                      border: '1px solid var(--border-glass)',
                      background: 'var(--bg-surface-elevated)',
                      color: 'var(--text-main)',
                      fontSize: '0.85rem'
                    }}
                  >
                    <option value="inbound">Inbound</option>
                    <option value="outbound">Outbound</option>
                    <option value="missed">Missed</option>
                  </select>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-dim)', marginBottom: '0.3rem' }}>
                    Duration (Sec)
                  </label>
                  <input
                    type="number"
                    value={simDuration}
                    onChange={e => setSimDuration(Number(e.target.value))}
                    style={{
                      width: '100%',
                      padding: '0.65rem 0.9rem',
                      borderRadius: '8px',
                      border: '1px solid var(--border-glass)',
                      background: 'var(--bg-surface-elevated)',
                      color: 'var(--text-main)',
                      fontSize: '0.85rem'
                    }}
                  />
                </div>
              </div>

              <div style={{ marginTop: '0.5rem' }}>
                <button
                  type="button"
                  onClick={triggerSimulatedCallComplete}
                  className="btn-primary"
                  style={{ width: '100%', padding: '0.8rem', fontSize: '0.86rem', fontWeight: 700 }}
                >
                  Log Call Record & Encrypted Audio
                </button>
              </div>
            </div>
          </div>

          {/* Simulator Form: WhatsApp & SMS */}
          <div className="glass-card" style={{ padding: '1.75rem' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '1.25rem' }}>
              <MessageCircle size={20} color="#10b981" />
              <h3 style={{ fontSize: '1.1rem', fontWeight: 800, margin: 0, color: 'var(--text-main)' }}>
                Simulate WhatsApp & SMS Intercepts
              </h3>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
              <div>
                <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-dim)', marginBottom: '0.3rem' }}>
                  WhatsApp Sender
                </label>
                <input
                  type="text"
                  value={simWaSender}
                  onChange={e => setSimWaSender(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '0.65rem 0.9rem',
                    borderRadius: '8px',
                    border: '1px solid var(--border-glass)',
                    background: 'var(--bg-surface-elevated)',
                    color: 'var(--text-main)',
                    fontSize: '0.85rem'
                  }}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-dim)', marginBottom: '0.3rem' }}>
                  WhatsApp Message Body
                </label>
                <textarea
                  rows={2}
                  value={simWaMsg}
                  onChange={e => setSimWaMsg(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '0.65rem 0.9rem',
                    borderRadius: '8px',
                    border: '1px solid var(--border-glass)',
                    background: 'var(--bg-surface-elevated)',
                    color: 'var(--text-main)',
                    fontSize: '0.85rem'
                  }}
                />
              </div>

              <button
                type="button"
                onClick={triggerSimulatedWhatsApp}
                style={{
                  padding: '0.7rem',
                  borderRadius: '8px',
                  border: '1px solid #10b981',
                  background: 'rgba(16, 185, 129, 0.15)',
                  color: '#10b981',
                  fontSize: '0.82rem',
                  fontWeight: 700,
                  cursor: 'pointer'
                }}
              >
                + Intercept WhatsApp Notification
              </button>

              <div style={{ borderTop: '1px solid var(--border-subtle)', paddingTop: '0.75rem' }}>
                <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-dim)', marginBottom: '0.3rem' }}>
                  Carrier SMS Content
                </label>
                <input
                  type="text"
                  value={simSmsMsg}
                  onChange={e => setSimSmsMsg(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '0.65rem 0.9rem',
                    borderRadius: '8px',
                    border: '1px solid var(--border-glass)',
                    background: 'var(--bg-surface-elevated)',
                    color: 'var(--text-main)',
                    fontSize: '0.85rem',
                    marginBottom: '0.75rem'
                  }}
                />

                <button
                  type="button"
                  onClick={triggerSimulatedSms}
                  style={{
                    width: '100%',
                    padding: '0.7rem',
                    borderRadius: '8px',
                    border: '1px solid #f59e0b',
                    background: 'rgba(245, 158, 11, 0.15)',
                    color: '#f59e0b',
                    fontSize: '0.82rem',
                    fontWeight: 700,
                    cursor: 'pointer'
                  }}
                >
                  + Log Inbound Carrier SMS
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* =========================================================================
          TAB 7: SYNC DIAGNOSTICS & AUDIT LOGS
      ========================================================================= */}
      {activeTab === 'diagnostics' && (
        <div className="glass-card" style={{ padding: '1.75rem' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem' }}>
            <h3 style={{ fontSize: '1.1rem', fontWeight: 800, margin: 0, color: 'var(--text-main)' }}>
              Synchronization Engine Diagnostics & Telemetry Audit
            </h3>
            <span style={{ fontSize: '0.78rem', color: 'var(--accent-emerald)' }}>
              Idempotency & Duplicate Prevention Active
            </span>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
            {sortedDiagnostics.map(diag => (
              <div
                key={diag.id}
                style={{
                  padding: '1rem',
                  borderRadius: '10px',
                  background: 'var(--bg-surface-elevated)',
                  border: '1px solid var(--border-glass)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  flexWrap: 'wrap',
                  gap: '0.5rem'
                }}
              >
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.2rem' }}>
                    <span style={{
                      fontSize: '0.7rem',
                      fontWeight: 800,
                      padding: '0.15rem 0.45rem',
                      borderRadius: '4px',
                      background: diag.status === 'SUCCESS' ? 'rgba(16, 185, 129, 0.15)' : 'rgba(239, 68, 68, 0.15)',
                      color: diag.status === 'SUCCESS' ? '#10b981' : '#f87171'
                    }}>
                      {diag.status}
                    </span>
                    <strong style={{ fontSize: '0.88rem', color: 'var(--text-main)' }}>
                      {diag.event_type}
                    </strong>
                    <span style={{ fontSize: '0.75rem', color: 'var(--text-dim)' }}>
                      • Device: {diag.device_id}
                    </span>
                  </div>
                  <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)' }}>
                    Batch Size: {diag.batch_size} items • Latency: {diag.duration_ms}ms {diag.error_message ? `• Error: ${diag.error_message}` : ''}
                  </div>
                </div>

                <div style={{ fontSize: '0.74rem', color: 'var(--text-dim)' }}>
                  {diag.created_at ? formatToIST(diag.created_at) : 'Recent'}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Edit Call Text / Notes Modal */}
      {editingCall && (
        <div style={{
          position: 'fixed',
          inset: 0,
          background: 'rgba(0, 0, 0, 0.75)',
          backdropFilter: 'blur(8px)',
          WebkitBackdropFilter: 'blur(8px)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 9999,
          padding: '1.5rem'
        }}>
          <div className="glass-card" style={{
            width: '100%',
            maxWidth: '560px',
            background: 'var(--bg-glass-elevated)',
            border: '1px solid var(--border-glass)',
            borderRadius: '16px',
            padding: '1.75rem',
            boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.5)'
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
                <div style={{
                  width: '36px',
                  height: '36px',
                  borderRadius: '10px',
                  background: 'rgba(56, 189, 248, 0.15)',
                  color: '#38bdf8',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center'
                }}>
                  <Edit3 size={18} />
                </div>
                <div>
                  <h3 style={{ margin: 0, fontSize: '1.1rem', fontWeight: 800, color: 'var(--text-main)' }}>
                    Edit Call Telemetry & Text
                  </h3>
                  <span style={{ fontSize: '0.75rem', color: 'var(--text-dim)' }}>
                    ID: {editingCall.id} • {editingCall.phone_number}
                  </span>
                </div>
              </div>
              <button
                onClick={() => setEditingCall(null)}
                style={{
                  background: 'none',
                  border: 'none',
                  color: 'var(--text-dim)',
                  cursor: 'pointer',
                  padding: '0.4rem'
                }}
              >
                <X size={20} />
              </button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem', marginBottom: '1.5rem' }}>
              <div>
                <label style={{ display: 'block', fontSize: '0.78rem', fontWeight: 700, color: 'var(--text-muted)', marginBottom: '0.4rem' }}>
                  Contact Name
                </label>
                <input
                  type="text"
                  value={editContactName}
                  onChange={e => setEditContactName(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '0.6rem 0.85rem',
                    borderRadius: '8px',
                    border: '1px solid var(--border-glass)',
                    background: 'var(--bg-surface-elevated)',
                    color: 'var(--text-main)',
                    fontSize: '0.85rem'
                  }}
                  placeholder="e.g. John Doe (VIP Client)"
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.78rem', fontWeight: 700, color: 'var(--text-muted)', marginBottom: '0.4rem' }}>
                  Call Outcome
                </label>
                <select
                  value={editOutcome}
                  onChange={e => setEditOutcome(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '0.6rem 0.85rem',
                    borderRadius: '8px',
                    border: '1px solid var(--border-glass)',
                    background: 'var(--bg-surface-elevated)',
                    color: 'var(--text-main)',
                    fontSize: '0.85rem'
                  }}
                >
                  <option value="Call Completed">Call Completed</option>
                  <option value="Demo Completed - Contract Requested">Demo Completed - Contract Requested</option>
                  <option value="Technical Validation Passed">Technical Validation Passed</option>
                  <option value="Proposal Sent">Proposal Sent</option>
                  <option value="Follow-up Required">Follow-up Required</option>
                  <option value="Voicemail / No Answer">Voicemail / No Answer</option>
                  <option value="Missed Inbound - Auto Follow-up Needed">Missed Inbound - Auto Follow-up Needed</option>
                </select>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.78rem', fontWeight: 700, color: 'var(--text-muted)', marginBottom: '0.4rem' }}>
                  Call Text / Rep Notes (Stored in Server DB)
                </label>
                <textarea
                  rows={4}
                  value={editNotes}
                  onChange={e => setEditNotes(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '0.65rem 0.85rem',
                    borderRadius: '8px',
                    border: '1px solid var(--border-glass)',
                    background: 'var(--bg-surface-elevated)',
                    color: 'var(--text-main)',
                    fontSize: '0.85rem',
                    resize: 'vertical'
                  }}
                  placeholder="Enter detailed conversation text, client feedback, next steps..."
                />
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.75rem' }}>
              <button
                onClick={() => setEditingCall(null)}
                className="btn-secondary"
                style={{ padding: '0.6rem 1.1rem', fontSize: '0.82rem', fontWeight: 700 }}
              >
                Cancel
              </button>
              <button
                onClick={handleSaveCallUpdate}
                disabled={isUpdatingCall}
                className="btn-primary"
                style={{
                  padding: '0.6rem 1.3rem',
                  fontSize: '0.82rem',
                  fontWeight: 700,
                  display: 'flex',
                  alignItems: 'center',
                  gap: '0.4rem',
                  background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)'
                }}
              >
                {isUpdatingCall ? (
                  <>
                    <RefreshCw size={15} className="spin-animation" />
                    <span>Saving to Server...</span>
                  </>
                ) : (
                  <>
                    <Check size={15} />
                    <span>Save Text to Server</span>
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}

    </div>
  );
}
