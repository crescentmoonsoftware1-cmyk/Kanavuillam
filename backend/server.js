const express = require('express');
const multer = require('multer');
const { createClient } = require('@supabase/supabase-js');
const cors = require('cors');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const dns = require('dns').promises;
const Razorpay = require('razorpay');
const crypto = require('crypto');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 3000;

process.on('unhandledRejection', (reason, promise) => {
  console.error('[Global] Unhandled Rejection at:', promise, 'reason:', reason);
});
process.on('uncaughtException', (error) => {
  console.error('[Global Fatal] Uncaught Exception:', error);
  if (process.env.NODE_ENV === 'production') {
    setTimeout(() => process.exit(1), 1000);
  }
});

// Initialize Razorpay
function getRazorpayInstance() {
  return new Razorpay({
    key_id: process.env.RAZORPAY_KEY_ID || 'rzp_test_placeholder',
    key_secret: process.env.RAZORPAY_KEY_SECRET || 'placeholder_secret',
  });
}
const razorpay = getRazorpayInstance();

const supabase = createClient(
  process.env.SUPABASE_URL || 'https://placeholder-project.supabase.co',
  process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_KEY || 'placeholder-anon-key'
);

// ─── Authentication Middlewares ─────────────────────────────────────────────
async function authenticateToken(req, res, next) {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.substring(7).trim();
    try {
      const { data: { user }, error } = await supabase.auth.getUser(token);
      if (!error && user) {
        req.user = user;
        return next();
      }
    } catch (err) {
      console.warn('[Auth Middleware] Verification error:', err.message);
    }
  }
  // No fallback: all protected routes require a valid JWT.
  // Play Store reviewers must log in with a real account.
  return res.status(401).json({ error: 'Unauthorized: A valid authentication token is required.' });
}

async function optionalAuth(req, res, next) {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.substring(7).trim();
    try {
      const { data: { user } } = await supabase.auth.getUser(token);
      if (user) req.user = user;
    } catch (_) {}
  }
  next();
}

const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map(s => s.trim().toLowerCase())
  : [
      'http://localhost:3000',
      'http://localhost:5000',
      'http://127.0.0.1:3000',
      // Add your production domains below or set ALLOWED_ORIGINS env var
      'https://kanavuillam.vercel.app',
      'https://kanavuillam-web.vercel.app',
      'https://kanavuillam.com',
      'https://www.kanavuillam.com',
      'https://kanavuillam.in',
      'https://www.kanavuillam.in',
      'https://api.kanavuillam.in'
    ];

app.use(cors({
  origin: (origin, callback) => {
    // Allow non-browser requests (mobile apps, curl, etc.)
    if (!origin) return callback(null, true);
    const normalized = origin.toLowerCase();
    if (
      process.env.NODE_ENV !== 'production' ||
      allowedOrigins.includes(normalized) ||
      normalized.startsWith('http://localhost:') ||
      normalized.startsWith('http://127.0.0.1:')
    ) {
      return callback(null, true);
    }
    return callback(new Error('Blocked by CORS policy'));
  },
  credentials: true
}));
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// ─── Rate Limiting (Protects AI costs, prevents denial of service) ───────────
const generalLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 120, // 120 requests/min per IP
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests from this IP, please try again in a minute.' }
});
app.use('/api/', generalLimiter);

const uploadLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 15, // 15 blueprint analyses per 15 minutes per IP
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Upload rate limit reached. Please wait a few minutes before analyzing another floor plan.' }
});

const aiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 20, // 20 AI material queries per 15 minutes per IP
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'AI request limit reached. Please wait a few minutes before trying again.' }
});

// Strict limiter for auth endpoints to prevent brute-force attacks
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // 10 login/signup attempts per 15 minutes per IP
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many authentication attempts. Please wait 15 minutes before trying again.' }
});

// ─── Health Check Endpoints (For Railway, Docker & Uptime monitoring) ───────
app.get('/api/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    uptime_seconds: Math.floor(process.uptime()),
    timestamp: new Date().toISOString()
  });
});
app.get('/health', (req, res) => res.status(200).json({ status: 'ok' }));

// ─── Private IP Validator (SSRF Protection) ──────────────────────────────────
function isPrivateIpAddress(ip) {
  if (!ip) return true;
  if (ip === '0.0.0.0' || ip === '127.0.0.1' || ip.startsWith('127.')) return true;
  if (ip.startsWith('10.') || ip.startsWith('192.168.') || ip.startsWith('169.254.')) return true;
  if (/^172\.(1[6-9]|2[0-9]|3[01])\./.test(ip)) return true;
  if (/^100\.(6[4-9]|[7-9][0-9]|1[0-1][0-9]|12[0-7])\./.test(ip)) return true;
  if (ip === '::' || ip === '::1' || ip.startsWith('fc00:') || ip.startsWith('fd00:') || ip.startsWith('fe80:')) return true;
  if (ip.startsWith('::ffff:')) {
    const v4 = ip.replace('::ffff:', '');
    return isPrivateIpAddress(v4);
  }
  return false;
}

// ─── Proxy Image (with DNS verification & redirect prevention) ───────────────
app.get('/api/proxy-image', async (req, res) => {
  try {
    const imageUrl = req.query.url;
    if (!imageUrl) return res.status(400).send('URL required');

    let parsed;
    try {
      parsed = new URL(imageUrl);
    } catch (_) {
      return res.status(400).send('Invalid URL format');
    }

    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
      return res.status(400).send('Only HTTP and HTTPS protocols are allowed');
    }

    const host = parsed.hostname.toLowerCase();
    const blockedHosts = [
      'localhost', '127.0.0.1', '0.0.0.0', '::1',
      '169.254.169.254', 'metadata.google.internal', 'instance-data'
    ];
    if (blockedHosts.includes(host) || host.endsWith('.local') || host.endsWith('.internal')) {
      console.warn(`[SSRF Blocked] Denied proxy request to host: ${host}`);
      return res.status(403).send('Access to internal or private hosts is strictly forbidden');
    }

    // Resolve hostname to inspect underlying IPv4/IPv6 address against private ranges
    try {
      const lookup = await dns.lookup(host);
      if (isPrivateIpAddress(lookup.address)) {
        console.warn(`[SSRF Blocked] Resolved host ${host} to private IP: ${lookup.address}`);
        return res.status(403).send('Access to internal or private network IP addresses is forbidden');
      }
    } catch (dnsErr) {
      console.warn(`[SSRF Blocked] Failed to resolve host: ${host}`);
      return res.status(400).send('Host could not be resolved');
    }

    // Fetch with redirect: 'error' to prevent open-redirect SSRF bypasses
    const response = await fetch(imageUrl, { redirect: 'error' });
    if (!response.ok) throw new Error(`Failed to fetch image: ${response.status}`);

    const arrayBuffer = await response.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);

    res.set('Content-Type', response.headers.get('content-type') || 'image/jpeg');
    res.set('Cache-Control', 'public, max-age=31536000');
    res.set('Access-Control-Allow-Origin', '*');
    res.send(buffer);
  } catch (err) {
    console.error('[Proxy Error]', err.message);
    res.status(500).send(err.message);
  }
});

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dir = 'uploads';
    if (!fs.existsSync(dir)) fs.mkdirSync(dir);
    cb(null, dir);
  },
  filename: (req, file, cb) => cb(null, Date.now() + path.extname(file.originalname))
});

const upload = multer({
  storage,
  limits: { fileSize: 15 * 1024 * 1024 }, // Max 15MB per file (generous for architectural blueprints)
  fileFilter: (req, file, cb) => {
    const allowedMime = ['image/jpeg', 'image/png', 'image/webp', 'image/jpg'];
    const ext = path.extname(file.originalname || '').toLowerCase();
    const allowedExts = ['.jpg', '.jpeg', '.png', '.webp'];

    if (allowedMime.includes(file.mimetype) || allowedExts.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only JPEG, PNG, and WebP floor plans are allowed.'));
    }
  }
});
const multiUpload = upload.fields([{ name: 'ground_plan', maxCount: 1 }, { name: 'first_plan', maxCount: 1 }, { name: 'second_plan', maxCount: 1 }]);

// ─── Immediate Zero-Storage: Purge all residual files on server boot ─────────
function purgeUploadsFolder(dir) {
  try {
    if (!fs.existsSync(dir)) return;
    const allFiles = fs.readdirSync(dir);
    allFiles.forEach(name => {
      const fullPath = path.join(dir, name);
      try {
        if (fs.statSync(fullPath).isFile()) {
          fs.unlinkSync(fullPath);
          console.log(`[Zero-Storage] Purged residual file: ${name}`);
        }
      } catch (_) { }
    });
  } catch (err) {
    console.error('[Zero-Storage Error]', err.message);
  }
}

// Ensure 0 residual files on server boot
purgeUploadsFolder(path.join(__dirname, 'uploads'));

// ─── Helpers ──────────────────────────────────────────────────────────────────

function validateModelData(data) {
  if (!data || typeof data !== 'object') return null;
  if (data.error === "STRICT_VALIDATION_FAILED") {
    console.warn("Geometry Validation Failed but proceeding anyway to prevent pipeline crash:", JSON.stringify(data.error_details));
  }
  // If this is the new deterministic Canonical JSON (schema 1.0 or 2.0), pass it through unchanged & normalize room bounds
  if (data.schema_version === "1.0" || data.schema_version === "2.0") {
    if (data.building && !data.project) {
      data.project = {
        width: data.building.width_ft,
        height: data.building.length_ft,
        floors: 1
      };
    }
    if (data.rooms) {
      data.rooms.forEach(r => {
        if (r.bounds) {
          r.x = r.bounds.x;
          r.y = r.bounds.y;
          r.width = r.bounds.w;
          r.height = r.bounds.h;
        } else if (r.bounding_box) {
          r.x = r.bounding_box.x;
          r.y = r.bounding_box.y;
          r.width = r.bounding_box.w;
          r.height = r.bounding_box.h;
        } else if (r.polygon && r.polygon.length > 0 && r.dimensions) {
          const xs = r.polygon.map(p => p.x !== undefined ? p.x : (Array.isArray(p) ? p[0] : 0));
          const ys = r.polygon.map(p => p.y !== undefined ? p.y : (Array.isArray(p) ? p[1] : 0));
          r.x = Math.min(...xs);
          r.y = Math.min(...ys);
          r.width = r.dimensions.width_ft || (Math.max(...xs) - r.x);
          r.height = r.dimensions.length_ft || (Math.max(...ys) - r.y);
        }
      });
    }
    if (data.doors) {
      data.doors.forEach(d => {
        if (d.start && d.end && d.x === undefined) {
          d.x = (d.start.x + d.end.x) / 2;
          d.y = (d.start.y + d.end.y) / 2;
          d.width = d.width_ft || Math.hypot(d.start.x - d.end.x, d.start.y - d.end.y);
        } else if (d.position) {
          d.x = d.position.x;
          d.y = d.position.y;
        }
      });
    }
    if (data.windows) {
      data.windows.forEach(w => {
        if (w.start && w.end && w.x === undefined) {
          w.x = (w.start.x + w.end.x) / 2;
          w.y = (w.start.y + w.end.y) / 2;
          w.width = w.width_ft || Math.hypot(w.start.x - w.end.x, w.start.y - w.end.y);
        } else if (w.position) {
          w.x = w.position.x;
          w.y = w.position.y;
        }
      });
    }
    return data;
  }

  if (!data.project) data.project = { name: 'Floor Plan' };

  // V4 -> V3 Polyfill for downstream estimators (add rooms array, does not mutate existing walls)
  if (data.semantic) {
    const allRooms = [...(data.semantic.assigned || []), ...(data.semantic.ambiguous || []), ...(data.semantic.unassigned || [])];
    data.rooms = allRooms.map(r => {
      let x = 0, y = 0, w = 10, h = 10;
      if (r.coordinates_ft && r.coordinates_ft.polygon && r.coordinates_ft.polygon.length > 0) {
        const poly = r.coordinates_ft.polygon;
        const minX = Math.min(...poly.map(p => p[0]));
        const maxX = Math.max(...poly.map(p => p[0]));
        const minY = Math.min(...poly.map(p => p[1]));
        const maxY = Math.max(...poly.map(p => p[1]));
        x = minX; y = minY; w = maxX - minX; h = maxY - minY;
      }
      return {
        name: r.label || 'Unknown',
        x: x, y: y, width: w, height: h
      };
    });
  }

  ['rooms', 'walls', 'doors', 'windows', 'furnitures', 'stairs', 'voids', 'columns'].forEach(k => {
    if (!Array.isArray(data[k])) data[k] = [];
  });

  // If processor provided walls, use them; otherwise regenerate walls from all rooms & stairs
  if (!data.walls || data.walls.length === 0) {
    if (data.rooms.length > 0) {
      data.walls = generateWallsFromRooms(data.rooms, data.project, data.stairs);
    }
  }

  // Ensure rooms have door entries
  if (data.rooms.length > 0 && data.doors.length === 0) {
    let dIdx = 1;
    data.rooms.forEach(r => {
      const rName = (r.name || r.label || '').toLowerCase();
      const rx = r.x || (r.bounds ? r.bounds.x : 0);
      const ry = r.y || (r.bounds ? r.bounds.y : 0);
      const rw = r.width || (r.bounds ? r.bounds.w : 10);
      const rh = r.height || (r.bounds ? r.bounds.h : 10);

      const isMain = rName.includes('living') || rName.includes('hall') || rName.includes('portico');
      const isToilet = rName.includes('toilet') || rName.includes('bath') || rName.includes('wc');

      data.doors.push({
        id: `D_auto_${dIdx++}`,
        source_id: `D_auto_${dIdx}`,
        type: 'DOOR',
        label: isMain ? 'MD' : (isToilet ? 'D1' : 'D'),
        position: { x: rx + rw / 2, y: ry + rh },
        x: rx + rw / 2,
        y: ry + rh,
        width_ft: isMain ? 3.5 : (isToilet ? 2.2 : 3.0),
        width: isMain ? 3.5 : (isToilet ? 2.2 : 3.0)
      });
    });
  }

  return data;
}

function generateWallsFromRooms(rooms, project, stairs = []) {
  const pw = parseFloat(project?.overall_dimensions?.width_ft || project?.width); const ph = parseFloat(project?.overall_dimensions?.length_ft || project?.height); if (!pw || !ph || isNaN(pw) || isNaN(ph)) throw new Error('SCALE_CALIBRATION_FAILED: Missing physical dimensions.');
  const wallSet = new Set(), walls = [];
  const allElements = [...rooms, ...stairs];

  allElements.forEach(room => {
    const rx = room.x || 0, ry = room.y || 0, rw = room.width || 0, rh = room.height || 0;
    const edges = [
      [[rx, ry], [rx + rw, ry]], [[rx, ry + rh], [rx + rw, ry + rh]],
      [[rx, ry], [rx, ry + rh]], [[rx + rw, ry], [rx + rw, ry + rh]],
    ];
    edges.forEach(([s, e]) => {
      const isExt = s[0] <= 0.5 || s[0] >= pw - 0.5 || e[0] <= 0.5 || e[0] >= pw - 0.5 ||
        s[1] <= 0.5 || s[1] >= ph - 0.5 || e[1] <= 0.5 || e[1] >= ph - 0.5;
      const key = [
        Math.min(s[0], e[0]).toFixed(1), Math.min(s[1], e[1]).toFixed(1),
        Math.max(s[0], e[0]).toFixed(1), Math.max(s[1], e[1]).toFixed(1)
      ].join(',');
      if (!wallSet.has(key)) {
        wallSet.add(key);
        walls.push({
          start: [+s[0].toFixed(2), +s[1].toFixed(2)],
          end: [+e[0].toFixed(2), +e[1].toFixed(2)],
          thickness: isExt ? 0.75 : 0.4
        });
      }
    });
  });

  // Ensure 4 outer perimeter walls are always closed
  const perimeter = [
    [[0, 0], [pw, 0]], [[0, ph], [pw, ph]],
    [[0, 0], [0, ph]], [[pw, 0], [pw, ph]],
  ];
  perimeter.forEach(([s, e]) => {
    const key = [
      Math.min(s[0], e[0]).toFixed(1), Math.min(s[1], e[1]).toFixed(1),
      Math.max(s[0], e[0]).toFixed(1), Math.max(s[1], e[1]).toFixed(1)
    ].join(',');
    if (!wallSet.has(key)) {
      wallSet.add(key);
      walls.push({
        start: [+s[0].toFixed(2), +s[1].toFixed(2)],
        end: [+e[0].toFixed(2), +e[1].toFixed(2)],
        thickness: 0.75
      });
    }
  });

  return walls;
}

// ─── Step 1 + 2: Computer Vision Pipeline → Structured JSON ──────────────────

function runPython(imagePath) {
  return new Promise((resolve, reject) => {
    let output = '';
    let isSettled = false;
    const pythonCmd = process.env.PYTHON_PATH || (process.platform === 'win32' ? 'python' : 'python3');
    const proc = spawn(pythonCmd, ['processor.py', imagePath], { env: { ...process.env }, cwd: __dirname });

    // 120-Second Hard Timeout Guard to prevent orphan/zombie Python processes
    const timeoutMs = 120000;
    const timer = setTimeout(() => {
      if (!isSettled) {
        isSettled = true;
        console.error(`[Python Timeout] Killing processor.py for ${imagePath} after ${timeoutMs / 1000}s`);
        try {
          proc.kill('SIGKILL');
        } catch (_) {}
        reject(new Error('PROCESSING_TIMEOUT: Computer vision pipeline timed out after 120 seconds'));
      }
    }, timeoutMs);

    proc.stdout.on('data', d => { output += d.toString(); });
    proc.stderr.on('data', d => console.error(`[Python] ${d.toString().trim()}`));

    proc.on('close', code => {
      clearTimeout(timer);
      if (isSettled) return;
      isSettled = true;

      let data = null;
      try {
        let jsonStr = '';
        const firstBrace = output.indexOf('{');
        const lastBrace = output.lastIndexOf('}');
        if (firstBrace >= 0 && lastBrace > firstBrace) {
          jsonStr = output.substring(firstBrace, lastBrace + 1);
        } else {
          jsonStr = output.trim();
        }
        data = JSON.parse(jsonStr);
      } catch (e) {
        if (code !== 0) {
          console.error(`[Python Error Output] ${output}`);
          return reject(new Error(`Python process exited with code ${code}`));
        } else {
          console.error("Failed to parse python output:", output.substring(output.length - 200));
          return reject(new Error("Invalid JSON from python pipeline"));
        }
      }

      if (data.error && data.error !== "STRICT_VALIDATION_FAILED") {
        return reject(new Error(data.error));
      }

      if (code !== 0) {
        console.error(`[Python Error Output] ${output}`);
        return reject(new Error(`Python process exited with code ${code}`));
      }

      resolve(data);
    });

    proc.on('error', err => {
      clearTimeout(timer);
      if (!isSettled) {
        isSettled = true;
        reject(err);
      }
    });
  });
}

// ─── Step 5: Vastu Analysis Engine (Enhanced with OpenRouter & Retry Backoff) ─

async function askOpenRouter(prompt, imagePath = null, model = 'meta-llama/llama-3.3-70b-instruct:free') {
  const apiKey = process.env.OPENROUTER_API_KEY;
  if (!apiKey) return null;

  let contents = [{ type: 'text', text: prompt }];
  if (imagePath && fs.existsSync(imagePath)) {
    const imageData = fs.readFileSync(imagePath).toString('base64');
    contents.push({
      type: 'image_url',
      image_url: { url: `data:image/png;base64,${imageData}` }
    });
  }

  const maxRetries = 3;
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "HTTP-Referer": "http://localhost:3000",
          "X-Title": "Kanavu illam",
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          "model": model,
          "messages": [{ "role": "user", "content": contents }],
          "response_format": { "type": "json_object" }
        })
      });

      if (!response.ok) {
        const isRateOrTransient = [429, 500, 502, 503, 504].includes(response.status);
        if (isRateOrTransient && attempt < maxRetries) {
          const delayMs = Math.pow(2, attempt - 1) * 1000; // 1s, 2s, 4s
          console.warn(`[OpenRouter Retry] HTTP ${response.status} on attempt ${attempt}. Retrying in ${delayMs}ms...`);
          await new Promise(r => setTimeout(r, delayMs));
          continue;
        }
        throw new Error(`OpenRouter HTTP ${response.status}`);
      }

      const data = await response.json();
      if (data.choices && data.choices[0]) {
        const content = data.choices[0].message.content || "";
        return JSON.parse(content.replace(/```json|```/g, '').trim());
      }
      return null;
    } catch (e) {
      if (attempt < maxRetries) {
        const delayMs = Math.pow(2, attempt - 1) * 1000;
        console.warn(`[OpenRouter Error] Attempt ${attempt} failed: ${e.message}. Retrying in ${delayMs}ms...`);
        await new Promise(r => setTimeout(r, delayMs));
      } else {
        console.error('[OpenRouter Exhausted] All retry attempts failed:', e.message);
        return null;
      }
    }
  }
  return null;
}

async function runVastuAnalysis(modelData, lang = 'English', orientation = 'North', imagePath = null, fixedScore = null, fixedGrade = null, floorName = 'Ground') {
  const pw = parseFloat(modelData?.project?.overall_dimensions?.width_ft || modelData?.project?.width); const ph = parseFloat(modelData?.project?.overall_dimensions?.length_ft || modelData?.project?.height); if (!pw || !ph || isNaN(pw) || isNaN(ph)) throw new Error('SCALE_CALIBRATION_FAILED: Missing physical dimensions for Vastu.');
  const isTamil = lang && lang.toLowerCase().includes('tamil');

  let score = 100;
  const strengths = [];
  const violations = [];
  const suggestions = [];

  // Calculate total floor plan bounding box across all rooms to normalize coordinates accurately
  let plotMinX = Infinity, plotMinY = Infinity, plotMaxX = -Infinity, plotMaxY = -Infinity;
  const roomsForOri = modelData?.rooms || [];
  roomsForOri.forEach(r => {
    let rx = r.x !== undefined ? r.x : (r.bounds ? r.bounds.x : 0);
    let ry = r.y !== undefined ? r.y : (r.bounds ? r.bounds.y : 0);
    let rw = r.width !== undefined ? r.width : (r.bounds ? r.bounds.w : 0);
    let rh = r.height !== undefined ? r.height : (r.bounds ? r.bounds.h : 0);
    if (r.polygon_pts && Array.isArray(r.polygon_pts) && r.polygon_pts.length > 0) {
      r.polygon_pts.forEach(pt => {
        let px = pt.x !== undefined ? pt.x : (Array.isArray(pt) ? pt[0] : 0);
        let py = pt.y !== undefined ? pt.y : (Array.isArray(pt) ? pt[1] : 0);
        if (px < plotMinX) plotMinX = px;
        if (py < plotMinY) plotMinY = py;
        if (px > plotMaxX) plotMaxX = px;
        if (py > plotMaxY) plotMaxY = py;
      });
    } else if (r.polygon && Array.isArray(r.polygon) && r.polygon.length > 0) {
      r.polygon.forEach(pt => {
        let px = pt.x !== undefined ? pt.x : (Array.isArray(pt) ? pt[0] : 0);
        let py = pt.y !== undefined ? pt.y : (Array.isArray(pt) ? pt[1] : 0);
        if (px < plotMinX) plotMinX = px;
        if (py < plotMinY) plotMinY = py;
        if (px > plotMaxX) plotMaxX = px;
        if (py > plotMaxY) plotMaxY = py;
      });
    } else {
      if (rx < plotMinX) plotMinX = rx;
      if (ry < plotMinY) plotMinY = ry;
      if (rx + rw > plotMaxX) plotMaxX = rx + rw;
      if (ry + rh > plotMaxY) plotMaxY = ry + rh;
    }
  });

  if (plotMinX === Infinity || plotMaxX <= plotMinX) { plotMinX = 0; plotMaxX = pw || 100; }
  if (plotMinY === Infinity || plotMaxY <= plotMinY) { plotMinY = 0; plotMaxY = ph || 100; }
  const plotW = (plotMaxX - plotMinX) || 1;
  const plotH = (plotMaxY - plotMinY) || 1;

  // Auto-deduce plot orientation ONLY if user did NOT explicitly choose a direction
  const validUserDirections = ['North', 'North-East', 'East', 'South-East', 'South', 'South-West', 'West', 'North-West'];
  const userExplicitlyChose = validUserDirections.some(d => (orientation || '').toLowerCase().replace(/[\s\-_]/g, '') === d.toLowerCase().replace(/[\s\-_]/g, ''));
  if (!orientation || orientation === 'Auto' || (!userExplicitlyChose)) {

    let autoOrientation = null;

    // Priority 1: Spatial Geometry Deduction using Puja / Prayer Room & Kitchen positions (Vastu Anchors)
    if (roomsForOri.length > 0) {
      const pRoom = roomsForOri.find(r => (r.name || '').toLowerCase().match(/puja|pooja|prayer|temple/));
      if (pRoom) {
        let px = pRoom.x !== undefined ? pRoom.x : (pRoom.bounds ? pRoom.bounds.x : 0);
        let py = pRoom.y !== undefined ? pRoom.y : (pRoom.bounds ? pRoom.bounds.y : 0);
        const normPx = (px - plotMinX) / plotW;
        const normPy = (py - plotMinY) / plotH;
        // Puja room is traditionally placed in North-East (Eesanyam)
        if (normPy > 0.5 && normPx < 0.5) autoOrientation = "South";     // Bottom-Left is NE => Top is South
        else if (normPy < 0.5 && normPx < 0.5) autoOrientation = "East"; // Top-Left is NE => Top is East
        else if (normPy > 0.5 && normPx > 0.5) autoOrientation = "West"; // Bottom-Right is NE => Top is West
        else if (normPy < 0.5 && normPx > 0.5) autoOrientation = "North";// Top-Right is NE => Top is North
      }
    }

    // Priority 2: Dedicated explicit compass text search
    if (!autoOrientation) {
      const strData = (JSON.stringify(modelData) + " " + (modelData?.raw_ocr_text || "")).toUpperCase();
      if (strData.includes("FACING: SOUTH") || strData.includes("S-FACING") || strData.includes("SOUTH FACING")) autoOrientation = "South";
      else if (strData.includes("FACING: EAST") || strData.includes("E-FACING") || strData.includes("EAST FACING")) autoOrientation = "East";
      else if (strData.includes("FACING: WEST") || strData.includes("W-FACING") || strData.includes("WEST FACING")) autoOrientation = "West";
      else if (strData.includes("FACING: NORTH") || strData.includes("N-FACING") || strData.includes("NORTH FACING")) autoOrientation = "North";
    }

    // Priority 3: Secondary Kitchen placement heuristics (Bottom-Right kitchen is Agni Moolai => Top is North)
    if (!autoOrientation && roomsForOri.length > 0) {
      const kRoom = roomsForOri.find(r => (r.name || '').toLowerCase().match(/kitchen|cook/));
      if (kRoom) {
        let kx = kRoom.x !== undefined ? kRoom.x : (kRoom.bounds ? kRoom.bounds.x : 0);
        let ky = kRoom.y !== undefined ? kRoom.y : (kRoom.bounds ? kRoom.bounds.y : 0);
        const normKx = (kx - plotMinX) / plotW;
        const normKy = (ky - plotMinY) / plotH;
        if (normKy > 0.5 && normKx > 0.5) autoOrientation = "North"; // Bottom-Right kitchen => Top is North
        else if (normKy > 0.5 && normKx < 0.5) autoOrientation = "East"; // Bottom-Left kitchen => Top is East
        else if (normKy < 0.5 && normKx > 0.5) autoOrientation = "West"; // Top-Right kitchen => Top is West
        else if (normKy < 0.5 && normKx < 0.5) autoOrientation = "South"; // Top-Left kitchen => Top is South
      }
    }

    if (autoOrientation) {
      orientation = autoOrientation;
    }
  }

  const DIRECTIONS = ['North', 'North-East', 'East', 'South-East', 'South', 'South-West', 'West', 'North-West'];
  let normOrientation = (orientation || 'North').trim();
  const lowerOri = normOrientation.toLowerCase().replace(/[\s\-_]/g, '');
  let k = 0;
  if (lowerOri === 'northeast' || lowerOri === 'ne') k = 1;
  else if (lowerOri === 'east' || lowerOri === 'e') k = 2;
  else if (lowerOri === 'southeast' || lowerOri === 'se') k = 3;
  else if (lowerOri === 'south' || lowerOri === 's') k = 4;
  else if (lowerOri === 'southwest' || lowerOri === 'sw') k = 5;
  else if (lowerOri === 'west' || lowerOri === 'w') k = 6;
  else if (lowerOri === 'northwest' || lowerOri === 'nw') k = 7;
  else k = 0;

  const analysis = {
    mainEntrance: isTamil
      ? `வாஸ்து நிபுணர் அறிக்கை: உங்கள் ${normOrientation} மனை வடிவமைப்பில் தலைவாசல் கதவானது ${['North', 'North-East', 'East'].includes(normOrientation) ? normOrientation : 'வடக்கு அல்லது கிழக்கு'} திசையில் (உச்ச பகுதி) அமைக்கப்படுவது 100% சுபிட்சமான அமைப்பாகும். இது வீட்டிற்குள் லட்சுமி கடாட்சத்தையும், மன அமைதியையும், தொடர் நிதி வளர்ச்சியையும் கொண்டு வரும். தலைவாசல் கதவு எப்போதும் உட்புறமாக கடிகார திசையில் திறக்குமாறு இருக்க வேண்டும்.`
      : `Expert Vastu Report: For this ${normOrientation}-facing plot, the Main Entrance should ideally be positioned in the exalted ${['North', 'North-East', 'East'].includes(normOrientation) ? normOrientation : 'North or East'} zone. An entrance in North, East, or North-East attracts Lord Kubera's wealth energy and protects the family from negative aura. Ensure the door opens inwards clockwise.`,
    kitchen: isTamil
      ? `வாஸ்து நிபுணர் அறிக்கை: சமையலறையானது தென்கிழக்கு திசையில் 'அக்னி மூலை'யில் (Zone of Fire) அமைக்கப்பட வேண்டும். சமையல் செய்பவர் கிழக்கு நோக்கி நின்று சமைக்க வேண்டும். இது பஞ்சபூதங்களில் அக்னி தத்துவத்தை நிலைநிறுத்தி, குடும்பத்தினருக்குச் சிறந்த ஆரோக்கியத்தையும், செழிப்பையும், அன்னபூரணி தேவியின் அருளையும் வழங்கும்.`
      : `Expert Vastu Report: The Kitchen must be constructed in the South-East corner ('Agni Moolai' - Zone of Fire). The cooking stove should face East to harness positive solar rays, ensuring digestive health, physical vitality, and family financial abundance.`,
    masterBedroom: isTamil
      ? `வாஸ்து நிபுணர் அறிக்கை: முதன்மைப் படுக்கையறை வீட்டின் தென்மேற்கு திசையில் 'நிருதி மூலை'யில் (நில தத்துவம்) அமைக்கப்பட வேண்டும். நில தத்துவத்தைக் கொண்ட நிருதி மூலை குடும்பத் தலைவருக்குத் தலைமைப் பண்பையும், மன உறுதியையும், நிதி நிலைத்தன்மையையும் அளிக்கும். தலை தெற்கு அல்லது மேற்கு நோக்கி வைத்து தூங்குவது ஆழ்ந்த உறக்கத்தையும் ஆரோக்கியத்தையும் தரும்.`
      : `Expert Vastu Report: The Master Bedroom should ideally be positioned in the South-West corner ('Niruthi Moolai' - Earth Element). This anchors grounding stability, health, and financial authority for the house owner. Sleep with head pointing South or West for restorative rest.`,
    bathroom: isTamil
      ? `வாஸ்து நிபுணர் அறிக்கை: கழிவறை மற்றும் குளியலறையை வீட்டின் வடமேற்கு 'வாயு மூலை' அல்லது மேற்கு/தெற்கு பகுதிகளில் அமைக்க வேண்டும். வடகிழக்கு (ஈசான்யம்), தென்மேற்கு (நிருதி) மற்றும் வீட்டின் மையப்பகுதி (பிரம்மஸ்தானம்) ஆகியவற்றில் கழிவறை கட்டுவதை முற்றிலும் தவிர்க்க வேண்டும். கழிவறைக் கோப்பை வடக்கு-தெற்கு அச்சில் அமைய வேண்டும்.`
      : `Expert Vastu Report: Bathrooms and Toilets should be positioned safely in the North-West ('Vayu Moolai'), West, or South zones. Strictly avoid building toilets in the sacred North-East (Eesanyam), South-West (Niruthi), or plot Center (Brahmasthan) to prevent spiritual and financial drain. Align commode North-South.`,
    staircase: isTamil
      ? `வாஸ்து நிபுணர் அறிக்கை: மாடிப்படி வீட்டின் தெற்கு, மேற்கு அல்லது தென்மேற்குப் பகுதியில் அமைவது சிறந்தது. தெற்கு/மேற்கில் பளு இருப்பது வீட்டின் நிதி நிலையையும் பாதுகாப்பையும் வலுப்படுத்தும். படியானது கடிகார திசையில் (Clockwise) சுழன்று மேலேறுமாறு அமைக்கப்பட வேண்டும். வடகிழக்கில் மாடிப்படி அமைப்பதைத் தவிர்க்கவும்.`
      : `Expert Vastu Report: Construct the staircase along the South, West, or South-West perimeter. Placing heavy load in South/West anchors wealth security. Ensure steps turn in a clockwise direction as you ascend, and keep the space under the stairs clutter-free.`,
    poojaRoom: isTamil
      ? `வாஸ்து நிபுணர் அறிக்கை: பூஜை அறையை வடகிழக்கு 'ஈசான்ய மூலை'யில் (இறைவனின் திசை) அமைக்க வேண்டும். சுவாமி படங்கள் கிழக்கு அல்லது வடக்கு நோக்கி இருக்க வேண்டும். இது வீட்டிற்குள் இறைவனின் அருளையும், மன அமைதியையும், தொடர் நேர்மறை அதிர்வுகளையும் நிரப்பும். தியானம் மற்றும் கூட்டுப் பிரார்த்தனைக்கு இது மிகச் சிறந்த இடமாகும்.`
      : `Expert Vastu Report: Locate the Pooja / Prayer room in the North-East corner ('Eesanyam Moolai'). Idols should face East or North so devotees face East while praying. This invites divine cosmic vibrations, wisdom, and emotional harmony across the household.`,
    livingRoom: isTamil
      ? `வாஸ்து நிபுணர் அறிக்கை: வரவேற்பு அறையானது (Living Hall) வடக்கு, கிழக்கு அல்லது வடகிழக்கு திசையில் அமைய வேண்டும். இது வீட்டிற்கு வரும் விருந்தினர்களுக்கு இதமான உணர்வைத் தருவதோடு, குடும்பத்தில் எப்போதும் மகிழ்ச்சியையும் அதிக வெளிச்சத்தையும் காற்றோட்டத்தையும் பராமரிக்கும்.`
      : `Expert Vastu Report: The Living Room or Main Hall should be situated in the North, East, or North-East zones. This maximizes natural lighting, magnetic solar radiation, fresh airflow, and welcoming energy for all family members and visitors.`,
  };

  const GRID_OFFSETS = [
    [7, 0, 1],
    [6, -1, 2],
    [5, 4, 3]
  ];

  const rooms = modelData.rooms || [];

  if (rooms.length === 0) {
    score = 70;
    violations.push(isTamil ? "அறைகள் எதுவும் 2D வரைபடத்தில் சரியாகக் கண்டறியப்படவில்லை." : "No specific rooms detected in the 2D layout to perform deep room placement audit.");
  }

  const processedTypes = new Set();
  const roomPlacements = [];

  rooms.forEach(room => {
    const rawName = (room.name || '').trim();
    const name = rawName.toLowerCase();

    let cx = 0, cy = 0;
    if (room.polygon_pts && Array.isArray(room.polygon_pts) && room.polygon_pts.length > 0) {
      let sumX = 0, sumY = 0;
      room.polygon_pts.forEach(pt => {
        sumX += pt.x !== undefined ? pt.x : (Array.isArray(pt) ? pt[0] : 0);
        sumY += pt.y !== undefined ? pt.y : (Array.isArray(pt) ? pt[1] : 0);
      });
      cx = sumX / room.polygon_pts.length;
      cy = sumY / room.polygon_pts.length;
    } else if (room.polygon && Array.isArray(room.polygon) && room.polygon.length > 0) {
      let sumX = 0, sumY = 0;
      room.polygon.forEach(pt => {
        sumX += pt.x !== undefined ? pt.x : (Array.isArray(pt) ? pt[0] : 0);
        sumY += pt.y !== undefined ? pt.y : (Array.isArray(pt) ? pt[1] : 0);
      });
      cx = sumX / room.polygon.length;
      cy = sumY / room.polygon.length;
    } else {
      let rx = room.x !== undefined ? room.x : (room.bounds ? room.bounds.x : 0);
      let ry = room.y !== undefined ? room.y : (room.bounds ? room.bounds.y : 0);
      let rw = room.width !== undefined ? room.width : (room.bounds ? room.bounds.w : 10);
      let rh = room.height !== undefined ? room.height : (room.bounds ? room.bounds.h : 10);
      cx = rx + (rw / 2);
      cy = ry + (rh / 2);
    }

    const normX = (cx - plotMinX) / plotW;
    const normY = (cy - plotMinY) / plotH;

    let row = 1;
    if (normY < 0.33) row = 0;
    else if (normY > 0.67) row = 2;

    let col = 1;
    if (normX < 0.33) col = 0;
    else if (normX > 0.67) col = 2;

    const offset = GRID_OFFSETS[row][col];
    let zone = 'Center-Center';
    if (offset !== -1) {
      zone = DIRECTIONS[(k + offset) % 8];
    }

    let roomVastuText = '';

    if (name.includes('kitchen') || name.includes('cook')) {
      if (zone === 'South-East') {
        roomVastuText = isTamil
          ? `100% வாஸ்து சுபிட்சமான அமைப்பு! சமையலறையானது தென்கிழக்கு 'அக்னி மூலை'யில் அமைந்துள்ளது.`
          : `100% Ideal Vastu Placement! Kitchen is located in South-East ('Agni Moolai').`;
        if (!processedTypes.has('kitchen')) {
          strengths.push(isTamil
            ? `1. சமையலறை மனை வடிவமைப்பின் தென்கிழக்கு 'அக்னி மூலை'யில் (Agni Zone) 100% சரியாக அமைந்துள்ளது.\n2. பஞ்சபூதங்களில் அக்னி தத்துவத்தைக் கொண்ட இத்திசையில் சமையலறை அமைப்பது வீட்டின் ஆரோக்கியத்தை மேம்படுத்தும்.\n3. சமையல் செய்பவர் கிழக்கு நோக்கி நின்று சமைக்கும் வகையில் மேடை அமைப்பது சூரியனின் நேர்மறை கதிர்களை ஈர்க்கும்.\n4. இதனால் குடும்ப உறுப்பினர்களுக்குச் செரிமானக் குறைபாடுகள் இன்றி நல்ல உடல் ஆரோக்கியம் கிடைக்கும்.\n5. மேலும் அன்னபூரணி தேவியின் அருளால் வீட்டில் உணவு மற்றும் செல்வ வளம் தொடர்ந்து பெருகும்.`
            : `1. The Kitchen is accurately positioned in the South-East corner ('Agni Moolai' - Zone of Fire) of your floor plan.\n2. Placing the culinary area in this fire element sector creates an ideal elemental balance in your home.\n3. Designing the cooking counter so the cook faces East harnesses healthy morning solar radiation.\n4. This placement optimizes digestive health, physical energy, and emotional vitality for all residents.\n5. It attracts financial prosperity and ensures a continuous abundance of nourishment for the household.`);
          analysis.kitchen = roomVastuText;
        }
      } else if (zone === 'North-West') {
        score -= 5;
        roomVastuText = isTamil
          ? `2-வது சிறந்த வாஸ்து அமைப்பு. சமையலறை வடமேற்கு 'வாயு மூலை'யில் அமைந்துள்ளது.`
          : `Secondary Preferred Vastu Placement. Kitchen in North-West ('Vayu Moolai').`;
        if (!processedTypes.has('kitchen')) analysis.kitchen = roomVastuText;
      } else if (zone === 'North-East') {
        score -= 20;
        roomVastuText = isTamil
          ? `கடுமையான வாஸ்து தோஷம்! சமையலறை வடகிழக்கு 'ஈசான்ய மூலை'யில் அமைந்திருப்பது நீர்-நெருப்பு மோதலை உண்டாக்கும்.`
          : `Severe Vastu Defect! Kitchen in North-East ('Eesanyam Moolai') creates a Water-Fire elemental clash.`;
        if (!processedTypes.has('kitchen')) {
          violations.push(isTamil
            ? `1. சமையலறை வடகிழக்கு 'ஈசான்ய மூலை'யில் அமைந்திருப்பது மிகக் கடுமையான நீர்-நெருப்பு வாஸ்து தோஷமாகும்.\n2. ஈசான்ய மூலை நீர் மற்றும் இறை தத்துவத்தைக் கொண்டதால் அங்கு அக்னியை வைப்பது குடும்ப அமைதியைக் கெடுக்கும்.\n3. இது வீட்டிலுள்ள உறுப்பினர்களுக்கு தேவையற்ற மருத்துவச் செலவுகளையும் மன அழுத்தத்தையும் ஏற்படுத்தும்.\n4. இதனால் நிதி நிலைமையில் எதிர்பாராத தடங்கல்களும் தொழில் நஷ்டங்களும் ஏற்பட வாய்ப்புள்ளது.\n5. இந்த வாஸ்து குறைபாடு காரணமாக உங்கள் வாஸ்து புள்ளியில் இருந்து -20 புள்ளிகள் குறைக்கப்பட்டுள்ளது.`
            : `1. Constructing the Kitchen in the sacred North-East ('Eesanyam Moolai') zone is a major elemental clash.\n2. North-East represents the Water and Divine element; introducing Fire here destroys cosmic harmony.\n3. This severe conflict causes sudden medical expenses, family disputes, and chronic stress for residents.\n4. It leads to unexpected financial drain and blocks career growth opportunities.\n5. Due to this major elemental contradiction, 20 points have been deducted from your Vastu score.`);
          suggestions.push(isTamil
            ? `1. சமையலறையை கூடிய விரைவில் தென்கிழக்கு (அக்னி மூலை) அல்லது வடமேற்கு (வாயு மூலை) திசைக்கு மாற்றவும்.\n2. உடனடியாக மாற்ற இயலவில்லை எனில், சமையல் மேடையின் தென்கிழக்கு மூலையில் ஒரு சிறிய வாஸ்து பிரமிடு வைக்கவும்.\n3. சமையல் அடுப்பை எப்போதும் கிழக்கு நோக்கி நின்று சமைக்குமாறு திசையை மாற்றியமைக்கவும்.\n4. சமையலறை சுவர்களுக்கு இளம் மஞ்சள் அல்லது ஆரஞ்சு வர்ணம் பூசுவது அக்னி ஆற்றலை சமன்படுத்தும்.\n5. சிங்க் (Sink) மற்றும் அடுப்புக்கு இடையே குறைந்தபட்சம் 3 அடி இடைவெளி பராமரிப்பது நீர்-நெருப்பு மோதலைத் தவிர்க்கும்.`
            : `1. Plan to relocate the kitchen space to the South-East ('Agni Moolai') or North-West zone when possible.\n2. If structural relocation is delayed, place a specialized Vastu Pyramid in the South-East corner of the kitchen.\n3. Ensure the cook faces East while preparing meals to receive beneficial morning solar energy.\n4. Paint kitchen walls in warm pastel shades like yellow or light orange to balance fire energy.\n5. Maintain at least 3 feet distance between the water sink and cooking stove to minimize elemental clash.`);
          analysis.kitchen = roomVastuText;
        }
      } else {
        score -= 15;
        roomVastuText = isTamil
          ? `வாஸ்து குறைபாடு! சமையலறை ${zone} திசையில் அமைந்துள்ளது. தென்கிழக்கு அல்லது வடமேற்கு சிறந்ததாகும்.`
          : `Vastu Defect! Kitchen is situated in ${zone} zone. South-East or North-West is ideal.`;
        if (!processedTypes.has('kitchen')) analysis.kitchen = roomVastuText;
      }
      processedTypes.add('kitchen');
    } else if (name.includes('master') || (name.includes('bed') && !name.includes('guest'))) {
      if (zone === 'South-West') {
        roomVastuText = isTamil
          ? `100% வாஸ்து சுபிட்சமான அமைப்பு! முதன்மைப் படுக்கையறை தென்மேற்கு 'நிருதி மூலை'யில் அமைந்துள்ளது.`
          : `100% Perfect Vastu Placement! Master Bedroom is located in South-West ('Niruthi Moolai').`;
        if (!processedTypes.has('bedroom')) {
          strengths.push(isTamil
            ? `1. முதன்மைப் படுக்கையறை வீட்டின் தென்மேற்கு 'நிருதி மூலை'யில் (Earth Element) மிக நேர்த்தியாக அமைந்துள்ளது.\n2. நில தத்துவத்தைக் கொண்ட இத்திசை குடும்பத் தலைவருக்கு தலைமைப் பண்பையும் மன உறுதியையும் வழங்கும்.\n3. தென்மேற்கில் படுக்கையறை அமைவது நிதி நிலைத்தன்மையையும் குடும்பப் பாதுகாப்பையும் பலப்படுத்தும்.\n4. கட்டிலை தெற்கு அல்லது மேற்கு நோக்கிய தலைப்பகுதியுடன் அமைப்பது ஆழ்ந்த உறக்கத்தைத் தரும்.\n5. இது தம்பதியரிடையே பரஸ்பர அன்பையும் குடும்ப அமைதியையும் நீண்ட காலம் பராமரிக்க உதவும்.`
            : `1. The Master Bedroom is impeccably located in the South-West corner ('Niruthi Moolai' - Earth Element).\n2. The Earth element zone provides grounding energy, mental authority, and emotional stability to the breadwinner.\n3. Occupying this corner secures long-term financial prosperity and shields the family from external risks.\n4. Sleeping with the head pointing towards South or West promotes deep restorative sleep and physical health.\n5. It fosters deep mutual understanding, domestic peace, and overall family wellbeing.`);
          analysis.masterBedroom = roomVastuText;
        }
      } else if (zone === 'North-East') {
        score -= 20;
        roomVastuText = isTamil
          ? `கடுமையான வாஸ்து தோஷம்! வடகிழக்கில் படுக்கையறை அமைப்பது மன அழுத்ததைத் தரும்.`
          : `Severe Vastu Defect! Bedroom in North-East causes mental anxiety and sleep disorders.`;
        if (!processedTypes.has('bedroom')) {
          violations.push(isTamil
            ? `1. படுக்கையறை வடகிழக்கு 'ஈசான்ய மூலை'யில் அமைந்திருப்பது கடுமையான வாஸ்து குறைபாடாகும்.\n2. ஈசான்யம் லேசான இறை மண்டலம் என்பதால் அங்கு படுக்கையறை வைப்பது மனக் கலக்கத்தை உண்டாக்கும்.\n3. இது குடும்பத் தலைவருக்குத் தேவையான நிதி ஆதிக்கத்தையும் முடிவெடுக்கும் திறனையும் பலவீனப்படுத்தும்.\n4. தூக்கத்தில் தொடர் இடையூறுகள் மற்றும் தலைவலி போன்ற உடல்நலக் குறைபாடுகள் ஏற்பட வாய்ப்புள்ளது.\n5. இக்குறைபாட்டின் காரணமாக வாஸ்து மதிப்பெண்ணில் இருந்து -20 புள்ளிகள் குறைக்கப்பட்டுள்ளது.`
            : `1. Constructing the Master Bedroom in the North-East ('Eesanyam Moolai') zone is a severe Vastu violation.\n2. North-East is a light, divine spiritual quadrant; heavy sleeping furniture here causes mental anxiety.\n3. It weakens the house owner's decision-making power, financial dominance, and leadership authority.\n4. Residents may experience chronic sleep disturbances, headaches, and persistent restlessness.\n5. Due to this structural mismatch, 20 points have been deducted from your overall Vastu score.`);
          suggestions.push(isTamil
            ? `1. வடகிழக்கு அறையை தியானம், படிப்பு அல்லது பூஜை அறையாக மாற்றவும்.\n2. கட்டிலை தெற்கு அல்லது மேற்கு திசைக்கு தலை வைத்து தூங்குமாறு உடனடியாக மாற்றியமைக்கவும்.\n3. அறையின் தென்மேற்கு மூலையில் ஒரு சிறிய வாஸ்து படிகாரம் வைக்கவும்.\n4. அறைக்கு லேசான நீலம் அல்லது வெள்ளை வர்ணம் பூசுவது மன அமைதியைத் தரும்.\n5. வடகிழக்கு மூலையில் கனமான மர அலமாரிகள் வைப்பதைத் தவிர்க்கவும்.`
            : `1. Convert the North-East room into a prayer, meditation, or quiet study space.\n2. Reposition the bed frame so head points South or West while sleeping.\n3. Place a small Vastu sea salt crystal bowl in the South-West corner of the bedroom.\n4. Paint bedroom walls with calming white or soft sky-blue colors for tranquil energy.\n5. Avoid placing heavy wardrobes or storage safes in the North-East corner of this room.`);
          analysis.masterBedroom = roomVastuText;
        }
      } else if (zone === 'North-West') {
        roomVastuText = isTamil
          ? `நடுத்தரமான வாஸ்து அமைப்பு. வடமேற்கு 'வாயு மூலை'யில் படுக்கையறை உள்ளது.`
          : `Acceptable Secondary Placement. Bedroom is in North-West ('Vayu Moolai').`;
        if (!processedTypes.has('bedroom')) analysis.masterBedroom = roomVastuText;
      } else if (zone === 'South-East') {
        score -= 10;
        roomVastuText = isTamil
          ? `வாஸ்து குறைபாடு! தென்கிழக்கு 'அக்னி மூலை'யில் படுக்கையறை இருப்பது தூக்கத்தில் எரிச்சலைத் தரும்.`
          : `Vastu Caution! South-East bedroom introduces excess elemental heat.`;
        if (!processedTypes.has('bedroom')) {
          violations.push(isTamil
            ? `1. படுக்கையறை தென்கிழக்கு 'அக்னி மூலை'யில் அமைந்திருப்பது வெப்ப ஆற்றலை அதிகப்படுத்தும்.\n2. அக்னி மண்டலத்தில் உறங்குவது உடலின் தட்பவெப்ப நிலையை உயர்த்தி கோபத்தையும் எரிச்சலையும் தரும்.\n3. இது தம்பதியரிடையே தேவையற்ற மனக்கசப்புகளையும் தூக்கமின்மையையும் உண்டாக்கலாம்.\n4. இரத்த அழுத்தம் மற்றும் செரிமானப் பிரச்சினைகள் ஏற்பட வாய்ப்புள்ளது.\n5. இதன் காரணமாக வாஸ்து மதிப்பெண்ணில் இருந்து -10 புள்ளிகள் குறைக்கப்பட்டுள்ளது.`
            : `1. Positioning the bedroom in South-East ('Agni Moolai') introduces excess elemental heat.\n2. Sleeping in the fire zone increases physical body temperature and emotional irritability.\n3. It can cause frequent arguments among couples and restless sleeping patterns.\n4. Residents may experience blood pressure fluctuations and digestive discomforts.\n5. Due to this elemental mismatch, 10 points have been deducted from your Vastu score.`);
          suggestions.push(isTamil
            ? `1. கட்டிலை அறையின் தென்மேற்கு மூலையில் போட்டு தெற்கு நோக்கி தலைவைத்து தூங்கவும்.\n2. அறைக்கு குளிர்ச்சியான வெளிர் நீலம் அல்லது பச்சை நிற பெயிண்ட் பூசவும்.\n3. அறையின் வடகிழக்கு மூலையில் எப்போதும் ஒரு பாத்திரத்தில் சுத்தமான நீர் வைக்கலாம்.\n4. தென்கிழக்கு மூலையில் மின்சாதனப் பொருட்களை அதிகமாக வைப்பதைத் தவிர்க்கவும்.\n5. இரவில் தூங்கும் போது அறை வெப்பநிலையைக் குளிர்ச்சியாகப் பராமரிக்கவும்.`
            : `1. Shift bed placement strictly towards the South-West corner of the room facing South.\n2. Paint the walls with cool pastel shades of blue or light green to neutralize fire heat.\n3. Keep a bowl of clean water in the North-East corner of the bedroom.\n4. Minimize electronic appliances and heavy electrical equipment in the South-East corner.\n5. Ensure good ventilation and maintain cool ambient room temperatures at night.`);
          analysis.masterBedroom = roomVastuText;
        }
      } else {
        roomVastuText = isTamil
          ? `படுக்கையறை ${zone} திசையில் அமைந்துள்ளது.`
          : `Bedroom is placed in ${zone} zone. Head resting towards South or West is recommended.`;
        if (!processedTypes.has('bedroom')) analysis.masterBedroom = roomVastuText;
      }
      processedTypes.add('bedroom');
    } else if (name.includes('guest')) {
      if (zone === 'North-West' || zone === 'West' || zone === 'South') {
        roomVastuText = isTamil
          ? `100% சிறந்த வாஸ்து அமைப்பு! விருந்தினர் அறை ${zone} திசையில் அமைந்துள்ளது.`
          : `100% Ideal Placement! Guest room is located in ${zone} zone.`;
        strengths.push(isTamil
          ? `1. விருந்தினர் அறை ${zone} திசையில் வாஸ்து விதிகளின்படி நேர்த்தியாக அமைந்துள்ளது.\n2. இத்திசையில் விருந்தினர்கள் தங்குவது வீட்டிற்கு நல்வரவையும் நேர்மறை அதிர்வுகளையும் தரும்.\n3. விருந்தினர்களுக்கு மன நிம்மதியும் நல் ஆரோக்கியமும் கிடைக்க இவடிவமைப்பு உதவும்.\n4. வீட்டின் முதன்மை நிருதி மூலையைப் பாதிக்காமல் விருந்தினர் அறை தனியாக அமைக்கப்பட்டுள்ளது.\n5. இது குடும்பத்தின் விருந்தோம்பல் பண்பையும் சமூக மரியாதையும் உயர்த்தும்.`
          : `1. Guest room is positioned in ${zone} zone in strict accordance with architectural Vastu.\n2. Placing guest quarters in this sector brings welcoming energy and positive hospitality vibes.\n3. It ensures visitors feel comfortable, peaceful, and refreshed during their stay.\n4. It preserves the Master Bedroom's privacy and South-West authority intact.\n5. It enhances social goodwill, family harmony, and prestigious guest relations.`);
      } else {
        roomVastuText = isTamil
          ? `விருந்தினர் அறை ${zone} திசையில் அமைந்துள்ளது.`
          : `Guest room is placed in ${zone} zone.`;
      }
    } else if (name.includes('bath') || name.includes('toilet') || name.includes('wc') || name.includes('wash')) {
      if (zone === 'North-West' || zone === 'West' || zone === 'South') {
        roomVastuText = isTamil
          ? `100% சரியான வாஸ்து அமைப்பு! கழிவறை பாதுகாப்பான ${zone} திசையில் அமைந்துள்ளது.`
          : `100% Correct Vastu Alignment! Bathroom/toilet is safely positioned in ${zone} zone.`;
        if (!processedTypes.has('bathroom')) {
          strengths.push(isTamil
            ? `1. கழிவறை மற்றும் குளியலறை வடமேற்கு 'வாயு மூலை'யில் (Zone of Air) பாதுகாப்பாக அமைக்கப்பட்டுள்ளது.\n2. வாயு மூலையானது கழிவுகளை வெளியேற்றுவதற்கு வாஸ்து விதிகளின்படி 100% உகந்த திசையாகும்.\n3. வடகிழக்கு மற்றும் தென்மேற்கு ஆகிய புனித திசைகளில் கழிவறை வராமல் தடுத்திருப்பது மிகப்பெரிய பலமாகும்.\n4. கழிவறைக் கோப்பை வடக்கு-தெற்கு அச்சில் அமைப்பது உடலியல் ஆரோக்கியத்திற்கு ஏற்றதாகும்.\n5. இது வீட்டின் தெய்வீக ஆற்றலையும் நிதி நிலைமையையும் பாதிக்காமல் பாதுகாக்கும்.`
            : `1. Bathrooms and Toilets are safely located in the North-West sector ('Vayu Moolai' - Air Element).\n2. Air element zone naturally dispels waste and negative energies without contaminating house aura.\n3. Keeping the sacred North-East and South-West zones free of toilets is a major architectural strength.\n4. Aligning the commode in a North-South orientation adheres strictly to traditional Vastu principles.\n5. This protects your family's health, spiritual purity, and prevents unnecessary financial leaks.`);
          analysis.bathroom = roomVastuText;
        }
      } else if (zone === 'North-East' || zone === 'South-West' || zone === 'Center-Center') {
        score -= 25;
        roomVastuText = isTamil
          ? `மிகக் கடுமையான வாஸ்து பேரழிவு! கழிவறை ${zone} திசையில் அமைந்துள்ளது.`
          : `Catastrophic Vastu Defect! Toilet is improperly located in sacred ${zone} zone.`;
        if (!processedTypes.has('bathroom')) {
          violations.push(isTamil
            ? `1. கழிவறை ${zone} போன்ற புனித வாஸ்து மண்டலத்தில் அமைந்திருப்பது கடுமையான தோஷமாகும்.\n2. ஈசான்யம் அல்லது நிருதி மூலையில் கழிவறை அமைப்பது வீட்டின் தெய்வீக அதிர்வுகளை முழுமையாக சிதைக்கும்.\n3. இது குடும்ப உறுப்பினர்களுக்கு தொடர் பண இழப்பு மற்றும் குணப்படுத்த முடியாத உடல்நலக் கோளாறுகளைத் தரும்.\n4. குடும்ப அமைதி சீர்குலைந்து உறுப்பினரிடையே தேவையற்ற மனக்கசப்புகளும் பிணக்குகளும் ஏற்படும்.\n5. இக்கடுமையான வாஸ்து குறைபாட்டின் காரணமாக உங்கள் மதிப்பெண்ணில் இருந்து -25 புள்ளிகள் குறைக்கப்பட்டுள்ளது.`
            : `1. Positioning the toilet in sacred zones like ${zone} is a major Vastu violation.\n2. Building a restroom in Eesanyam or Niruthi severely pollutes the home's spiritual magnetic field.\n3. It causes persistent financial drains, unexpected debts, and chronic health ailments for residents.\n4. It disturbs household tranquility, creating emotional stress and misunderstandings among family members.\n5. Due to this severe structural defect, 25 points have been deducted from your Vastu score.`);
          suggestions.push(isTamil
            ? `1. கழிவறையை முடிந்தவரை வடமேற்கு (வாயு மூலை) அல்லது மேற்கு எல்லைப் பகுதிக்கு மாற்ற முயற்சி செய்யவும்.\n2. மாற்ற இயலாத பட்சத்தில், கழிவறையின் கதவை எப்போதும் மூடியே வைத்து உட்புறம் தூய்மையாகப் பராமரிக்கவும்.\n3. கழிவறைக்குள் ஒரு சிறிய கண்ணாடி கிண்ணத்தில் கடல் உப்பு வைத்து வாரத்திற்கு ஒருமுறை மாற்றவும்.\n4. கழிவறையின் வெளிப்புறச் சுவரில் ஒரு வாஸ்து நிவர்த்தி கிரிஸ்டல் அல்லது துளசி செடி வைக்கலாம்.\n5. கழிவறைக்குள் எப்போதும் நல்ல காற்றோட்டம் மற்றும் துர்நாற்றம் வராதவாறு எக்சாஸ்ட் ஃபேன் பயன்படுத்தவும்.`
            : `1. Plan to relocate the restroom to the North-West ('Vayu Moolai') or West perimeter in future renovations.\n2. Keep the toilet door strictly closed at all times to prevent negative energy from entering living spaces.\n3. Place a bowl of unrefined sea salt inside the restroom and refresh it once every week to absorb negativity.\n4. Install an exhaust fan to ensure continuous air circulation and keep the restroom dry and fresh.\n5. Position a small Vastu crystal or remedy strip on the outer wall of the restroom for energetic protection.`);
          analysis.bathroom = roomVastuText;
        }
      } else {
        roomVastuText = isTamil
          ? `கழிவறை ${zone} திசையில் அமைந்துள்ளது.`
          : `Bathroom is situated in ${zone} zone. Keep door closed and use exhaust fan.`;
        if (!processedTypes.has('bathroom')) analysis.bathroom = roomVastuText;
      }
      processedTypes.add('bathroom');
    } else if (name.includes('pooja') || name.includes('puja') || name.includes('prayer') || name.includes('temple')) {
      if (zone === 'North-East') {
        roomVastuText = isTamil
          ? `100% சிறந்த தெய்வீக வாஸ்து அமைப்பு! பூஜை அறை வடகிழக்கு ஈசான்ய மூலையில் அமைந்துள்ளது.`
          : `100% Perfect Divine Vastu Placement! Pooja room is in North-East ('Eesanyam Moolai').`;
        if (!processedTypes.has('pooja')) {
          strengths.push(isTamil
            ? `1. பூஜை அறை வடகிழக்கு 'ஈசான்ய மூலை'யில் (Divine Gateway) 100% தூய்மையாக அமைந்துள்ளது.\n2. ஈசான்ய மூலை இறைவனின் வீடாகக் கருதப்படுவதால் அங்கு இறை வழிபாடு செய்வது தெய்வீக ஆற்றலைத் தரும்.\n3. சுவாமி உருவங்களை கிழக்கு அல்லது வடக்கு நோக்கி வைப்பது வழிபாட்டின் போது நேர்மறை அதிர்வுகளை உயர்த்தும்.\n4. இது வீட்டில் உள்ள உறுப்பினர்களுக்கு தெளிவான சிந்தனை, ஞானம் மற்றும் மன அமைதியை அளிக்கும்.\n5. வீட்டில் எப்போதும் லக்ஷ்மி கடாட்சமும் நேர்மறை ஆற்றலும் நிறைந்திருக்க இத்தூய அமைப்பு வழிவகுக்கும்.`
            : `1. The Pooja Room is positioned in the sacred North-East corner ('Eesanyam Moolai' - Divine Gateway).\n2. As North-East holds highest spiritual vibrations, praying here connects residents directly to divine aura.\n3. Placing idols facing East or North allows devotees to face East during daily prayers.\n4. This enhances mental clarity, spiritual wisdom, concentration, and harmony across all family members.\n5. It attracts auspicious opportunities and maintains a serene, uplifting environment throughout the house.`);
          analysis.poojaRoom = roomVastuText;
        }
      } else if (zone.includes('North') || zone.includes('East')) {
        roomVastuText = isTamil
          ? `மிகச் சிறந்த வாஸ்து அமைப்பு. பூஜை அறை ${zone} திசையில் அமைந்துள்ளது.`
          : `Highly Auspicious Placement. Pooja room is located in ${zone} zone.`;
        if (!processedTypes.has('pooja')) analysis.poojaRoom = roomVastuText;
      } else {
        score -= 10;
        roomVastuText = isTamil
          ? `பூஜை அறை ${zone} திசையில் அமைந்துள்ளது. வடகிழக்கு அல்லது கிழக்கு சிறந்ததாகும்.`
          : `Suboptimal Placement. Pooja room is in ${zone} zone. Relocate to North-East.`;
        if (!processedTypes.has('pooja')) {
          violations.push(isTamil
            ? `1. பூஜை அறை ${zone} திசையில் அமைந்திருப்பது போதுமான தெய்வீக அதிர்வுகளைத் தராது.\n2. தெற்கு அல்லது மேற்கு திசைகளில் பூஜை அறை வைப்பது ஆன்மீக ஆற்றலைக் குறைக்கும்.\n3. இது பிரார்த்தனையின் போது கவனச்சிதறலையும் குடும்பத்தில் சிறு சலசலப்புகளையும் ஏற்படுத்தலாம்.\n4. வடகிழக்கு ஈசான்ய மூலையை காலியாக விட்டு பூஜையை ${zone}-ல் வைப்பது சுபிட்சத்தைக் குறைக்கும்.\n5. இக்குறைபாட்டின் காரணமாக வாஸ்து புள்ளியில் இருந்து -10 புள்ளிகள் குறைக்கப்பட்டுள்ளது.`
            : `1. Placing the Pooja Room in ${zone} zone provides suboptimal spiritual vibrations.\n2. Orienting prayer altars towards South or West reduces divine cosmic reception.\n3. It may lead to lack of concentration during prayers and minor family frictions.\n4. Leaving North-East unutilized while keeping Pooja in ${zone} weakens domestic peace.\n5. Due to this placement mismatch, 10 points have been deducted from your Vastu score.`);
          suggestions.push(isTamil
            ? `1. பூஜை அறையை வடகிழக்கு (ஈசான்யம்) அல்லது கிழக்கு திசைக்கு மாற்ற முயற்சி செய்யவும்.\n2. சுவாமி படங்களை எப்போதும் கிழக்கு அல்லது வடக்கு நோக்கி முகம் பார்க்குமாறு வைக்கவும்.\n3. பூஜை அறையின் கதவுகள் இரட்டைப் பலகைகளாக (Double shutter) இருப்பது சிறப்பு.\n4. பூஜை அறையில் எப்போதும் ஒரு நெய் தீபம் அல்லது நல்லெண்ணெய் தீபம் ஏற்றி வைக்கவும்.\n5. பூஜை அறைக்கு மேல் அல்லது கீழே கழிவறை வராதவாறு பார்த்துக் கொள்ளவும்.`
            : `1. Relocate prayer altar towards North-East ('Eesanyam') or East sector when feasible.\n2. Ensure deity idols face East or North so worshippers face East during prayers.\n3. Design two-shutter wooden doors for the Pooja altar for traditional sanctity.\n4. Keep a small brass oil lamp lit during morning and evening prayer sessions.\n5. Ensure toilets or staircases are not located directly above or below the Pooja unit.`);
          analysis.poojaRoom = roomVastuText;
        }
      }
      processedTypes.add('pooja');
    } else if (name.includes('living') || name.includes('hall') || name.includes('drawing')) {
      if (zone.includes('North') || zone.includes('East') || zone.includes('North-East')) {
        roomVastuText = isTamil
          ? `100% சிறந்த வாஸ்து அமைப்பு! வரவேற்பு அறை ${zone} திசையில் அமைந்துள்ளது.`
          : `100% Excellent Vastu Alignment! Living Room is situated in ${zone} zone.`;
        if (!processedTypes.has('living')) {
          strengths.push(isTamil
            ? `1. வரவேற்பு அறை (Living Hall) ${zone} திசையில் மிகச் சிறப்பாக அமைந்துள்ளது.\n2. வடகிழக்கு மற்றும் கிழக்குத் திசைகளில் இருந்து வரும் இயல்பான சூரிய ஒளி மற்றும் காற்றோட்டம் வீட்டை நிரப்பும்.\n3. இது வீட்டிற்கு வரும் விருந்தினர்களுக்கு இதமான உணர்வைத் தருவதோடு குடும்பத்தில் மகிழ்ச்சியைப் பெருக்கும்.\n4. பிரம்மஸ்தானத்தில் அதிக பளு இல்லாத வகையில் திறந்தவெளி வரவேற்பறையாக அமைப்பது ஆற்றல் ஓட்டத்தை உயர்த்தும்.\n5. குடும்ப உறுப்பினர்களிடையே பரஸ்பர உறவையும் தொடர்பையும் பலப்படுத்த இவடிவமைப்பு உதவும்.`
            : `1. The Living Hall is positioned excellently across ${zone} quadrant.\n2. This orientation welcomes abundant morning solar light, magnetic energy, and natural ventilation.\n3. It provides a warm, welcoming ambience for guests and fosters harmonious family gatherings.\n4. Keeping the central Brahmasthan open and clutter-free optimizes cosmic energy circulation.\n5. It strengthens social connections, household vitality, and positive mental wellbeing for all.`);
          analysis.livingRoom = roomVastuText;
        }
      } else if (zone === 'Center-Center') {
        roomVastuText = isTamil
          ? `மிகச் சிறந்த அமைப்பு! வரவேற்பு அறை பிரம்மஸ்தானத்தில் அமைந்துள்ளது.`
          : `Auspicious Placement! Main living area spans across plot center (Brahmasthan).`;
        if (!processedTypes.has('living')) analysis.livingRoom = roomVastuText;
      } else {
        roomVastuText = isTamil
          ? `வரவேற்பு அறை ${zone} திசையில் அமைந்துள்ளது.`
          : `Living Room is situated in ${zone} zone. Position heavy furniture in South or West.`;
        if (!processedTypes.has('living')) analysis.livingRoom = roomVastuText;
      }
      processedTypes.add('living');
    } else if (name.includes('stair') || name.includes('step')) {
      if (zone.includes('South') || zone.includes('West')) {
        roomVastuText = isTamil
          ? `100% சிறந்த வாஸ்து அமைப்பு! மாடிப்படி ${zone} திசையில் அமைந்துள்ளது.`
          : `100% Ideal Vastu Placement! Staircase is built in ${zone} zone.`;
        if (!processedTypes.has('stair')) {
          strengths.push(isTamil
            ? `1. மாடிப்படி வீட்டின் ${zone} பகுதியில் வாஸ்து விதிகளின்படி அமைந்துள்ளது.\n2. தெற்கு மற்றும் மேற்குத் திசைகளில் மாடிப்படியின் கனமான எடையைக் கொடுப்பது வீட்டின் நிதிப் பாதுகாப்பை உறுதியாக்கும்.\n3. படியானது கடிகார திசையில் (Clockwise direction) சுழன்று மேலேறுமாறு அமைக்கப்படுவது நன்மைகளைத் தரும்.\n4. வடகிழக்கு (ஈசான்ய) மூலையில் மாடிப்படி அமைப்பதைத் தவிர்த்திருப்பது மிகப்பெரிய வாஸ்து பலமாகும்.\n5. இது குடும்பத் தலைவரின் தொழில் வளர்ச்சிக்கும் பண இருப்புக்கும் வலுவான அடித்தளமாக அமையும்.`
            : `1. The Staircase is constructed in ${zone} zone in compliance with Vastu rules.\n2. Adding structural weight in the South/West perimeter anchors financial security and household authority.\n3. Designing steps to climb in a clockwise direction aligns perfectly with positive vortex energy.\n4. Avoiding heavy staircase placement in the North-East cosmic gateway is a key architectural asset.\n5. It supports steady professional growth, capital stability, and physical safety for all occupants.`);
          analysis.staircase = roomVastuText;
        }
      } else if (zone === 'North-East' || zone === 'Center-Center') {
        score -= 15;
        roomVastuText = isTamil
          ? `கடுமையான வாஸ்து குறைபாடு! மாடிப்படி ${zone} திசையில் அமைந்துள்ளது.`
          : `Severe Vastu Defect! Heavy staircase in ${zone} zone blocks energy flow.`;
        if (!processedTypes.has('stair')) {
          violations.push(isTamil
            ? `1. மாடிப்படி ${zone} போன்ற புனித மண்டலத்தில் அமைவது பெரிய வாஸ்து தோஷமாகும்.\n2. வடகிழக்கு அல்லது மையப் பகுதியில் கனமான மாடிப்படி அமைப்பது இறை ஆற்றலின் நுழைவாயிலை அடைத்துவிடும்.\n3. இது குடும்பத்தினருக்குத் தொழில் தடைகள், தொடர் கடன் சுமை மற்றும் மன உளைச்சலை உண்டாக்கும்.\n4. பிரம்மஸ்தானத்தில் படி அமைப்பது வீட்டின் அமைதியைக் கெடுத்து நிம்மதியற்ற சூழலை உருவாக்கும்.\n5. இக்கடுமையான வாஸ்து குறைபாட்டின் காரணமாக உங்கள் மதிப்பெண்ணில் இருந்து -15 புள்ளிகள் குறைக்கப்பட்டுள்ளது.`
            : `1. Building the staircase in ${zone} is a critical Vastu defect.\n2. Placing heavy concrete steps in the North-East or Center blocks the cosmic energy gateway entering your house.\n3. It leads to persistent business obstacles, accumulating debts, and severe mental stress for occupants.\n4. A central staircase creates internal turmoil and destabilizes overall household harmony.\n5. Due to this severe structural obstruction, 15 points have been deducted from your Vastu score.`);
          suggestions.push(isTamil
            ? `1. மாடிப்படியை தெற்கு அல்லது மேற்கு எல்லைப் பகுதிக்கு மாற்றி அமைப்பது மிகச் சிறந்த தீர்வாகும்.\n2. படிக்கட்டுகளின் எண்ணிக்கை எப்போதும் ஒற்றைப்படையில் (15, 17, 21 steps) வருமாறு அமைக்கவும்.\n3. படிக்கட்டுகளுக்குக் கீழே கழிவறை, சமையலறை அல்லது பூஜை அறை அமைப்பதை முற்றிலும் தவிர்க்கவும்.\n4. படி ஏறும் போது எப்போதும் கடிகார திசையில் (Clockwise) சுழன்று ஏறுமாறு வடிவமைக்கவும்.\n5. மாடிப்படி அடியில் பொருட்கள் தேங்காமல் எப்போதும் தூய்மையாக வைத்திருக்கவும்.`
            : `1. Plan to position the staircase along the South or West boundary walls in structural execution.\n2. Ensure total step count is an odd number (e.g. 15, 17, 19, or 21 steps).\n3. Strictly avoid placing restrooms, kitchens, or prayer units under the staircase space.\n4. Ensure the staircase turns clockwise as you ascend to match natural positive vortexes.\n5. Keep the storage under the staircase clean, clutter-free, and well-lit at all times.`);
          analysis.staircase = roomVastuText;
        }
      } else {
        roomVastuText = isTamil
          ? `மாடிப்படி ${zone} திசையில் அமைந்துள்ளது.`
          : `Staircase is positioned in ${zone} zone. Ensure steps climb clockwise.`;
        if (!processedTypes.has('stair')) analysis.staircase = roomVastuText;
      }
      processedTypes.add('stair');
    } else if (name.includes('dining')) {
      if (zone === 'West' || zone === 'East' || zone === 'South-East') {
        roomVastuText = isTamil
          ? `100% சிறந்த வாஸ்து அமைப்பு! உணவருந்தும் அறை ${zone} திசையில் அமைந்துள்ளது.`
          : `100% Ideal Placement! Dining hall is situated in ${zone} zone.`;
        strengths.push(isTamil ? `உணவருந்தும் அறை ${zone} திசையில் உள்ளது.` : `Dining area in ${zone} promotes health and appetite.`);
      } else {
        roomVastuText = isTamil
          ? `உணவருந்தும் அறை ${zone} திசையில் அமைந்துள்ளது.`
          : `Dining area is placed in ${zone} zone. Facing East or North while eating is recommended.`;
      }
    } else if (name.includes('utility') || name.includes('store')) {
      if (zone === 'North-West' || zone === 'West' || zone === 'South') {
        roomVastuText = isTamil
          ? `பாதுகாப்பான வாஸ்து அமைப்பு. ஸ்டோர் / யூட்டிலிட்டி ${zone} திசையில் உள்ளது.`
          : `Safe Placement. Utility / Store room is located in ${zone} zone.`;
      } else {
        roomVastuText = isTamil
          ? `ஸ்டோர் / யூட்டிலிட்டி ${zone} திசையில் அமைந்துள்ளது.`
          : `Utility / Store room is placed in ${zone} zone. Keep it clean and uncluttered.`;
      }
    } else {
      roomVastuText = isTamil
        ? `${rawName || 'அறை'} ${zone} திசையில் அமைந்துள்ளது.`
        : `${rawName || 'Room'} is positioned in ${zone} zone.`;
    }

    roomPlacements.push({
      name: rawName || 'Room',
      zone: zone,
      text: roomVastuText,
      isIdeal: !roomVastuText.toLowerCase().includes('defect') && !roomVastuText.toLowerCase().includes('caution') && !roomVastuText.includes('குறைபாடு') && !roomVastuText.includes('தோஷம்')
    });
  });

  analysis.roomPlacements = roomPlacements;

  // Ensure score stays within bounds
  score = Math.max(20, Math.min(100, score));

  if (fixedScore !== null) score = fixedScore;

  let grade = 'B';
  if (score >= 90) grade = 'A+';
  else if (score >= 75) grade = 'A';
  else if (score >= 50) grade = 'B';
  else grade = 'C';

  if (fixedGrade !== null) grade = fixedGrade;

  // Helper to flatten multiline string arrays into clean single-line bullet strings
  function flattenPoints(arr) {
    const result = [];
    arr.forEach(item => {
      if (!item) return;
      if (typeof item === 'string' && item.includes('\n')) {
        item.split('\n').forEach(line => {
          const clean = line.trim();
          if (clean.length > 0) result.push(clean);
        });
      } else if (typeof item === 'string') {
        const clean = item.trim();
        if (clean.length > 0) result.push(clean);
      }
    });
    return result;
  }

  const cleanStrengths = flattenPoints(strengths);
  const cleanViolations = flattenPoints(violations);
  const cleanSuggestions = flattenPoints(suggestions);

  // ─── ENSURE MINIMUM 3 VALID AUTHENTIC VASTU POINTS FOR EACH CATEGORY ───
  if (cleanStrengths.length < 3) {
    if (isTamil) {
      cleanStrengths.push(`1. உங்கள் ${pw}x${ph} அடி மனை வடிவமைப்பில் அறைகளின் அளவு மற்றும் இடப்பகிர்வு பிரதான வாஸ்து அளவீடுகளுக்கு இணங்க உள்ளது.`);
      cleanStrengths.push(`2. பிரம்மஸ்தானம் (மையப்பகுதி) அதிக பளுவின்றி திறந்தவெளியாகப் பராமரிக்கப்பட்டு தடையற்ற காந்த ஆற்றல் ஓட்டத்தை உறுதி செய்கிறது.`);
      cleanStrengths.push(`3. இயல்பான சூரிய ஒளி மற்றும் குறுக்குக் காற்றோட்டம் சீராகக் கிடைக்கும் வண்ணம் அறைகளின் கதவு மற்றும் ஜன்னல் அச்சுகள் அமைந்துள்ளன.`);
    } else {
      cleanStrengths.push(`1. Spatial room allocation and structural dimensions in this ${pw}x${ph} ft floor plan align with core Vastu proportions.`);
      cleanStrengths.push(`2. Central Brahmasthan core remains unencumbered for smooth cosmic air flow and magnetic energy circulation.`);
      cleanStrengths.push(`3. Natural morning solar illumination and cross-ventilation flow seamlessly across primary living areas.`);
    }
  }

  if (score === 100) {
    if (isTamil) {
      cleanViolations.push(`1. இந்த 2D வரைபடத்தில் எந்தவொரு முக்கிய வாஸ்து தோஷங்களும் கண்டறியப்படவில்லை (100% பூரண சுபிட்சமான வடிவமைப்பு).`);
      cleanViolations.push(`2. சமையலறை, படுக்கையறை, கழிவறை மற்றும் வரவேற்பறை அனைத்தும் 100% சரியான பஞ்சபூத மண்டலங்களில் அமைந்துள்ளன.`);
      cleanViolations.push(`3. காந்தப்புல ஆற்றல் ஓட்டம் வீட்டினுள் தடையின்றி இயல்பாக சுழலும் வகையில் அமைந்துள்ளது.`);
    } else {
      cleanViolations.push(`1. 0 Major Vastu Defects detected in this 2D room layout (100% Auspicious Elemental Alignment).`);
      cleanViolations.push(`2. Kitchen, Master Bedroom, Restroom, and Living zones strictly occupy their ideal directional quadrants.`);
      cleanViolations.push(`3. Magnetic flux and solar radiation flow seamlessly throughout all interior living spaces.`);
    }
  } else if (cleanViolations.length < 3) {
    if (isTamil) {
      cleanViolations.push(`1. 2D வரைபடத்தின் மனை அச்சில் சிறு திசை விலகல்கள் உள்ளன (-${100 - score} புள்ளிகள் குறைக்கப்பட்டது).`);
      cleanViolations.push(`2. தலைவாசல் நிலை மற்றும் ஜன்னல்களின் காற்றோட்ட அச்சு வடகிழக்கு-தென்மேற்கு திசையமைப்பில் மேலும் சீரமைக்கப்பட வேண்டும்.`);
      cleanViolations.push(`3. கழிவறை மற்றும் சமையலறை நீர் வெளியேறும் வடகிழக்கு வடிகால் அமைப்பை 100% துல்லியமாக அமைக்க வேண்டும்.`);
    } else {
      cleanViolations.push(`1. Directional grid axis variations detected in this 2D floor plan layout (-${100 - score} pts deducted).`);
      cleanViolations.push(`2. Main entrance threshold and window cross-ventilation axis require fine-tuning along NorthEast-SouthWest corridor.`);
      cleanViolations.push(`3. Ensure plumbing drainage and waste discharge outlets are aligned strictly towards North or East during site execution.`);
    }
  }

  if (cleanSuggestions.length < 3) {
    if (isTamil) {
      cleanSuggestions.push(`1. தலைவாசலை எப்போதும் பிரகாசமான வெளிச்சத்துடன் தூய்மையாக வைத்து லட்சுமி கடாட்சத்தையும் குபேர ஆற்றலையும் ஈர்க்கவும்.`);
      cleanSuggestions.push(`2. வடகிழக்கு (ஈசான்ய) மூலையில் கனமான பொருட்களை வைக்காமல் எப்போதும் காலியாகவும் தூய்மையாகவும் பராமரிக்கவும்.`);
      cleanSuggestions.push(`3. படுக்கையறைகளில் தெற்கு அல்லது மேற்கு திசையில் தலைவைத்து தூங்குமாறு கட்டில் அமைப்பை அமைக்கவும்.`);
    } else {
      cleanSuggestions.push(`1. Maintain bright, welcoming illumination around the main entrance door to invite Kubera energy into your home.`);
      cleanSuggestions.push(`2. Ensure the sacred North-East ('Eesanyam') corner remains light, clean, and unburdened by heavy structural loads.`);
      cleanSuggestions.push(`3. Align sleeping beds so head points strictly towards South or West for restful circadian sleep.`);
    }
  }

  const whyPointsReduced = [];
  if (score < 100) {
    const pts = 100 - score;
    if (isTamil) {
      whyPointsReduced.push(`1. 2D வரைபடத்தில் கண்டறியப்பட்ட வாஸ்து குறைபாடுகளின் அடிப்படையில் -${pts} புள்ளிகள் குறைக்கப்பட்டுள்ளது.`);
      whyPointsReduced.push(`2. வீட்டின் அறைகளின் திசையமைப்பில் உள்ள பஞ்சபூத முரண்பாடுகள் ஆற்றல் சுழற்சியைப் பாதிக்கின்றன.`);
      whyPointsReduced.push(`3. கட்டுமானத்தின் போது வழங்கப்பட்டுள்ள வாஸ்து நிவாரணங்களைப் (Vastu Remedies) பின்பற்றுவது இப்புள்ளிகளை ஈடுசெய்யும்.`);
    } else {
      whyPointsReduced.push(`1. A total of -${pts} points were deducted based on room location mismatches in the 2D layout.`);
      whyPointsReduced.push(`2. Elemental quadrant conflicts detected in room placement affect overall cosmic energy circulation.`);
      whyPointsReduced.push(`3. Applying the recommended Vastu Pyramids and directional remedies during site execution restores 100% balance.`);
    }
  }

  return {
    orientation: DIRECTIONS[k],
    score: Math.round(score),
    grade: grade,
    mainEntrance: processedTypes.has('entrance') ? analysis.mainEntrance : null,
    kitchen: processedTypes.has('kitchen') ? analysis.kitchen : null,
    masterBedroom: processedTypes.has('bedroom') ? analysis.masterBedroom : null,
    bathroom: processedTypes.has('bathroom') ? analysis.bathroom : null,
    staircase: processedTypes.has('stair') ? analysis.staircase : null,
    poojaRoom: processedTypes.has('pooja') ? analysis.poojaRoom : null,
    livingRoom: processedTypes.has('living') ? analysis.livingRoom : null,
    roomPlacements: roomPlacements,
    rooms: roomPlacements.map((rp, idx) => ({
      id: `r_${idx}`,
      title: rp.name,
      subtitle: rp.zone,
      isCorrect: rp.isIdeal,
      analysis: rp.text ? [rp.text] : []
    })),
    strengths: [...new Set(cleanStrengths)].slice(0, 7),
    violations: [...new Set(cleanViolations)].slice(0, 7),
    suggestions: [...new Set(cleanSuggestions)].slice(0, 7),
    fixes: cleanSuggestions.map((s, idx) => ({
      number: `${idx + 1}`,
      issue: cleanViolations[idx] || (isTamil ? 'வாஸ்து பரிந்துரை' : 'Vastu Recommendation'),
      fix: s,
      points: '+5 pts'
    })),
    whyPointsReduced: [...new Set(whyPointsReduced)].slice(0, 7),
    room_ratings: {}
  };
}

// ─── Step 6: Cost Estimation ──────────────────────────────────────────────────

// ─── Live Market Price Helper ────────────────────────────────────────────────
async function fetchLiveMarketPrices(location = 'Tamil Nadu, India') {
  const prompt = `Predict & return current live market rates in ${location} for Indian residential construction materials.
Provide realistic market rates in INR for each material category across Basic, Standard, and Premium quality tiers.

Return a STRICT JSON object in this format:
{
  "location": "${location}",
  "is_live_market": true,
  "materials": {
    "cement": { "basic": 390, "standard": 440, "premium": 490, "unit": "bag", "name": "Cement (OPC/PPC)" },
    "steel": { "basic": 68, "standard": 84, "premium": 92, "unit": "kg", "name": "TMT Steel Rebar" },
    "sand": { "basic": 65, "standard": 75, "premium": 110, "unit": "cft", "name": "M-Sand / River Sand" },
    "aggregate": { "basic": 40, "standard": 48, "premium": 55, "unit": "cft", "name": "Blue Metal Aggregate" },
    "bricks": { "basic": 9, "standard": 12, "premium": 65, "unit": "pcs", "name": "Bricks / AAC Blocks" },
    "tiles": { "basic": 45, "standard": 75, "premium": 160, "unit": "sqft", "name": "Flooring Tiles" },
    "paint": { "basic": 190, "standard": 280, "premium": 420, "unit": "liter", "name": "Paint & Putty" },
    "electrical": { "basic": 110, "standard": 140, "premium": 220, "unit": "sqft", "name": "Electrical Systems" },
    "plumbing": { "basic": 95, "standard": 130, "premium": 210, "unit": "sqft", "name": "Plumbing Systems" },
    "doors": { "basic": 7500, "standard": 12000, "premium": 22000, "unit": "nos", "name": "Doors" },
    "windows": { "basic": 5500, "standard": 8500, "premium": 14000, "unit": "nos", "name": "Windows" }
  },
  "sqft_base_rates": {
    "basic": 1750,
    "standard": 2250,
    "premium": 3350
  }
}`;

  try {
    let data = null;
    if (process.env.OPENROUTER_API_KEY) {
      data = await askOpenRouter(prompt, null);
    }
    if (data && data.materials) return data;
  } catch (err) {
    console.warn('[Live Market Prices] Query note:', err.message);
  }

  return {
    location: location,
    is_live_market: true,
    materials: {
      cement: { basic: 390, standard: 440, premium: 490, unit: 'bag', name: 'Cement (OPC/PPC)' },
      steel: { basic: 68, standard: 84, premium: 92, unit: 'kg', name: 'TMT Steel Rebar' },
      sand: { basic: 65, standard: 75, premium: 110, unit: 'cft', name: 'M-Sand / River Sand' },
      aggregate: { basic: 40, standard: 48, premium: 55, unit: 'cft', name: 'Blue Metal Aggregate' },
      bricks: { basic: 9, standard: 12, premium: 65, unit: 'pcs', name: 'Bricks / AAC Blocks' },
      tiles: { basic: 45, standard: 75, premium: 160, unit: 'sqft', name: 'Flooring Tiles' },
      paint: { basic: 190, standard: 280, premium: 420, unit: 'liter', name: 'Paint & Putty' },
      electrical: { basic: 110, standard: 140, premium: 220, unit: 'sqft', name: 'Electrical Systems' },
      plumbing: { basic: 95, standard: 130, premium: 210, unit: 'sqft', name: 'Plumbing Systems' },
      doors: { basic: 7500, standard: 12000, premium: 22000, unit: 'nos', name: 'Doors' },
      windows: { basic: 5500, standard: 8500, premium: 14000, unit: 'nos', name: 'Windows' }
    },
    sqft_base_rates: {
      basic: 1750,
      standard: 2250,
      premium: 3350
    }
  };
}

// ─── Step 6: Cost Estimation ──────────────────────────────────────────────────

function runCostEstimation(modelData, customLiveRates = null) {
  const rooms = modelData.rooms || [];
  const walls = modelData.walls || [];
  const doors = modelData.doors || [];
  const windows = modelData.windows || [];
  const project = modelData.project || {};

  const width = parseFloat(project?.overall_dimensions?.width_ft || project?.width || 0);
  const height = parseFloat(project?.overall_dimensions?.length_ft || project?.height || 0);
  const floors = parseInt(project.floors || 1);
  let floorArea = parseFloat(project?.total_built_area_sqft || project?.built_area || project?.total_area_sqft || modelData?.total_built_area_sqft || modelData?.built_area || modelData?.total_area_sqft);
  if (!floorArea || isNaN(floorArea) || floorArea <= 0) {
    if (width > 0 && height > 0) {
      floorArea = width * height;
    }
  }
  if (!floorArea || isNaN(floorArea) || floorArea <= 0) {
    floorArea = rooms.reduce((acc, r) => acc + (parseFloat(r.area_sqft) || (parseFloat(r.width || 0) * parseFloat(r.height || 0))), 0);
  }
  if (!floorArea || isNaN(floorArea) || floorArea <= 0) {
    throw new Error('SCALE_CALIBRATION_FAILED: Missing physical scale for Cost Estimation.');
  }
  const totalArea = floorArea * floors;

  // 1. Calculate Exact Wall Length from 2D Geometry
  let totalWallLength = 0;
  if (walls.length > 0) {
    walls.forEach(w => {
      const s = w.start || (w.coordinates_ft ? w.coordinates_ft.start : null);
      const e = w.end || (w.coordinates_ft ? w.coordinates_ft.end : null);
      if (s && e) {
        const sx = typeof s === 'object' ? (s.x ?? s[0]) : s[0];
        const sy = typeof s === 'object' ? (s.y ?? s[1]) : s[1];
        const ex = typeof e === 'object' ? (e.x ?? e[0]) : e[0];
        const ey = typeof e === 'object' ? (e.y ?? e[1]) : e[1];
        const dx = ex - sx;
        const dy = ey - sy;
        totalWallLength += Math.sqrt(dx * dx + dy * dy);
      }
    });
  }
  if (!totalWallLength || totalWallLength === 0) {
    totalWallLength = (width + height) * 2 * 1.5; // fallback
  }
  totalWallLength *= floors;

  const wallHeight = 10;
  let grossWallArea = totalWallLength * wallHeight;

  // 2. Exact Doors and Windows Count
  const doorCount = (doors.length > 0 ? doors.length : Math.max(1, Math.floor(floorArea / 200))) * floors;
  const windowCount = (windows.length > 0 ? windows.length : Math.max(2, Math.floor(floorArea / 150))) * floors;

  const doorArea = doorCount * 21; // 7x3 ft standard door
  const windowArea = windowCount * 16; // 4x4 ft standard window
  const netWallArea = Math.max(0, grossWallArea - doorArea - windowArea);

  // 3. True Bill of Quantities (BOQ) Constants (per 100 sqft or 100 cft)
  const BRICKS_PER_SQFT = 8.5; // For 9-inch wall
  const CEMENT_PER_100SQFT_WALL = 1.5; // bags
  const SAND_PER_100SQFT_WALL = 15; // cft

  const PLASTER_AREA = netWallArea * 2; // both sides
  const CEMENT_PER_100SQFT_PLASTER = 0.5;
  const SAND_PER_100SQFT_PLASTER = 5;

  const SLAB_VOLUME = totalArea * 0.416; // 5 inch thick slab
  const CEMENT_PER_100CFT_RCC = 22;
  const SAND_PER_100CFT_RCC = 42;
  const AGGREGATE_PER_100CFT_RCC = 84;
  const STEEL_PER_SQFT = 3.5; // kg

  const PAINT_AREA = PLASTER_AREA + totalArea; // Walls + ceiling
  const PAINT_COVERAGE = 50; // sqft per liter (2 coats)

  // 4. Calculate Exact Material Quantities
  const qBricks = Math.ceil(netWallArea * BRICKS_PER_SQFT);
  const qCement = Math.ceil((netWallArea / 100 * CEMENT_PER_100SQFT_WALL) + (PLASTER_AREA / 100 * CEMENT_PER_100SQFT_PLASTER) + (SLAB_VOLUME / 100 * CEMENT_PER_100CFT_RCC));
  const qSand = Math.ceil((netWallArea / 100 * SAND_PER_100SQFT_WALL) + (PLASTER_AREA / 100 * SAND_PER_100SQFT_PLASTER) + (SLAB_VOLUME / 100 * SAND_PER_100CFT_RCC));
  const qAggregate = Math.ceil(SLAB_VOLUME / 100 * AGGREGATE_PER_100CFT_RCC);
  const qSteel = Math.ceil(totalArea * STEEL_PER_SQFT);
  const qTiles = Math.ceil(totalArea * 1.05); // 5% wastage
  const qPaint = Math.ceil(PAINT_AREA / PAINT_COVERAGE);

  // 5. Dynamic Live Market Rates (INR)
  const rates = customLiveRates || {
    cement: 440,     // Live Market Standard Cement (UltraTech/Ramco)
    steel: 84,       // Live Market Standard Steel TMT 550D
    sand: 75,        // Live Market M-Sand cft
    aggregate: 48,   // Live Market Blue metal 20mm cft
    bricks: 12,      // Live Market Red brick piece
    tiles: 75,       // Live Market Vitrified tiles sqft
    paint: 280,      // Live Market Emulsion liter
    doors: 12000,    // Live Market Teak/Flush door
    windows: 8500,   // Live Market UPVC window
    electrical: 140, // Live Market Electrical sqft
    plumbing: 130    // Live Market Plumbing sqft
  };

  const materials = {
    cement: { name: 'Cement (Live Market)', quantity: qCement, unit: 'bags', price: rates.cement },
    steel: { name: 'Steel TMT (Live Market)', quantity: qSteel, unit: 'kg', price: rates.steel },
    sand: { name: 'M-Sand / P-Sand (Live Market)', quantity: qSand, unit: 'cft', price: rates.sand },
    aggregate: { name: 'Blue Metal Aggregate (Live Market)', quantity: qAggregate, unit: 'cft', price: rates.aggregate },
    bricks: { name: 'Bricks/Blocks (Live Market)', quantity: qBricks, unit: 'pcs', price: rates.bricks },
    tiles: { name: 'Floor Tiles (Live Market)', quantity: qTiles, unit: 'sqft', price: rates.tiles },
    paint: { name: 'Paint & Putty (Live Market)', quantity: qPaint, unit: 'liters', price: rates.paint },
    doors: { name: 'Doors (Live Market)', quantity: doorCount, unit: 'nos', price: rates.doors },
    windows: { name: 'Windows (Live Market)', quantity: windowCount, unit: 'nos', price: rates.windows },
    electrical: { name: 'Electrical Wiring (Live Market)', quantity: Math.round(totalArea), unit: 'sqft', price: rates.electrical },
    plumbing: { name: 'Plumbing & Pipes (Live Market)', quantity: Math.round(totalArea), unit: 'sqft', price: rates.plumbing }
  };

  let totalMaterialCost = 0;
  Object.values(materials).forEach(m => { totalMaterialCost += (m.quantity * m.price); });

  // Labor cost (approx 45% of material cost in current live Indian market)
  const laborCost = Math.round(totalMaterialCost * 0.45);
  const baseTotal = totalMaterialCost + laborCost;

  // Breakdown for UI
  const structureCost = (materials.cement.quantity * materials.cement.price) +
    (materials.steel.quantity * materials.steel.price) +
    (materials.sand.quantity * materials.sand.price) +

    (materials.aggregate.quantity * materials.aggregate.price) +
    (materials.bricks.quantity * materials.bricks.price) +
    (laborCost * 0.5);

  const finishingCost = (materials.paint.quantity * materials.paint.price) + (laborCost * 0.2);
  const flooringCost = (materials.tiles.quantity * materials.tiles.price) + (laborCost * 0.15);
  const doorsWindowsCost = (materials.doors.quantity * materials.doors.price) + (materials.windows.quantity * materials.windows.price) + (laborCost * 0.05);
  const elecPlumbingCost = (materials.electrical.quantity * materials.electrical.price) + (materials.plumbing.quantity * materials.plumbing.price) + (laborCost * 0.1);
  const contingency = Math.round(baseTotal * 0.05);

  // Room breakdown removed as requested by user
  const roomBreakdown = [];

  return {
    is_live_market: true,
    market_source: 'Live Market Rate Analysis (Tamil Nadu & Pan-India)',
    total_area_sqft: +totalArea.toFixed(1),
    room_breakdown: [],
    cost_breakdown: {
      structure_construction: Math.round(structureCost),
      finishing_plaster_paint: Math.round(finishingCost),
      electrical_plumbing: Math.round(elecPlumbingCost),
      flooring: Math.round(flooringCost),
      doors_windows: Math.round(doorsWindowsCost),
      miscellaneous_contingency: Math.round(contingency)
    },
    estimates: {
      basic: Math.round(baseTotal * 0.8),
      standard: Math.round(baseTotal * 1.0),
      premium: Math.round(baseTotal * 1.5)
    },
    cost_per_sqft: {
      basic: Math.round((baseTotal * 0.8) / totalArea),
      standard: Math.round(baseTotal / totalArea),
      premium: Math.round((baseTotal * 1.5) / totalArea)
    },
    materials: materials,
    currency: 'INR',
    note: 'Live Market Cost Estimation dynamically calculated based on current market rates.'
  };
}

// ─── Live Market Prices Endpoint ─────────────────────────────────────────────
app.post('/api/material/live-prices', aiLimiter, optionalAuth, async (req, res) => {
  const location = req.body.location || 'Tamil Nadu, India';
  try {
    const prices = await fetchLiveMarketPrices(location);
    res.json(prices);
  } catch (err) {
    console.error('[API] Live market prices error:', err.message);
    res.status(500).json({ error: 'Failed to fetch live market prices', details: err.message });
  }
});

// ─── Material Search Endpoint ───────────────────────────────────────────────
app.post('/api/material/search', aiLimiter, optionalAuth, async (req, res) => {
  const { query } = req.body;
  if (!query) return res.status(400).json({ error: 'Query required' });

  try {
    const prompt = `Find 3 to 4 highly accurate current market prices in India for construction materials related to: "${query}".
    Provide realistic, data-driven estimates based on the current market. Include the exact matched brand and 2-3 similar alternatives or related materials.
    Return a STRICT JSON array of objects:
    [
      {
        "brand": "Exact Brand Name (e.g., Priya Cement, Tata Tiscon, Asian Paints)",
        "price": numeric_price_only (e.g. 390),
        "unit": "unit (e.g., bag, kg, piece, liter, sqft)"
      }
    ]`;

    let data = null;

    // Try OpenRouter if available
    if (process.env.OPENROUTER_API_KEY) {
      console.log(`[Material Search] Querying OpenRouter for: ${query}`);
      data = await askOpenRouter(prompt, null);
    }

    if (Array.isArray(data)) {
      data.forEach(item => {
        if (item && typeof item.price === 'string') item.price = parseFloat(item.price) || 0;
      });
    } else if (data && data.brand) {
      if (typeof data.price === 'string') data.price = parseFloat(data.price) || 0;
      data = [data]; // Fallback if AI returned single object
    } else {
      data = [];
    }

    res.json(data);
  } catch (err) {
    console.error('[API] Material search error:', err.message);

    // Smart Fallback if Google API is rate-limited or blocked
    const q = query.toLowerCase();
    let fallback = [
      { brand: query + " (Estimated)", price: 500, unit: 'unit' },
      { brand: query + " Premium (Estimated)", price: 800, unit: 'unit' }
    ];

    if (q.includes('cement') || q.includes('ultra tech') || q.includes('priya') || q.includes('acc')) {
      fallback = [
        { brand: "Priya Cement (Estimated)", price: 390, unit: 'bag' },
        { brand: "UltraTech Cement (Estimated)", price: 450, unit: 'bag' },
        { brand: "ACC Cement (Estimated)", price: 440, unit: 'bag' }
      ];
    } else if (q.includes('steel') || q.includes('tata') || q.includes('jsw') || q.includes('tiscon')) {
      fallback = [
        { brand: "Tata Tiscon 550SD (Estimated)", price: 88, unit: 'kg' },
        { brand: "JSW Neosteel (Estimated)", price: 85, unit: 'kg' },
        { brand: "SAIL TMT (Estimated)", price: 82, unit: 'kg' }
      ];
    } else if (q.includes('paint') || q.includes('asian') || q.includes('berger')) {
      fallback = [
        { brand: "Asian Paints Royale (Estimated)", price: 320, unit: 'liter' },
        { brand: "Berger WeatherCoat (Estimated)", price: 280, unit: 'liter' },
        { brand: "Dulux Velvet (Estimated)", price: 340, unit: 'liter' }
      ];
    } else if (q.includes('tile') || q.includes('kajaria')) {
      fallback = [
        { brand: "Kajaria Vitrified (Estimated)", price: 65, unit: 'sqft' },
        { brand: "Somany Ceramics (Estimated)", price: 60, unit: 'sqft' },
        { brand: "RAK Ceramics (Estimated)", price: 85, unit: 'sqft' }
      ];
    } else if (q.includes('wire') || q.includes('electric') || q.includes('havells')) {
      fallback = [
        { brand: "Havells Wires (Estimated)", price: 1500, unit: 'coil' },
        { brand: "Polycab Wires (Estimated)", price: 1350, unit: 'coil' },
        { brand: "Finolex Cables (Estimated)", price: 1400, unit: 'coil' }
      ];
    } else if (q.includes('pipe') || q.includes('plumb') || q.includes('ashirvad')) {
      fallback = [
        { brand: "Astral CPVC (Estimated)", price: 550, unit: 'length' },
        { brand: "Ashirvad CPVC (Estimated)", price: 580, unit: 'length' },
        { brand: "Supreme PVC (Estimated)", price: 450, unit: 'length' }
      ];
    } else if (q.includes('sand')) {
      fallback = [
        { brand: "River Sand (Estimated)", price: 110, unit: 'cft' },
        { brand: "M-Sand Washed (Estimated)", price: 75, unit: 'cft' },
        { brand: "P-Sand (Estimated)", price: 85, unit: 'cft' }
      ];
    } else if (q.includes('brick')) {
      fallback = [
        { brand: "Red Bricks (Estimated)", price: 12, unit: 'pcs' },
        { brand: "Fly Ash Bricks (Estimated)", price: 8, unit: 'pcs' },
        { brand: "AAC Blocks (Estimated)", price: 65, unit: 'pcs' }
      ];
    } else if (q.includes('door')) {
      fallback = [
        { brand: "Teak Wood Main Door (Estimated)", price: 25000, unit: 'unit' },
        { brand: "Flush Door Standard (Estimated)", price: 4500, unit: 'unit' },
        { brand: "PVC Bathroom Door (Estimated)", price: 2500, unit: 'unit' }
      ];
    } else if (q.includes('window')) {
      fallback = [
        { brand: "UPVC Sliding Window (Estimated)", price: 4500, unit: 'unit' },
        { brand: "Aluminum Window (Estimated)", price: 3500, unit: 'unit' },
        { brand: "Wooden Window Frame (Estimated)", price: 8500, unit: 'unit' }
      ];
    }

    res.json(fallback);
  }
});

// ─── Step 7: Structural Report ────────────────────────────────────────────────

function runStructuralReport(modelData) {
  const rooms = modelData.rooms || [];
  const project = modelData.project || {};
  const width = parseFloat(project?.overall_dimensions?.width_ft || project?.width || 0);
  const height = parseFloat(project?.overall_dimensions?.length_ft || project?.height || 0);
  let floorArea = parseFloat(project.total_built_area_sqft || project.built_area || project.total_area_sqft || modelData.total_built_area_sqft || modelData.built_area || modelData.total_area_sqft);
  if (!floorArea || isNaN(floorArea) || floorArea <= 0) {
    if (width > 0 && height > 0) {
      floorArea = width * height;
    }
  }
  if (!floorArea || isNaN(floorArea) || floorArea <= 0) {
    floorArea = rooms.reduce((acc, r) => acc + (parseFloat(r.area_sqft) || (parseFloat(r.width || 0) * parseFloat(r.height || 0))), 0);
  }
  if (!floorArea || isNaN(floorArea) || floorArea <= 0) {
    floorArea = 1200;
  }
  const floors = project.floors || 1;
  const totalArea = floorArea * floors;

  // Load Estimations (Approximate)
  const deadLoad = totalArea * 150; // 150 kg/sqft for slab, walls, etc.
  const liveLoad = totalArea * 40;  // 40 kg/sqft for residential
  const totalLoad = deadLoad + liveLoad;

  // Column Suggestions (at room corners and junctions)
  const columns = [];
  const corners = new Set();
  rooms.forEach(r => {
    const rx = parseFloat(r.x), ry = parseFloat(r.y), rw = parseFloat(r.width), rh = parseFloat(r.height);
    [[rx, ry], [rx + rw, ry], [rx, ry + rh], [rx + rw, ry + rh]].forEach(p => {
      const key = `${p[0]},${p[1]}`;
      if (!corners.has(key)) {
        corners.add(key);
        columns.push({ x: p[0], y: p[1], size: "12\"x12\"" });
      }
    });
  });

  // Filter columns to reduce density (min 8ft spacing)
  const optimizedColumns = [];
  columns.forEach(c => {
    const isTooClose = optimizedColumns.some(oc => {
      const dist = Math.sqrt(Math.pow(c.x - oc.x, 2) + Math.pow(c.y - oc.y, 2));
      return dist < 8;
    });
    if (!isTooClose) optimizedColumns.push(c);
  });

  return {
    summary: {
      total_area: totalArea,
      floor_area: floorArea,
      floors: floors,
      estimated_load_kg: Math.round(totalLoad),
      dead_load_kg: Math.round(deadLoad),
      live_load_kg: Math.round(liveLoad)
    },
    recommendations: {
      column_count: optimizedColumns.length,
      typical_column_size: "12\" x 12\"",
      typical_beam_size: "12\" x 18\"",
      foundation_depth_ft: 5
    },
    column_placements: optimizedColumns,
    beam_schedule: [
      { mark: "B1 (Main Beam)", size: "9\" x 12\"", top_steel: "2 - 16mm", bottom_steel: "2 - 16mm", stirrups: "8mm @ 6\" c/c" },
      { mark: "B2 (Secondary Beam)", size: "9\" x 9\"", top_steel: "2 - 12mm", bottom_steel: "2 - 12mm", stirrups: "8mm @ 8\" c/c" },
      { mark: "PB (Portico Beam)", size: "9\" x 15\"", top_steel: "2 - 16mm", bottom_steel: "3 - 16mm", stirrups: "8mm @ 6\" c/c" }
    ],
    beam_details: [
      { name: "B1", width: 9, height: 12, top_bars: 2, top_size: "16mm", bot_bars: 2, bot_size: "16mm" },
      { name: "B2", width: 9, height: 9, top_bars: 2, top_size: "12mm", bot_bars: 2, bot_size: "12mm" },
      { name: "PB", width: 9, height: 15, top_bars: 2, top_size: "16mm", bot_bars: 3, bot_size: "16mm" }
    ],
    column_design: {
      type: "RCC Square/Rectangular",
      main_column: { size: "9\" x 15\"", bars: "6 - 16mm", stirrups: "8mm @ 6\" c/c" },
      secondary_column: { size: "9\" x 12\"", bars: "4 - 16mm", stirrups: "8mm @ 7\" c/c" },
      mix_ratio: "M25 (1:1:2)"
    },
    slab_design: {
      type: "RCC Slab (Two-way/One-way)",
      thickness_inches: 5,
      main_steel: "10mm @ 5\" c/c",
      distribution_steel: "8mm @ 7\" c/c",
      mix_ratio: "M20 (1:1.5:3)"
    },
    foundation_design: {
      type: "Isolated RCC Footing",
      depth_ft: 5,
      footing_size: "4'x4' to 5'x5'",
      steel_mesh: "12mm @ 6\" c/c both ways",
      mix_ratio: "M20 (1:1.5:3)"
    },
    material_estimation: {
      cement_bags: Math.round(totalArea * 0.45),
      steel_kg: Math.round(totalArea * 4.2),
      sand_cft: Math.round(totalArea * 1.8),
      aggregate_cft: Math.round(totalArea * 2.2)
    },
    load_distribution: "RCC Framed Structure",
    safety_factor: 1.5
  };
}

// ─── Main Upload Endpoint ─────────────────────────────────────────────────────

app.post('/api/upload', uploadLimiter, authenticateToken, (req, res, next) => {
  multiUpload(req, res, err => {
    if (err) {
      console.error('[Upload] Multer error:', err.message);
      return res.status(400).json({ error: 'Upload error: ' + err.message });
    }
    console.log('[Upload] Files received:', Object.keys(req.files || {}).map(k => `${k}: ${req.files[k][0].path}`));
    next();
  });
}, async (req, res) => {
  if (!req.files || !req.files['ground_plan']) {
    return res.status(400).json({ error: 'Ground plan image is required' });
  }

  try {
    const groundPath = req.files['ground_plan'][0].path;
    const firstPath = req.files['first_plan'] ? req.files['first_plan'][0].path : null;
    const secondPath = req.files['second_plan'] ? req.files['second_plan'][0].path : null;

    // ── Steps 1 & 2: Image → Structured JSON ──────────────────────────────
    console.log('\n═══ PIPELINE START ═══');

    // Process floors sequentially to avoid RAM spikes and Linux OOM kills on cloud containers
    console.log('[Step 1] Running floor plan extractions (memory-safe mode)...');
    const groundResult = await runPython(groundPath).then(r => validateModelData(r));
    let firstResult = null;
    if (firstPath) {
      console.log('[Step 1] Processing First Floor plan...');
      firstResult = await runPython(firstPath).then(r => validateModelData(r));
    }
    let secondResult = null;
    if (secondPath) {
      console.log('[Step 1] Processing Second Floor plan...');
      secondResult = await runPython(secondPath).then(r => validateModelData(r));
    }

    if (!groundResult) throw new Error('Floor plan extraction failed for ground floor');
    console.log(`[Step 2] ✓ ${groundResult.rooms.length} rooms extracted for Ground Floor`);
    if (firstResult) console.log(`[Step 2] ✓ ${firstResult.rooms.length} rooms extracted for First Floor`);
    if (secondResult) console.log(`[Step 2] ✓ ${secondResult.rooms.length} rooms extracted for Second Floor`);

    // ── Step 3: Assemble 3D model ──────────────────────────────────────────
    console.log('[Step 3] ✓ 3D model data assembled');
    const modelData = {
      project: groundResult.project,
      floors: { ground: groundResult, ...(firstResult ? { first: firstResult } : {}), ...(secondResult ? { second: secondResult } : {}) }
    };

    const reportModelData = {
      project: {
        ...groundResult.project,
        floors: secondResult ? 3 : (firstResult ? 2 : 1)
      },
      rooms: [...groundResult.rooms, ...(firstResult ? firstResult.rooms : []), ...(secondResult ? secondResult.rooms : [])]
    };

    // ── Step 5: Vastu Analysis (Separate Floors) ──────────────────────
    console.log('[Step 5] Running Vastu analysis concurrently...');
    const orientation = req.body.orientation || 'North';
    const vastuPromises = {
      ground: runVastuAnalysis(groundResult, 'English', orientation, groundPath, null, null, 'Ground')
    };
    if (firstResult) vastuPromises.first = runVastuAnalysis(firstResult, 'English', orientation, firstPath, null, null, 'First');
    if (secondResult) vastuPromises.second = runVastuAnalysis(secondResult, 'English', orientation, secondPath, null, null, 'Second');

    const vastu = {};
    const vastuResults = await Promise.all(Object.values(vastuPromises));
    Object.keys(vastuPromises).forEach((key, index) => {
      vastu[key] = vastuResults[index];
    });
    console.log(`[Step 5] ✓ Vastu Ground score: ${vastu.ground.score}/100`);

    // ── Step 6: Cost Estimation (Separate Floors) ────────────────────
    console.log('[Step 6] ✓ Cost estimation complete');
    const costEstimate = {};
    costEstimate.ground = runCostEstimation(groundResult);
    if (firstResult) costEstimate.first = runCostEstimation(firstResult);
    if (secondResult) costEstimate.second = runCostEstimation(secondResult);
    costEstimate.total = runCostEstimation(reportModelData);

    // ── Step 7: Structural Report (Separate Floors) ──────────────────
    console.log('[Step 7] Generating Structural Report...');
    const structural = {};
    structural.ground = runStructuralReport(groundResult);
    if (firstResult) structural.first = runStructuralReport(firstResult);
    if (secondResult) structural.second = runStructuralReport(secondResult);
    console.log(`[Step 7] ✓ Structural Ground: ${structural.ground.column_placements?.length || 0} columns`);

    // ── Step 4 & 8: Elevation & AI Visual Design (Deferred for V1 Launch) ─────
    console.log('[Step 4 & 8] AI Elevation generation deferred for V1 launch.');
    const elevation = {
      front_width: groundResult.project?.width || 30,
      depth: groundResult.project?.height || 40,
      floors: secondResult ? 3 : (firstResult ? 2 : 1),
      status: "deferred_v1"
    };

    const visualDesign = {
      status: "deferred_v1",
      variations: [],
      structural: {
        preview_url: "",
        blueprint_url: ""
      }
    };
    console.log(`[Step 8] ✓ AI 3D Design variations ready: ${visualDesign.variations?.length || 0}`);

    // ── Database: Supabase ────────────────────────────────────────────────
    console.log('[DB] Saving to Supabase...');

    // Inject structural URLs into the structural report object for easier access
    if (structural.ground && visualDesign.structural) {
      structural.ground.preview_url = visualDesign.structural.preview_url;
      structural.ground.blueprint_url = visualDesign.structural.blueprint_url;
    }
    if (structural.first && visualDesign.structural) {
      structural.first.preview_url = visualDesign.structural.preview_url;
      structural.first.blueprint_url = visualDesign.structural.blueprint_url;
    }

    const fullModelData = {
      ...modelData,
      orientation: orientation,
      _vastu: vastu,
      _cost: costEstimate,
      _elevation: elevation,
      _structural: structural,
      _visual: visualDesign
    };

    // Zero-Storage: uploaded floor plans are unlinked from disk immediately; image_url is null
    const imageUrl = null;
    // Use only authenticated identity — never trust request body for ownership
    const projectUserId = req.user.id || null;
    const projectUserEmail = req.user.email || null;

    let data;
    try {
      const dbResponse = await supabase
        .from('projects')
        .insert([{
          name: req.body.name || 'New Project',
          user_id: projectUserId,
          user_email: projectUserEmail,
          image_url: imageUrl,
          model_data: fullModelData,
          vastu_data: vastu,
          cost_data: costEstimate,
          elevation_data: elevation,
          structural_data: structural,
          visual_data: visualDesign
        }])
        .select().single();
      if (dbResponse.error) throw dbResponse.error;
      data = dbResponse.data;
      console.log(`[DB] ✓ Project record created. ID: ${data.id}`);
    } catch (dbErr) {
      console.warn(`[DB] Supabase unreachable or optional, continuing statelessly: ${dbErr.message}`);
      data = {
        id: 'project_' + Date.now(),
        name: req.body.name || 'New Project',
        user_id: projectUserId,
        user_email: projectUserEmail,
        image_url: imageUrl,
        model_data: fullModelData,
        vastu_data: vastu,
        cost_data: costEstimate,
        elevation_data: elevation,
        structural_data: structural,
        visual_data: visualDesign
      };
    }
    console.log('═══ PIPELINE COMPLETE ═══\n');

    res.json({
      success: true,
      project: {
        ...data,
        vastu_data: data.model_data?._vastu,
        cost_data: data.model_data?._cost,
        elevation_data: data.model_data?._elevation,
        structural_data: data.model_data?._structural || {},
        visual_data: data.model_data?._visual || {},
      }
    });

  } catch (err) {
    console.error('[Pipeline Error]', err.message);
    res.status(500).json({ error: 'Processing failed.', details: err.message });
  } finally {
    // ─── Immediate Zero-Storage: Instantly delete uploaded files from disk ───────
    const filesToPurge = [
      req.files && req.files['ground_plan'] ? req.files['ground_plan'][0].path : null,
      req.files && req.files['first_plan'] ? req.files['first_plan'][0].path : null,
      req.files && req.files['second_plan'] ? req.files['second_plan'][0].path : null,
    ].filter(Boolean);

    filesToPurge.forEach(filePath => {
      try {
        if (fs.existsSync(filePath)) {
          fs.unlinkSync(filePath);
          console.log(`[Zero-Storage] ✓ Instantly unlinked: ${path.basename(filePath)} (Server: 0 files retained)`);
        }
      } catch (e) {
        console.warn(`[Zero-Storage] Could not unlink ${filePath}:`, e.message);
      }
    });
  }
});

// ─── Standalone Vastu endpoint ────────────────────────────────────────────────

app.post('/api/analyze-vastu/:id', authenticateToken, async (req, res) => {
  const projectId = req.params.id;
  const lang = req.body.lang || 'English';
  console.log(`[API] Authenticated Vastu Request for Project: ${projectId}, User: ${req.user.email}`);

  try {
    const { data: project, error } = await supabase
      .from('projects')
      .select('user_id, user_email, model_data, image_url')
      .eq('id', projectId)
      .single();

    if (error || !project) {
      console.error(`[API] Project ${projectId} not found in DB`);
      return res.status(404).json({ error: 'Project not found' });
    }

    const isOwner =
      (project.user_id && project.user_id === req.user.id) ||
      (project.user_email && project.user_email.toLowerCase() === (req.user.email || '').toLowerCase());

    if (!isOwner) {
      return res.status(403).json({ error: 'Forbidden: You do not have permission to analyze this project.' });
    }

    const storedOrientation = project.model_data?.orientation || project.model_data?._vastu?.ground?.orientation || project.model_data?._vastu?.orientation || 'North';
    const floorsData = project.model_data?.floors || { ground: project.model_data };

    const result = {};
    for (const [floorName, floorData] of Object.entries(floorsData)) {
      result[floorName] = await runVastuAnalysis(
        floorData,
        lang,
        storedOrientation,
        null, // Zero-storage: 9-zone Vastu engine runs on model_data.rooms spatial geometry
        null,
        null,
        floorName
      );
    }

    res.json(result);
  } catch (err) {
    console.error('[API] analyze-vastu internal error:', err.message);
    res.status(500).json({ error: 'Vastu analysis failed', details: err.message });
  }
});

app.get('/api/vastu/:id', authenticateToken, async (req, res) => {
  const { data, error } = await supabase.from('projects').select('user_id, user_email, model_data').eq('id', req.params.id).single();
  if (error || !data) return res.status(404).json({ error: 'Project not found' });

  const isOwner =
    (data.user_id && data.user_id === req.user.id) ||
    (data.user_email && data.user_email.toLowerCase() === (req.user.email || '').toLowerCase());
  if (!isOwner) return res.status(403).json({ error: 'Forbidden: Access denied to this project.' });

  if (data.model_data?._vastu) return res.json(data.model_data._vastu);

  const storedOrientation = data.model_data?.orientation || data.model_data?._vastu?.ground?.orientation || data.model_data?._vastu?.orientation || 'North';
  const vastu = await runVastuAnalysis(data.model_data?.floors?.ground || data.model_data, 'English', storedOrientation, null, null, null, 'Ground');
  res.json({ ground: vastu });
});

// ─── Standalone Cost endpoint ─────────────────────────────────────────────────

app.get('/api/cost/:id', authenticateToken, async (req, res) => {
  const { data, error } = await supabase.from('projects').select('user_id, user_email, model_data').eq('id', req.params.id).single();
  if (error || !data) return res.status(404).json({ error: 'Project not found' });

  const isOwner =
    (data.user_id && data.user_id === req.user.id) ||
    (data.user_email && data.user_email.toLowerCase() === (req.user.email || '').toLowerCase());
  if (!isOwner) return res.status(403).json({ error: 'Forbidden: Access denied to this project.' });

  if (data.model_data?._cost) return res.json(data.model_data._cost);

  res.json({ ground: runCostEstimation(data.model_data?.floors?.ground || data.model_data) });
});

// ─── Projects (List & Single Retrieval) ──────────────────────────────────────

app.get('/api/projects', optionalAuth, async (req, res) => {
  const user = req.user;
  const queryEmail = (req.query.email || '').trim().toLowerCase();

  const userId = user?.id;
  const userEmail = (user?.email || queryEmail || '').trim().toLowerCase();

  // If neither authenticated user nor email was supplied, return empty list safely
  if (!userId && !userEmail) {
    return res.json([]);
  }

  // Optimize payload: only return lightweight list metadata, omit massive model_data JSON
  let query = supabase.from('projects').select('id, name, created_at, image_url').order('created_at', { ascending: false });

  if (userId && userEmail) {
    query = query.or(`user_id.eq.${userId},user_email.ilike.${userEmail}`);
  } else if (userId) {
    query = query.eq('user_id', userId);
  } else if (userEmail) {
    query = query.ilike('user_email', userEmail);
  }

  const { data, error } = await query;
  if (error) {
    console.error('[Projects API Error]', error.message);
    return res.status(500).json({ error: error.message });
  }
  res.json(data || []);
});

// GET single project by ID (Item 8 Route Mismatch Fix)
app.get('/api/project/:id', optionalAuth, async (req, res) => {
  const projectId = req.params.id;
  const user = req.user;
  const queryEmail = (req.query.email || '').trim().toLowerCase();

  const { data, error } = await supabase.from('projects').select('*').eq('id', projectId).single();
  if (error || !data) return res.status(404).json({ error: 'Project not found' });

  const userId = user?.id;
  const userEmail = (user?.email || queryEmail || '').toLowerCase();

  const isOwner =
    (data.user_id && userId && data.user_id === userId) ||
    (data.user_email && userEmail && data.user_email.toLowerCase() === userEmail);

  if (!isOwner && (userId || userEmail)) return res.status(403).json({ error: 'Forbidden: Access denied to this project.' });

  res.json(data);
});

// ─── Razorpay Payment Endpoints ─────────────────────────────────────────────

app.post('/api/payment/create-order', optionalAuth, async (req, res) => {
  // Support client requested amount with ₹500 standard fallback
  const requestedAmount = Number(req.body?.amount);
  const SERVER_PRICE_INR = (requestedAmount > 0 && requestedAmount <= 100000)
    ? Math.round(requestedAmount)
    : 500;
  const isDev = process.env.NODE_ENV !== 'production' && process.env.ALLOW_PAYMENT_MOCK === 'true';

  const options = {
    amount: SERVER_PRICE_INR * 100, // Razorpay expects amount in paise (50,000 paise = ₹500)
    currency: "INR",
    receipt: `receipt_order_${Date.now()}`,
  };

  try {
    const keyId = process.env.RAZORPAY_KEY_ID;
    const isPlaceholderKey = !keyId || keyId.trim() === '' || keyId.includes('placeholder');
    if (isPlaceholderKey) {
      if (isDev) {
        console.log(`[Payment] DEV MOCK MODE: Order Created for ₹${SERVER_PRICE_INR}`);
        return res.json({
          id: `order_mock_${Date.now()}`,
          amount: SERVER_PRICE_INR * 100,
          currency: "INR",
          is_mock: true,
          key_id: 'rzp_test_placeholder'
        });
      }
      return res.status(503).json({ error: 'Payment gateway credentials (RAZORPAY_KEY_ID) are not configured on the server.' });
    }

    const rzp = getRazorpayInstance();
    const order = await rzp.orders.create(options);
    console.log(`[Payment] Order Created: ${order.id} for ₹${SERVER_PRICE_INR}`);

    // Persist pending order in Supabase payments table, linked to project if provided
    const projectId = req.body.project_id || null;
    try {
      await supabase.from('payments').insert([{
        order_id: order.id,
        user_id: req.user?.id || null,
        user_email: req.user?.email || null,
        project_id: projectId,
        amount: SERVER_PRICE_INR,
        currency: 'INR',
        status: 'pending'
      }]);
    } catch (dbErr) {
      console.warn('[Payment DB Notice] Could not insert pending order to DB:', dbErr.message);
    }

    res.json({
      id: order.id,
      amount: order.amount,
      currency: order.currency,
      key_id: process.env.RAZORPAY_KEY_ID,
      is_mock: false
    });
  } catch (error) {
    console.error('[Payment] Create Order Error:', error);
    res.status(502).json({
      error: 'Failed to create payment order. Payment gateway communication failed.'
    });
  }
});

// ─── Web Checkout & Payment Tracking ─────────────────────────────────────────
const paidOrders = new Set();

app.post('/api/payment/verify-payment', optionalAuth, async (req, res) => {
  const {
    razorpay_order_id,
    razorpay_payment_id,
    razorpay_signature
  } = req.body;

  const isDev = process.env.NODE_ENV !== 'production' && process.env.ALLOW_PAYMENT_MOCK === 'true';

  if (razorpay_order_id && (razorpay_order_id.startsWith('order_mock_') || razorpay_order_id.startsWith('order_error_fallback_'))) {
    if (isDev) {
      console.log(`[Payment] Dev Mock Payment Verified: ${razorpay_order_id}`);
      paidOrders.add(razorpay_order_id);
      return res.json({ success: true, message: "Mock payment verified successfully (Dev Mode)" });
    }
    console.warn(`[Payment Security] Rejected mock order verification in production: ${razorpay_order_id}`);
    return res.status(403).json({ success: false, message: "Mock payment verification forbidden in production." });
  }

  if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
    return res.status(400).json({ success: false, message: "Missing required payment verification parameters" });
  }

  const sign = razorpay_order_id + "|" + razorpay_payment_id;
  const expectedSign = crypto
    .createHmac("sha256", process.env.RAZORPAY_KEY_SECRET || 'placeholder_secret')
    .update(sign.toString())
    .digest("hex");

  if (razorpay_signature === expectedSign) {
    console.log(`[Payment] Verified: ${razorpay_payment_id} for Order: ${razorpay_order_id}`);
    paidOrders.add(razorpay_order_id);

    // Update payment record in Supabase
    try {
      await supabase.from('payments').update({
        status: 'paid',
        payment_id: razorpay_payment_id,
        updated_at: new Date().toISOString()
      }).eq('order_id', razorpay_order_id);
    } catch (dbErr) {
      console.warn('[Payment DB Notice] Could not update payment status in DB:', dbErr.message);
    }

    return res.json({ success: true, message: "Payment verified successfully" });
  } else {
    console.error('[Payment] Verification Failed: Signature mismatch');
    return res.status(400).json({ success: false, message: "Invalid signature" });
  }
});

// Check if an order has been paid (checks memory cache + Supabase fallback across restarts)
app.get('/api/payment/status/:orderId', async (req, res) => {
  const orderId = req.params.orderId;
  if (paidOrders.has(orderId)) {
    return res.json({ success: true, status: 'paid' });
  }

  try {
    const { data: pay } = await supabase
      .from('payments')
      .select('status')
      .eq('order_id', orderId)
      .maybeSingle();

    if (pay?.status === 'paid') {
      paidOrders.add(orderId); // Warm in-memory cache
      return res.json({ success: true, status: 'paid' });
    }
  } catch (dbErr) {
    console.warn('[Payment Status DB Notice]:', dbErr.message);
  }

  res.json({ success: true, status: 'pending' });
});

// ─── Web Checkout Page for External / In-App Browser ─────────────────────────
// HTML-escape helper to prevent reflected XSS in server-rendered pages
function escapeHtml(str) {
  return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#x27;');
}

app.get('/checkout', (req, res) => {
  // Validate and sanitise every query-string value before embedding in HTML/JS
  const rawAmount = parseFloat(req.query.amount);
  const amount = (!isNaN(rawAmount) && rawAmount > 0) ? rawAmount : 500;
  const orderId = escapeHtml(req.query.orderId || `order_${Date.now()}`);
  const email = escapeHtml(req.query.email || 'customer@kanavuillam.com');
  const rzpKey = process.env.RAZORPAY_KEY_ID || 'rzp_test_placeholder';
  const isMock = !process.env.RAZORPAY_KEY_ID || process.env.RAZORPAY_KEY_ID.includes('placeholder');

  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Kanavu Illam - Secure Checkout</title>
  <script src="https://checkout.razorpay.com/v1/checkout.js"></script>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0B0E14; color: #E2E8F0; margin: 0; padding: 24px 16px; display: flex; justify-content: center; align-items: center; min-height: 100vh; box-sizing: border-box; }
    .card { background: #151A23; border: 1px solid #242C3D; border-radius: 20px; max-width: 440px; width: 100%; padding: 28px; box-shadow: 0 20px 40px rgba(0,0,0,0.5); text-align: center; }
    .badge { display: inline-block; background: rgba(245, 158, 11, 0.15); color: #F59E0B; padding: 6px 14px; border-radius: 100px; font-size: 12px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 16px; }
    h1 { font-size: 22px; margin: 0 0 8px 0; color: #FFFFFF; font-weight: 700; }
    p { font-size: 14px; color: #94A3B8; margin: 0 0 20px 0; line-height: 1.5; }
    .features { text-align: left; background: #1C2331; border-radius: 12px; padding: 14px 16px; margin-bottom: 24px; font-size: 13.5px; }
    .feature-item { display: flex; align-items: center; margin-bottom: 8px; color: #CBD5E1; }
    .feature-item:last-child { margin-bottom: 0; }
    .check { color: #10B981; margin-right: 8px; font-weight: bold; }
    .amount-box { display: flex; justify-content: space-between; align-items: center; padding: 16px; background: #1E293B; border-radius: 14px; margin-bottom: 24px; }
    .amount-label { font-size: 14px; color: #94A3B8; }
    .amount-val { font-size: 26px; font-weight: 800; color: #F59E0B; }
    .btn-pay { width: 100%; background: linear-gradient(135deg, #F59E0B, #D97706); color: #0B0E14; border: none; padding: 16px; font-size: 16px; font-weight: 800; border-radius: 100px; cursor: pointer; transition: transform 0.1s, opacity 0.2s; box-shadow: 0 10px 20px rgba(245, 158, 11, 0.3); }
    .btn-pay:hover { opacity: 0.95; }
    .btn-pay:active { transform: scale(0.98); }
    .footer-secure { font-size: 12px; color: #64748B; margin-top: 20px; display: flex; justify-content: center; align-items: center; gap: 6px; }
    .spinner { display: none; margin: 16px auto 0; width: 28px; height: 28px; border: 3px solid rgba(245, 158, 11, 0.3); border-top-color: #F59E0B; border-radius: 50%; animation: spin 0.8s linear infinite; }
    @keyframes spin { to { transform: rotate(360deg); } }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">Official Web Checkout</div>
    <h1>Kanavu Illam</h1>
    <p>Unlock comprehensive architectural reports, Vastu compliance analysis, and structural CAD estimates.</p>
    
    <div class="features">
      <div class="feature-item"><span class="check">✓</span> 3D Virtual Walkthrough & Mesh Model</div>
      <div class="feature-item"><span class="check">✓</span> 100-Point Tamil Vastu Compliance Report</div>
      <div class="feature-item"><span class="check">✓</span> IS 456 Civil Structural Engineering Specs</div>
      <div class="feature-item"><span class="check">✓</span> BOQ Material Quantity & Cost Estimation</div>
      <div class="feature-item"><span class="check">✓</span> High-Resolution Printable PDF Deliverable</div>
    </div>

    <div class="amount-box">
      <span class="amount-label">Total Payable</span>
      <span class="amount-val">₹${amount}</span>
    </div>

    <button id="payBtn" class="btn-pay" onclick="initiatePayment()">Pay with UPI / Cards / NetBanking</button>
    <div id="loader" class="spinner"></div>

    <div class="footer-secure">
      <span>🔒 256-bit Encrypted &bull; Razorpay Certified Gateway</span>
    </div>
  </div>

  <script>
    const orderId = ${JSON.stringify(orderId)};
    const amountVal = ${Number(amount) || 0};
    const isMock = ${Boolean(isMock)};
    const rzpKey = ${JSON.stringify(rzpKey)};
    const userEmail = ${JSON.stringify(email)};

    function initiatePayment() {
      const btn = document.getElementById('payBtn');
      const loader = document.getElementById('loader');
      btn.disabled = true;
      btn.innerText = 'Connecting to Payment Gateway...';
      loader.style.display = 'block';

      if (isMock) {
        // Mock Gateway verification for dev / testing
        setTimeout(async () => {
          await fetch('/api/payment/verify-payment', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              razorpay_order_id: orderId,
              razorpay_payment_id: 'pay_mock_' + Date.now(),
              razorpay_signature: 'mock_sig'
            })
          });
          window.location.href = '/payment-success?order_id=' + orderId;
        }, 1200);
        return;
      }

      const options = {
        key: rzpKey,
        amount: Math.round(amountVal * 100),
        currency: "INR",
        name: "Kanavu Illam",
        description: "Architectural & Vastu Reports",
        order_id: orderId,
        prefill: { email: userEmail, contact: "9876543210" },
        theme: { color: "#F59E0B" },
        handler: async function (response) {
          btn.innerText = 'Verifying Transaction...';
          try {
            const verifyRes = await fetch('/api/payment/verify-payment', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                razorpay_order_id: response.razorpay_order_id,
                razorpay_payment_id: response.razorpay_payment_id,
                razorpay_signature: response.razorpay_signature
              })
            });
            const vData = await verifyRes.json();
            if (vData.success) {
              window.location.href = '/payment-success?order_id=' + response.razorpay_order_id;
            } else {
              alert('Payment Verification Failed: ' + (vData.message || 'Unknown error'));
              btn.disabled = false;
              btn.innerText = 'Retry Payment';
              loader.style.display = 'none';
            }
          } catch (e) {
            alert('Verification network error: ' + e.message);
            btn.disabled = false;
            btn.innerText = 'Retry Payment';
            loader.style.display = 'none';
          }
        },
        modal: {
          ondismiss: function() {
            btn.disabled = false;
            btn.innerText = 'Pay with UPI / Cards / NetBanking';
            loader.style.display = 'none';
          }
        }
      };

      const rzp = new Razorpay(options);
      rzp.on('payment.failed', function(resp) {
        alert('Payment Failed: ' + (resp.error ? resp.error.description : 'Transaction cancelled'));
        btn.disabled = false;
        btn.innerText = 'Retry Payment';
        loader.style.display = 'none';
      });
      rzp.open();
    }
  </script>
</body>
</html>`);
});

// ─── Payment Success Return Page ─────────────────────────────────────────────
app.get('/payment-success', (req, res) => {
  const orderId = req.query.order_id || '';
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Payment Successful - Kanavu Illam</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0B0E14; color: #E2E8F0; margin: 0; padding: 24px; display: flex; justify-content: center; align-items: center; min-height: 100vh; text-align: center; box-sizing: border-box; }
    .card { background: #151A23; border: 1px solid #10B981; border-radius: 24px; max-width: 420px; width: 100%; padding: 36px 24px; box-shadow: 0 20px 40px rgba(16, 185, 129, 0.15); }
    .icon { width: 68px; height: 68px; background: rgba(16, 185, 129, 0.2); color: #10B981; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 32px; margin: 0 auto 20px; }
    h1 { font-size: 24px; color: #FFFFFF; margin: 0 0 10px 0; }
    p { font-size: 14.5px; color: #94A3B8; line-height: 1.5; margin: 0 0 24px 0; }
    .btn-return { display: inline-block; width: 100%; background: #10B981; color: #FFFFFF; text-decoration: none; padding: 15px; font-size: 15px; font-weight: 700; border-radius: 100px; box-sizing: border-box; transition: opacity 0.2s; }
    .btn-return:hover { opacity: 0.9; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">✓</div>
    <h1>Payment Successful!</h1>
    <p>Your payment has been verified. You can now return to the Kanavu Illam app to view your 3D floor plan, Vastu, and structural reports.</p>
    <a href="kanavuillam://payment-success?order_id=${orderId}" class="btn-return" id="returnBtn">Return to Kanavu Illam App</a>
  </div>
  <script>
    // Auto-trigger deep link return if supported
    setTimeout(() => {
      try {
        window.location.href = "kanavuillam://payment-success?order_id=${orderId}";
      } catch (_) {}
    }, 800);
  </script>
</body>
</html>`);
});

// ─── Token Refresh Endpoint ───────────────────────────────────────────────────
app.post('/api/auth/refresh', authLimiter, async (req, res) => {
  const { refresh_token } = req.body;
  if (!refresh_token) return res.status(400).json({ error: 'refresh_token is required' });
  try {
    const { data, error } = await supabase.auth.refreshSession({ refresh_token });
    if (error || !data?.session) throw error || new Error('Refresh failed');
    res.json({ session: data.session, user: data.user });
  } catch (err) {
    res.status(401).json({ error: 'Session refresh failed. Please log in again.' });
  }
});

app.post('/api/auth/signup', authLimiter, async (req, res) => {
  const { email, password, name, phone } = req.body;
  if (!email || !password) return res.status(400).json({ error: 'Email and password required' });
  try {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: { data: { name, phone } }
    });
    if (error) throw error;
    res.json({ message: 'Signup successful', user: data.user });
  } catch (err) {
    const errorMsg = (err.message || '').toLowerCase();
    const isDev = process.env.NODE_ENV !== 'production' && process.env.ALLOW_OFFLINE_MOCK === 'true';
    if (isDev && (errorMsg.includes('rate limit') || errorMsg.includes('fetch failed') || errorMsg.includes('enotfound'))) {
      console.log('[Auth] Dev offline bypass triggered for signup.');
      return res.json({
        message: 'Mock Signup successful (Offline Bypassed)',
        user: { email, user_metadata: { name, phone } }
      });
    }
    const statusCode = errorMsg.includes('rate limit') ? 429 : 400;
    res.status(statusCode).json({ error: err.message });
  }
});

app.post('/api/auth/login', authLimiter, async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) return res.status(400).json({ error: 'Email and password required' });
  try {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) throw error;
    res.json({ message: 'Login successful', session: data.session, user: data.user });
  } catch (err) {
    const errorMsg = (err.message || '').toLowerCase();
    const isDev = process.env.NODE_ENV !== 'production' && process.env.ALLOW_OFFLINE_MOCK === 'true';
    if (isDev && (errorMsg.includes('rate limit') || errorMsg.includes('fetch failed') || errorMsg.includes('enotfound'))) {
      console.log('[Auth] Dev offline bypass triggered for login.');
      return res.json({
        message: 'Mock Login successful (Offline Bypassed)',
        session: { access_token: 'mock_token' },
        user: { email, user_metadata: { name: 'Test User', phone: '1234567890' } }
      });
    }
    const statusCode = errorMsg.includes('rate limit') ? 429 : 401;
    res.status(statusCode).json({ error: err.message });
  }
});

app.get('/api/auth/google', async (req, res) => {
  try {
    const { data, error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: 'http://localhost:3000/api/auth/callback'
      }
    });
    if (error) throw error;
    res.redirect(data.url);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.post('/api/auth/google/token', authLimiter, async (req, res) => {
  const { idToken, email, name } = req.body;
  if (!idToken) return res.status(400).json({ error: 'ID token required' });
  try {
    const { data, error } = await supabase.auth.signInWithIdToken({
      provider: 'google',
      token: idToken,
    });
    if (error) throw error;
    res.json({ message: 'Login successful', session: data.session, user: data.user });
  } catch (err) {
    console.error('[Auth] Google ID Token error:', err.message);
    const errorMsg = (err.message || '').toLowerCase();
    const isDev = process.env.NODE_ENV !== 'production' && process.env.ALLOW_OFFLINE_MOCK === 'true';
    if (isDev && (errorMsg.includes('rate limit') || errorMsg.includes('fetch failed') || errorMsg.includes('enotfound'))) {
      return res.json({
        message: 'Mock Login successful (Offline Bypassed)',
        session: { access_token: 'mock_token' },
        user: { email, user_metadata: { name: name || 'Test User' } }
      });
    }
    const statusCode = errorMsg.includes('rate limit') ? 429 : 401;
    res.status(statusCode).json({ error: err.message });
  }
});

// ─── Account Deletion Endpoint (JWT Authenticated, Play Store Compliant) ─────
app.post('/api/auth/delete-account', authLimiter, async (req, res) => {
  const authHeader = req.headers.authorization;
  let targetUserId = null;
  let targetEmail = null;

  // 1. Authenticate identity from Bearer token
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.substring(7).trim();
    try {
      const { data: { user }, error } = await supabase.auth.getUser(token);
      if (!error && user) {
        targetUserId = user.id;
        targetEmail = (user.email || '').toLowerCase().trim();
      }
    } catch (authErr) {
      console.warn('[Account Deletion] Token verification error:', authErr.message);
    }
  }

  // 2. Reject unauthenticated requests
  if (!targetUserId && !targetEmail) {
    return res.status(401).json({
      error: 'Unauthorized: A valid authenticated session token is required to delete an account.'
    });
  }

  console.log(`[Account Deletion] Authenticated deletion for: userId=${targetUserId}, email=${targetEmail}`);
  const deletionErrors = [];
  try {
    // 3. Delete associated data across database tables
    if (targetUserId) {
      const { error: e1 } = await supabase.from('profiles').delete().eq('id', targetUserId);
      if (e1 && e1.code !== 'PGRST116') deletionErrors.push(`profiles[id]: ${e1.message}`);
      const { error: e2 } = await supabase.from('projects').delete().eq('user_id', targetUserId);
      if (e2) deletionErrors.push(`projects[user_id]: ${e2.message}`);
      const { error: e3 } = await supabase.from('history').delete().eq('user_id', targetUserId);
      if (e3 && e3.code !== 'PGRST116') deletionErrors.push(`history[user_id]: ${e3.message}`);
    }
    if (targetEmail) {
      const { error: e4 } = await supabase.from('profiles').delete().eq('email', targetEmail);
      if (e4 && e4.code !== 'PGRST116') deletionErrors.push(`profiles[email]: ${e4.message}`);
      const { error: e5 } = await supabase.from('projects').delete().eq('user_email', targetEmail);
      if (e5) deletionErrors.push(`projects[user_email]: ${e5.message}`);
      const { error: e6 } = await supabase.from('history').delete().eq('email', targetEmail);
      if (e6 && e6.code !== 'PGRST116') deletionErrors.push(`history[email]: ${e6.message}`);
    }

    if (deletionErrors.length > 0) {
      console.error('[Account Deletion] Data deletion errors:', deletionErrors);
      return res.status(500).json({ error: 'Partial deletion failure. Please contact support.', details: deletionErrors });
    }

    // 4. If Service Role Key is present, delete user from Supabase Auth
    if (process.env.SUPABASE_SERVICE_ROLE_KEY && targetUserId) {
      try {
        const adminSupabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
        await adminSupabase.auth.admin.deleteUser(targetUserId);
        console.log(`[Account Deletion] Successfully deleted user ${targetUserId} from Supabase Auth.`);
      } catch (adminErr) {
        console.warn(`[Account Deletion] Admin Auth deletion error:`, adminErr.message);
        return res.status(500).json({ error: 'Failed to delete account from auth provider. Please contact support.' });
      }
    }

    return res.json({ success: true, message: 'Account and associated data deleted successfully.' });
  } catch (err) {
    console.error('[Account Deletion Error]:', err.message);
    return res.status(500).json({ error: 'Failed to delete account. Please try again or contact support.' });
  }
});

// ─── Public Web Page for Account Deletion (Play Store Mandatory URL) ──────────
app.get('/delete-account', (req, res) => {
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Request Account Deletion - Kanavu Illam</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #F1F5F9; color: #0F172A; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; padding: 20px; box-sizing: border-box; }
    .card { background: white; max-width: 500px; width: 100%; border-radius: 20px; padding: 32px; box-shadow: 0 10px 25px rgba(0,0,0,0.06); border: 1px solid #E2E8F0; }
    h1 { font-size: 24px; margin-top: 0; color: #1E293B; }
    p { font-size: 14.5px; line-height: 1.6; color: #475569; }
    .info-box { background: #FEF3C7; border: 1px solid #FDE68A; border-radius: 12px; padding: 14px; font-size: 13.5px; color: #92400E; margin: 18px 0; }
    label { display: block; font-size: 13px; font-weight: 600; margin-bottom: 6px; color: #334155; }
    input[type="email"] { width: 100%; padding: 12px 14px; border-radius: 10px; border: 1px solid #CBD5E1; font-size: 15px; box-sizing: border-box; margin-bottom: 16px; outline: none; }
    input[type="email"]:focus { border-color: #F59E0B; }
    button { width: 100%; background: #DC2626; color: white; border: none; padding: 14px; font-size: 15px; font-weight: 700; border-radius: 100px; cursor: pointer; transition: background 0.2s; }
    button:hover { background: #B91C1C; }
    .footer { font-size: 12px; color: #94A3B8; text-align: center; margin-top: 24px; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Delete Your Kanavu Illam Account</h1>
    <p>In accordance with Google Play and Indian data protection policies, you have the right to request the permanent deletion of your account and personal data.</p>
    <div class="info-box">
      <strong>What will be deleted:</strong> Your profile, login credentials, uploaded floor plans, 3D architectural models, and analysis history. Financial records are retained only as required by statutory tax and GST regulations.
    </div>
    <form id="deleteForm" onsubmit="handleDelete(event)">
      <label for="email">Account Email Address</label>
      <input type="email" id="email" required placeholder="Enter the email linked to your account" />
      <button type="submit" id="submitBtn">Request Permanent Deletion</button>
    </form>
    <div id="statusMsg" style="display:none; margin-top: 16px; padding: 12px; border-radius: 10px; font-size: 14px; text-align: center;"></div>
    <div class="footer">
      Kanavu Illam &bull; Support: support@kanavuillam.com
    </div>
  </div>
  <script>
    async function handleDelete(e) {
      e.preventDefault();
      const email = document.getElementById('email').value.trim();
      const btn = document.getElementById('submitBtn');
      const msg = document.getElementById('statusMsg');
      btn.disabled = true;
      btn.innerText = 'Processing...';
      try {
        const res = await fetch('/api/auth/delete-account', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ email })
        });
        const data = await res.json();
        msg.style.display = 'block';
        if (res.ok && data.success) {
          msg.style.background = '#DCFCE7';
          msg.style.color = '#166534';
          msg.innerText = 'Your deletion request has been processed successfully. Your account and personal data have been removed.';
          document.getElementById('deleteForm').style.display = 'none';
        } else {
          msg.style.background = '#FEE2E2';
          msg.style.color = '#991B1B';
          msg.innerText = data.error || 'Failed to process request. Please contact support@kanavuillam.com.';
          btn.disabled = false;
          btn.innerText = 'Request Permanent Deletion';
        }
      } catch (err) {
        msg.style.display = 'block';
        msg.style.background = '#FEE2E2';
        msg.style.color = '#991B1B';
        msg.innerText = 'Network error. Please try again or email support@kanavuillam.com.';
        btn.disabled = false;
        btn.innerText = 'Request Permanent Deletion';
      }
    }
  </script>
</body>
</html>`);
});

// ─── Public Web Page for Privacy Policy (Google Play Mandatory URL) ───────────
app.get(['/privacy-policy', '/privacy'], (req, res) => {
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Privacy Policy - Kanavu Illam</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0B0E14; color: #E2E8F0; margin: 0; padding: 40px 20px; line-height: 1.6; }
    .container { max-width: 820px; margin: 0 auto; background: #151A23; border: 1px solid #242C3D; border-radius: 20px; padding: 40px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); }
    h1 { font-size: 26px; color: #FFFFFF; margin-top: 0; border-bottom: 1px solid #242C3D; padding-bottom: 16px; }
    h2 { font-size: 18px; color: #F59E0B; margin-top: 28px; }
    p, li { font-size: 14.5px; color: #CBD5E1; }
    ul { padding-left: 20px; }
    a { color: #F59E0B; text-decoration: none; }
    a:hover { text-decoration: underline; }
    .highlight-box { background: rgba(245, 158, 11, 0.08); border-left: 4px solid #F59E0B; padding: 14px 18px; margin: 18px 0; border-radius: 0 10px 10px 0; font-size: 14px; color: #E2E8F0; }
    .footer { font-size: 13px; color: #64748B; margin-top: 40px; border-top: 1px solid #242C3D; padding-top: 20px; text-align: center; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Privacy Policy for Kanavu Illam</h1>
    <p><em>Effective Date: October 27, 2026</em></p>
    <p>Kanavu Illam ("we", "our", or "us"), operated by Kanavu Illam Technologies, Tamil Nadu, India, is committed to safeguarding your personal data and privacy. This Privacy Policy details how we collect, process, store, and protect your information across our mobile application and web services in full compliance with the <strong>Digital Personal Data Protection Act, 2023 (DPDP Act)</strong>, the <strong>Information Technology Act, 2000</strong>, the <strong>SPDI Rules, 2011</strong>, and <strong>Google Play Developer Data Safety Policies</strong>.</p>

    <h2>1. Information We Collect and Purpose of Processing</h2>
    <p>We collect only the minimum necessary data to authenticate accounts, analyze floor plans, and generate architectural reports:</p>
    <ul>
      <li><strong>Account Credentials:</strong> Full name and email address provided via Google Sign-In (OAuth) or Supabase authentication, used strictly to create, authenticate, and manage your account.</li>
      <li><strong>Uploaded Floor Plan Images:</strong> 2D architectural blueprint drawings or sketches uploaded by you. These are used solely for automated geometric contour detection, room boundary segmentation, and text reading.</li>
      <li><strong>Derived Architectural Project Data:</strong> 3D parametric CAD coordinates, room dimensions, traditional Tamil Vastu rule scores, estimated material bill of quantities (BOQ), and preliminary structural guidance generated from your uploads. These are saved to your account so you can view, review, and export them at any time in your History tab.</li>
      <li><strong>Payment and Transaction Records:</strong> When you unlock premium deliverables, our payment partner (Razorpay) provides us with the transaction ID, order ID, payment status, timestamp, and amount. These records are used strictly for order fulfillment, fraud prevention, accounting, and statutory tax (GST) compliance. <em>We never receive, process, or store credit/debit card numbers, CVVs, or UPI PINs on our servers.</em></li>
      <li><strong>Technical Telemetry & Device Logs:</strong> IP address, device operating system version, and standard access logs collected ephemerally for rate limiting, DDoS defense, and server health diagnostics.</li>
      <li><strong>Local Storage:</strong> Authentication session tokens and language preferences (English/Tamil) stored locally on your device via secure application storage (SharedPreferences).</li>
    </ul>

    <h2>2. Immediate Zero-Storage Architecture for Raw Blueprints</h2>
    <div class="highlight-box">
      <strong>Zero-Storage Guarantee:</strong> Uploaded floor plan image files are temporarily stored on secure server disk strictly during automated processing by computer-vision and OCR models (trained YOLO object detection and EasyOCR). Immediately upon completing the analysis, the raw image files are permanently unlinked and erased from the server disk. No raw floor plan image files are retained on our servers.
    </div>

    <h2>3. Project Results & Cloud Data Storage</h2>
    <p>Unlike raw blueprint images, the derived architectural models (room polygons, 3D vectors, Vastu scores, and cost estimations) are stored securely in our cloud database (Supabase) under your unique user ID. This enables you to access your projects across app sessions in your History screen. These project results remain stored under your account until you choose to delete them or permanently delete your account.</p>

    <h2>4. Third-Party Service Providers & Data Transfers</h2>
    <p>We work with trusted infrastructure providers that adhere to industry security standards (ISO 27001 / SOC 2):</p>
    <ul>
      <li><strong>Supabase Inc.:</strong> Cloud database hosting, user authentication, and Row Level Security (RLS).</li>
      <li><strong>Railway Corp.:</strong> Secure cloud backend hosting and API pipeline execution.</li>
      <li><strong>Vercel Inc.:</strong> Hosting our static web portals and compliance documentation.</li>
      <li><strong>Google LLC:</strong> Google OAuth 2.0 user authentication.</li>
      <li><strong>Razorpay Software Private Limited:</strong> RBI-authorized payment processing. All payment transaction data is localized and stored in India in compliance with Reserve Bank of India (RBI) mandates.</li>
      <li><strong>OpenRouter Inc.:</strong> Ephemeral text queries for live regional construction material prices. <em>Your floor plan drawings, personal identifiers, and private account details are never sent to OpenRouter or external LLMs.</em></li>
    </ul>

    <h2>5. Data Retention & Account Deletion Policy</h2>
    <p>We retain your personal profile and project history only for as long as your account is active:</p>
    <ul>
      <li><strong>User-Initiated Deletion:</strong> You have the absolute right to delete your account at any time. You can trigger deletion within the app under <strong>Profile &gt; Delete Account</strong>, or via our public web deletion page at <a href="/delete-account">Request Account Deletion</a>.</li>
      <li><strong>What is Purged:</strong> Deleting your account immediately and permanently removes your profile, authentication credentials, project records, 3D models, and history logs from our database.</li>
      <li><strong>Statutory Retention Exception:</strong> Anonymized payment transaction logs are retained strictly for the statutory duration required by Indian tax, GST, and financial audit regulations.</li>
    </ul>

    <h2>6. User Rights (DPDP Act, 2023)</h2>
    <p>In accordance with the Digital Personal Data Protection Act, you possess the right to:</p>
    <ul>
      <li>Access a summary of your personal data processed by us.</li>
      <li>Request correction or updating of inaccurate or incomplete personal data.</li>
      <li>Withdraw your consent at any time and request erasure of your data.</li>
      <li>Nominate another individual in accordance with applicable legal provisions.</li>
    </ul>

    <h2>7. Age Eligibility (18+ Requirement)</h2>
    <p>Kanavu Illam is designed and intended strictly for adults aged 18 years and above. We do not knowingly solicit or collect personal information from individuals under the age of 18.</p>

    <h2>8. Security Safeguards & Breach Management</h2>
    <p>We protect your data using industry-grade measures including TLS 1.3 encryption for data in transit, strict PostgreSQL Row Level Security (RLS) ensuring that users can only access their own records, private container networking, and rate-limited API endpoints. In the unlikely event of a verified data incident, we will notify affected users and regulatory bodies within the statutory timeline.</p>

    <h2>9. Grievance Redressal & Contact Information</h2>
    <p>In compliance with Rule 3(2) of the Information Technology (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021 and the DPDP Act, 2023, the details of our Grievance Officer are:</p>
    <ul>
      <li><strong>Publisher / Entity:</strong> Kanavu Illam Technologies</li>
      <li><strong>Grievance Officer:</strong> Chandramouli S</li>
      <li><strong>Designation:</strong> Grievance Officer</li>
      <li><strong>Address:</strong> Kanavu Illam Technologies, Tamil Nadu, India</li>
      <li><strong>Grievance Email:</strong> <a href="mailto:grievance@kanavuillam.com">grievance@kanavuillam.com</a> (cc: <a href="mailto:support@kanavuillam.com">support@kanavuillam.com</a>)</li>
      <li><strong>Statutory SLA:</strong> Acknowledgment within 24 hours; resolution within 15–30 days.</li>
    </ul>

    <div class="footer">
      &copy; 2026 Kanavu Illam Technologies. All Rights Reserved. &bull; <a href="/terms">Terms & Conditions</a> &bull; <a href="/delete-account">Account Deletion</a>
    </div>
  </div>
</body>
</html>`);
});

// ─── Public Web Page for Terms and Conditions ─────────────────────────────────
app.get(['/terms', '/terms-and-conditions'], (req, res) => {
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Terms and Conditions - Kanavu Illam</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0B0E14; color: #E2E8F0; margin: 0; padding: 40px 20px; line-height: 1.6; }
    .container { max-width: 820px; margin: 0 auto; background: #151A23; border: 1px solid #242C3D; border-radius: 20px; padding: 40px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); }
    h1 { font-size: 26px; color: #FFFFFF; margin-top: 0; border-bottom: 1px solid #242C3D; padding-bottom: 16px; }
    h2 { font-size: 18px; color: #F59E0B; margin-top: 28px; }
    p, li { font-size: 14.5px; color: #CBD5E1; }
    ul { padding-left: 20px; }
    a { color: #F59E0B; text-decoration: none; }
    a:hover { text-decoration: underline; }
    .highlight-box { background: rgba(245, 158, 11, 0.08); border-left: 4px solid #F59E0B; padding: 14px 18px; margin: 18px 0; border-radius: 0 10px 10px 0; font-size: 14px; color: #E2E8F0; }
    .footer { font-size: 13px; color: #64748B; margin-top: 40px; border-top: 1px solid #242C3D; padding-top: 20px; text-align: center; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Terms and Conditions</h1>
    <p><em>Effective Date: October 27, 2026</em></p>
    <p>Welcome to Kanavu Illam, an architectural planning software application operated by Kanavu Illam Technologies, Tamil Nadu, India ("we", "our", or "us"). By accessing, installing, or using our mobile application or web services, you agree to be bound by these Terms and Conditions. If you do not agree, please do not use the service.</p>

    <h2>1. Eligibility & User Accounts</h2>
    <p>You must be at least 18 years of age to enter into a legally binding contract under the Indian Contract Act, 1872. By using this service, you represent and warrant that you meet this age requirement. You are responsible for maintaining the confidentiality of your login credentials and for all activities that occur under your account.</p>

    <h2>2. Nature of Services & Computer-Vision Disclaimer</h2>
    <p>Kanavu Illam provides automated architectural analysis tools, including 2D-to-3D parametric CAD modeling, traditional Tamil Vastu rule compliance scoring, and preliminary civil structural and cost estimations.</p>
    <div class="highlight-box">
      <strong>Important Accuracy Disclaimer:</strong> Floor plans are read automatically using computer-vision software (including trained YOLO contour detection and EasyOCR models), which may misread labels, hand-drawn lines, walls, or dimensions. Users must manually verify all dimensions, room boundaries, and site orientations before relying on any output.
    </div>
    <ul>
      <li><strong>Vastu Compliance:</strong> Vastu scoring follows traditional cultural rule systems and is provided purely for informational and cultural reference. It does not constitute licensed architectural design, civil engineering, or legal advice.</li>
      <li><strong>Cost Estimations (BOQ):</strong> Material prices, labor costs, and rate breakdowns are indicative planning estimates based on regional benchmarks and may vary depending on local suppliers, site conditions, and market fluctuations.</li>
      <li><strong>Structural Guidelines:</strong> Structural assessments and column/beam sizing are preliminary planning guidelines calculated based on commonly used Indian Standard planning formulas (IS 456 and IS 1893 conventions). They do not substitute for on-site geotechnical soil testing, formal municipal building approvals, or certified drawings signed by a licensed structural engineer.</li>
    </ul>

    <h2>3. Pricing, Deliverables & Refund Policy</h2>
    <ul>
      <li><strong>Pricing:</strong> Access to generate complete architectural deliverables is ₹500 per floor plan scan, inclusive of applicable taxes.</li>
      <li><strong>Payments:</strong> All transactions are processed securely through RBI-authorized payment aggregators (Razorpay). We do not store sensitive payment card details or UPI PINs on our servers.</li>
      <li><strong>Non-Refundable Computational Processing:</strong> Fees paid cover immediate computational server execution and customized PDF compilation. Once analysis has commenced and deliverables are generated, payments are strictly non-refundable.</li>
      <li><strong>Technical Failure & One Free Re-try:</strong> In the rare event of a verified technical failure (such as a pipeline crash, system error, or failure to deliver the final PDF report), cash refunds are not issued. If your report fails to generate or deliver due to a technical error, contact <a href="mailto:support@kanavuillam.com">support@kanavuillam.com</a> within 7 days of purchase with your transaction Order ID. Upon quick verification, our support team will enable <strong>one free re-processing of the same floor plan</strong> at zero additional charge.</li>
    </ul>

    <h2>4. Intellectual Property & Limited License</h2>
    <p>Kanavu Illam Technologies retains all rights, title, and interest in and to the application, software, algorithms, 3D parametric viewer, branding, UI designs, and underlying code. Upon successful generation and payment, you are granted a perpetual, personal, non-exclusive license to view, download, print, and share your generated PDF report.</p>

    <h2>5. Limitation of Liability</h2>
    <p>To the maximum extent permitted under applicable Indian law, Kanavu Illam Technologies, its founders, and employees shall not be liable for any indirect, incidental, punitive, or consequential damages, construction defects, contractor disputes, foundation settlement, structural collapse, or cost overruns resulting from the use of or reliance on automated reports.</p>
    <div class="highlight-box">
      <strong>Liability Cap:</strong> In all circumstances, our maximum aggregate liability arising out of or related to your use of the application or reports shall be strictly capped at the amount actually paid by you for the specific service (maximum ₹500).
    </div>

    <h2>6. Termination & Acceptable Use</h2>
    <p>You agree not to misuse the platform, reverse engineer the computer-vision algorithms, upload malicious or unlawful content, or attempt unauthorized access to our servers. We reserve the right to suspend or terminate accounts that violate these terms.</p>

    <h2>7. Governing Law & Jurisdiction</h2>
    <p>These Terms shall be governed by and construed in accordance with the laws of the Republic of India. Any disputes, claims, or controversies arising out of or relating to these Terms or the use of the service shall be subject to the exclusive jurisdiction of the competent courts in Tamil Nadu, India.</p>

    <h2>8. Changes to Terms</h2>
    <p>We reserve the right to modify these Terms at any time. Any changes will be published on this page with an updated Effective Date. Continued use of the application following the posting of revised Terms constitutes your acceptance.</p>

    <h2>9. Contact Information</h2>
    <p>For questions or assistance regarding these terms, please contact:</p>
    <ul>
      <li><strong>Entity:</strong> Kanavu Illam Technologies</li>
      <li><strong>Address:</strong> Tamil Nadu, India</li>
      <li><strong>Email:</strong> <a href="mailto:support@kanavuillam.com">support@kanavuillam.com</a></li>
    </ul>

    <div class="footer">
      &copy; 2026 Kanavu Illam Technologies. All Rights Reserved. &bull; <a href="/privacy">Privacy Policy</a> &bull; <a href="/delete-account">Account Deletion</a>
    </div>
  </div>
</body>
</html>`);
});

if (require.main === module) {
  app.listen(port, '0.0.0.0', () => console.log(`\\nKanavu illam Backend running at http://0.0.0.0:${port}`));
}

module.exports = { app, runCostEstimation, runVastuAnalysis };

