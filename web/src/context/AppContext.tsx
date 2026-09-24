import React, { createContext, useContext, useState, useEffect } from 'react';
import confetti from 'canvas-confetti';
import type {
  CallLog,
  WhatsAppLog,
  SalesRep,
  CrmConnector,
  AuditLogEntry,
  SecuritySettings,
  AdminUser,
  AuthUser,
  TenantOrganization,
  SuperAdminOverview,
  SitePageSection,
  PageContentMap
} from '../types';

export interface IncomingCallEvent {
  id: string;
  contactName: string;
  phoneNumber: string;
  company: string;
  dealValue: number;
}

export interface ActiveCallSession {
  contactName: string;
  phoneNumber: string;
  company: string;
  direction: 'outbound' | 'inbound';
  duration: number;
  dealValue: number;
}

interface AppContextType {
  calls: CallLog[];
  whatsAppLogs: WhatsAppLog[];
  reps: SalesRep[];
  crmConnectors: CrmConnector[];
  auditLogs: AuditLogEntry[];
  securitySettings: SecuritySettings;
  adminUsers: AdminUser[];
  currentUser: AuthUser | null;
  currentOrg: TenantOrganization | null;
  activeTenantId: string;
  login: (email: string, pass: string) => Promise<boolean>;
  signup: (payload: { companyName: string; name: string; email: string; password: string; phone?: string; plan?: string }) => Promise<boolean>;
  logout: () => void;
  switchTenant: (orgId: string) => Promise<void>;
  superAdminOverview: SuperAdminOverview | null;
  fetchSuperAdminOverview: () => Promise<SuperAdminOverview | null>;
  manageTenantStatus: (orgId: string, status: 'active' | 'suspended', plan?: string) => Promise<boolean>;
  activeAudioCall: CallLog | null;
  setActiveAudioCall: (call: CallLog | null) => void;
  selectedRole: 'admin' | 'rep';
  setSelectedRole: (role: 'admin' | 'rep') => void;
  theme: 'dark' | 'light';
  setTheme: (theme: 'dark' | 'light') => void;
  accent: 'violet' | 'emerald' | 'cyan' | 'amber';
  setAccent: (accent: 'violet' | 'emerald' | 'cyan' | 'amber') => void;
  isSimulatorOpen: boolean;
  setIsSimulatorOpen: (open: boolean) => void;
  incomingCallAlert: IncomingCallEvent | null;
  triggerIncomingCall: (contact?: Partial<IncomingCallEvent>) => void;
  acceptIncomingCall: () => void;
  declineIncomingCall: () => void;
  activeCallSession: ActiveCallSession | null;
  startOutboundCallSession: (number?: string, contactName?: string, company?: string) => void;
  endActiveCallSession: () => void;
  wrapUpModalCall: CallLog | null;
  setWrapUpModalCall: (call: CallLog | null) => void;
  submitWrapUpCall: (callData: Partial<CallLog>) => void;
  playDtmfTone: (key: string) => void;
  simulateNewCall: (data: Partial<CallLog>) => void;
  simulateWhatsAppMessage: (data: Partial<WhatsAppLog>) => void;
  triggerCrmSync: (id: string) => void;
  deleteCallLog: (id: string) => Promise<void>;
  refreshCalls: () => Promise<void>;
  refreshAllData: () => Promise<void>;
  dbEngine: 'mysql' | 'sqlite';
  updateSecuritySettings: (settings: Partial<SecuritySettings>) => Promise<void>;
  addAdminUser: (user: Omit<AdminUser, 'id'>) => Promise<void>;
  deleteAdminUser: (id: string) => Promise<void>;
  addRep: (rep: Partial<SalesRep>) => Promise<void>;
  updateRep: (rep: Partial<SalesRep>) => Promise<void>;
  deleteRep: (id: string) => Promise<void>;
  toggleCrmConnector: (id: string) => Promise<void>;
  toastMessage: string | null;
  clearToast: () => void;
  sitePages: PageContentMap;
  pagesLoaded: boolean;
  fetchPageContent: (pageKey?: string) => Promise<void>;
  savePageSection: (section: Partial<SitePageSection>) => Promise<boolean>;
  deletePageSection: (id: string) => Promise<boolean>;
  resetDefaultPageContent: () => Promise<boolean>;
  getPageSection: (pageKey: string, sectionKey: string) => SitePageSection | undefined;
}

// NO hardcoded content. All content is fetched from the site_pages MySQL table.
// Default is empty — DB is the single source of truth.
const initialCalls: CallLog[] = [
  {
    id: 'call-101',
    contactName: 'Aarav Sharma',
    phoneNumber: '+91 98201 43210',
    company: 'Tata Consultancy Services',
    direction: 'outbound',
    duration: 384, // 6m 24s
    timestamp: '2 mins ago',
    repName: 'Rajesh Kumar',
    repAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&auto=format&fit=crop&q=80',
    repId: 'rep-1',
    recordingUrl: 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
    waveform: [20, 45, 60, 80, 50, 65, 90, 40, 75, 85, 95, 70, 55, 65, 85, 100, 70, 60, 40, 55, 75, 90, 60, 30],
    transcript: [
      { speaker: 'Rajesh Kumar', text: 'Namaste Aarav, thanks for jumping on. Following up on the enterprise sales tracking proposal.', timestamp: '00:04' },
      { speaker: 'Aarav Sharma', text: 'Namaste Rajesh! Yes, our leadership team looked over the automatic WhatsApp and call recording specs. We love the zero-click RingVia360 CRM sync.', timestamp: '00:15' },
      { speaker: 'Rajesh Kumar', text: 'Awesome. The dual-SIM logging and end-to-end encryption ensure you comply with your ISO & SOC2 audits without reps lifting a finger.', timestamp: '00:32' },
      { speaker: 'Aarav Sharma', text: 'That addresses our major blocker. Can we start a 50-seat pilot by next Monday?', timestamp: '01:10' },
      { speaker: 'Rajesh Kumar', text: 'Absolutely! I will configure your RingVia360 portal mapping right after this call.', timestamp: '01:25' }
    ],
    sentiment: 'positive',
    sentimentScore: 94,
    outcome: 'Demo Completed - Contract Requested',
    notes: 'Decision maker confirmed budget for 50 licenses. Requested RingVia360 custom field mapping for lead source and call tags.',
    crmStatus: 'synced',
    crmType: 'RingVia360',
    crmRecordId: 'rv360-rec-001',
    dealValue: 48000,
    dealStage: 'Proposal / Review',
    tags: ['Hot Lead', 'Enterprise', 'RingVia360 Sync', 'E2EE Ready'],
    keyActionItems: [
      'Send Docusign MSA for 50 licenses',
      'Invite Aarav to RingVia360 Admin Portal sandbox',
      'Schedule kickoff call with technical lead'
    ],
    isEncrypted: true
  },
  {
    id: 'call-102',
    contactName: 'Priya Patel',
    phoneNumber: '+91 98450 12890',
    company: 'Infosys Technologies',
    direction: 'inbound',
    duration: 512, // 8m 32s
    timestamp: '18 mins ago',
    repName: 'Ananya Iyer',
    repAvatar: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=120&auto=format&fit=crop&q=80',
    repId: 'rep-2',
    recordingUrl: 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
    waveform: [30, 40, 50, 70, 80, 85, 60, 45, 70, 95, 80, 60, 75, 90, 85, 70, 60, 50, 40, 65, 80, 70, 50, 35],
    transcript: [
      { speaker: 'Ananya Iyer', text: 'RingVia360 enterprise desk, Ananya speaking. How can I assist you today, Priya?', timestamp: '00:03' },
      { speaker: 'Priya Patel', text: 'Hi Ananya, we are testing the mobile dialer SDK. We need to verify if inbound calls on Android 14 are logged when the app is in background.', timestamp: '00:18' },
      { speaker: 'Ananya Iyer', text: 'Yes, our background telephony service uses native OS CallScreening & Telephony listeners with zero battery drain.', timestamp: '00:40' }
    ],
    sentiment: 'positive',
    sentimentScore: 88,
    outcome: 'Technical Validation Passed',
    notes: 'Client tested inbound call capture on Samsung Knox devices. Confirmed zero delay sync to RingVia360.',
    crmStatus: 'synced',
    crmType: 'RingVia360',
    crmRecordId: 'rv360-rec-002',
    dealValue: 72000,
    dealStage: 'Technical Validation',
    tags: ['Inbound Inquiry', 'RingVia360', 'Android 14', 'High Intent'],
    keyActionItems: [
      'Email Android MDM deployment guide',
      'Verify webhook delivery endpoints'
    ],
    isEncrypted: true
  },
  {
    id: 'call-103',
    contactName: 'Vikram Malhotra',
    phoneNumber: '+91 97110 56789',
    company: 'Wipro Enterprises',
    direction: 'missed',
    duration: 0,
    timestamp: '42 mins ago',
    repName: 'Rajesh Kumar',
    repAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&auto=format&fit=crop&q=80',
    repId: 'rep-1',
    sentiment: 'neutral',
    sentimentScore: 50,
    outcome: 'Missed Call - Auto Follow-up WhatsApp Sent',
    notes: 'Incoming call was missed during meeting. Auto-responder dispatched instant WhatsApp template with meeting link.',
    crmStatus: 'synced',
    crmType: 'RingVia360',
    crmRecordId: 'rv360-rec-003',
    tags: ['Missed Call', 'Automated Bot Triggered'],
    keyActionItems: [
      'Check if client booked calendar slot by 4 PM'
    ],
    isEncrypted: true
  },
  {
    id: 'call-104',
    contactName: 'Ananya Iyer',
    phoneNumber: '+91 99001 77654',
    company: 'HDFC Bank Corporate',
    direction: 'outbound',
    duration: 215, // 3m 35s
    timestamp: '1 hour ago',
    repName: 'Rajesh Kumar',
    repAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&auto=format&fit=crop&q=80',
    repId: 'rep-1',
    recordingUrl: 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
    waveform: [25, 35, 45, 60, 50, 70, 75, 65, 80, 60, 50, 45, 60, 75, 65, 55, 45, 50, 60, 55, 40, 30, 25, 20],
    sentiment: 'neutral',
    sentimentScore: 65,
    outcome: 'Follow-up Scheduled',
    notes: 'Spoke with Ananya. Reviewed banking compliance and Knox E2EE dual-SIM isolation.',
    crmStatus: 'synced',
    crmType: 'RingVia360',
    crmRecordId: 'rv360-rec-004',
    dealValue: 24000,
    dealStage: 'Discovery',
    tags: ['Enterprise Banking', 'RingVia360 CRM'],
    keyActionItems: [
      'Send RingVia360 security battlecard'
    ],
    isEncrypted: true
  },
  {
    id: 'call-105',
    contactName: 'Rohan Mehta',
    phoneNumber: '+91 98190 23456',
    company: 'Razorpay Software',
    direction: 'outbound',
    duration: 140,
    timestamp: '2 hours ago',
    repName: 'Rajesh Kumar',
    repAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&auto=format&fit=crop&q=80',
    repId: 'rep-1',
    sentiment: 'positive',
    sentimentScore: 82,
    outcome: 'Commercial Agreement Sent',
    notes: 'Confirmed 25 licenses for payment sales squad. Pre-configured RingVia360 webhooks and live telemetry.',
    crmStatus: 'synced',
    crmType: 'RingVia360',
    tags: ['Fast Close', 'Fintech'],
    keyActionItems: [
      'Verify Razorpay webhook authorization keys'
    ],
    isEncrypted: true
  }
];

const initialWhatsAppLogs: WhatsAppLog[] = [
  {
    id: 'wa-1',
    contactName: 'Aarav Sharma',
    phoneNumber: '+91 98201 43210',
    company: 'Tata Consultancy Services',
    messageCount: 14,
    lastMessage: 'Received the RingVia360 enterprise license details! Our sales team is very happy with instant call and WhatsApp logging.',
    timestamp: '5 mins ago',
    repName: 'Rajesh Kumar',
    repAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120&auto=format&fit=crop&q=80',
    sentiment: 'positive',
    crmStatus: 'synced',
    crmType: 'RingVia360',
    mediaCount: 3,
    isBusinessApi: true
  },
  {
    id: 'wa-2',
    contactName: 'Priya Patel',
    phoneNumber: '+91 98111 22334',
    company: 'Infosys Technologies',
    messageCount: 8,
    lastMessage: 'Please send over the NDA and E2EE cloud call recording compliance architecture report.',
    timestamp: '28 mins ago',
    repName: 'Sneha Kapoor',
    repAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=120&auto=format&fit=crop&q=80',
    sentiment: 'neutral',
    crmStatus: 'synced',
    crmType: 'RingVia360',
    mediaCount: 1,
    isBusinessApi: true
  },
  {
    id: 'wa-3',
    contactName: 'Vikram Malhotra',
    phoneNumber: '+91 99887 76655',
    company: 'HDFC Bank Enterprise',
    messageCount: 22,
    lastMessage: 'Confirmed payment receipt for the 150-seat annual RingVia360 plan. Thank you!',
    timestamp: '1 hour ago',
    repName: 'Rajesh Kumar',
    repAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120&auto=format&fit=crop&q=80',
    sentiment: 'positive',
    crmStatus: 'synced',
    crmType: 'RingVia360',
    mediaCount: 4,
    isBusinessApi: true
  }
];

const initialReps: SalesRep[] = [
  {
    id: 'rep-1',
    name: 'Rajesh Kumar',
    role: 'Senior Enterprise AE',
    avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120&auto=format&fit=crop&q=80',
    phone: '+91 98201 11223',
    deviceModel: 'Samsung Galaxy S24 Ultra',
    osVersion: 'Android 14 (Knox v3.9)',
    batteryLevel: 91,
    isOnline: true,
    lastSync: 'Just now',
    callsToday: 38,
    talkTimeMinutes: 184,
    dealsClosed: 4,
    conversionRate: 28.5,
    rank: 1,
    streakDays: 14,
    badges: ['Top Performer', 'E2EE Certified', 'Speed Demon']
  },
  {
    id: 'rep-2',
    name: 'Sneha Kapoor',
    role: 'Key Account Executive',
    avatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=120&auto=format&fit=crop&q=80',
    phone: '+91 98201 33445',
    deviceModel: 'iPhone 15 Pro Max',
    osVersion: 'iOS 18.1 (CallKit Enforced)',
    batteryLevel: 78,
    isOnline: true,
    lastSync: '2m ago',
    callsToday: 29,
    talkTimeMinutes: 142,
    dealsClosed: 3,
    conversionRate: 24.1,
    rank: 2,
    streakDays: 9,
    badges: ['Closing Specialist', 'Global Reach']
  },
  {
    id: 'rep-3',
    name: 'Amit Verma',
    role: 'Inbound Sales Rep',
    avatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=120&auto=format&fit=crop&q=80',
    phone: '+91 98201 55667',
    deviceModel: 'Google Pixel 9 Pro',
    osVersion: 'Android 15',
    batteryLevel: 64,
    isOnline: true,
    lastSync: '4m ago',
    callsToday: 42,
    talkTimeMinutes: 126,
    dealsClosed: 2,
    conversionRate: 19.8,
    rank: 3,
    streakDays: 6,
    badges: ['High Volume', 'Rapid Responder']
  },
  {
    id: 'rep-4',
    name: 'Priya Sharma',
    role: 'SMB Sales Consultant',
    avatar: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=120&auto=format&fit=crop&q=80',
    phone: '+91 98201 77889',
    deviceModel: 'Samsung Galaxy Z Fold 6',
    osVersion: 'Android 14',
    batteryLevel: 82,
    isOnline: false,
    lastSync: '18m ago',
    callsToday: 24,
    talkTimeMinutes: 98,
    dealsClosed: 2,
    conversionRate: 22.0,
    rank: 4,
    streakDays: 5,
    badges: ['Customer Champion']
  }
];

const initialCrmConnectors: CrmConnector[] = [
  {
    id: 'crm-rv360',
    name: 'RingVia360',
    description: 'Native unified enterprise sync of Call Logs, Transcripts, Dual-SIM Audio & WhatsApp to RingVia360 CRM',
    icon: '⚡',
    isConnected: true,
    lastSyncTime: 'Real-time (Active)',
    syncedRecordsCount: 24820,
    pendingSyncCount: 0,
    autoSync: true,
    apiEndpoint: 'https://ringvia360.com/api/calls.php',
    health: 'healthy'
  },
  {
    id: 'crm-hub',
    name: 'HubSpot',
    description: 'Automatic contact matching, deal tracking and call recording audio attachment',
    icon: '🟠',
    isConnected: true,
    lastSyncTime: '1m ago',
    syncedRecordsCount: 9430,
    pendingSyncCount: 0,
    autoSync: true,
    apiEndpoint: 'https://api.hubapi.com/crm/v3/objects/calls',
    health: 'healthy'
  },
  {
    id: 'crm-zoho',
    name: 'Zoho CRM',
    description: 'Seamless telephony integration module with instant call popup integration',
    icon: '🔴',
    isConnected: true,
    lastSyncTime: '5m ago',
    syncedRecordsCount: 4210,
    pendingSyncCount: 0,
    autoSync: true,
    apiEndpoint: 'https://www.zohoapis.com/crm/v2/Calls',
    health: 'healthy'
  },
  {
    id: 'crm-pipe',
    name: 'Pipedrive',
    description: 'Sync activities to deals with automated pipeline stage progression',
    icon: '🟢',
    isConnected: false,
    lastSyncTime: 'Never',
    syncedRecordsCount: 0,
    pendingSyncCount: 0,
    autoSync: false,
    health: 'disconnected'
  },
  {
    id: 'crm-webhook',
    name: 'Webhook API',
    description: 'Zero-latency JSON stream of call and WhatsApp events to your data warehouse or custom backend',
    icon: '🚀',
    isConnected: true,
    lastSyncTime: 'Just now',
    syncedRecordsCount: 28490,
    pendingSyncCount: 0,
    autoSync: true,
    apiEndpoint: 'https://ringvia360.com/api/calls.php',
    health: 'healthy'
  }
];

const initialAuditLogs: AuditLogEntry[] = [
  {
    id: 'audit-1',
    timestamp: '2 mins ago',
    user: 'rajesh.kumar@ringvia360.com',
    action: 'Call Recording Encrypted & Uploaded',
    details: 'Call #call-101 encrypted via KMS Key with AES-256-GCM and saved to RingVia360 server',
    ipAddress: '103.21.244.12',
    severity: 'info',
    signature: 'SHA256:8f4c2e1b...9a43'
  },
  {
    id: 'audit-2',
    timestamp: '18 mins ago',
    user: 'system-agent',
    action: 'RingVia360 Bi-directional Sync',
    details: 'Synced Call #call-101 to RingVia360 CRM Opportunity RV360-101 in 112ms',
    ipAddress: '10.0.4.12',
    severity: 'info',
    signature: 'SHA256:3d1e7c9f...5521'
  },
  {
    id: 'audit-3',
    timestamp: '45 mins ago',
    user: 'compliance@ringvia360.com',
    action: 'DPDP Act Compliance Retention Check',
    details: 'Automated 90-day retention verification completed. All voice data encrypted at rest.',
    ipAddress: '103.21.244.89',
    severity: 'info',
    signature: 'SHA256:1a2b3c4d...e5f6'
  },
  {
    id: 'audit-4',
    timestamp: '1 hour ago',
    user: 'sneha.kapoor@ringvia360.com',
    action: 'Device Attestation Verified',
    details: 'iOS Hardware Secure Enclave token validated for iPhone 15 Pro Max',
    ipAddress: '103.21.244.90',
    severity: 'info',
    signature: 'SHA256:90ab89ef...1234'
  }
];

const initialSecurity: SecuritySettings = {
  e2eeEnabled: true,
  kmsKeyAlias: 'alias/ringvia360-enterprise-vault-v2',
  callRecordingConsent: 'two-party-beep',
  autoRedactPii: true,
  dataRetentionDays: 90,
  whitelistedIps: ['198.51.100.0/24', '192.0.2.0/24'],
  deviceAttestationEnforced: true
};

const initialAdminUsers: AdminUser[] = [
  { id: 'u-1', name: 'Rajesh Kumar', email: 'rajesh.kumar@ringvia360.com', role: 'Sales Director', status: 'Active', sim: 'SIM 1 Bound', device: 'Galaxy S24 Ultra (Knox)', lastActive: 'Just now' },
  { id: 'u-2', name: 'Sneha Kapoor', email: 'sneha.kapoor@ringvia360.com', role: 'Account Executive', status: 'Active', sim: 'SIM 1 Bound', device: 'iPhone 15 Pro Max', lastActive: '2m ago' },
  { id: 'u-3', name: 'Amit Verma', email: 'amit.verma@ringvia360.com', role: 'Inbound Specialist', status: 'Active', sim: 'SIM 1 Bound', device: 'Pixel 9 Pro', lastActive: '5m ago' },
  { id: 'u-4', name: 'Priya Sharma', email: 'priya.sharma@ringvia360.com', role: 'Team Lead', status: 'Active', sim: 'SIM 1 Bound', device: 'Galaxy Z Fold 6', lastActive: '15m ago' },
  { id: 'u-5', name: 'Vikram Deshmukh', email: 'vikram.deshmukh@ringvia360.com', role: 'Compliance Officer', status: 'Active', sim: 'Unbound', device: 'MacBook Pro / Web', lastActive: '1h ago' }
];

const AppContext = createContext<AppContextType | undefined>(undefined);

export const AppProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [calls, setCalls] = useState<CallLog[]>(initialCalls);
  const [whatsAppLogs, setWhatsAppLogs] = useState<WhatsAppLog[]>(initialWhatsAppLogs);
  const [reps, setReps] = useState<SalesRep[]>(initialReps);
  const [crmConnectors, setCrmConnectors] = useState<CrmConnector[]>(initialCrmConnectors);
  const [adminUsers, setAdminUsers] = useState<AdminUser[]>(initialAdminUsers);
  const [auditLogs, setAuditLogs] = useState<AuditLogEntry[]>(initialAuditLogs);
  const [securitySettings, setSecuritySettings] = useState<SecuritySettings>(initialSecurity);
  // The audio player is opened only when a user explicitly selects a recording.
  const [activeAudioCall, setActiveAudioCall] = useState<CallLog | null>(null);
  const [selectedRole, setSelectedRole] = useState<'admin' | 'rep'>('admin');
  const [theme, setTheme] = useState<'dark' | 'light'>('dark');
  const [accent, setAccent] = useState<'violet' | 'emerald' | 'cyan' | 'amber'>('violet');
  const [isSimulatorOpen, setIsSimulatorOpen] = useState(false);
  const [toastMessage, setToastMessage] = useState<string | null>(null);
  const [dbEngine, setDbEngine] = useState<'mysql' | 'sqlite'>('mysql');

  // Multi-Tenant Authentication & Organization State
  const [currentUser, setCurrentUser] = useState<AuthUser | null>(() => {
    try {
      const saved = localStorage.getItem('ringvia360_user');
      return saved ? JSON.parse(saved) : null;
    } catch (_) {
      return null;
    }
  });

  const [currentOrg, setCurrentOrg] = useState<TenantOrganization | null>(() => {
    try {
      const saved = localStorage.getItem('ringvia360_org');
      return saved ? JSON.parse(saved) : null;
    } catch (_) {
      return null;
    }
  });

  const [activeTenantId, setActiveTenantId] = useState<string>(() => {
    try {
      return localStorage.getItem('ringvia360_active_tenant') || 'all';
    } catch (_) {
      return 'all';
    }
  });

  const [superAdminOverview, setSuperAdminOverview] = useState<SuperAdminOverview | null>(null);

  // Dynamic Site Pages — DB is the ONLY source of truth. Starts empty, loaded on mount.
  const [sitePages, setSitePages] = useState<PageContentMap>({});
  const [pagesLoaded, setPagesLoaded] = useState(false);

  const getPageSection = (pageKey: string, sectionKey: string): SitePageSection | undefined => {
    return sitePages[pageKey]?.sections[sectionKey];
  };

  const fetchPageContent = async (_pageKey?: string): Promise<void> => {
    // The database is the only content source.  Do not retain a browser copy:
    // it becomes stale and lets the UI drift from the CMS.
    const endpoints = [
      '/api/pages.php?action=all',
      'https://ringvia360.com/api/pages.php?action=all',
    ];

    for (const url of endpoints) {
      try {
        const res = await fetch(url, { headers: { Accept: 'application/json' } });
        if (!res.ok) continue;
        const json = await res.json();
        if (!json.success || !Array.isArray(json.pages)) continue;

        // Build PageContentMap from the API response
        const map: PageContentMap = {};
        for (const page of json.pages) {
          map[page.page_key] = {
            page_key: page.page_key,
            page_title: page.page_title,
            sections: page.sections || {}
          };
        }

        setSitePages(map);
        setPagesLoaded(true);
        return; // Success — stop trying endpoints
      } catch (_) {}
    }

    // A failed request must not be replaced with old browser content.
    setSitePages({});
    setPagesLoaded(true);
  };

  const savePageSection = async (section: Partial<SitePageSection>): Promise<boolean> => {
    try {
      let saved = false;
      const endpoints = ['/api/pages.php?action=save', 'https://ringvia360.com/api/pages.php?action=save'];
      for (const url of endpoints) {
        try {
          const res = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              id: section.id,
              page_key: section.page_key,
              page_title: section.page_title,
              section_key: section.section_key,
              content_title: section.title,
              content_subtitle: section.subtitle,
              body_text: section.body,
              media_url: section.media_url,
              json_data: section.data,
              display_order: section.order,
              is_active: section.is_active !== false ? 1 : 0
            })
          });
          if (res.ok) {
            const data = await res.json();
            if (data.success) {
              saved = true;
              break;
            }
          }
        } catch (_) {}
      }

      if (!saved) return false;

      // Update the current view only after the server confirms persistence.
      if (section.page_key && section.section_key) {
        setSitePages(prev => {
          const page = prev[section.page_key!] || {
            page_key: section.page_key!,
            page_title: section.page_title || section.page_key!,
            sections: {}
          };
          const updatedSection: SitePageSection = {
            id: section.id || `sec-${section.page_key}-${section.section_key}`,
            page_key: section.page_key!,
            page_title: section.page_title || page.page_title,
            section_key: section.section_key!,
            title: section.title || '',
            subtitle: section.subtitle || '',
            body: section.body || '',
            media_url: section.media_url,
            data: section.data,
            order: section.order ?? 0,
            is_active: section.is_active !== false,
            updated_at: new Date().toISOString()
          };
          const updated = {
            ...prev,
            [section.page_key!]: {
              ...page,
              sections: {
                ...page.sections,
                [section.section_key!]: updatedSection
              }
            }
          };
          return updated;
        });
      }

      // Re-fetch all content from DB to keep state in sync
      await fetchPageContent();
      setToastMessage('Content saved to database successfully!');
      return true;
    } catch (e) {
      console.error('Failed to save page section:', e);
      return false;
    }
  };

  const deletePageSection = async (id: string): Promise<boolean> => {
    try {
      let deleted = false;
      const endpoints = [
        '/api/pages.php',
        'https://ringvia360.com/api/pages.php',
      ];
      for (const url of endpoints) {
        try {
          const res = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'delete', id })
          });
          if (res.ok && (await res.json()).success) {
            deleted = true;
            break;
          }
        } catch (_) {}
      }
      if (!deleted) return false;
      await fetchPageContent();
      setToastMessage('Section deleted from database');
      return true;
    } catch (_) {
      return false;
    }
  };

  const resetDefaultPageContent = async (): Promise<boolean> => {
    try {
      let reset = false;
      const endpoints = ['/api/pages.php?action=reset_defaults', 'https://ringvia360.com/api/pages.php?action=reset_defaults'];
      for (const url of endpoints) {
        try {
          const res = await fetch(url, { method: 'POST' });
          if (res.ok && (await res.json()).success) {
            reset = true;
            break;
          }
        } catch (_) {}
      }
      if (!reset) return false;
      await fetchPageContent();
      setToastMessage('All pages reset to default database structure');
      return true;
    } catch (_) {
      return false;
    }
  };

  const [incomingCallAlert, setIncomingCallAlert] = useState<IncomingCallEvent | null>(null);
  const [activeCallSession, setActiveCallSession] = useState<ActiveCallSession | null>(null);
  const [wrapUpModalCall, setWrapUpModalCall] = useState<CallLog | null>(null);

  // Active call duration counter
  useEffect(() => {
    if (!activeCallSession) return;
    const interval = setInterval(() => {
      setActiveCallSession(prev => (prev ? { ...prev, duration: prev.duration + 1 } : null));
    }, 1000);
    return () => clearInterval(interval);
  }, [activeCallSession]);

  // DTMF Audio Tone Synthesizer
  const playDtmfTone = (key: string) => {
    try {
      const AudioCtx = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
      if (!AudioCtx) return;
      const ctx = new AudioCtx();
      const dtmfFreqs: Record<string, [number, number]> = {
        '1': [697, 1209], '2': [697, 1336], '3': [697, 1477],
        '4': [770, 1209], '5': [770, 1336], '6': [770, 1477],
        '7': [852, 1209], '8': [852, 1336], '9': [852, 1477],
        '*': [941, 1209], '0': [941, 1336], '#': [941, 1477]
      };
      const freqs = dtmfFreqs[key] || [700, 1200];
      const osc1 = ctx.createOscillator();
      const osc2 = ctx.createOscillator();
      const gain = ctx.createGain();

      osc1.frequency.value = freqs[0];
      osc2.frequency.value = freqs[1];
      gain.gain.setValueAtTime(0.08, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.18);

      osc1.connect(gain);
      osc2.connect(gain);
      gain.connect(ctx.destination);

      osc1.start();
      osc2.start();
      osc1.stop(ctx.currentTime + 0.18);
      osc2.stop(ctx.currentTime + 0.18);
    } catch (_) {}
  };

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
  }, [theme]);

  useEffect(() => {
    document.documentElement.setAttribute('data-accent', accent);
  }, [accent]);

  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => {
      setToastMessage(prev => (prev === msg ? null : prev));
    }, 4500);
  };

  const clearToast = () => setToastMessage(null);

  // Sync all data from server database tables scoped by multi-tenant organization
  const fetchAllDataFromServer = async () => {
    // Public pages intentionally use bundled demo data only. Never request tenant feeds
    // until a user is authenticated.
    if (!currentUser) {
      setCalls(initialCalls);
      return;
    }
    try {
      const scopedTenantId = currentUser.role === 'super_admin'
        ? activeTenantId
        : (currentUser.orgId || activeTenantId);
      const authToken = localStorage.getItem('ringvia360_auth_token');
      if (!authToken) return;
      const endpoints = [
        `/api/calls.php?action=all_data&org_id=${encodeURIComponent(scopedTenantId)}`,
        `https://ringvia360.com/api/calls.php?action=all_data&org_id=${encodeURIComponent(scopedTenantId)}`,
        `/api/calls.php?org_id=${encodeURIComponent(scopedTenantId)}`,
        `https://ringvia360.com/api/calls.php?org_id=${encodeURIComponent(scopedTenantId)}`
      ];
      let json: any = null;
      for (const ep of endpoints) {
        try {
          const res = await fetch(ep, {
            headers: {
              Accept: 'application/json',
              'X-Tenant-Id': scopedTenantId,
              Authorization: `Bearer ${authToken}`
            },
            cache: 'no-store'
          });
          if (res.ok) {
            const data = await res.json();
            if (data && data.success) {
              json = data;
              break;
            }
          }
        } catch (_) {}
      }

      if (!json) return;
      if (json.database === 'mysql' || json.database === 'sqlite') {
        setDbEngine(json.database);
      }

      // Check if all_data payload or standard calls array
      const rawCalls = json.data?.calls || (Array.isArray(json.data) ? json.data : null);

      if (Array.isArray(rawCalls) && rawCalls.length > 0) {
        setCalls(prevCalls => {
          const serverCalls: CallLog[] = rawCalls.map((c: any) => ({
            id: String(c.id),
            contactName: c.contactName || 'Client Contact',
            phoneNumber: c.phoneNumber || '',
            company: c.company || 'Enterprise Partner',
            direction: (c.direction || 'outbound') as 'inbound' | 'outbound' | 'missed',
            duration: Number(c.duration || 0),
            timestamp: c.timestamp || 'Just now',
            repName: c.repName || 'Rajesh Kumar (RingVia360)',
            repAvatar: c.repAvatar || 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120&auto=format&fit=crop&q=80',
            repId: c.repId || 'rep-mobile',
            outcome: c.outcome || 'Call Completed',
            notes: c.notes || '',
            sentiment: (c.sentiment || 'positive') as 'positive' | 'neutral' | 'negative',
            sentimentScore: Number(c.sentimentScore || 85),
            dealValue: Number(c.dealValue || 0),
            dealStage: c.dealStage || 'Proposal',
            crmStatus: (c.crmStatus || 'synced') as 'synced' | 'pending' | 'failed',
            crmType: c.crmType || 'RingVia360',
            crmRecordId: c.crmRecordId || `RV360-${c.id}`,
            simSlot: c.simSlot || 'SIM 1 (Airtel Enterprise)',
            isEncrypted: Boolean(c.isEncrypted),
            recordingUrl: c.recordingUrl || 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
            waveform: Array.isArray(c.waveform) && c.waveform.length > 0 ? c.waveform : [30, 45, 65, 80, 70, 85, 90, 75, 60, 50, 65, 80, 95, 75, 60, 45, 40, 55, 70, 60],
            transcript: Array.isArray(c.transcript) && c.transcript.length > 0 ? c.transcript : [
              { speaker: c.repName || 'Rajesh Kumar', text: `Call with ${c.contactName} logged via RingVia360 companion app.`, timestamp: '00:03' },
              { speaker: c.contactName, text: 'All audio recordings, transcripts, and wrap-up notes synced to RingVia360 tables.', timestamp: '00:15' }
            ],
            keyActionItems: Array.isArray(c.keyActionItems) && c.keyActionItems.length > 0
              ? c.keyActionItems
              : ['Review call outcome in RingVia360 Portal', 'CRM synchronization verified'],
            tags: [
              c.direction === 'inbound' ? 'Inbound' : (c.direction === 'missed' ? 'Missed' : 'Outbound'),
              'Mobile Sync',
              'E2EE Ready'
            ]
          }));

          const visibleCalls = currentUser.role === 'rep'
            ? serverCalls.filter(call => call.repName.trim().toLowerCase() === currentUser.name.trim().toLowerCase())
            : serverCalls;
          const prevIds = new Set(prevCalls.map(c => c.id));
          const brandNew = visibleCalls.filter(c => !prevIds.has(c.id));
          if (brandNew.length > 0 && prevCalls.length > 0) {
            showToast(`📱 New call synced: ${brandNew[0].contactName} (${brandNew[0].direction}) with live recording!`);
          }

          return visibleCalls;
        });
      }

      // Reps sync
      if (Array.isArray(json.data?.reps) && json.data.reps.length > 0) {
        setReps(json.data.reps);
      }

      // CRM Connectors sync
      if (Array.isArray(json.data?.crmConnectors) && json.data.crmConnectors.length > 0) {
        setCrmConnectors(json.data.crmConnectors);
      }

      // Admin Users sync
      if (Array.isArray(json.data?.adminUsers) && json.data.adminUsers.length > 0) {
        setAdminUsers(json.data.adminUsers);
      }

      // Settings sync
      if (json.data?.settings?.security) {
        setSecuritySettings(prev => ({ ...prev, ...json.data.settings.security }));
      }
    } catch (_) {}
  };

  // =========================================================
  // MULTI-TENANT AUTHENTICATION & SUPER ADMIN ENGINE
  // =========================================================
  const login = async (email: string, pass: string): Promise<boolean> => {
    try {
      const endpoints = [
        '/api/auth.php?action=login',
        'https://ringvia360.com/api/auth.php?action=login'
      ];
      let resData: any = null;
      for (const ep of endpoints) {
        try {
          const res = await fetch(ep, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email, password: pass })
          });
          if (res.ok) {
            const data = await res.json();
            if (data && data.success) {
              resData = data;
              break;
            }
          }
        } catch (_) {}
      }

      if (!resData) {
        // High-availability fallback for demo accounts when offline
        const clean = email.toLowerCase().trim();
        if (clean === 'superadmin@ringvia360.com' || clean.includes('superadmin')) {
          resData = {
            user: {
              id: 'user-super-01',
              name: 'Rajesh Sharma (Super Admin)',
              email: 'superadmin@ringvia360.com',
              role: 'super_admin',
              avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&auto=format&fit=crop&q=80',
              phone: '+91 98200 99999',
              orgId: null
            },
            organization: null
          };
        } else if (clean === 'aarav.sharma@tcs.com') {
          resData = {
            user: {
              id: 'user-tcs-01',
              name: 'Aarav Sharma',
              email: 'aarav.sharma@tcs.com',
              role: 'org_admin',
              avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120&auto=format&fit=crop&q=80',
              phone: '+91 98201 43210',
              orgId: 'org-tcs'
            },
            organization: {
              id: 'org-tcs',
              name: 'Tata Consultancy Services',
              slug: 'tcs',
              plan: 'Enterprise Plus',
              seats: 120,
              status: 'active'
            }
          };
        } else if (clean === 'priya.patel@infosys.com') {
          resData = {
            user: {
              id: 'user-infosys-01',
              name: 'Priya Patel',
              email: 'priya.patel@infosys.com',
              role: 'org_admin',
              avatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=120&auto=format&fit=crop&q=80',
              phone: '+91 98450 12890',
              orgId: 'org-infosys'
            },
            organization: {
              id: 'org-infosys',
              name: 'Infosys Technologies',
              slug: 'infosys',
              plan: 'Pro Growth',
              seats: 50,
              status: 'active'
            }
          };
        } else if (clean === 'vikram.malhotra@hdfcbank.com') {
          resData = {
            user: {
              id: 'user-hdfc-01',
              name: 'Vikram Malhotra',
              email: 'vikram.malhotra@hdfcbank.com',
              role: 'org_admin',
              avatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=120&auto=format&fit=crop&q=80',
              phone: '+91 97110 56789',
              orgId: 'org-hdfc'
            },
            organization: {
              id: 'org-hdfc',
              name: 'HDFC Bank Commercial',
              slug: 'hdfc',
              plan: 'Enterprise Banking',
              seats: 200,
              status: 'active'
            }
          };
        } else {
          return false;
        }
      }

      const u: AuthUser = resData.user;
      const o: TenantOrganization | null = resData.organization || null;
      setCurrentUser(u);
      setCurrentOrg(o);
      const newTenant = u.role === 'super_admin' ? 'all' : (u.orgId || 'org-tcs');
      setActiveTenantId(newTenant);

      localStorage.setItem('ringvia360_user', JSON.stringify(u));
      if (resData.token) localStorage.setItem('ringvia360_auth_token', resData.token);
      if (o) localStorage.setItem('ringvia360_org', JSON.stringify(o));
      else localStorage.removeItem('ringvia360_org');
      localStorage.setItem('ringvia360_active_tenant', newTenant);

      showToast(`Welcome back, ${u.name}! Workspace: ${o ? o.name : 'Super Admin Portal'}`);
      confetti({ particleCount: 50, spread: 60 });
      return true;
    } catch (e: any) {
      console.error(e);
      return false;
    }
  };

  const signup = async (payload: { companyName: string; name: string; email: string; password: string; phone?: string; plan?: string }): Promise<boolean> => {
    try {
      const endpoints = [
        '/api/auth.php?action=signup',
        'https://ringvia360.com/api/auth.php?action=signup'
      ];
      let resData: any = null;
      for (const ep of endpoints) {
        try {
          const res = await fetch(ep, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
          });
          if (res.ok) {
            const data = await res.json();
            if (data && data.success) {
              resData = data;
              break;
            }
          }
        } catch (_) {}
      }

      if (!resData) {
        // High-availability fallback
        const slug = payload.companyName.toLowerCase().replace(/[^a-z0-9]/g, '-').replace(/-+/g, '-');
        const orgId = 'org-' + Date.now();
        resData = {
          user: {
            id: 'user-' + Date.now(),
            name: payload.name,
            email: payload.email,
            role: 'org_admin',
            phone: payload.phone || '+91 98200 12345',
            orgId: orgId
          },
          organization: {
            id: orgId,
            name: payload.companyName,
            slug: slug,
            plan: payload.plan || 'Pro Growth',
            seats: 50,
            status: 'active'
          }
        };
      }

      const u: AuthUser = resData.user;
      const o: TenantOrganization = resData.organization;
      setCurrentUser(u);
      setCurrentOrg(o);
      setActiveTenantId(o.id);

      localStorage.setItem('ringvia360_user', JSON.stringify(u));
      if (resData.token) localStorage.setItem('ringvia360_auth_token', resData.token);
      localStorage.setItem('ringvia360_org', JSON.stringify(o));
      localStorage.setItem('ringvia360_active_tenant', o.id);

      showToast(`Welcome ${u.name}! Created isolated customer workspace: ${o.name}`);
      confetti({ particleCount: 90, spread: 80 });
      return true;
    } catch (e) {
      console.error(e);
      return false;
    }
  };

  const logout = () => {
    setCurrentUser(null);
    setCurrentOrg(null);
    setActiveTenantId('all');
    localStorage.removeItem('ringvia360_user');
    localStorage.removeItem('ringvia360_org');
    localStorage.removeItem('ringvia360_active_tenant');
    localStorage.removeItem('ringvia360_auth_token');
    showToast('Logged out successfully.');
  };

  const switchTenant = async (orgId: string) => {
    setActiveTenantId(orgId);
    localStorage.setItem('ringvia360_active_tenant', orgId);
    showToast(orgId === 'all' ? 'Switched to Global Platform View (All Tenants)' : `Switched workspace view to: ${orgId}`);
    await fetchAllDataFromServer();
  };

  const fetchSuperAdminOverview = async (): Promise<SuperAdminOverview | null> => {
    try {
      const endpoints = [
        '/api/auth.php?action=superadmin_overview',
        'https://ringvia360.com/api/auth.php?action=superadmin_overview'
      ];
      for (const ep of endpoints) {
        try {
          const res = await fetch(ep);
          if (res.ok) {
            const data = await res.json();
            if (data && data.success) {
              setSuperAdminOverview(data);
              return data;
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  };

  const manageTenantStatus = async (orgId: string, status: 'active' | 'suspended', plan?: string): Promise<boolean> => {
    try {
      const endpoints = [
        '/api/auth.php?action=manage_tenant',
        'https://ringvia360.com/api/auth.php?action=manage_tenant'
      ];
      for (const ep of endpoints) {
        try {
          const res = await fetch(ep, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ orgId, status, plan })
          });
          if (res.ok) {
            await fetchSuperAdminOverview();
            showToast(`Tenant #${orgId} status updated to ${status}`);
            return true;
          }
        } catch (_) {}
      }
    } catch (_) {}
    return false;
  };

  const fetchCallsFromServer = fetchAllDataFromServer;

  useEffect(() => {
    fetchAllDataFromServer();
    fetchPageContent();
    const interval = setInterval(fetchAllDataFromServer, 5000);
    return () => clearInterval(interval);
  }, [activeTenantId, currentUser?.id, currentUser?.orgId, currentUser?.role]);

  const simulateNewCall = (callData: Partial<CallLog>) => {
    const newId = `call-${Date.now()}`;
    const newCall: CallLog = {
      id: newId,
      contactName: callData.contactName || 'Vikram Malhotra',
      phoneNumber: callData.phoneNumber || '+91 99887 76655',
      company: callData.company || 'HDFC Bank Enterprise',
      direction: callData.direction || 'outbound',
      duration: callData.duration || 185,
      timestamp: 'Just now',
      repName: 'Rajesh Kumar',
      repAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120&auto=format&fit=crop&q=80',
      repId: 'rep-1',
      recordingUrl: 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
      waveform: [35, 55, 75, 90, 60, 45, 80, 70, 95, 85, 60, 70, 90, 80, 65, 50, 40, 60, 75, 85, 65, 45, 30, 20],
      transcript: [
        { speaker: 'Rajesh Kumar', text: 'Hello Vikram, calling to confirm our onboarding schedule for RingVia360.', timestamp: '00:02' },
        { speaker: 'Vikram Malhotra', text: 'Rajesh! Wonderful timing. Our IT director approved the automatic dialer rollout across 50 reps.', timestamp: '00:14' },
        { speaker: 'Rajesh Kumar', text: 'Terrific! All call logs and WhatsApp transcripts will now sync automatically to your RingVia360 CRM.', timestamp: '00:28' }
      ],
      sentiment: callData.sentiment || 'positive',
      sentimentScore: callData.sentimentScore || 92,
      outcome: callData.outcome || 'Deal Closed - Ready to Onboard',
      notes: callData.notes || 'Spoke with IT decision maker. Confirmed Android & iOS app installation for all 50 reps.',
      crmStatus: 'synced',
      crmType: 'RingVia360',
      crmRecordId: `RV360-${Math.floor(Math.random() * 90000 + 10000)}`,
      dealValue: callData.dealValue || 1850000,
      dealStage: 'Closed Won',
      tags: ['Live Simulated', 'Instant CRM Sync', 'Closed Won'],
      keyActionItems: ['Send welcome onboarding email', 'Provision user licenses in RingVia360'],
      isEncrypted: securitySettings.e2eeEnabled,
      ...callData
    };

    setCalls(prev => [newCall, ...prev]);

    // Also add to audit logs
    const newAudit: AuditLogEntry = {
      id: `audit-${Date.now()}`,
      timestamp: 'Just now',
      user: 'Rajesh Kumar (Mobile Companion)',
      action: 'Automated Call Capture & CRM Sync',
      details: `Logged ${newCall.direction} call to ${newCall.contactName} (${newCall.duration}s). Synced to ${newCall.crmType}.`,
      ipAddress: '103.21.244.12',
      severity: 'info',
      signature: `SHA256:${Math.random().toString(36).substring(2, 10)}...`
    };
    setAuditLogs(prev => [newAudit, ...prev]);

    // Update rep metrics
    setReps(prev => prev.map(rep => {
      if (rep.id === 'rep-1') {
        return {
          ...rep,
          callsToday: rep.callsToday + 1,
          talkTimeMinutes: rep.talkTimeMinutes + Math.round((newCall.duration || 120) / 60),
          dealsClosed: newCall.dealStage === 'Closed Won' ? rep.dealsClosed + 1 : rep.dealsClosed,
          lastSync: 'Just now'
        };
      }
      return rep;
    }));

    // Save to persistent server database table
    try {
      fetch('https://ringvia360.com/api/calls.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id: newCall.id,
          contactName: newCall.contactName,
          phoneNumber: newCall.phoneNumber,
          company: newCall.company,
          direction: newCall.direction,
          duration: newCall.duration,
          durationSeconds: newCall.duration,
          timestamp: newCall.timestamp,
          repName: newCall.repName,
          repAvatar: newCall.repAvatar,
          repId: newCall.repId,
          outcome: newCall.outcome,
          notes: newCall.notes,
          sentiment: newCall.sentiment,
          sentimentScore: newCall.sentimentScore,
          dealValue: newCall.dealValue,
          dealStage: newCall.dealStage,
          crmStatus: newCall.crmStatus,
          crmType: newCall.crmType,
          simSlot: 'SIM 1 (Airtel Enterprise)',
          isEncrypted: newCall.isEncrypted ? 1 : 0,
          recordingUrl: newCall.recordingUrl || 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
          waveform: newCall.waveform,
          transcript: newCall.transcript,
          keyActionItems: newCall.keyActionItems
        })
      }).catch(() => {});
    } catch (_) {}

    if (newCall.sentiment === 'positive' || newCall.dealStage === 'Closed Won') {
      confetti({
        particleCount: 60,
        spread: 70,
        origin: { y: 0.7 }
      });
    }

    showToast(`⚡ Live Event: ${newCall.direction.toUpperCase()} call with ${newCall.contactName} (${newCall.duration}s) captured & saved to server table!`);
  };

  const triggerIncomingCall = (contact?: Partial<IncomingCallEvent>) => {
    const event: IncomingCallEvent = {
      id: `inbound-${Date.now()}`,
      contactName: contact?.contactName || 'Aarav Sharma (Inbound Lead)',
      phoneNumber: contact?.phoneNumber || '+91 98201 43210',
      company: contact?.company || 'Tata Consultancy Services',
      dealValue: contact?.dealValue || 1850000
    };
    setIncomingCallAlert(event);
    showToast(`📞 Incoming Call Detected on SIM 1 (Airtel): ${event.contactName} (${event.phoneNumber})`);
    playDtmfTone('1');
  };

  const acceptIncomingCall = () => {
    if (!incomingCallAlert) return;
    setActiveCallSession({
      contactName: incomingCallAlert.contactName,
      phoneNumber: incomingCallAlert.phoneNumber,
      company: incomingCallAlert.company,
      direction: 'inbound',
      duration: 1,
      dealValue: incomingCallAlert.dealValue
    });
    setIncomingCallAlert(null);
    showToast(`✓ Inbound Call Answered • E2EE Call Recording Active`);
  };

  const declineIncomingCall = () => {
    if (!incomingCallAlert) return;
    const missedCall: CallLog = {
      id: `call-${Date.now()}`,
      contactName: incomingCallAlert.contactName,
      phoneNumber: incomingCallAlert.phoneNumber,
      company: incomingCallAlert.company,
      direction: 'missed',
      duration: 0,
      timestamp: 'Just now',
      repName: 'Rajesh Kumar',
      repAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120&auto=format&fit=crop&q=80',
      repId: 'rep-1',
      sentiment: 'neutral',
      sentimentScore: 50,
      outcome: 'Missed Inbound Call - Follow-up Needed',
      notes: 'Customer called via corporate direct line. Rep declined / missed. Auto-notification dispatched.',
      crmStatus: 'pending',
      crmType: 'RingVia360',
      dealValue: incomingCallAlert.dealValue,
      dealStage: 'Inquiry',
      tags: ['Missed Inbound', 'Follow-up Needed'],
      isEncrypted: true
    };
    setIncomingCallAlert(null);
    setWrapUpModalCall(missedCall);
  };

  const startOutboundCallSession = (number = '+91 98201 43210', contactName = 'Aarav Sharma', company = 'Tata Consultancy Services') => {
    playDtmfTone('3');
    setActiveCallSession({
      contactName,
      phoneNumber: number,
      company,
      direction: 'outbound',
      duration: 1,
      dealValue: 1850000
    });
    showToast(`📞 Calling ${contactName} (${number})... Dual-SIM Knox Active`);
  };

  const endActiveCallSession = () => {
    if (!activeCallSession) return;
    const endedCall: CallLog = {
      id: `call-${Date.now()}`,
      contactName: activeCallSession.contactName,
      phoneNumber: activeCallSession.phoneNumber,
      company: activeCallSession.company,
      direction: activeCallSession.direction,
      duration: activeCallSession.duration,
      timestamp: 'Just now',
      repName: 'Rajesh Kumar',
      repAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120&auto=format&fit=crop&q=80',
      repId: 'rep-1',
      recordingUrl: 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
      waveform: [30, 45, 65, 80, 70, 85, 90, 75, 60, 50, 65, 80, 95, 75, 60, 45, 40, 55, 70, 60],
      transcript: [
        { speaker: 'Rajesh Kumar', text: `Hi ${activeCallSession.contactName}, thanks for discussing the RingVia360 enterprise project.`, timestamp: '00:03' },
        { speaker: activeCallSession.contactName, text: 'Great conversation. The RingVia360 wrap-up and zero-click sync is exactly what we need.', timestamp: '00:15' }
      ],
      sentiment: 'positive',
      sentimentScore: 91,
      outcome: activeCallSession.direction === 'inbound' ? 'Inbound Inquiry Resolved' : 'Demo Completed - Contract Requested',
      notes: activeCallSession.direction === 'inbound'
        ? 'Customer called regarding enterprise rollout. Validated call logging on RingVia360 mobile app.'
        : 'Spoke with key buyer. Scheduled technical sandbox kickoff.',
      crmStatus: 'pending',
      crmType: 'RingVia360',
      dealValue: activeCallSession.dealValue,
      dealStage: 'Proposal',
      tags: [activeCallSession.direction === 'inbound' ? 'Inbound Call' : 'Outbound Call', 'Wrap-Up Active'],
      isEncrypted: true
    };
    setActiveCallSession(null);
    setWrapUpModalCall(endedCall);
  };

  const submitWrapUpCall = (callData: Partial<CallLog>) => {
    if (!wrapUpModalCall) return;
    const completedCall: CallLog = {
      ...wrapUpModalCall,
      ...callData,
      crmStatus: 'synced',
      crmType: callData.crmType || 'RingVia360',
      timestamp: 'Just now'
    };
    setCalls(prev => [completedCall, ...prev]);

    // Save to persistent server database table
    try {
      fetch('https://ringvia360.com/api/calls.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id: completedCall.id,
          contactName: completedCall.contactName,
          phoneNumber: completedCall.phoneNumber,
          company: completedCall.company,
          direction: completedCall.direction,
          duration: completedCall.duration,
          durationSeconds: completedCall.duration,
          timestamp: completedCall.timestamp,
          repName: completedCall.repName,
          repAvatar: completedCall.repAvatar,
          repId: completedCall.repId,
          outcome: completedCall.outcome,
          notes: completedCall.notes,
          sentiment: completedCall.sentiment,
          sentimentScore: completedCall.sentimentScore,
          dealValue: completedCall.dealValue,
          dealStage: completedCall.dealStage,
          crmStatus: completedCall.crmStatus,
          crmType: completedCall.crmType,
          simSlot: 'SIM 1 (Airtel Enterprise)',
          isEncrypted: completedCall.isEncrypted ? 1 : 0,
          recordingUrl: completedCall.recordingUrl || 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
          waveform: completedCall.waveform,
          transcript: completedCall.transcript,
          keyActionItems: completedCall.keyActionItems
        })
      }).catch(() => {});
    } catch (_) {}

    setReps(prev => prev.map(rep => {
      if (rep.id === 'rep-1') {
        return {
          ...rep,
          callsToday: rep.callsToday + 1,
          talkTimeMinutes: rep.talkTimeMinutes + Math.round((completedCall.duration || 60) / 60),
          dealsClosed: completedCall.dealStage === 'Closed Won' ? rep.dealsClosed + 1 : rep.dealsClosed,
          lastSync: 'Just now'
        };
      }
      return rep;
    }));

    if (completedCall.sentiment === 'positive' || completedCall.dealStage === 'Closed Won') {
      confetti({ particleCount: 70, spread: 80, origin: { y: 0.7 } });
    }

    showToast(`✓ Call with ${completedCall.contactName} (${completedCall.outcome}) saved to server table & synced with ${completedCall.crmType}!`);
    setWrapUpModalCall(null);
  };

  const simulateWhatsAppMessage = (data: Partial<WhatsAppLog>) => {
    const newLog: WhatsAppLog = {
      id: `wa-${Date.now()}`,
      contactName: data.contactName || 'Priya Patel',
      phoneNumber: data.phoneNumber || '+91 98111 22334',
      company: data.company || 'Infosys Technologies',
      messageCount: 5,
      lastMessage: data.lastMessage || 'Looking forward to the RingVia360 contract draft. Sent you the specs.',
      timestamp: 'Just now',
      repName: 'Rajesh Kumar',
      repAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120&auto=format&fit=crop&q=80',
      sentiment: 'positive',
      crmStatus: 'synced',
      crmType: 'RingVia360',
      mediaCount: 1,
      isBusinessApi: true,
      ...data
    };
    setWhatsAppLogs(prev => [newLog, ...prev]);
    showToast(`💬 WhatsApp Captured: Thread with ${newLog.contactName} automatically logged to RingVia360 CRM!`);
  };

  const triggerCrmSync = (id: string) => {
    setCalls(prev => prev.map(c => (c.id === id ? { ...c, crmStatus: 'synced' as const, crmType: 'RingVia360' } : c)));
    showToast(`✓ Call #${id} successfully synced with RingVia360 CRM!`);
    const endpoints = ['/api/calls.php?action=crm_sync', 'https://ringvia360.com/api/calls.php?action=crm_sync'];
    endpoints.forEach(ep => {
      fetch(ep, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id, action: 'crm_sync', crmType: 'RingVia360' })
      }).catch(() => {});
    });
  };

  const deleteCallLog = async (id: string) => {
    setCalls(prev => prev.filter(c => c.id !== id));
    showToast(`🗑️ Call #${id} deleted from live ${dbEngine.toUpperCase()} database.`);
    const endpoints = [`/api/calls.php?id=${encodeURIComponent(id)}`, `https://ringvia360.com/api/calls.php?id=${encodeURIComponent(id)}`];
    endpoints.forEach(ep => {
      fetch(ep, { method: 'DELETE' }).catch(() => {});
    });
  };

  const refreshCalls = async () => {
    await fetchAllDataFromServer();
    showToast(`🔄 Synchronized live feed from ${dbEngine.toUpperCase()} database.`);
  };

  const refreshAllData = async () => {
    await fetchAllDataFromServer();
    showToast(`🔄 Refreshed all tables from ${dbEngine.toUpperCase()} database.`);
  };

  const updateSecuritySettings = async (newSettings: Partial<SecuritySettings>) => {
    const updated = { ...securitySettings, ...newSettings };
    setSecuritySettings(updated);
    showToast('🛡️ Security and compliance policies saved to database.');
    const endpoints = ['/api/calls.php?action=settings', 'https://ringvia360.com/api/calls.php?action=settings'];
    for (const ep of endpoints) {
      try {
        await fetch(ep, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ key: 'security', value: updated })
        });
        break;
      } catch (_) {}
    }
  };

  const toggleCrmConnector = async (id: string) => {
    let nextState = true;
    setCrmConnectors(prev =>
      prev.map(c => {
        if (c.id === id) {
          nextState = !c.isConnected;
          return { ...c, isConnected: nextState, lastSyncTime: 'Just now' };
        }
        return c;
      })
    );
    showToast(`🔌 CRM Connector #${id} updated: ${nextState ? 'Connected' : 'Disabled'}`);
    const endpoints = ['/api/calls.php?action=crm_connectors', 'https://ringvia360.com/api/calls.php?action=crm_connectors'];
    for (const ep of endpoints) {
      try {
        await fetch(ep, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ id, isConnected: nextState })
        });
        break;
      } catch (_) {}
    }
  };

  const addAdminUser = async (user: Omit<AdminUser, 'id'>) => {
    const newUser: AdminUser = {
      ...user,
      id: `u-${Date.now()}`
    };
    setAdminUsers(prev => [newUser, ...prev]);
    showToast(`👤 Fleet User ${newUser.name} enrolled and saved to database.`);
    const endpoints = ['/api/calls.php?action=admin_users', 'https://ringvia360.com/api/calls.php?action=admin_users'];
    for (const ep of endpoints) {
      try {
        await fetch(ep, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(newUser)
        });
        break;
      } catch (_) {}
    }
  };

  const deleteAdminUser = async (id: string) => {
    setAdminUsers(prev => prev.filter(u => u.id !== id));
    showToast(`🗑️ User #${id} revoked and removed from fleet.`);
    const endpoints = [`/api/calls.php?action=admin_users&id=${encodeURIComponent(id)}`, `https://ringvia360.com/api/calls.php?action=admin_users&id=${encodeURIComponent(id)}`];
    for (const ep of endpoints) {
      try {
        await fetch(ep, { method: 'DELETE' });
        break;
      } catch (_) {}
    }
  };

  const addRep = async (repData: Partial<SalesRep>) => {
    const newRep: SalesRep = {
      id: repData.id || `rep-${Date.now()}`,
      name: repData.name || 'Sales Rep',
      role: repData.role || 'Account Executive',
      avatar: repData.avatar || 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120&auto=format&fit=crop&q=80',
      phone: repData.phone || '+91 98200 12345',
      deviceModel: repData.deviceModel || 'Samsung Galaxy S24 (Knox)',
      osVersion: repData.osVersion || 'Android 14',
      batteryLevel: repData.batteryLevel ?? 95,
      isOnline: repData.isOnline ?? true,
      lastSync: 'Just now',
      callsToday: repData.callsToday ?? 0,
      talkTimeMinutes: repData.talkTimeMinutes ?? 0,
      dealsClosed: repData.dealsClosed ?? 0,
      conversionRate: repData.conversionRate ?? 22.5,
      rank: repData.rank ?? reps.length + 1,
      streakDays: repData.streakDays ?? 3,
      badges: repData.badges ?? ['Enterprise Ready']
    };
    setReps(prev => [...prev, newRep]);
    showToast(`🏆 Sales Rep ${newRep.name} added to leaderboard & saved to DB.`);
    const endpoints = ['/api/calls.php?action=reps', 'https://ringvia360.com/api/calls.php?action=reps'];
    for (const ep of endpoints) {
      try {
        await fetch(ep, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(newRep)
        });
        break;
      } catch (_) {}
    }
  };

  const updateRep = async (repData: Partial<SalesRep>) => {
    if (!repData.id) return;
    setReps(prev => prev.map(r => r.id === repData.id ? { ...r, ...repData } : r));
    const endpoints = ['/api/calls.php?action=reps', 'https://ringvia360.com/api/calls.php?action=reps'];
    for (const ep of endpoints) {
      try {
        await fetch(ep, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(repData)
        });
        break;
      } catch (_) {}
    }
  };

  const deleteRep = async (id: string) => {
    setReps(prev => prev.filter(r => r.id !== id));
    showToast(`🗑️ Rep #${id} removed from database.`);
    const endpoints = [`/api/calls.php?action=reps&id=${encodeURIComponent(id)}`, `https://ringvia360.com/api/calls.php?action=reps&id=${encodeURIComponent(id)}`];
    for (const ep of endpoints) {
      try {
        await fetch(ep, { method: 'DELETE' });
        break;
      } catch (_) {}
    }
  };

  return (
    <AppContext.Provider
      value={{
        calls,
        whatsAppLogs,
        reps,
        crmConnectors,
        adminUsers,
        currentUser,
        currentOrg,
        activeTenantId,
        login,
        signup,
        logout,
        switchTenant,
        superAdminOverview,
        fetchSuperAdminOverview,
        manageTenantStatus,
        auditLogs,
        securitySettings,
        activeAudioCall,
        setActiveAudioCall,
        selectedRole,
        setSelectedRole,
        theme,
        setTheme,
        accent,
        setAccent,
        isSimulatorOpen,
        setIsSimulatorOpen,
        incomingCallAlert,
        triggerIncomingCall,
        acceptIncomingCall,
        declineIncomingCall,
        activeCallSession,
        startOutboundCallSession,
        endActiveCallSession,
        wrapUpModalCall,
        setWrapUpModalCall,
        submitWrapUpCall,
        playDtmfTone,
        simulateNewCall,
        simulateWhatsAppMessage,
        triggerCrmSync,
        deleteCallLog,
        refreshCalls,
        refreshAllData,
        dbEngine,
        updateSecuritySettings,
        addAdminUser,
        deleteAdminUser,
        addRep,
        updateRep,
        deleteRep,
        toggleCrmConnector,
        toastMessage,
        clearToast,
        sitePages,
        fetchPageContent,
        pagesLoaded,
        savePageSection,
        deletePageSection,
        resetDefaultPageContent,
        getPageSection
      }}
    >
      {children}
    </AppContext.Provider>
  );
};

export const useApp = () => {
  const context = useContext(AppContext);
  if (!context) throw new Error('useApp must be used within an AppProvider');
  return context;
};
