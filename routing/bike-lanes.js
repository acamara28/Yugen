import { readFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DATA_PATH = join(__dirname, '../data/nyc-bike-routes.geojson');

// ── Facility quality scores (0–1) ────────────────────────────
// Based on NYC DOT facility class + type.
// These feed directly into edge scenic bonus in the road graph.
const FACILITY_SCORES = {
  // Class I — physically separated from traffic
  'Protected':            0.95,  // protected bike lane, barrier separated
  'Boardwalk':            0.90,  // boardwalk — scenic, traffic-free
  'Unpaved':              0.85,  // unpaved path — park trail quality
  'Greenway':             0.95,  // dedicated greenway
  'Curbside Buffered':    0.80,  // curbside with buffer
  'Conventional Buffered':0.75,  // buffered bike lane
  // Class II — marked lane on road
  'Conventional':         0.60,  // standard painted bike lane
  'Curbside':             0.55,  // curbside lane
  'Wide Parking Lane':    0.45,  // wide parking lane, shareable
  'Ped Plaza':            0.70,  // pedestrian plaza
  'Sidewalk':             0.50,  // sidewalk cycling
  // Class III — shared road
  'Shared':               0.30,  // shared lane marking (sharrow)
  'Signed Route':         0.20,  // signed route only, no marking
  'Link':                 0.25,  // connector link
};

// Greenway gets maximum bonus — these are Yugen's gold standard paths
const GREENWAY_SCORE = 0.98;

// ── Spatial grid index ────────────────────────────────────────
// Divides the map into ~100m cells. Each cell stores segments
// that pass through it. Lookup goes from O(n) to O(1) average.
const GRID_SIZE = 0.001; // ~100m in degrees

class SpatialIndex {
  constructor() {
    this.grid    = new Map();
    this.segments = [];
  }

  // Add a line segment with its quality score
  add(coords, score, meta) {
    const idx = this.segments.length;
    this.segments.push({ coords, score, meta });

    // Index every point in the segment
    for (const [lng, lat] of coords) {
      const key = this._key(lng, lat);
      if (!this.grid.has(key)) this.grid.set(key, []);
      this.grid.get(key).push(idx);
    }
  }

  // Query: what is the best bike facility within radiusDeg of [lng, lat]?
  // Returns { score, facilityType, isGreenway, streetName } or null
  query(lng, lat, radiusDeg = 0.0003) {
    let best = null;

    // Check surrounding grid cells
    const cellR = Math.ceil(radiusDeg / GRID_SIZE);
    const gridLng = Math.floor(lng / GRID_SIZE);
    const gridLat = Math.floor(lat / GRID_SIZE);

    const checked = new Set();
    for (let dx = -cellR; dx <= cellR; dx++) {
      for (let dy = -cellR; dy <= cellR; dy++) {
        const key = `${gridLng+dx},${gridLat+dy}`;
        const idxList = this.grid.get(key);
        if (!idxList) continue;
        for (const idx of idxList) {
          if (checked.has(idx)) continue;
          checked.add(idx);
          const seg = this.segments[idx];
          const d = this._distToSegment(lng, lat, seg.coords);
          if (d < radiusDeg && (!best || seg.score > best.score)) {
            best = { score: seg.score, ...seg.meta, dist: d };
          }
        }
      }
    }
    return best;
  }

  _key(lng, lat) {
    return `${Math.floor(lng/GRID_SIZE)},${Math.floor(lat/GRID_SIZE)}`;
  }

  // Minimum distance from point to a polyline
  _distToSegment(px, py, coords) {
    let minDist = Infinity;
    for (let i = 0; i < coords.length - 1; i++) {
      const [x1,y1] = coords[i], [x2,y2] = coords[i+1];
      const dx = x2-x1, dy = y2-y1;
      const lenSq = dx*dx + dy*dy;
      const t = lenSq === 0 ? 0 : Math.max(0, Math.min(1, ((px-x1)*dx+(py-y1)*dy)/lenSq));
      const dist = Math.sqrt((px-x1-t*dx)**2 + (py-y1-t*dy)**2);
      if (dist < minDist) minDist = dist;
    }
    return minDist;
  }
}

// ── Module-level index (built once on first import) ───────────
let index = null;
let loaded = false;
let stats  = { total: 0, greenways: 0, protected: 0, classes: {} };

export function loadBikeLanes() {
  if (loaded) return;
  if (!existsSync(DATA_PATH)) {
    console.log('[BikeLanes] No data file — bike lane bonuses disabled');
    loaded = true;
    return;
  }

  console.log('[BikeLanes] Loading NYC bike routes...');
  const raw  = JSON.parse(readFileSync(DATA_PATH, 'utf8'));
  index = new SpatialIndex();

  for (const feature of raw.features) {
    const p    = feature.properties;
    if (p.status !== 'Current') continue; // skip retired segments

    const isGreenway = p.grnwy === 'Greenway';
    const facType    = p.ft_facilit || p.tf_facilit || 'unknown';
    const facClass   = p.facilitycl || 'III';
    const score      = isGreenway
      ? GREENWAY_SCORE
      : (FACILITY_SCORES[facType] ?? (facClass === 'I' ? 0.70 : facClass === 'II' ? 0.50 : 0.20));

    const meta = {
      facilityType: isGreenway ? 'Greenway' : facType,
      facilityClass: facClass,
      isGreenway,
      streetName: p.street || '',
      gwSystem:   p.gwsystem || '',
    };

    // MultiLineString: index each line
    for (const line of feature.geometry.coordinates) {
      index.add(line, score, meta);
    }

    stats.total++;
    if (isGreenway) stats.greenways++;
    if (facType === 'Protected') stats.protected++;
    stats.classes[facClass] = (stats.classes[facClass] || 0) + 1;
  }

  loaded = true;
  console.log(`[BikeLanes] Loaded: ${stats.total} segments, ` +
    `${stats.greenways} greenways, ${stats.protected} protected lanes`);
  console.log(`[BikeLanes] Class breakdown:`, stats.classes);
}

// ── Public API ────────────────────────────────────────────────

// Get bike facility quality at a coordinate (0 if no facility nearby)
export function getBikeLaneScore(lng, lat, radiusDeg = 0.0003) {
  if (!index) return 0;
  const result = index.query(lng, lat, radiusDeg);
  return result ? result.score : 0;
}

// Get full facility info at a coordinate (for highlights/description)
export function getBikeLaneInfo(lng, lat, radiusDeg = 0.0003) {
  if (!index) return null;
  return index.query(lng, lat, radiusDeg);
}

// Check if a route passes through any greenway
export function detectGreenways(coords) {
  if (!index) return [];
  const found = new Set();
  const sample = Math.max(1, Math.floor(coords.length / 30));
  for (let i = 0; i < coords.length; i += sample) {
    const info = getBikeLaneInfo(coords[i][0], coords[i][1]);
    if (info?.isGreenway && info.gwSystem) found.add(info.gwSystem);
  }
  return [...found];
}

// Summarise bike infrastructure quality along a route (0–1)
export function scoreBikeInfrastructure(coords) {
  if (!index || !coords.length) return 0;
  const sample = Math.max(1, Math.floor(coords.length / 40));
  let hits = 0, total = 0;
  for (let i = 0; i < coords.length; i += sample) {
    const score = getBikeLaneScore(coords[i][0], coords[i][1]);
    if (score > 0) hits += score;
    total++;
  }
  return total === 0 ? 0 : hits / total;
}

export { stats as bikeLaneStats };
