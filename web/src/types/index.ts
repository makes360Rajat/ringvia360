export type CallDirection = 'inbound' | 'outbound' | 'missed';
export type Sentiment = 'positive' | 'neutral' | 'negative';
export type CrmSyncStatus = 'synced' | 'pending' | 'failed';

export interface CallLog {
  id: string;
  contactName: string;
  phoneNumber: string;
  company: string;
  direction: CallDirection;
  duration: number; // in seconds
  timestamp: string;
  repName: string;
  repAvatar: string;
  repId: string;
  recordingUrl?: string;
  waveform?: number[];
  transcript?: {
    speaker: string;
    text: string;
    timestamp: string;
  }[];
  sentiment: Sentiment;
  sentimentScore: number; // 0 to 100
  outcome: string;
  notes: string;
  crmStatus: CrmSyncStatus;
  crmType: 'RingVia360' | 'Salesforce' | 'HubSpot' | 'Zoho' | 'Custom';
  crmRecordId?: string;
  dealValue?: number;
  dealStage?: string;
  tags: string[];
  keyActionItems?: string[];
  isEncrypted: boolean;
}

export interface WhatsAppLog {
  id: string;
  contactName: string;
  phoneNumber: string;
  company: string;
  messageCount: number;
  lastMessage: string;
  timestamp: string;
  repName: string;
  repAvatar: string;
  sentiment: Sentiment;
  crmStatus: CrmSyncStatus;
  crmType: string;
  mediaCount: number;
  isBusinessApi: boolean;
}

export interface SalesRep {
  id: string;
  name: string;
  role: string;
  avatar: string;
  phone: string;
  deviceModel: string;
  osVersion: string;
  batteryLevel: number;
  isOnline: boolean;
  lastSync: string;
  callsToday: number;
  talkTimeMinutes: number;
  dealsClosed: number;
  conversionRate: number;
  rank: number;
  streakDays: number;
  badges: string[];
}

export interface CrmConnector {
  id: string;
  name: 'RingVia360' | 'Salesforce' | 'HubSpot' | 'Zoho CRM' | 'Pipedrive' | 'Webhook API';
  description: string;
  icon: string;
  isConnected: boolean;
  lastSyncTime: string;
  syncedRecordsCount: number;
  pendingSyncCount: number;
  autoSync: boolean;
  apiEndpoint?: string;
  health: 'healthy' | 'degraded' | 'disconnected';
}

export interface AuditLogEntry {
  id: string;
  timestamp: string;
  user: string;
  action: string;
  details: string;
  ipAddress: string;
  severity: 'info' | 'warning' | 'critical';
  signature: string; // E2EE verification hash
}

export interface SecuritySettings {
  e2eeEnabled: boolean;
  kmsKeyAlias: string;
  callRecordingConsent: 'two-party-beep' | 'verbal-ai-prompt' | 'disabled';
  autoRedactPii: boolean;
  dataRetentionDays: number;
  whitelistedIps: string[];
  deviceAttestationEnforced: boolean;
}
