-- ============================================================================
-- RingVia360 Production Database Schema & Seed Data
-- Database Name: u488332847_dn_name
-- Target: MySQL / MariaDB (Hostinger)
-- ============================================================================

SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+05:30";

-- ----------------------------------------------------------------------------
-- 1. Table structure for table `site_pages` (Dynamic Page Content Engine)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `site_pages` (
  `id` VARCHAR(128) NOT NULL,
  `page_key` VARCHAR(64) NOT NULL,
  `page_title` VARCHAR(255) NOT NULL,
  `section_key` VARCHAR(64) NOT NULL,
  `content_title` VARCHAR(255) DEFAULT NULL,
  `content_subtitle` TEXT DEFAULT NULL,
  `body_text` LONGTEXT DEFAULT NULL,
  `media_url` VARCHAR(512) DEFAULT NULL,
  `json_data` LONGTEXT DEFAULT NULL,
  `display_order` INT(11) DEFAULT 0,
  `is_active` TINYINT(1) DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_page_section` (`page_key`, `section_key`),
  KEY `idx_page_order` (`page_key`, `display_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- 2. Table structure for table `organizations` (Multi-Tenant Companies)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `organizations` (
  `id` VARCHAR(128) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `subdomain` VARCHAR(128) UNIQUE DEFAULT NULL,
  `plan` VARCHAR(64) DEFAULT 'pro',
  `monthly_fee_inr` INT(11) DEFAULT 14999,
  `status` VARCHAR(32) DEFAULT 'active',
  `max_reps` INT(11) DEFAULT 25,
  `crm_provider` VARCHAR(64) DEFAULT 'Salesforce',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- 3. Table structure for table `users` (Super Admin & Customer Admins)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `users` (
  `id` VARCHAR(128) NOT NULL,
  `org_id` VARCHAR(128) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `email` VARCHAR(255) NOT NULL UNIQUE,
  `password_hash` VARCHAR(255) NOT NULL,
  `role` VARCHAR(32) DEFAULT 'tenant_admin',
  `status` VARCHAR(32) DEFAULT 'active',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_user_org` (`org_id`),
  KEY `idx_user_role` (`role`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- 4. Table structure for table `call_logs` (Calls, Audio Recordings & Transcripts)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `call_logs` (
  `id` VARCHAR(128) NOT NULL,
  `org_id` VARCHAR(128) DEFAULT 'org-tcs',
  `contact_name` VARCHAR(255) NOT NULL,
  `phone_number` VARCHAR(64) NOT NULL,
  `company` VARCHAR(255) DEFAULT NULL,
  `direction` VARCHAR(32) NOT NULL,
  `duration` INT(11) NOT NULL DEFAULT 0,
  `timestamp` VARCHAR(64) NOT NULL,
  `rep_name` VARCHAR(255) DEFAULT 'Rajesh Kumar (RingVia360)',
  `rep_avatar` VARCHAR(512) DEFAULT NULL,
  `rep_id` VARCHAR(128) DEFAULT 'rep-mobile',
  `outcome` VARCHAR(255) DEFAULT NULL,
  `notes` TEXT DEFAULT NULL,
  `sentiment` VARCHAR(32) DEFAULT 'positive',
  `sentiment_score` INT(11) DEFAULT 85,
  `deal_value` DECIMAL(12,2) DEFAULT 0.00,
  `deal_stage` VARCHAR(128) DEFAULT 'Proposal',
  `crm_status` VARCHAR(64) DEFAULT 'synced',
  `crm_type` VARCHAR(64) DEFAULT 'RingVia360',
  `sim_slot` VARCHAR(64) DEFAULT 'SIM 1 (Corporate)',
  `is_encrypted` TINYINT(1) DEFAULT 1,
  `recording_url` VARCHAR(512) DEFAULT NULL,
  `waveform` TEXT DEFAULT NULL,
  `transcript` TEXT DEFAULT NULL,
  `key_action_items` TEXT DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_calls_org` (`org_id`),
  KEY `idx_calls_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- 5. Table structure for table `leads_contacts` (Indian Enterprise Contacts)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `leads_contacts` (
  `id` VARCHAR(128) NOT NULL,
  `org_id` VARCHAR(128) DEFAULT 'org-tcs',
  `name` VARCHAR(255) NOT NULL,
  `phone_number` VARCHAR(64) NOT NULL,
  `company` VARCHAR(255) DEFAULT NULL,
  `title` VARCHAR(128) DEFAULT NULL,
  `open_deal_value` DECIMAL(12,2) DEFAULT 0.00,
  `last_contacted` VARCHAR(64) DEFAULT NULL,
  `crm_account_id` VARCHAR(128) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_leads_org` (`org_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- 6. Table structure for table `sales_reps` (Team Performance & Scores)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `sales_reps` (
  `id` VARCHAR(128) NOT NULL,
  `org_id` VARCHAR(128) DEFAULT 'org-tcs',
  `name` VARCHAR(255) NOT NULL,
  `email` VARCHAR(255) DEFAULT NULL,
  `avatar` VARCHAR(512) DEFAULT NULL,
  `calls_today` INT(11) DEFAULT 0,
  `talk_time` VARCHAR(32) DEFAULT '0m',
  `sentiment_score` INT(11) DEFAULT 85,
  `pipeline_attributed` DECIMAL(12,2) DEFAULT 0.00,
  `status` VARCHAR(32) DEFAULT 'active',
  PRIMARY KEY (`id`),
  KEY `idx_reps_org` (`org_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- 7. Table structure for table `admin_users`
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `admin_users` (
  `id` VARCHAR(128) NOT NULL,
  `org_id` VARCHAR(128) DEFAULT 'org-tcs',
  `name` VARCHAR(255) NOT NULL,
  `email` VARCHAR(255) NOT NULL,
  `role` VARCHAR(32) DEFAULT 'Manager',
  `avatar` VARCHAR(512) DEFAULT NULL,
  `last_active` VARCHAR(64) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_admin_org` (`org_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- 8. Table structure for table `crm_connectors`
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `crm_connectors` (
  `id` VARCHAR(128) NOT NULL,
  `org_id` VARCHAR(128) DEFAULT 'org-tcs',
  `name` VARCHAR(128) NOT NULL,
  `status` VARCHAR(32) DEFAULT 'connected',
  `last_sync` VARCHAR(64) DEFAULT NULL,
  `records_synced` INT(11) DEFAULT 0,
  `webhook_url` VARCHAR(512) DEFAULT NULL,
  `api_key` VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_crm_org` (`org_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- 9. Table structure for table `whatsapp_logs`
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `whatsapp_logs` (
  `id` VARCHAR(128) NOT NULL,
  `org_id` VARCHAR(128) DEFAULT 'org-tcs',
  `contact_phone` VARCHAR(64) NOT NULL,
  `template_name` VARCHAR(128) DEFAULT NULL,
  `status` VARCHAR(32) DEFAULT 'delivered',
  `sent_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_wa_org` (`org_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- 10. Table structure for table `audit_logs`
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `audit_logs` (
  `id` VARCHAR(128) NOT NULL,
  `org_id` VARCHAR(128) DEFAULT NULL,
  `user_id` VARCHAR(128) DEFAULT NULL,
  `action` VARCHAR(128) NOT NULL,
  `details` TEXT DEFAULT NULL,
  `ip_address` VARCHAR(64) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_audit_org` (`org_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- SEED DATA INSERTIONS
-- ============================================================================

-- Organizations
INSERT IGNORE INTO `organizations` (`id`, `name`, `subdomain`, `plan`, `monthly_fee_inr`, `status`, `max_reps`, `crm_provider`) VALUES
('org-super', 'RingVia360 Master Platform', 'app', 'master', 0, 'active', 9999, 'Internal'),
('org-tcs', 'Tata Consultancy Services', 'tcs', 'enterprise', 45000, 'active', 100, 'Salesforce'),
('org-infosys', 'Infosys Limited', 'infosys', 'pro', 14999, 'active', 25, 'HubSpot'),
('org-hdfc', 'HDFC Bank Corporate Calling', 'hdfc', 'custom', 85000, 'active', 250, 'LeadSquared');

-- Users (All Passwords are: Password123!)
INSERT IGNORE INTO `users` (`id`, `org_id`, `name`, `email`, `password_hash`, `role`, `status`) VALUES
('usr-super', 'org-super', 'Super Administrator', 'superadmin@ringvia360.com', '$2y$10$w09aVn6Z5u4wWb37gLp1Z.mK1o9k5B2kMvU2jU5Yv8m8dFhWqL0ey', 'superadmin', 'active'),
('usr-tcs-admin', 'org-tcs', 'Rajesh Sharma (TCS Lead)', 'admin@tcs.in', '$2y$10$w09aVn6Z5u4wWb37gLp1Z.mK1o9k5B2kMvU2jU5Yv8m8dFhWqL0ey', 'tenant_admin', 'active'),
('usr-inf-admin', 'org-infosys', 'Ananya Deshmukh', 'admin@infosys.in', '$2y$10$w09aVn6Z5u4wWb37gLp1Z.mK1o9k5B2kMvU2jU5Yv8m8dFhWqL0ey', 'tenant_admin', 'active'),
('usr-hdfc-admin', 'org-hdfc', 'Vikramaditya Verma', 'admin@hdfcbank.in', '$2y$10$w09aVn6Z5u4wWb37gLp1Z.mK1o9k5B2kMvU2jU5Yv8m8dFhWqL0ey', 'tenant_admin', 'active');

-- Dynamic Page Content (site_pages)
INSERT IGNORE INTO `site_pages` (`id`, `page_key`, `page_title`, `section_key`, `content_title`, `content_subtitle`, `body_text`, `media_url`, `json_data`, `display_order`, `is_active`) VALUES
('sec-home-hero', 'home', 'Home', 'hero', 
 'Automate Call Tracking & Audio Intelligence for Enterprise Sales', 
 'RingVia360 securely captures SIM & VoIP calls, generates real-time audio transcripts & waveforms, and syncs directly into your CRM with zero battery drain.', 
 'Built for high-velocity Indian & global sales teams. Native Samsung Knox dual-SIM hardware partition separates personal calls from corporate CRM activity.', 
 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3', 
 '{\"badge\":\"⚡ ENTERPRISE TELEPHONY AUTOMATION 2026\",\"cta_primary\":\"Start 14-Day Free Trial\",\"cta_secondary\":\"Book Architecture Demo\",\"trust_badge\":\"Trusted by 450+ High-Growth Enterprises Across India\"}', 1, 1),

('sec-home-stats', 'home', 'Home', 'stats',
 'Platform Benchmark & Performance Numbers',
 'Real-time telemetry from enterprise production instances',
 'Our carrier-grade cloud network processes hundreds of thousands of outbound calls daily with zero data loss.',
 '',
 '{\"items\":[{\"value\":\"99.8%\",\"label\":\"Automated Call Capture\",\"desc\":\"Zero manual rep logging required\"},{\"value\":\"₹48.5L+\",\"label\":\"Daily Deal Volume Tracked\",\"desc\":\"Integrated CRM pipeline attribution\"},{\"value\":\"45%\",\"label\":\"Productivity Increase\",\"desc\":\"Saved 1.5 hrs/rep/day in data entry\"},{\"value\":\"100%\",\"label\":\"Knox E2EE Isolation\",\"desc\":\"Complete hardware privacy protection\"}]}', 2, 1),

('sec-pricing-hero', 'pricing', 'Pricing', 'hero',
 'Corporate Pricing Tailored for Indian & Global Scale',
 'Transparent INR corporate pricing with isolated tenant workspaces, unlimited storage, and 99.9% uptime SLA.',
 'Every subscription includes private database isolation, Knox hardware telemetry, and dedicated support.',
 '',
 '{\"badge\":\"SIMPLE TRANSPARENT PLANS IN INR\",\"billing_period\":\"monthly\",\"plans\":[{\"id\":\"starter\",\"name\":\"Starter Team\",\"price_inr\":\"₹4,999\",\"period\":\"/ month\",\"max_reps\":\"Up to 5 Reps\",\"features\":[\"Automated SIM Call Capture\",\"Encrypted Audio Recording\",\"RingVia360 Cloud CRM\",\"Post-Call Notes & Audio Pod\",\"Email Support\"],\"popular\":false},{\"id\":\"pro\",\"name\":\"Growth & Scale\",\"price_inr\":\"₹14,999\",\"period\":\"/ month\",\"max_reps\":\"Up to 25 Reps\",\"features\":[\"Everything in Starter\",\"Knox Dual-SIM Separation\",\"Salesforce & HubSpot Auto-Sync\",\"AI Sentiment & Waveform Pod\",\"Priority Phone Support\"],\"popular\":true},{\"id\":\"enterprise\",\"name\":\"Enterprise Business\",\"price_inr\":\"₹45,000\",\"period\":\"/ month\",\"max_reps\":\"Up to 100 Reps\",\"features\":[\"Everything in Growth\",\"Custom CRM Field Mappings\",\"Dedicated Multi-Tenant Isolation\",\"Custom WhatsApp Bot Templates\",\"24/7 Dedicated Account Manager\"],\"popular\":false},{\"id\":\"custom\",\"name\":\"Banking & Telecom\",\"price_inr\":\"₹85,000\",\"period\":\"/ month\",\"max_reps\":\"Unlimited Reps\",\"features\":[\"Custom On-Prem / VPC Hosting\",\"SOC-2 & ISO 27001 Compliance\",\"Custom Knox MDM Integration\",\"Unlimited Call Audio Vault\",\"Tailored SLA Guarantee\"],\"popular\":false}]}', 1, 1),

('sec-features-hero', 'features', 'Features', 'hero',
 'Enterprise Telephony Engineered for Modern Sales Teams',
 'Deep mobile telemetry, carrier-grade audio capture, and autonomous CRM automation for seamless closing.',
 'RingVia360 combines high-availability mobile companion apps with web admin supervision.',
 '',
 '{\"badge\":\"PLATFORM CAPABILITIES\",\"filter_categories\":[\"All Capabilities\",\"Compliance & Privacy\",\"CRM Automation\",\"Speech Intelligence\"]}', 1, 1),

('sec-activities-hero', 'activities', 'Activities', 'hero',
 'Real-Time Sales Activity & Call Stream',
 'Live inbound and outbound call feeds with waveform audio player, rep attribution, and CRM delivery verification.',
 'Monitor rep conversations as they happen across all active field agents.',
 '',
 '{\"live_banner\":\"LIVE FEED CONNECTED • 41 ACTIVE CALLS SYNCHRONIZED TODAY\",\"quick_filters\":[\"All Calls\",\"Inbound\",\"Outbound\",\"Missed\",\"High Value (>₹50k)\"]}', 1, 1),

('sec-analytics-hero', 'analytics', 'Analytics', 'hero',
 'Telephony Performance & Pipeline Intelligence',
 'Transform field calling volume into quantifiable revenue outcomes and rep coaching opportunities.',
 'Interactive drill-downs into call duration distributions, conversion velocity, and sentiment scores.',
 '',
 '{\"target_talk_time_min\":180,\"positive_sentiment_goal\":\"85%\",\"active_reps_online\":12}', 1, 1),

('sec-crm-hero', 'crm_sync', 'CRM Sync', 'hero',
 'Zero-Touch Bi-Directional CRM Integrations',
 'Eliminate manual logging forever. Every call, note, audio recording, and sentiment tag is automatically pushed to your CRM.',
 'Supports automatic contact creation, deal stage progression, and custom field synchronization.',
 '',
 '{\"supported_crms\":[\"Salesforce\",\"HubSpot\",\"Zoho CRM\",\"LeadSquared\",\"Freshsales\",\"Custom Webhooks\"],\"sync_frequency\":\"Real-time (sub-second webhook push)\"}', 1, 1);

-- Sample Call Logs (Scoped to org-tcs)
INSERT IGNORE INTO `call_logs` (`id`, `org_id`, `contact_name`, `phone_number`, `company`, `direction`, `duration`, `timestamp`, `rep_name`, `rep_avatar`, `rep_id`, `outcome`, `notes`, `sentiment`, `sentiment_score`, `deal_value`, `deal_stage`, `crm_status`, `crm_type`, `sim_slot`, `is_encrypted`, `recording_url`, `waveform`, `transcript`, `key_action_items`) VALUES
('call-101', 'org-tcs', 'Alexander Hayes', '+1 (415) 890-2341', 'Apex Cloud Solutions', 'outbound', 384, '8m ago', 'Rajesh Kumar (RingVia360)', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&auto=format&fit=crop&q=80', 'rep-1', 'Demo Completed - Contract Requested', 'Decision maker confirmed budget for 50 licenses. Requested Salesforce field mapping.', 'positive', 94, 48000.00, 'Proposal / Review', 'synced', 'Salesforce', 'SIM 1 (Corporate)', 1, 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3', '[30, 45, 65, 80, 70, 85, 90, 75, 60, 50, 65, 80, 95, 75, 60, 45, 40, 55, 70, 60]', '[{\"speaker\":\"Rajesh Kumar\",\"text\":\"Good morning Alexander, thanks for jumping on. Did you get a chance to test our SIM isolation?\",\"timestamp\":\"00:03\"},{\"speaker\":\"Alexander Hayes\",\"text\":\"Yes Rajesh, our team tested the Knox dual-SIM isolation on 10 devices. Corporate calls were logged flawlessly.\",\"timestamp\":\"00:45\"}]', '[\"Send Docusign MSA for 50 licenses\",\"Schedule kickoff call with IT Director\"]'),
('call-102', 'org-tcs', 'Dr. Ramesh Patel', '+91 98201 45892', 'Apollo Health Systems', 'inbound', 512, '35m ago', 'Priya Sharma (RingVia360)', 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=120&auto=format&fit=crop&q=80', 'rep-2', 'Technical Validation Passed', 'Client tested inbound call capture on Samsung Knox devices with zero battery impact.', 'positive', 88, 72000.00, 'Technical Validation', 'synced', 'HubSpot', 'SIM 1 (Corporate)', 1, 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3', '[40, 55, 75, 90, 85, 95, 80, 70, 60, 75, 85, 90, 65, 50, 45, 60, 75, 85, 70, 55]', '[{\"speaker\":\"Dr. Ramesh Patel\",\"text\":\"Hello Priya, we just completed the 24-hour battery consumption benchmark on our sales team.\",\"timestamp\":\"00:08\"},{\"speaker\":\"Priya Sharma\",\"text\":\"Great to hear, Ramesh! How did RingVia360 perform against Salestrail?\",\"timestamp\":\"00:25\"}]', '[\"Email Knox MDM deployment guide\"]');

-- Sample Indian Enterprise Leads (Scoped to org-tcs)
INSERT IGNORE INTO `leads_contacts` (`id`, `org_id`, `name`, `phone_number`, `company`, `title`, `open_deal_value`, `last_contacted`, `crm_account_id`) VALUES
('lead-1', 'org-tcs', 'Dr. Ramesh Patel', '+91 98201 45892', 'Apollo Health Systems', 'Chief Medical Director', 72000.00, 'Today, 11:30 AM', 'RV360-ACC-01'),
('lead-2', 'org-tcs', 'Vikram Singhania', '+91 99887 76655', 'Singhania Logistics Ltd', 'VP Supply Chain', 54000.00, 'Yesterday', 'RV360-ACC-02'),
('lead-3', 'org-tcs', 'Deepika Padukone', '+91 98111 22334', 'Kaabil Media & Entertainment', 'Operations Head', 36000.00, '2 days ago', 'RV360-ACC-03'),
('lead-4', 'org-tcs', 'Anand Mahindra', '+91 98222 33445', 'Mahindra Tech Park', 'Procurement Director', 120000.00, '3 days ago', 'RV360-ACC-04');

-- Sales Reps
INSERT IGNORE INTO `sales_reps` (`id`, `org_id`, `name`, `email`, `avatar`, `calls_today`, `talk_time`, `sentiment_score`, `pipeline_attributed`, `status`) VALUES
('rep-1', 'org-tcs', 'Rajesh Kumar', 'rajesh.kumar@tcs.in', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&auto=format&fit=crop&q=80', 28, '3h 12m', 94, 185000.00, 'active'),
('rep-2', 'org-tcs', 'Priya Sharma', 'priya.sharma@tcs.in', 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=120&auto=format&fit=crop&q=80', 22, '2h 45m', 89, 142000.00, 'active'),
('rep-3', 'org-tcs', 'Amitabh Bachchan', 'amitabh@tcs.in', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120&auto=format&fit=crop&q=80', 16, '1h 58m', 86, 98000.00, 'active');

COMMIT;
SET FOREIGN_KEY_CHECKS = 1;
