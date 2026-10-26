const { execSync } = require('child_process');
const http = require('http');
const fs = require('fs');
const path = require('path');

const ADB = '/Users/makes360team/Library/Android/sdk/platform-tools/adb';
const DEVICE = 'R9ZY5097D2N';
const LOCAL_DB_PULL = path.join(__dirname, 'phone_sales_track.db');
const TEMP_REC_DIR = path.join(__dirname, 'temp_recordings');
if (!fs.existsSync(TEMP_REC_DIR)) fs.mkdirSync(TEMP_REC_DIR, { recursive: true });

async function postJson(endpoint, data) {
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify(data);
    const req = http.request({
      hostname: 'localhost',
      port: 8080,
      path: endpoint,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData),
        'X-Sales-Track-Token': 'local_dev_token_sales_track_360'
      }
    }, res => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(body));
        } catch (_) {
          resolve({ raw: body });
        }
      });
    });
    req.on('error', reject);
    req.write(postData);
    req.end();
  });
}

async function uploadRecording(uid, filePath) {
  return new Promise((resolve, reject) => {
    if (!fs.existsSync(filePath)) {
      return resolve({ success: false, error: 'File not found locally' });
    }
    const boundary = '----SalesTrackFormBoundary' + Math.random().toString(16).slice(2);
    const fileData = fs.readFileSync(filePath);
    const filename = path.basename(filePath);

    const part1 = Buffer.from(
      `--${boundary}\r\nContent-Disposition: form-data; name="uid"\r\n\r\n${uid}\r\n` +
      `--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="${filename}"\r\nContent-Type: audio/mp4\r\n\r\n`
    );
    const part2 = Buffer.from(`\r\n--${boundary}--\r\n`);
    const fullBody = Buffer.concat([part1, fileData, part2]);

    const req = http.request({
      hostname: 'localhost',
      port: 8080,
      path: '/mks_sales_track/api/v1/recording',
      method: 'POST',
      headers: {
        'Content-Type': `multipart/form-data; boundary=${boundary}`,
        'Content-Length': fullBody.length,
        'X-Sales-Track-Token': 'local_dev_token_sales_track_360'
      }
    }, res => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(body));
        } catch (_) {
          resolve({ raw: body });
        }
      });
    });
    req.on('error', reject);
    req.write(fullBody);
    req.end();
  });
}

async function main() {
  console.log('===========================================================');
  console.log(' STEP 1: PULLING LATEST LOCAL DATABASE FROM SAMSUNG PHONE');
  console.log('===========================================================');

  try {
    execSync(`${ADB} -s ${DEVICE} shell "run-as com.makes360.salestrack.sales_track_crm cp databases/sales_track_local.db /sdcard/sales_track_local.db"`);
    execSync(`${ADB} -s ${DEVICE} pull /sdcard/sales_track_local.db "${LOCAL_DB_PULL}"`);
    console.log(`✓ Pulled SQLite database: ${LOCAL_DB_PULL} (${fs.statSync(LOCAL_DB_PULL).size} bytes)`);
  } catch (e) {
    console.error('Failed to pull db via run-as, attempting fallback /tmp/sales_track_local.db...');
    if (fs.existsSync('/tmp/sales_track_local.db')) {
      fs.copyFileSync('/tmp/sales_track_local.db', LOCAL_DB_PULL);
    }
  }

  console.log('\n===========================================================');
  console.log(' STEP 2: EXTRACTING ALL LOCAL TELEMETRY EVENTS');
  console.log('===========================================================');

  // Query events using sqlite3 CLI
  const query = `sqlite3 -json "${LOCAL_DB_PULL}" "SELECT uid, kind, time, direction, number, name, sim, duration, recording, media, app, text, source, recording_path FROM events ORDER BY time DESC;"`;
  const rawEvents = execSync(query, { encoding: 'utf8', maxBuffer: 50 * 1024 * 1024 });
  const events = JSON.parse(rawEvents);

  const calls = events.filter(e => e.kind === 'call');
  const waCalls = events.filter(e => e.kind === 'whatsapp_call');
  const sms = events.filter(e => e.kind === 'sms');
  const waMsgs = events.filter(e => e.kind === 'whatsapp_message');
  const recordingsToUpload = events.filter(e => e.recording_path && e.recording_path.trim().length > 0);

  console.log(`Total Events Found:       ${events.length}`);
  console.log(` - Phone Calls:           ${calls.length}`);
  console.log(` - WhatsApp Calls:        ${waCalls.length}`);
  console.log(` - SMS Messages:          ${sms.length}`);
  console.log(` - WhatsApp Messages:     ${waMsgs.length}`);
  console.log(` - Audio Recordings Path: ${recordingsToUpload.length}`);

  console.log('\n===========================================================');
  console.log(' STEP 3: SYNCING EVENTS TO LOCAL SERVER IN BATCHES OF 50');
  console.log('===========================================================');

  const BATCH_SIZE = 50;
  let syncedCount = 0;

  for (let i = 0; i < events.length; i += BATCH_SIZE) {
    const chunk = events.slice(i, i + BATCH_SIZE).map(e => ({
      uid: e.uid,
      kind: e.kind,
      time: e.time,
      direction: e.direction,
      number: e.number,
      name: e.name || '',
      sim: e.sim || 1,
      duration: e.duration || 0,
      recording: e.recording === 1 || Boolean(e.recording_path),
      media: e.media || undefined,
      app: e.app || undefined,
      text: e.text || undefined,
      source: e.source || 'auto'
    }));

    const res = await postJson('/mks_sales_track/api/v1/sync', { events: chunk });
    syncedCount += (res.stored ? res.stored.length : chunk.length);
    const progress = Math.min(100, Math.round((syncedCount / events.length) * 100));
    process.stdout.write(`\rUploading events: ${syncedCount}/${events.length} [${progress}%] - Batch ${Math.floor(i / BATCH_SIZE) + 1}/${Math.ceil(events.length / BATCH_SIZE)}`);
  }
  console.log('\n✓ All events successfully synced to local backend server!');

  console.log('\n===========================================================');
  console.log(' STEP 4: PULLING & UPLOADING AUDIO CALL RECORDINGS');
  console.log('===========================================================');

  let uploadedRecs = 0;
  for (let i = 0; i < recordingsToUpload.length; i++) {
    const rec = recordingsToUpload[i];
    const remotePath = rec.recording_path;
    const localFile = path.join(TEMP_REC_DIR, `rec_${rec.uid}.m4a`);

    process.stdout.write(`[${i + 1}/${recordingsToUpload.length}] Pulling: ${path.basename(remotePath)}... `);

    try {
      execSync(`${ADB} -s ${DEVICE} pull "${remotePath}" "${localFile}"`, { stdio: 'pipe' });
      const upRes = await uploadRecording(rec.uid, localFile);
      if (upRes.success) {
        uploadedRecs++;
        console.log(`✓ Uploaded (${fs.statSync(localFile).size} bytes)`);
      } else {
        console.log(`✗ Upload failed: ${JSON.stringify(upRes)}`);
      }
    } catch (err) {
      console.log(`✗ ADB pull error (${err.message.split('\n')[0]})`);
    }
  }

  console.log(`\n✓ Uploaded ${uploadedRecs}/${recordingsToUpload.length} audio recordings to local backend!`);

  console.log('\n===========================================================');
  console.log(' SYNC COMPLETE SUMMARY');
  console.log('===========================================================');
  console.log(`✓ Events Synced:      ${syncedCount}`);
  console.log(`✓ Recordings Stored:  ${uploadedRecs}`);
  console.log(`✓ View Dashboard:     http://localhost:8080/`);
  console.log('===========================================================');
}

main().catch(err => {
  console.error('Fatal sync error:', err);
});
