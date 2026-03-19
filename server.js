import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { scoreRoute, fetchFeaturesFlat, adaptiveScenicWeight } from './scenic/scorer.js';
import { fetchRoute, fetchLoop } from './routing/graphhopper.js';
import { geocode } from './routing/geocoder.js';
import { fetchGraph, nearestNode, pathToGeoJSON, pathDistance, estimateDuration, getBbox } from './routing/graph-builder.js';
import { scenicAStar } from './scenic/panoramic-astar.js';
import { loadBikeLanes, bikeLaneStats } from './routing/bike-lanes.js';
import { loadTrees, treeStats } from './routing/trees.js';

const app       = express();
const PORT      = process.env.PORT || 3001;
const __dirname = dirname(fileURLToPath(import.meta.url));

// ── CORS ──────────────────────────────────────────────────────
const ALLOWED = [
  'http://localhost:3001',
  'http://127.0.0.1:3001',
  /^https:\/\/.+\.ngrok-free\.app$/,
  /^https:\/\/.+\.ngrok\.io$/,
];
app.use(cors({
  origin: (origin, cb) => {
    if (!origin) return cb(null, true);
    const ok = ALLOWED.some(o => typeof o === 'string' ? o === origin : o.test(origin));
    cb(ok ? null : new Error('CORS: origin not allowed'), ok);
  },
}));
app.use(express.json({ limit: '1mb' }));
app.use(express.static(join(__dirname, 'public')));

// ── Rate limiter — 30 req / IP / minute ──────────────────────
const rateLimiter = (() => {
  const counts = new Map();
  setInterval(() => counts.clear(), 60_000);
  return (req, res, next) => {
    const ip = req.ip || 'unknown';
    const n  = (counts.get(ip) || 0) + 1;
    counts.set(ip, n);
    if (n > 30) return res.status(429).json({ error: 'Too many requests — slow down' });
    next();
  };
})();
app.use('/api', rateLimiter);

// ── resolveCoords ─────────────────────────────────────────────
// Use pre-locked autocomplete coords when available.
// Fall back to geocoding the address text otherwise.
async function resolveCoords(coords, text, token) {
  if (Array.isArray(coords) && coords.length === 2) return coords;
  return geocode(text, token);
}

// ── buildBreakdown ────────────────────────────────────────────
// Normalise scorer output into a consistent breakdown object.
// All six categories always present, default 0 when unavailable.
function buildBreakdown(s) {
  return {
    nature:       s.nature       ?? 0,
    architecture: s.architecture ?? 0,
    water:        s.water        ?? 0,
    quiet:        s.quiet        ?? 0,
    bike:         s.bike         ?? 0,
    visual:       s.visual       ?? 0,
  };
}

// ── GET /api/config ───────────────────────────────────────────
app.get('/api/config', (req, res) => {
  const token = process.env.MAPBOX_TOKEN;
  if (!token) return res.status(404).json({ error: 'MAPBOX_TOKEN not set in .env' });
  res.json({ mapboxToken: token });
});

// ── GET /api/health ───────────────────────────────────────────
app.get('/api/health', (req, res) => {
  res.json({
    status:    'ok',
    app:       'Yugen API',
    token:     process.env.MAPBOX_TOKEN ? '✓ loaded' : '✗ missing',
    mapillary: process.env.MAPILLARY_TOKEN ? '✓ loaded' : '○ not set',
    bikeLanes: bikeLaneStats.total > 0
      ? `✓ ${bikeLaneStats.total} segments (${bikeLaneStats.greenways} greenways)`
      : '○ loading…',
    trees: treeStats.total > 0
      ? `✓ ${treeStats.total.toLocaleString()} trees`
      : '○ fetching from NYC Open Data (runs once, then cached)',
  });
});

// ── POST /api/route ───────────────────────────────────────────
// OSRM fastest path + Overpass scenic score. Fallback endpoint.
app.post('/api/route', async (req, res) => {
  const { origin, destination, mode = 'walk', weights } = req.body;
  const token = req.body.mapboxToken || process.env.MAPBOX_TOKEN;
  if (!origin || !destination)
    return res.status(400).json({ error: 'origin and destination required' });
  if (!token)
    return res.status(400).json({ error: 'No Mapbox token' });
  try {
    console.log(`[Route] "${origin}" → "${destination}" (${mode})`);
    const [oc, dc] = await Promise.all([
      resolveCoords(req.body.originCoords, origin, token),
      resolveCoords(req.body.destCoords,   destination, token),
    ]);
    const route  = await fetchRoute(oc, dc, mode);
    const scenic = await scoreRoute(route.coords, weights, process.env.MAPILLARY_TOKEN);
    res.json({
      route:        { geometry: route.geometry, distance: route.distance, duration: route.duration },
      scenicScore:  scenic.composite,
      breakdown:    buildBreakdown(scenic),
      highlights:   scenic.highlights,
      description:  scenic.description,
      scoreDrivers: scenic.scoreDrivers,
    });
  } catch (err) {
    console.error('[Route error]', err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── POST /api/loop ────────────────────────────────────────────
// OSRM triangle loop + Overpass scenic score.
app.post('/api/loop', async (req, res) => {
  const { origin, distanceMeters, mode = 'walk', seed = 0, weights } = req.body;
  const token = req.body.mapboxToken || process.env.MAPBOX_TOKEN;
  if (!origin)         return res.status(400).json({ error: 'origin required' });
  if (!distanceMeters) return res.status(400).json({ error: 'distanceMeters required' });
  if (!token)          return res.status(400).json({ error: 'No Mapbox token' });
  try {
    console.log(`[Loop] "${origin}" ${(distanceMeters/1000).toFixed(1)}km (${mode}) seed=${seed}`);
    const oc     = await resolveCoords(req.body.originCoords, origin, token);
    const route  = await fetchLoop(oc, distanceMeters, mode, seed);
    const scenic = await scoreRoute(route.coords, weights, process.env.MAPILLARY_TOKEN);
    res.json({
      route:        { geometry: route.geometry, distance: route.distance, duration: route.duration },
      scenicScore:  scenic.composite,
      breakdown:    buildBreakdown(scenic),
      highlights:   scenic.highlights,
      description:  scenic.description,
      scoreDrivers: scenic.scoreDrivers,
      matchInfo: {
        requestedKm: +(distanceMeters / 1000).toFixed(1),
        actualKm:    +(route.distance  / 1000).toFixed(1),
        diffKm:      +Math.abs(route.distance/1000 - distanceMeters/1000).toFixed(1),
      },
    });
  } catch (err) {
    console.error('[Loop error]', err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── POST /api/score ───────────────────────────────────────────
// Score a pre-computed route geometry.
app.post('/api/score', async (req, res) => {
  const { coords, weights } = req.body;
  if (!coords?.length) return res.status(400).json({ error: 'coords array required' });
  try {
    const mToken = req.body.mapillaryToken || process.env.MAPILLARY_TOKEN;
    const scenic = await scoreRoute(coords, weights, mToken);
    res.json({ ...scenic, breakdown: buildBreakdown(scenic) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── POST /api/scenic-route ────────────────────────────────────
// Yugen's Panoramic A* — three route alternatives.
// Primary endpoint. /api/route is the fallback.
app.post('/api/scenic-route', async (req, res) => {
  const { origin, destination, mode = 'walk', weights } = req.body;
  const token = req.body.mapboxToken || process.env.MAPBOX_TOKEN;
  if (!origin || !destination)
    return res.status(400).json({ error: 'origin and destination required' });
  if (!token)
    return res.status(400).json({ error: 'No Mapbox token' });

  try {
    console.log(`[Scenic] "${origin}" → "${destination}" (${mode})`);

    const [oc, dc] = await Promise.all([
      resolveCoords(req.body.originCoords, origin, token),
      resolveCoords(req.body.destCoords,   destination, token),
    ]);

    const bbox = getBbox(oc, dc, mode);
    const [graph, features] = await Promise.all([
      fetchGraph(bbox, mode),
      fetchFeaturesFlat(bbox),
    ]);

    const startId = nearestNode(graph, oc);
    const goalId  = nearestNode(graph, dc);
    if (!startId || !goalId)
      throw new Error('Could not snap to nearby roads — try a more specific address');

    const approxDist = haversine(oc[1], oc[0], dc[1], dc[0]);
    const baseWeight = adaptiveScenicWeight(approxDist, weights ?? {});

    const ALTS = [
      { label: 'efficient', mult: 0.1, description: 'Fastest path, minimal detour' },
      { label: 'balanced',  mult: 0.5, description: 'Best balance of speed and scenery' },
      { label: 'scenic',    mult: 1.0, description: 'Most scenic route available' },
    ];

    const routes = [];
    for (const alt of ALTS) {
      const w      = { ...(weights ?? {}), _scenicOverride: baseWeight * alt.mult };
      const result = scenicAStar(graph, features, startId, goalId, w);
      if (!result.path.length) continue;

      const geometry = pathToGeoJSON(graph, result.path);
      const distance = pathDistance(graph, result.path);
      const duration = estimateDuration(distance, mode);
      const scenic   = await scoreRoute(geometry.coordinates, weights, process.env.MAPILLARY_TOKEN);

      routes.push({
        label:            alt.label,
        description:      alt.description,
        route:            { geometry, distance, duration },
        scenicScore:      scenic.composite,
        breakdown:        buildBreakdown(scenic),
        highlights:       scenic.highlights,
        routeDescription: scenic.description,
        scoreDrivers:     scenic.scoreDrivers,
        iterations:       result.iterations,
      });
      console.log(`[Scenic:${alt.label}] ${(distance/1000).toFixed(1)}km  score:${scenic.composite}/10  iter:${result.iterations}`);
    }

    if (!routes.length)
      throw new Error('No route found — try closer points or switch to Walking');

    res.json({
      alternatives: routes,
      recommended:  routes.find(r => r.label === 'balanced') ?? routes[0],
      algorithm:    'panoramic-astar',
    });

  } catch (err) {
    console.error('[Scenic error]', err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── Haversine (metres) ────────────────────────────────────────
function haversine(lat1, lng1, lat2, lng2) {
  const R    = 6371000;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a    = Math.sin(dLat/2) ** 2 +
               Math.cos(lat1 * Math.PI/180) * Math.cos(lat2 * Math.PI/180) *
               Math.sin(dLng/2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ── Startup ───────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`\n🗺  Yugen API`);
  console.log(`   App      → http://localhost:${PORT}/`);
  console.log(`   Health   → http://localhost:${PORT}/api/health`);
  console.log(`   Token    → ${process.env.MAPBOX_TOKEN    ? '✓ loaded' : '✗ missing — check .env'}`);
  console.log(`   Mapillary → ${process.env.MAPILLARY_TOKEN ? '✓ loaded' : '○ add to .env for visual scoring'}\n`);
  setImmediate(() => { loadBikeLanes(); loadTrees(); });
});
