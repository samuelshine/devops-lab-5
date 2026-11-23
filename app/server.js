// Pod Pulse: a tiny web app that reports which Kubernetes pod served each request.
// No npm dependencies, only Node's built-in modules.
const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');

const PORT = Number(process.env.PORT || 3000);
const VERSION = process.env.APP_VERSION || 'dev';
const POD = process.env.POD_NAME || os.hostname();
const NODE = process.env.NODE_NAME || 'local';
const POD_IP = process.env.POD_IP || '127.0.0.1';
const NAMESPACE = process.env.POD_NAMESPACE || 'default';
const GREETING = process.env.GREETING || 'Hello from Kubernetes';
const STARTUP_DELAY_MS = Number(process.env.STARTUP_DELAY_MS || 3000);
// Version 3.0.0-bad is built with BROKEN=true so its readiness probe always fails.
const BROKEN = process.env.BROKEN === 'true';

const started = Date.now();
let ready = false;
let shuttingDown = false;
let served = 0;

const page = fs.readFileSync(path.join(__dirname, 'public', 'index.html'), 'utf8');

function send(res, status, body, type = 'application/json') {
  res.writeHead(status, {
    'Content-Type': type,
    'Cache-Control': 'no-store',
    // Close the TCP connection after each API reply so the Service can pick a
    // different pod for the next request instead of reusing one keep-alive socket.
    Connection: 'close',
  });
  res.end(typeof body === 'string' ? body : JSON.stringify(body));
}

function info() {
  return {
    pod: POD,
    node: NODE,
    podIP: POD_IP,
    namespace: NAMESPACE,
    version: VERSION,
    greeting: GREETING,
    uptimeSec: Math.round((Date.now() - started) / 1000),
    served,
    time: new Date().toISOString(),
  };
}

// Busy-loop the CPU for `ms` milliseconds. Used to drive the HorizontalPodAutoscaler.
function burn(ms) {
  const end = Date.now() + ms;
  let x = 0;
  while (Date.now() < end) x += Math.sqrt(Math.random() * 1e6);
  return x;
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://x');
  switch (url.pathname) {
    case '/':
      return send(res, 200, page.replaceAll('__VERSION__', VERSION), 'text/html; charset=utf-8');
    case '/api/info':
      served++;
      return send(res, 200, info());
    case '/api/load': {
      const ms = Math.min(Number(url.searchParams.get('ms') || 200), 2000);
      burn(ms);
      served++;
      return send(res, 200, { pod: POD, version: VERSION, burnedMs: ms });
    }
    case '/healthz':
      return send(res, 200, { status: 'alive', pod: POD });
    case '/readyz':
      if (BROKEN) return send(res, 503, { status: 'broken build', pod: POD });
      if (!ready || shuttingDown) return send(res, 503, { status: 'not ready', pod: POD });
      return send(res, 200, { status: 'ready', pod: POD });
    default:
      return send(res, 404, { error: 'not found' });
  }
});

server.listen(PORT, () => {
  console.log(`pod-pulse ${VERSION} listening on ${PORT} (pod ${POD}, node ${NODE})`);
  // Simulate warm-up work (cache loading etc.) before the pod accepts traffic.
  setTimeout(() => {
    ready = true;
    console.log(`pod-pulse ${VERSION} is ready`);
  }, STARTUP_DELAY_MS);
});

// On SIGTERM, fail readiness first so the endpoint is removed, then drain and exit.
process.on('SIGTERM', () => {
  console.log('SIGTERM received, draining connections');
  shuttingDown = true;
  setTimeout(() => server.close(() => process.exit(0)), 4000);
});
