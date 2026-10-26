const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');

const PORT = 8080;
const DATA_DIR = path.join(__dirname, 'data');
const RECORDINGS_DIR = path.join(__dirname, 'recordings');

// Ensure storage directories exist
if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
if (!fs.existsSync(RECORDINGS_DIR)) fs.mkdirSync(RECORDINGS_DIR, { recursive: true });

const EVENTS_FILE = path.join(DATA_DIR, 'events.json');
const OUTCOMES_FILE = path.join(DATA_DIR, 'outcomes.json');
const DEVICES_FILE = path.join(DATA_DIR, 'devices.json');

function readJsonFile(file, defaultVal) {
  try {
    if (fs.existsSync(file)) {
      return JSON.parse(fs.readFileSync(file, 'utf8'));
    }
  } catch (e) {
    console.error('Error reading ' + file + ':', e.message);
  }
  return defaultVal;
}

function writeJsonFile(file, data) {
  try {
    fs.writeFileSync(file, JSON.stringify(data, null, 2), 'utf8');
  } catch (e) {
    console.error('Error writing ' + file + ':', e.message);
  }
}

// In-memory caches backed by files
let eventsStore = readJsonFile(EVENTS_FILE, []);
let outcomesStore = readJsonFile(OUTCOMES_FILE, []);
let devicesStore = readJsonFile(DEVICES_FILE, [
  {
    id: 1,
    token: 'local_dev_token_sales_track_360',
    label: 'Samsung Local Device',
    staff_id: 1,
    status: 'active',
    track_sim: 0,
    created_at: new Date().toISOString()
  }
]);

const defaultConfig = {
  tracking_calls: true,
  tracking_recordings: true,
  tracking_whatsapp_calls: true,
  tracking_sms: true,
  track_sim: 0,
  sms_text: 'all',
  sync_minutes: 15,
  history_days: 90,
  batch_size: 50,
  recordings: {
    wifi_only: false,
    max_mb: 50,
    formats: ['m4a', 'mp3', 'aac', 'wav', 'ogg', 'amr', '3gp']
  },
  app: {
    min_version: ''
  },
  app_lock: {
    enabled: false,
    algorithm: 'pbkdf2',
    iterations: 100000,
    salt: '',
    hash: ''
  },
  outcomes: {
    ask: 'connected',
    mandatory: false,
    note_required: false,
    create_lead: true,
    list: [
      { key: 'interested', label: 'Interested', tone: 'success', follow_up: true, lead_status: 1 },
      { key: 'call_back', label: 'Call Back', tone: 'info', follow_up: true, lead_status: 0 },
      { key: 'not_interested', label: 'Not Interested', tone: 'muted', follow_up: false, lead_status: 0 },
      { key: 'wrong_number', label: 'Wrong Number', tone: 'danger', follow_up: false, lead_status: 0 },
      { key: 'no_answer', label: 'No Answer', tone: 'warning', follow_up: true, lead_status: 0 },
      { key: 'converted', label: 'Converted', tone: 'success', follow_up: false, lead_status: 2 }
    ],
    lead_statuses: [
      { id: 1, name: 'Lead', color: '#28B8DA' },
      { id: 2, name: 'Customer', color: '#10B981' }
    ]
  },
  version: '1.8.3'
};

function sendJson(res, statusCode, data) {
  res.writeHead(statusCode, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Sales-Track-Token'
  });
  res.end(JSON.stringify(data));
}

function parseMultipart(buffer, boundary) {
  const result = { fields: {}, files: {} };
  const boundaryBuffer = Buffer.from('--' + boundary);
  let start = 0;

  while ((start = buffer.indexOf(boundaryBuffer, start)) !== -1) {
    start += boundaryBuffer.length;
    if (buffer.slice(start, start + 2).toString() === '--') break; // end of parts
    if (buffer.slice(start, start + 2).toString() === '\r\n') start += 2;

    const nextBoundary = buffer.indexOf(boundaryBuffer, start);
    if (nextBoundary === -1) break;

    const partBuffer = buffer.slice(start, nextBoundary - 2);
    start = nextBoundary;

    const headerEnd = partBuffer.indexOf(Buffer.from('\r\n\r\n'));
    if (headerEnd === -1) continue;

    const headerStr = partBuffer.slice(0, headerEnd).toString('utf8');
    const bodyBuffer = partBuffer.slice(headerEnd + 4);

    const nameMatch = headerStr.match(/name="([^"]+)"/);
    const filenameMatch = headerStr.match(/filename="([^"]+)"/);

    if (nameMatch) {
      const fieldName = nameMatch[1];
      if (filenameMatch) {
        result.files[fieldName] = {
          filename: filenameMatch[1],
          data: bodyBuffer
        };
      } else {
        result.fields[fieldName] = bodyBuffer.toString('utf8').trim();
      }
    }
  }
  return result;
}

const server = http.createServer((req, res) => {
  // CORS Preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Sales-Track-Token'
    });
    res.end();
    return;
  }

  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const pathname = url.pathname;

  // Serve static recordings
  if (pathname.startsWith('/recordings/')) {
    const filename = path.basename(pathname);
    const filePath = path.join(RECORDINGS_DIR, filename);
    if (fs.existsSync(filePath)) {
      const stat = fs.statSync(filePath);
      res.writeHead(200, {
        'Content-Type': 'audio/mp4',
        'Content-Length': stat.size,
        'Access-Control-Allow-Origin': '*'
      });
      fs.createReadStream(filePath).pipe(res);
      return;
    } else {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('Recording not found');
      return;
    }
  }

  // Web Dashboard UI
  if (pathname === '/' || pathname === '/dashboard') {
    // Sort events newest first so recent WhatsApp messages appear immediately at the top
    const sortedEvents = eventsStore.slice().sort((a, b) => (Number(b.time) || 0) - (Number(a.time) || 0));
    const totalCalls = sortedEvents.filter(e => e.kind === 'call').length;
    const totalWaCalls = sortedEvents.filter(e => e.kind === 'whatsapp_call').length;
    const totalWaMsgs = sortedEvents.filter(e => e.kind === 'whatsapp_message').length;
    const totalSms = sortedEvents.filter(e => e.kind === 'sms').length;
    const recordingsCount = fs.readdirSync(RECORDINGS_DIR).length;

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Sales Track CRM - Local Server</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0B1120; color: #F8FAFC; margin: 0; padding: 24px; }
    h1 { color: #10B981; margin: 0 0 4px 0; font-size: 24px; font-weight: 700; }
    .badge { background: #1E293B; border: 1px solid #334155; padding: 5px 12px; border-radius: 9999px; font-size: 12px; color: #10B981; font-weight: 600; display: inline-flex; align-items: center; gap: 6px; }
    .badge-dot { width: 8px; height: 8px; background: #10B981; border-radius: 50%; display: inline-block; box-shadow: 0 0 8px #10B981; }
    .stats { display: flex; gap: 14px; margin: 20px 0; flex-wrap: wrap; }
    .card { background: #131E32; border: 1px solid #24344D; border-radius: 12px; padding: 16px 20px; min-width: 150px; cursor: pointer; transition: all 0.2s ease; flex: 1; }
    .card:hover { border-color: #10B981; transform: translateY(-2px); box-shadow: 0 8px 20px rgba(0,0,0,0.3); }
    .card.active { border-color: #10B981; background: #182842; }
    .card-label { font-size: 13px; color: #94A3B8; font-weight: 500; }
    .card-val { font-size: 28px; font-weight: 800; margin-top: 6px; }
    .tabs { display: flex; gap: 8px; margin: 20px 0 12px 0; border-bottom: 1px solid #1E293B; padding-bottom: 12px; flex-wrap: wrap; }
    .tab-btn { background: #131E32; color: #94A3B8; border: 1px solid #24344D; border-radius: 8px; padding: 8px 16px; font-size: 13px; font-weight: 600; cursor: pointer; transition: all 0.15s; }
    .tab-btn:hover { color: #fff; background: #1E2F4A; }
    .tab-btn.active { background: #10B981; color: #042F2E; border-color: #10B981; font-weight: 700; box-shadow: 0 2px 8px rgba(16,185,129,0.3); }
    .search-box { background: #131E32; border: 1px solid #24344D; color: #fff; padding: 10px 16px; border-radius: 8px; font-size: 13px; width: 340px; max-width: 100%; box-sizing: border-box; }
    .search-box:focus { outline: none; border-color: #10B981; box-shadow: 0 0 0 2px rgba(16,185,129,0.2); }
    .filter-info { font-size: 13px; color: #94A3B8; margin-top: 10px; display: flex; align-items: center; justify-content: space-between; }
    table { width: 100%; border-collapse: collapse; margin-top: 12px; background: #131E32; border-radius: 12px; overflow: hidden; border: 1px solid #24344D; }
    th, td { padding: 12px 16px; text-align: left; border-bottom: 1px solid #1E293B; font-size: 13px; vertical-align: middle; }
    th { background: #0B1120; color: #94A3B8; text-transform: uppercase; font-size: 11px; letter-spacing: 0.5px; font-weight: 600; }
    tr:hover td { background: #182842; }
    .tag { padding: 3px 8px; border-radius: 6px; font-size: 11px; font-weight: 700; display: inline-flex; align-items: center; gap: 4px; }
    .tag-call { background: rgba(56, 189, 248, 0.15); color: #38BDF8; border: 1px solid rgba(56, 189, 248, 0.3); }
    .tag-wacall { background: rgba(37, 211, 102, 0.15); color: #25D366; border: 1px solid rgba(37, 211, 102, 0.3); }
    .tag-wamsg { background: rgba(16, 185, 129, 0.2); color: #34D399; border: 1px solid rgba(16, 185, 129, 0.4); }
    .tag-sms { background: rgba(245, 158, 11, 0.15); color: #F59E0B; border: 1px solid rgba(245, 158, 11, 0.3); }
    .btn { background: #10B981; color: #042F2E; font-weight: 700; padding: 8px 16px; border-radius: 8px; border: none; cursor: pointer; text-decoration: none; display: inline-block; font-size: 13px; }
    audio { height: 28px; width: 180px; vertical-align: middle; }
    .msg-preview { max-width: 440px; white-space: pre-wrap; word-break: break-word; color: #E2E8F0; background: #0B1828; padding: 8px 12px; border-radius: 8px; border-left: 3px solid #10B981; font-size: 12.5px; line-height: 1.4; }
    .msg-preview.sms { border-left-color: #F59E0B; background: #1C1917; }
    .app-source { font-size: 11px; color: #64748B; margin-top: 2px; }
  </style>
</head>
<body>
  <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px;">
    <div>
      <h1>Sales Track CRM &bull; Local Control Center</h1>
      <p style="color: #94A3B8; margin: 4px 0 0 0; font-size: 13px;">mks_sales_track v1.8.3 API &bull; Active Port ${PORT} &bull; Samsung Device Synced</p>
    </div>
    <div style="display: flex; gap: 10px; align-items: center;">
      <span class="badge"><span class="badge-dot"></span> Live Sync Server Active</span>
      <a href="/" class="btn" style="background: #24344D; color: #fff;">Refresh</a>
    </div>
  </div>

  <div class="stats">
    <div class="card" id="card-whatsapp_message" onclick="filterKind('whatsapp_message')">
      <div class="card-label">WhatsApp Messages</div>
      <div class="card-val" style="color: #34D399;">${totalWaMsgs}</div>
    </div>
    <div class="card" id="card-call" onclick="filterKind('call')">
      <div class="card-label">Dialer Calls</div>
      <div class="card-val" style="color: #38BDF8;">${totalCalls}</div>
    </div>
    <div class="card" id="card-whatsapp_call" onclick="filterKind('whatsapp_call')">
      <div class="card-label">WhatsApp Calls</div>
      <div class="card-val" style="color: #25D366;">${totalWaCalls}</div>
    </div>
    <div class="card" id="card-sms" onclick="filterKind('sms')">
      <div class="card-label">SMS Messages</div>
      <div class="card-val" style="color: #F59E0B;">${totalSms}</div>
    </div>
    <div class="card" id="card-recording" onclick="filterKind('recording')">
      <div class="card-label">Audio Recordings</div>
      <div class="card-val" style="color: #A78BFA;">${recordingsCount}</div>
    </div>
  </div>

  <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px; margin-top: 20px;">
    <div class="tabs" style="border: none; margin: 0; padding: 0;">
      <button class="tab-btn active" id="tab-all" onclick="filterKind('all')">All Activity (${sortedEvents.length})</button>
      <button class="tab-btn" id="tab-whatsapp_message" onclick="filterKind('whatsapp_message')">WhatsApp Messages (${totalWaMsgs})</button>
      <button class="tab-btn" id="tab-call" onclick="filterKind('call')">Calls (${totalCalls})</button>
      <button class="tab-btn" id="tab-whatsapp_call" onclick="filterKind('whatsapp_call')">WhatsApp Calls (${totalWaCalls})</button>
      <button class="tab-btn" id="tab-sms" onclick="filterKind('sms')">SMS (${totalSms})</button>
      <button class="tab-btn" id="tab-recording" onclick="filterKind('recording')">Recordings (${recordingsCount})</button>
    </div>
    <input type="text" id="search-input" class="search-box" placeholder="Search number, contact name, or message text..." oninput="handleSearch()">
  </div>

  <div class="filter-info">
    <div id="filter-status-text">Showing latest activity</div>
    <div id="filter-count-badge" style="color: #10B981; font-weight: 600;"></div>
  </div>

  <table>
    <thead>
      <tr>
        <th style="width: 140px;">Type / App</th>
        <th style="width: 160px;">Phone / Channel</th>
        <th style="width: 210px;">Contact / Sender</th>
        <th style="width: 90px;">Direction</th>
        <th>Message Content / Duration</th>
        <th style="width: 150px;">Timestamp</th>
        <th style="width: 190px;">Recording</th>
      </tr>
    </thead>
    <tbody id="events-tbody">
      <!-- Injected via JavaScript below -->
    </tbody>
  </table>

  <script>
    const allEvents = ${JSON.stringify(sortedEvents)};
    const recordingsList = ${JSON.stringify(fs.readdirSync(RECORDINGS_DIR))};
    let currentKind = 'all';
    let searchQuery = '';

    function getTag(kind, app) {
      if (kind === 'whatsapp_message') {
        const isBiz = app === 'com.whatsapp.w4b';
        return '<span class="tag tag-wamsg">WA Msg' + (isBiz ? ' (Biz)' : '') + '</span>';
      }
      if (kind === 'whatsapp_call') {
        return '<span class="tag tag-wacall">WhatsApp Call</span>';
      }
      if (kind === 'sms') {
        return '<span class="tag tag-sms">SMS</span>';
      }
      return '<span class="tag tag-call">Phone Call</span>';
    }

    function renderRows() {
      const tbody = document.getElementById('events-tbody');
      const q = searchQuery.toLowerCase().trim();

      const filtered = allEvents.filter(e => {
        if (currentKind === 'recording') {
          if (!recordingsList.some(f => f.startsWith(e.uid))) return false;
        } else if (currentKind !== 'all') {
          if (e.kind !== currentKind) return false;
        }

        if (q) {
          const matchNum = (e.number || '').toLowerCase().includes(q);
          const matchName = (e.name || '').toLowerCase().includes(q);
          const matchText = (e.text || '').toLowerCase().includes(q);
          if (!matchNum && !matchName && !matchText) return false;
        }
        return true;
      });

      const countBadge = document.getElementById('filter-count-badge');
      const statusText = document.getElementById('filter-status-text');
      
      const kindLabel = currentKind === 'all' ? 'All Activity Events' :
                        currentKind === 'whatsapp_message' ? 'WhatsApp Messages' :
                        currentKind === 'whatsapp_call' ? 'WhatsApp Calls' :
                        currentKind === 'call' ? 'Dialer Calls' :
                        currentKind === 'sms' ? 'SMS Messages' : 'Audio Recordings';

      statusText.textContent = 'Filtered: ' + kindLabel + (q ? ' matching "' + q + '"' : '');
      countBadge.textContent = filtered.length + ' event' + (filtered.length === 1 ? '' : 's');

      if (filtered.length === 0) {
        tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; color:#64748B; padding:36px; font-size:14px;">No events found matching your filter criteria.</td></tr>';
        return;
      }

      // Display up to 500 rows
      tbody.innerHTML = filtered.slice(0, 500).map(e => {
        const d = new Date(e.time);
        const timeStr = d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) + ' &bull; ' + d.toLocaleDateString();
        const audioFile = recordingsList.find(f => f.startsWith(e.uid));
        const audioHtml = audioFile 
          ? '<audio controls src="/recordings/' + audioFile + '"></audio>'
          : (e.recording ? '<span style="color:#F59E0B; font-size:11px;">Audio Pending</span>' : '<span style="color:#64748B;">None</span>');

        let content = '';
        if (e.kind === 'whatsapp_message') {
          content = '<div class="msg-preview">' + (e.text || '<i style="color:#64748B;">(empty message)</i>') + '</div>';
        } else if (e.kind === 'sms') {
          content = '<div class="msg-preview sms">' + (e.text || '<i style="color:#64748B;">(empty SMS)</i>') + '</div>';
        } else {
          content = e.duration > 0 ? '<b>' + Math.floor(e.duration / 60) + 'm ' + (e.duration % 60) + 's</b>' : '<span style="color:#94A3B8;">0s (Missed / Unanswered)</span>';
        }

        let phoneCol = e.number;
        if (!phoneCol || phoneCol.trim() === '') {
          if (e.kind === 'whatsapp_message' || e.kind === 'whatsapp_call') {
            phoneCol = '<span style="color:#25D366; font-weight:600; font-size:12px;">' + 
              (e.app === 'com.whatsapp.w4b' ? 'WhatsApp Business' : 'WhatsApp') + '</span>';
          } else {
            phoneCol = '<span style="color:#64748B;">-</span>';
          }
        } else {
          phoneCol = '<b>' + phoneCol + '</b>';
        }

        return '<tr>' +
          '<td>' + getTag(e.kind, e.app) + '</td>' +
          '<td>' + phoneCol + '</td>' +
          '<td><b>' + (e.name || '-') + '</b></td>' +
          '<td><span style="text-transform: capitalize; color:#94A3B8; font-size:12px;">' + (e.direction || 'incoming') + '</span></td>' +
          '<td>' + content + '</td>' +
          '<td style="color:#94A3B8; font-size:12px; white-space:nowrap;">' + timeStr + '</td>' +
          '<td>' + audioHtml + '</td>' +
        '</tr>';
      }).join('');
    }

    function filterKind(kind) {
      currentKind = kind;
      document.querySelectorAll('.tab-btn').forEach(btn => btn.classList.remove('active'));
      const activeBtn = document.getElementById('tab-' + kind);
      if (activeBtn) activeBtn.classList.add('active');

      document.querySelectorAll('.card').forEach(c => c.classList.remove('active'));
      const activeCard = document.getElementById('card-' + kind);
      if (activeCard) activeCard.classList.add('active');

      if (window.location.hash !== '#' + kind) {
        history.replaceState(null, '', '#' + kind);
      }
      renderRows();
    }

    function handleSearch() {
      searchQuery = document.getElementById('search-input').value;
      renderRows();
    }

    // Check URL hash or query param on load
    window.addEventListener('DOMContentLoaded', () => {
      const hash = window.location.hash.replace('#', '');
      const urlParams = new URLSearchParams(window.location.search);
      const tabParam = urlParams.get('tab') || hash;
      if (tabParam && ['whatsapp_message', 'call', 'whatsapp_call', 'sms', 'recording'].includes(tabParam)) {
        filterKind(tabParam);
      } else {
        renderRows();
      }
    });
  </script>
</body>
</html>`;
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(html);
    return;
  }

  // --- API ROUTES (/mks_sales_track/api/v1/) ---
  if (pathname.includes('/api/v1/ping')) {
    sendJson(res, 200, {
      success: true,
      name: 'Sales Track',
      api: 'v1',
      module_version: '1.8.3',
      pairing: true,
      server_time: Date.now()
    });
    return;
  }

  if (pathname.includes('/api/v1/pair')) {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      let data = {};
      try { data = JSON.parse(body); } catch (_) {}
      console.log('Pairing request received with code:', data.code, data.device);
      const token = 'local_dev_token_' + Date.now();
      devicesStore[0].token = token;
      writeJsonFile(DEVICES_FILE, devicesStore);

      sendJson(res, 200, {
        success: true,
        token: token,
        device: { id: 1, label: 'Local Development Phone', status: 'active' },
        staff: { id: 1, name: 'Local Representative', email: 'sales@makes360.com' },
        config: defaultConfig,
        update_required: false,
        commands: []
      });
    });
    return;
  }

  if (pathname.includes('/api/v1/config')) {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      sendJson(res, 200, {
        success: true,
        device: { id: 1, label: 'Local Development Phone', status: 'active' },
        staff: { id: 1, name: 'Local Representative' },
        config: defaultConfig,
        update_required: false,
        commands: []
      });
    });
    return;
  }

  if (pathname.includes('/api/v1/sync')) {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      let data = {};
      try { data = JSON.parse(body); } catch (_) {}
      const events = data.events || [];
      console.log(`[SYNC] Ingesting ${events.length} telemetry events...`);

      const storedUids = [];
      const recordingsWanted = [];

      for (const ev of events) {
        if (!ev.uid) continue;
        storedUids.push(ev.uid);
        if (ev.recording) recordingsWanted.push(ev.uid);

        const existingIdx = eventsStore.findIndex(e => e.uid === ev.uid);
        if (existingIdx >= 0) {
          eventsStore[existingIdx] = { ...eventsStore[existingIdx], ...ev };
        } else {
          eventsStore.unshift(ev);
        }
      }

      writeJsonFile(EVENTS_FILE, eventsStore);

      sendJson(res, 200, {
        success: true,
        stored: storedUids,
        duplicate: [],
        skipped: [],
        rejected: [],
        recordings_wanted: recordingsWanted,
        config_version: '1.8.3'
      });
    });
    return;
  }

  if (pathname.includes('/api/v1/recording')) {
    const chunks = [];
    req.on('data', chunk => chunks.push(chunk));
    req.on('end', () => {
      const buffer = Buffer.concat(chunks);
      const contentType = req.headers['content-type'] || '';
      const boundaryMatch = contentType.match(/boundary=(?:"([^"]+)"|([^;]+))/i);
      
      let uid = '';
      if (boundaryMatch) {
        const boundary = boundaryMatch[1] || boundaryMatch[2];
        const parsed = parseMultipart(buffer, boundary);
        uid = parsed.fields['uid'] || '';
        const file = parsed.files['file'];
        if (uid && file) {
          const ext = path.extname(file.filename) || '.m4a';
          const destPath = path.join(RECORDINGS_DIR, `${uid}${ext}`);
          fs.writeFileSync(destPath, file.data);
          console.log(`[RECORDING] Saved audio recording for UID ${uid} (${file.data.length} bytes) to ${destPath}`);
        }
      }

      sendJson(res, 200, {
        success: true,
        uid: uid,
        status: 'stored'
      });
    });
    return;
  }

  if (pathname.includes('/api/v1/outcome')) {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      let data = {};
      try { data = JSON.parse(body); } catch (_) {}
      console.log('[OUTCOME] Received call outcome:', data);
      outcomesStore.unshift(data);
      writeJsonFile(OUTCOMES_FILE, outcomesStore);

      sendJson(res, 200, {
        success: true,
        uid: data.uid || ''
      });
    });
    return;
  }

  if (pathname.includes('/api/v1/lists')) {
    sendJson(res, 200, { success: true, lists: [] });
    return;
  }

  if (pathname.includes('/api/v1/directory')) {
    sendJson(res, 200, { success: true, directory: [] });
    return;
  }

  // Fallback 404
  sendJson(res, 404, { success: false, error: 'Endpoint not found' });
});

server.listen(PORT, '0.0.0.0', () => {
  const interfaces = os.networkInterfaces();
  const addresses = [];
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) {
        addresses.push(iface.address);
      }
    }
  }

  console.log('====================================================');
  console.log(` Sales Track CRM Local Backend running on port ${PORT}`);
  console.log('====================================================');
  console.log(` Web Dashboard: http://localhost:${PORT}/`);
  console.log(` API Endpoint:   http://localhost:${PORT}/mks_sales_track/api/v1/`);
  addresses.forEach(ip => {
    console.log(` LAN API:        http://${ip}:${PORT}/mks_sales_track/api/v1/`);
  });
  console.log('====================================================');
});
