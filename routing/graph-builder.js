import { overpassFetch } from './overpass-queue.js';
import { buildGraph } from '../scenic/panoramic-astar.js';
import { getBikeLaneScore, loadBikeLanes } from './bike-lanes.js';
import { getDb } from '../db/client.js';
import { estimateScoreFromFeatures } from '../scenic/feature-matcher.js';


// ── Highway filter by mode ────────────────────────────────────
// Cycling needs primary roads, park drives, and dedicated lanes.
// Walking/running stays on quieter streets.
const HIGHWAY_BY_MODE = {
  bike: new Set([
    'cycleway', 'path', 'footway', 'pedestrian', 'track', 'bridleway',
    'residential', 'living_street', 'service', 'unclassified',
    'tertiary', 'secondary', 'primary',   // needed for park roads + main avenues
  ]),
  run: new Set([
    'footway', 'path', 'pedestrian', 'steps', 'track', 'bridleway',
    'residential', 'living_street', 'service', 'unclassified', 'tertiary',
  ]),
  walk: new Set([
    'footway', 'path', 'pedestrian', 'steps', 'track', 'bridleway',
    'residential', 'living_street', 'service', 'unclassified', 'tertiary',
  ]),
};

// ── Edge scenic bonus by road type ───────────────────────────
// Applied directly on the edge so the algorithm sees scenic roads
// as cheaper BEFORE it even runs vision rays.
// Park roads and cycleways get a strong built-in bonus.
const ROAD_SCENIC_BONUS = {
  cycleway:     0.70,   // dedicated cycle path
  path:         0.60,   // park path, trail
  footway:      0.50,   // pedestrian path
  pedestrian:   0.55,   // pedestrian street
  track:        0.45,   // unpaved track
  residential:  0.15,   // quiet street
  living_street:0.20,
  service:      0.05,
  unclassified: 0.10,
  tertiary:     0.05,
  secondary:    0.00,
  primary:      0.00,
};

// Graph cache — 30 min TTL
const graphCache = new Map();

// ── Fetch OSM road graph ──────────────────────────────────────
export async function fetchGraph(bbox, mode = 'walk') {
  const key = bboxKey(bbox) + mode;
  if (graphCache.has(key)) {
    console.log('[Graph] cache hit —', graphCache.get(key).nodes.size, 'nodes');
    return graphCache.get(key);
  }

  const { south, west, north, east } = bbox;
  const b = `${south},${west},${north},${east}`;

  // Fetch roads AND park/leisure areas — park paths are often tagged
  // as leisure=park + highway=path, so we need both queries.
  const query = `
    [out:json][timeout:22];
    (
      way[highway](${b});
      node(w)(${b});
    );
    out body;
  `;

  console.log(`[Graph] fetching road network (${mode}) from Overpass...`);
  const data = await overpassFetch(query);

  const allWays  = data.elements.filter(e => e.type === 'way');
  const allNodes = data.elements.filter(e => e.type === 'node');

  const allowed = HIGHWAY_BY_MODE[mode] ?? HIGHWAY_BY_MODE.walk;
  const usableWays = allWays.filter(w => {
    const hw = w.tags?.highway;
    if (!hw) return false;
    if (!allowed.has(hw)) return false;
    // For cycling: exclude ways explicitly marked no bikes
    if (mode === 'bike' && w.tags?.bicycle === 'no') return false;
    // Exclude motorways always
    if (hw === 'motorway' || hw === 'trunk') return false;
    return true;
  });

  if (usableWays.length === 0) {
    throw new Error('No usable roads found — try a different location');
  }

  const graph = buildGraph(usableWays, allNodes);

  // Attach road-type scenic bonus directly onto each edge
  attachRoadBonuses(graph, usableWays);

  // For cycling: overlay official NYC bike lane quality scores
  // This means protected lanes and greenways cost even less
  if (mode === 'bike') {
    loadBikeLanes(); // no-op if already loaded
    applyBikeLaneBonuses(graph);
  }

  // Feature-matcher estimate: soft boost for ALL segments based on
  // OSM tag similarity to known scenic locations in MongoDB.
  // Runs before the direct-match boost so direct matches can stack on top.
  await applyFeatureMatcherBoosts(graph, usableWays);

  // Boost roadBonus for nodes near verified scenic MongoDB locations
  // (direct spatial match — stronger and more precise than feature estimate)
  await applyMongoLocationBoosts(graph, bbox);

  console.log(`[Graph] built: ${graph.nodes.size} nodes, ${usableWays.length} ways (${mode})`);

  graphCache.set(key, graph);
  setTimeout(() => graphCache.delete(key), 30 * 60 * 1000);

  return graph;
}

// ── Attach road-type scenic bonus to edges ────────────────────
// Modifies edges in-place to carry a scenicBonus field.
// The A* algorithm uses this to reduce edge cost before vision rays.
function attachRoadBonuses(graph, ways) {
  // Build a map: nodeId pair → road type
  const edgeType = new Map();
  for (const way of ways) {
    const bonus = ROAD_SCENIC_BONUS[way.tags?.highway] ?? 0;
    if (bonus === 0) continue;
    for (let i = 0; i < way.nodes.length - 1; i++) {
      edgeType.set(`${way.nodes[i]}-${way.nodes[i+1]}`, bonus);
      edgeType.set(`${way.nodes[i+1]}-${way.nodes[i]}`, bonus);
    }
  }
  // Apply to edges
  for (const [, node] of graph.nodes) {
    for (const edge of node.edges) {
      const key = `${node.id}-${edge.to}`;
      edge.roadBonus = edgeType.get(key) ?? 0;
    }
  }
}

// ── Feature-matcher background boost ─────────────────────────
// Estimates a scenic score for every road segment from OSM tags alone,
// using dot-product similarity against MongoDB locations that have known
// feature vectors. Applied at half the strength of a direct MongoDB match
// so spatial proximity always wins when it's available.
async function applyFeatureMatcherBoosts(graph, usableWays) {
  try {
    // Build nodeId → OSM tags map (first way a node appears in wins)
    const nodeTags = new Map();
    for (const way of usableWays) {
      const tags = way.tags || {};
      for (const nodeId of way.nodes) {
        if (!nodeTags.has(nodeId)) nodeTags.set(nodeId, tags);
      }
    }

    // Cache estimates by a compact key of the tags that matter.
    // All nodes sharing the same highway/landuse/natural profile get the
    // same estimate — avoids redundant async calls per node.
    const estimateCache = new Map();

    function tagKey(tags) {
      return [
        tags.highway   ?? '',
        tags.landuse   ?? '',
        tags.natural   ?? '',
        tags.leisure   ?? '',
        tags.waterway  ?? '',
        tags.surface   ?? '',
        tags.tourism   ?? '',
      ].join('|');
    }

    let boosted = 0;

    for (const [nodeId, node] of graph.nodes) {
      const tags = nodeTags.get(nodeId) ?? {};
      const key  = tagKey(tags);

      let estimate;
      if (estimateCache.has(key)) {
        estimate = estimateCache.get(key);
      } else {
        // No nearby Overpass features at this stage — enrichment happens
        // in scorer.js later. Tags alone are sufficient for a background estimate.
        estimate = await estimateScoreFromFeatures(tags, []);
        estimateCache.set(key, estimate);
      }

      if (estimate == null) continue;

      // Convert 0–10 scenic score to a roadBonus boost capped at 0.15.
      // Direct MongoDB spatial matches add up to 0.30, so they always dominate.
      const boost = (estimate / 10) * 0.15;
      for (const edge of node.edges) {
        edge.roadBonus = Math.min(0.98, (edge.roadBonus ?? 0) + boost);
      }
      boosted++;
    }

    console.log(
      `[Graph] feature-matcher: ${estimateCache.size} tag profiles → ${boosted} nodes boosted`
    );
  } catch (err) {
    // Non-fatal — routing still works without the feature-matcher boost
    console.warn('[Graph] feature-matcher skipped:', err.message);
  }
}

// ── Boost nodes near high-scoring MongoDB locations ───────────
async function applyMongoLocationBoosts(graph, bbox) {
  try {
    const db  = await getDb();
    const col = db.collection('locations');

    const locations = await col.find({
      scenicScore: { $gt: 7.5 },
      coordinates: {
        $geoWithin: {
          $box: [
            [bbox.west, bbox.south],
            [bbox.east, bbox.north],
          ],
        },
      },
    }, { projection: { coordinates: 1, scenicScore: 1 } }).toArray();

    if (locations.length === 0) return;

    let boosted = 0;
    for (const [, node] of graph.nodes) {
      for (const loc of locations) {
        const [locLng, locLat] = loc.coordinates.coordinates;
        const dist = haversine(node.lat, node.lng, locLat, locLng);
        if (dist <= 300) {
          const boost = (loc.scenicScore / 10) * 0.3;
          for (const edge of node.edges) {
            edge.roadBonus = Math.min(0.98, (edge.roadBonus ?? 0) + boost);
          }
          boosted++;
          break; // one boost per node (nearest location already applied)
        }
      }
    }
    console.log(`[Graph] MongoDB boost: ${locations.length} locations → ${boosted} nodes boosted`);
  } catch (err) {
    // Non-fatal — routing still works without MongoDB boost
    console.warn('[Graph] MongoDB boost skipped:', err.message);
  }
}

// ── Apply official bike lane quality to graph edges ──────────
function applyBikeLaneBonuses(graph) {
  let enhanced = 0;
  for (const [, node] of graph.nodes) {
    const laneScore = getBikeLaneScore(node.lng, node.lat);
    if (laneScore === 0) continue;
    for (const edge of node.edges) {
      // Add bike lane quality on top of existing road bonus
      // Cap at 0.98 so there's always a minimal distance cost
      edge.roadBonus = Math.min(0.98, (edge.roadBonus ?? 0) + laneScore * 0.4);
    }
    enhanced++;
  }
  console.log(`[Graph] bike lane overlay: ${enhanced} nodes enhanced`);
}

// ── Snap coordinate to nearest graph node ─────────────────────
// Builds a grid index on first call per graph, O(1) average lookup.
const nodeGridCache = new WeakMap();
const NODE_GRID = 0.001; // ~100m cells

function getNodeGrid(graph) {
  if (nodeGridCache.has(graph)) return nodeGridCache.get(graph);
  const grid = new Map();
  for (const [id, node] of graph.nodes) {
    const key = `${Math.floor(node.lng/NODE_GRID)},${Math.floor(node.lat/NODE_GRID)}`;
    if (!grid.has(key)) grid.set(key, []);
    grid.get(key).push(id);
  }
  nodeGridCache.set(graph, grid);
  return grid;
}

export function nearestNode(graph, lngLat) {
  const [lng, lat] = lngLat;
  const grid  = getNodeGrid(graph);
  let bestId   = null;
  let bestDist = Infinity;
  // Search expanding rings of cells until we find something
  for (let r = 0; r <= 5; r++) {
    for (let dx = -r; dx <= r; dx++) {
      for (let dy = -r; dy <= r; dy++) {
        if (Math.abs(dx) !== r && Math.abs(dy) !== r) continue; // only ring edge
        const key  = `${Math.floor(lng/NODE_GRID)+dx},${Math.floor(lat/NODE_GRID)+dy}`;
        const ids  = grid.get(key);
        if (!ids) continue;
        for (const id of ids) {
          const node = graph.nodes.get(id);
          const d    = (node.lng-lng)**2 + (node.lat-lat)**2;
          if (d < bestDist) { bestDist = d; bestId = id; }
        }
      }
    }
    if (bestId && r > 0) break; // found something in this ring, stop expanding
  }
  return bestId;
}

// ── Path → GeoJSON LineString ─────────────────────────────────
export function pathToGeoJSON(graph, nodeIds) {
  const coords = nodeIds
    .map(id => graph.nodes.get(id))
    .filter(Boolean)
    .map(n => [n.lng, n.lat]);
  return { type: 'LineString', coordinates: coords };
}

// ── Path distance (metres) ────────────────────────────────────
export function pathDistance(graph, nodeIds) {
  let dist = 0;
  for (let i = 0; i < nodeIds.length - 1; i++) {
    const a = graph.nodes.get(nodeIds[i]);
    const b = graph.nodes.get(nodeIds[i + 1]);
    if (a && b) dist += haversine(a.lat, a.lng, b.lat, b.lng);
  }
  return dist;
}

// ── Duration estimate (milliseconds) ─────────────────────────
const SPEED_MS = { walk: 1.4, run: 2.8, bike: 4.5 };
export function estimateDuration(distanceMeters, mode) {
  return (distanceMeters / (SPEED_MS[mode] ?? 1.4)) * 1000;
}

// ── Bounding box ──────────────────────────────────────────────
// Generous padding so the algorithm has room to find scenic detours.
// A route from Harlem to Upper East Side needs to be able to
// "see" Central Park and route through it.
export function getBbox(origin, dest, mode = 'walk') {
  const latDiff = Math.abs(origin[1] - dest[1]);
  const lngDiff = Math.abs(origin[0] - dest[0]);

  // Base padding: fixed minimum so very short routes still have context
  const basePad = 0.012; // ~1.3km minimum on each side

  // Scenic detour room: 15% of route length — enough to divert through a park
  // without loading half of Manhattan into the graph
  const routePad = Math.max(latDiff, lngDiff) * 0.15;

  // Hard cap: never exceed ~3km padding regardless of route length
  const pad = Math.min(0.028, basePad + routePad);

  return {
    west:  Math.min(origin[0], dest[0]) - pad,
    east:  Math.max(origin[0], dest[0]) + pad,
    south: Math.min(origin[1], dest[1]) - pad,
    north: Math.max(origin[1], dest[1]) + pad,
  };
}

// ── Helpers ───────────────────────────────────────────────────
function bboxKey({ south, west, north, east }) {
  return `${south.toFixed(3)},${west.toFixed(3)},${north.toFixed(3)},${east.toFixed(3)}`;
}

function haversine(lat1, lng1, lat2, lng2) {
  const R    = 6371000;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a    = Math.sin(dLat/2) ** 2 +
               Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
               Math.sin(dLng/2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}
