// Pure Node.js Smee relay — no npm packages, no experimental flags.
// Uses built-in `https` for the SSE stream and built-in `fetch` for forwarding.
const https = require('https');

const SMEE_URL = process.env.SMEE_URL;
const TARGET   = process.env.TARGET || 'http://jenkins:8080/github-webhook/';

if (!SMEE_URL) { console.error('SMEE_URL is required'); process.exit(1); }

const SKIP = new Set(['host', 'content-length', 'transfer-encoding', 'connection']);

async function relay(payload) {
  const headers = {};
  for (const [k, v] of Object.entries(payload)) {
    if (k === 'body' || k === 'query') continue;
    if (typeof v !== 'string') continue;
    if (SKIP.has(k.toLowerCase())) continue;
    headers[k] = v;
  }

  // Smee.io sends periodic keep-alive events with no GitHub headers — skip them.
  if (!headers['x-github-event']) return;

  // Guarantee the header Jenkins' GitHub plugin requires.
  if (!headers['content-type']) headers['content-type'] = 'application/json';

  // Smee stores form-encoded webhooks as { payload: "<json-string>" }.
  // Reconstruct the proper wire format based on Content-Type so Jenkins can parse it.
  let body;
  if (payload.body == null) {
    body = '';
  } else if (typeof payload.body === 'string') {
    body = payload.body;
  } else if ((headers['content-type'] || '').includes('x-www-form-urlencoded')) {
    body = new URLSearchParams(
      Object.entries(payload.body).map(([k, v]) => [k, typeof v === 'string' ? v : JSON.stringify(v)])
    ).toString();
  } else {
    body = JSON.stringify(payload.body);
  }

  try {
    const res = await fetch(TARGET, { method: 'POST', headers, body });
    // Log the response body on non-200 so we can see what Jenkins says.
    if (res.status === 200) {
      console.log(`POST ${TARGET} - ${res.status} [${headers['x-github-event']}]`);
    } else {
      const text = await res.text();
      console.log(`POST ${TARGET} - ${res.status} [${headers['x-github-event']}]: ${text.slice(0, 300)}`);
    }
  } catch (e) {
    console.error('Relay error:', e.message);
  }
}

function connect() {
  console.log(`Connected to ${SMEE_URL}`);
  console.log(`Forwarding ${SMEE_URL} to ${TARGET}`);

  const req = https.request(SMEE_URL, {
    headers: { Accept: 'text/event-stream', 'Cache-Control': 'no-cache' },
  }, (res) => {
    let buf = '';

    res.setEncoding('utf8');
    res.on('data', (chunk) => {
      buf += chunk;
      const blocks = buf.split('\n\n');
      buf = blocks.pop(); // keep the trailing incomplete event

      for (const block of blocks) {
        const line = block.split('\n').find(l => l.startsWith('data:'));
        if (!line) continue;
        const json = line.slice(5).trim();
        if (json === 'ping') continue;
        try { relay(JSON.parse(json)); } catch { /* ignore malformed events */ }
      }
    });

    res.on('end',   () => { console.log('SSE stream ended, reconnecting...'); setTimeout(connect, 2000); });
    res.on('error', (e) => { console.error('Stream error:', e.message); setTimeout(connect, 2000); });
  });

  req.on('error', (e) => { console.error('Request error:', e.message); setTimeout(connect, 2000); });
  req.end();
}

connect();
