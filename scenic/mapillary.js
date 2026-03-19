import fetch from 'node-fetch';

// ═══════════════════════════════════════════════════════════════
//  MAPILLARY VISUAL SCORING MODULE
//
//  Mapillary has already run computer vision on millions of
//  street-level photos and detected objects in each one.
//  We query their Map Features API to find what was visually
//  detected near a road segment — trees, vegetation, water,
//  benches, open sky — and convert those detections into a
//  visual scenic score.
//
//  This is real ground-truth scenic data: not "is there a park
//  mapped nearby" but "a photographer cycled this street and
//  the camera saw trees and water."
//
//  API docs: https://www.mapillary.com/developer/api-documentation
// ═══════════════════════════════════════════════════════════════

const API_BASE = 'https://graph.mapillary.com';
const TIMEOUT  = 10000;

// ── Object detection scenic scores ───────────────────────────
// Mapillary's detected object classes → scenic value (0–1)
// Full class list: https://www.mapillary.com/developer/api-documentation
const OBJECT_SCORES = {
  // Strong positive — nature
  'object--vegetation--tree':          0.92,
  'object--vegetation--vegetation':    0.80,
  'object--vegetation--bush':          0.72,
  'object--water':                     0.90,
  'object--bench':                     0.55,  // implies park/rest area
  'object--bike-rack':                 0.50,  // cycling infrastructure

  // Moderate positive — urban beauty
  'object--sign--information':         0.40,
  'construction--structure--building': 0.20,  // neutral-positive

  // Negative — industrial, ugly
  'object--trash-can':                -0.05,
  'construction--barrier--separator':  0.00,
  'marking--discrete--stop-line':      0.00,
};

// Minimum detections to trust a result (fewer = less reliable)
const MIN_DETECTIONS = 3;

// In-memory cache: bbox key → { score, features, timestamp }
const cache = new Map();
const CACHE_TTL = 7 * 24 * 60 * 60 * 1000; // 7 days — visual data rarely changes

// ── Main export: score a route visually ──────────────────────
export async function scoreRouteVisually(coords, token) {
  if (!token) return { score: 0, confidence: 0, detections: [] };

  // Sample route — query Mapillary at every Nth point
  const sample    = Math.max(1, Math.floor(coords.length / 12));
  const sampled   = coords.filter((_, i) => i % sample === 0);

  let totalScore  = 0;
  let totalWeight = 0;
  const allDetections = new Map(); // object_value → count

  for (const coord of sampled) {
    const result = await queryPoint(coord, token);
    if (!result) continue;

    totalScore  += result.score * result.detectionCount;
    totalWeight += result.detectionCount;
    for (const [obj, count] of Object.entries(result.objects)) {
      allDetections.set(obj, (allDetections.get(obj) || 0) + count);
    }
  }

  if (totalWeight < MIN_DETECTIONS) {
    return { score: 0, confidence: 0, detections: [] };
  }

  const score      = Math.min(1, totalScore / totalWeight);
  const confidence = Math.min(1, totalWeight / 30); // 30+ detections = full confidence

  // Top detected objects for highlights
  const detections = [...allDetections.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([obj]) => obj);

  return { score, confidence, detections };
}

// ── Query detected features near a single coordinate ─────────
async function queryPoint([lng, lat], token) {
  // Small bbox around the point (~200m radius)
  const r   = 0.0018;
  const bbox = `${lng-r},${lat-r},${lng+r},${lat+r}`;
  const key  = `${lng.toFixed(4)},${lat.toFixed(4)}`;

  if (cache.has(key)) {
    const cached = cache.get(key);
    if (Date.now() - cached.timestamp < CACHE_TTL) return cached;
  }

  try {
    // Query Mapillary map_features — computer vision detected objects
    const url = `${API_BASE}/map_features` +
      `?access_token=${token}` +
      `&fields=object_value,geometry` +
      `&bbox=${bbox}`;

    const res = await fetch(url, { signal: AbortSignal.timeout(TIMEOUT) });
    if (!res.ok) throw new Error(`Mapillary ${res.status}`);
    const data = await res.json();

    const features = data.data || [];
    if (!features.length) {
      const empty = { score: 0, detectionCount: 0, objects: {}, timestamp: Date.now() };
      cache.set(key, empty);
      return empty;
    }

    // Tally detected objects and compute score
    let scoreSum = 0;
    const objects = {};

    for (const f of features) {
      const objVal = f.object_value;
      if (!objVal) continue;
      const objScore = OBJECT_SCORES[objVal] ?? 0;
      scoreSum += objScore;
      objects[objVal] = (objects[objVal] || 0) + 1;
    }

    const result = {
      score:          Math.max(0, scoreSum / Math.max(features.length, 1)),
      detectionCount: features.length,
      objects,
      timestamp:      Date.now(),
    };

    cache.set(key, result);
    return result;

  } catch (err) {
    if (!err.message.includes('timeout')) {
      console.error('[Mapillary]', err.message);
    }
    return null;
  }
}

// ── Check if a location has Mapillary coverage ───────────────
// Useful for knowing whether visual scores are available
export async function hasCoverage(lng, lat, token) {
  if (!token) return false;
  try {
    const r   = 0.001;
    const url = `${API_BASE}/images` +
      `?access_token=${token}` +
      `&fields=id` +
      `&bbox=${lng-r},${lat-r},${lng+r},${lat+r}` +
      `&limit=1`;
    const res  = await fetch(url, { signal: AbortSignal.timeout(5000) });
    const data = await res.json();
    return (data.data?.length ?? 0) > 0;
  } catch { return false; }
}

// ── Translate detections → human-readable highlights ─────────
export function detectionsToHighlights(detections) {
  const h = [];
  if (detections.some(d => d.includes('tree')))       h.push('🌳 Visually confirmed tree canopy');
  if (detections.some(d => d.includes('vegetation'))) h.push('🌿 Green streetscape confirmed');
  if (detections.some(d => d.includes('water')))      h.push('💧 Water visually confirmed');
  if (detections.some(d => d.includes('bench')))      h.push('🪑 Rest spots along route');
  if (detections.some(d => d.includes('bike-rack'))) h.push('🚴 Bike-friendly infrastructure');
  return h;
}
