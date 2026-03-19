import fetch from 'node-fetch';
import { existsSync, writeFileSync, readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// ── Config ────────────────────────────────────────────────────
// NYC Open Data Socrata API — 2015 Street Tree Census
// Full dataset: ~683,788 trees across all 5 boroughs
// Socrata public API — /resource/ endpoint is open, no auth needed
// /api/v3/views/ requires an app token which is why it was 403ing
const API_BASE  = 'https://data.cityofnewyork.us/resource/uvpi-gqnh.json';
const CACHE_PATH = join(__dirname, '../data/nyc-trees-cache.json');
const PAGE_SIZE  = 50000;   // records per API request
const TIMEOUT    = 30000;

// ── Tree species scenic value (0–1) ──────────────────────────
// Based on canopy spread, seasonal beauty, and visual presence.
// Large native species with strong seasonal colour score highest.
const SPECIES_SCORES = {
  // Top tier — large canopy, iconic NYC trees
  'london planetree':          0.90,
  'honeylocust':               0.80,
  'callery pear':              0.75,
  'pin oak':                   0.88,
  'norway maple':              0.78,
  'red maple':                 0.92,  // brilliant autumn colour
  'silver maple':              0.85,
  'sugar maple':               0.95,  // peak autumn colour
  'american elm':              0.88,  // classic NYC street tree
  'ginkgo':                    0.85,  // spectacular gold in autumn
  'japanese zelkova':          0.80,
  'littleleaf linden':         0.82,
  'cherry':                    0.95,  // spring blossom — peak scenic
  'japanese flowering cherry': 0.95,
  'yoshino cherry':            0.95,
  'kwanzan cherry':            0.95,
  'serviceberry':              0.88,
  'magnolia':                  0.90,
  'tulip-tree':                0.87,
  'sweetgum':                  0.85,
  'swamp white oak':           0.88,
  'bur oak':                   0.86,
  'willow oak':                0.84,
  // Mid tier
  'norway spruce':             0.72,
  'white ash':                 0.75,
  'green ash':                 0.72,
  'sycamore maple':            0.74,
  'tree of heaven':            0.40,  // invasive, low scenic value
  'siberian elm':              0.55,
  'black locust':              0.65,
  'mimosa':                    0.80,  // showy flowers
};

// Health multipliers — a dying tree is less scenic
const HEALTH_MULT = { 'Good': 1.0, 'Fair': 0.75, 'Poor': 0.45 };

// ── Spatial grid index (same pattern as bike-lanes.js) ────────
const GRID_SIZE = 0.0008; // ~80m cells — tight enough for street trees

class TreeIndex {
  constructor() {
    this.grid  = new Map();
    this.trees = [];
  }

  add(lng, lat, score, meta) {
    const idx = this.trees.length;
    this.trees.push({ lng, lat, score, meta });
    const key = this._key(lng, lat);
    if (!this.grid.has(key)) this.grid.set(key, []);
    this.grid.get(key).push(idx);
  }

  // Query: average tree density score within radius
  // Returns { score, count, species[] } or null
  query(lng, lat, radiusDeg = 0.0005) {
    const cellR  = Math.ceil(radiusDeg / GRID_SIZE);
    const gLng   = Math.floor(lng / GRID_SIZE);
    const gLat   = Math.floor(lat / GRID_SIZE);
    const r2     = radiusDeg * radiusDeg;

    let totalScore = 0, count = 0;
    const species  = new Set();

    for (let dx = -cellR; dx <= cellR; dx++) {
      for (let dy = -cellR; dy <= cellR; dy++) {
        const key = `${gLng+dx},${gLat+dy}`;
        const list = this.grid.get(key);
        if (!list) continue;
        for (const idx of list) {
          const t  = this.trees[idx];
          const d2 = (t.lng-lng)**2 + (t.lat-lat)**2;
          if (d2 < r2) {
            totalScore += t.score;
            count++;
            if (t.meta.species) species.add(t.meta.species);
          }
        }
      }
    }

    if (count === 0) return null;
    return {
      score:   Math.min(1, totalScore / count),
      count,
      density: Math.min(1, count / 8),  // 8+ trees = max density
      species: [...species].slice(0, 3),
    };
  }

  _key(lng, lat) {
    return `${Math.floor(lng/GRID_SIZE)},${Math.floor(lat/GRID_SIZE)}`;
  }
}

// ── Module state ──────────────────────────────────────────────
let treeIndex = null;
let loading   = false;
export const treeStats = { total: 0, loaded: false, boroughs: {} };

// ── Load trees — fetch from API with pagination ───────────────
export async function loadTrees() {
  if (treeIndex || loading) return;
  loading = true;

  // Use cached version if available (avoids re-fetching 700k trees)
  if (existsSync(CACHE_PATH)) {
    console.log('[Trees] Loading from local cache...');
    try {
      const cached = JSON.parse(readFileSync(CACHE_PATH, 'utf8'));
      treeIndex = buildIndexFromCache(cached);
      treeStats.total   = cached.length;
      treeStats.loaded  = true;
      console.log(`[Trees] Loaded ${treeStats.total.toLocaleString()} trees from cache`);
      loading = false;
      return;
    } catch {
      console.log('[Trees] Cache invalid, re-fetching...');
    }
  }

  console.log('[Trees] Fetching NYC street tree census from Open Data API...');
  console.log('[Trees] This runs once — result is cached for future starts');

  const allTrees = [];
  let offset     = 0;
  let page       = 1;

  while (true) {
    // Socrata CSV API with pagination
    const url = `${API_BASE}?$limit=${PAGE_SIZE}&$offset=${offset}` +
      `&$select=latitude,longitude,spc_common,health,status,tree_dbh,boroname` +
      `&$where=status=%27Alive%27`;

    try {
      console.log(`[Trees] Page ${page} (${offset.toLocaleString()} fetched so far)...`);
      const res = await fetch(url, { signal: AbortSignal.timeout(TIMEOUT) });
      if (!res.ok) throw new Error(`API error ${res.status}`);

      const rows = await res.json();

      if (rows.length === 0) break; // done

      for (const row of rows) {
        const lat = parseFloat(row.latitude);
        const lng = parseFloat(row.longitude);
        if (!lat || !lng || isNaN(lat) || isNaN(lng)) continue;
        allTrees.push({
          lat, lng,
          species: (row.spc_common || '').toLowerCase(),
          health:  row.health  || 'Good',
          dbh:     parseFloat(row.tree_dbh) || 5,
          boro:    row.boroname || '',
        });
      }

      offset += PAGE_SIZE;
      page++;

      if (rows.length < PAGE_SIZE) break; // last page

    } catch (err) {
      console.error(`[Trees] Fetch error on page ${page}:`, err.message);
      break;
    }
  }

  if (allTrees.length === 0) {
    console.warn('[Trees] No trees loaded — tree scoring disabled');
    loading = false;
    return;
  }

  // Cache to disk so subsequent starts are instant
  writeFileSync(CACHE_PATH, JSON.stringify(allTrees));
  console.log(`[Trees] Cached ${allTrees.length.toLocaleString()} trees to disk`);

  treeIndex = buildIndexFromCache(allTrees);
  treeStats.total  = allTrees.length;
  treeStats.loaded = true;
  loading = false;

  console.log(`[Trees] Index built — ${treeStats.total.toLocaleString()} trees ready`);
}

// ── Build spatial index from tree array ───────────────────────
function buildIndexFromCache(trees) {
  const idx = new TreeIndex();
  for (const t of trees) {
    const speciesScore = SPECIES_SCORES[t.species] ?? 0.70;
    const healthMult   = HEALTH_MULT[t.health]    ?? 0.70;
    // Larger diameter = bigger canopy = more scenic presence
    const sizeMult     = Math.min(1.2, 0.7 + (t.dbh / 30) * 0.5);
    const score        = Math.min(1, speciesScore * healthMult * sizeMult);

    idx.add(t.lng, t.lat, score, { species: t.species, health: t.health, boro: t.boro });

    if (t.boro) treeStats.boroughs[t.boro] = (treeStats.boroughs[t.boro] || 0) + 1;
  }
  return idx;
}

// ── Public API ────────────────────────────────────────────────

// Tree canopy score at a coordinate (0–1)
export function getTreeScore(lng, lat) {
  if (!treeIndex) return 0;
  const r = treeIndex.query(lng, lat);
  return r ? r.score * r.density : 0;
}

// Full tree info for a coordinate (for highlights)
export function getTreeInfo(lng, lat) {
  if (!treeIndex) return null;
  return treeIndex.query(lng, lat);
}

// Score tree canopy along an entire route (0–1)
export function scoreTreeCanopy(coords) {
  if (!treeIndex || !coords.length) return 0;
  const sample = Math.max(1, Math.floor(coords.length / 40));
  let total = 0, hits = 0;
  for (let i = 0; i < coords.length; i += sample) {
    const s = getTreeScore(coords[i][0], coords[i][1]);
    if (s > 0) hits += s;
    total++;
  }
  return total === 0 ? 0 : hits / total;
}

// Detect notable tree species along a route
export function detectNotableSpecies(coords) {
  if (!treeIndex) return [];
  const found = new Set();
  const sample = Math.max(1, Math.floor(coords.length / 20));
  for (let i = 0; i < coords.length; i += sample) {
    const info = treeIndex.query(coords[i][0], coords[i][1], 0.0003);
    if (info?.species) info.species.forEach(s => {
      if (SPECIES_SCORES[s] >= 0.85) found.add(s); // only notable species
    });
  }
  return [...found].slice(0, 3);
}

// ── CSV parser (simple, no external deps) ────────────────────
function parseCSV(text) {
  const lines  = text.trim().split('\n');
  if (lines.length < 2) return [];
  const headers = lines[0].split(',').map(h => h.trim().replace(/^"|"$/g, ''));
  return lines.slice(1).map(line => {
    const vals = splitCSVLine(line);
    return Object.fromEntries(headers.map((h, i) => [h, (vals[i] || '').replace(/^"|"$/g, '').trim()]));
  });
}

function splitCSVLine(line) {
  const result = [];
  let current  = '';
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    if (line[i] === '"') { inQuotes = !inQuotes; continue; }
    if (line[i] === ',' && !inQuotes) { result.push(current); current = ''; continue; }
    current += line[i];
  }
  result.push(current);
  return result;
}
