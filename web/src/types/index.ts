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
  simSlot?: string;
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

export interface AdminUser {
  id: string;
  name: string;
  email: string;
  role: string;
  status: string;
  sim: string;
  device: string;
  lastActive: string;
}

export interface AuthUser {
  id: string;
  name: string;
  email: string;
  role: 'super_admin' | 'org_admin' | 'rep';
  avatar?: string;
  phone?: string;
  orgId?: string | null;
  orgName?: string;
}

export interface TenantOrganization {
  id: string;
  name: string;
  slug: string;
  plan: string;
  seats: number;
  monthly_price_inr?: number;
  status: 'active' | 'suspended';
  owner_email?: string;
  created_at?: string;
  user_count?: number;
  call_count?: number;
}

export interface SuperAdminOverview {
  platformMetrics: {
    totalTenants: number;
    activeTenants: number;
    totalUsers: number;
    totalCallsLogged: number;
    totalMonthlyRevenueInr: number;
    totalSeatsAllocated: number;
  };
  tenants: TenantOrganization[];
}

export interface SitePageSection {
  id: string;
  page_key: string;
  page_title: string;
  section_key: string;
  title: string;
  subtitle: string;
  body: string;
  media_url?: string;
  data?: any;
  order: number;
  is_active: boolean;
  updated_at?: string;
}

export type PageContentMap = Record<string, {
  page_key: string;
  page_title: string;
  sections: Record<string, SitePageSection>;
}>;



