// ═══════════════════════════════════════════════════════════════
//  YUGEN SCENIC A* ALGORITHM
//  "Panoramic A*" — extends standard A* with inward vision rays
//
//  Standard A* minimizes: f(n) = g(n) + h(n)
//    g(n) = cost from start to node n
//    h(n) = heuristic estimated cost from n to goal
//
//  Yugen Scenic A* minimizes: f(n) = g(n) + h(n) - s(n) * W
//    s(n) = scenic score at node n (0–1), computed by vision rays
//    W    = scenic weight (user controlled, 0–1)
//
//  The vision rays: at each node, cast N rays outward in a circle.
//  Each ray checks what OSM features it hits within a radius.
//  The scenic value of those features is summed and normalized.
//  This becomes s(n) — a local beauty score for that position.
//
//  The higher s(n) is, the cheaper that node becomes to traverse,
//  so the algorithm naturally routes toward beautiful areas.
// ═══════════════════════════════════════════════════════════════

// ── Config ────────────────────────────────────────────────────
const VISION_RAYS    = 8;      // Number of rays cast per node
const VISION_RADIUS  = 0.006;  // In degrees (~650m) — wide enough to see Central Park
const SCENIC_WEIGHT  = 0.75;   // Strong pull toward scenic areas

// OSM feature scenic values (0–1 scale)
// These are the "edge weights" that make Yugen different from Google Maps
const FEATURE_SCORES = {
  // Nature
  park:             0.90,
  nature_reserve:   0.95,
  forest:           0.85,
  grass:            0.70,
  meadow:           0.75,
  scrub:            0.55,
  heath:            0.65,
  // Water
  river:            0.92,
  lake:             0.88,
  stream:           0.75,
  canal:            0.70,
  waterfront:       0.85,
  // Urban beauty
  viewpoint:        0.95,
  historic:         0.80,
  monument:         0.75,
  place_of_worship: 0.65,
  attraction:       0.70,
  // Path quality
  cycleway:         0.60,
  footway:          0.55,
  pedestrian:       0.65,
  // Negative (penalize ugly routes)
  industrial:      -0.40,
  parking:         -0.30,
  highway_major:   -0.20,
};

// ── Main Export ───────────────────────────────────────────────
// graph: { nodes: Map<id, {lat,lng,edges:[{to,dist}]}>, ... }
// features: array of { point:[lng,lat], type:string } from Overpass
// start, goal: node IDs
// weights: user scenic preferences { nature, water, arch, ... }
export function scenicAStar(graph, features, startId, goalId, weights = {}) {
  // scenicWeight: uses override from route alternatives, or calculates from user prefs
  // _scenicOverride is set by /api/scenic-route when generating alternatives
  const scenicWeight = weights._scenicOverride !== undefined
    ? weights._scenicOverride
    : SCENIC_WEIGHT * (0.5 + ((weights.nature ?? 7) + (weights.water ?? 8)) / 20 * 0.5);

  // Precompute scenic scores for all nodes once (expensive, worth caching)
  const scenicCache = new Map();

  function getScenicScore(nodeId) {
    if (scenicCache.has(nodeId)) return scenicCache.get(nodeId);
    const node = graph.nodes.get(nodeId);
    if (!node) return 0;
    const score = castVisionRays(node, features, weights);
    scenicCache.set(nodeId, score);
    return score;
  }

  // Heuristic: straight-line distance to goal (same as standard A*)
  function heuristic(nodeId) {
    const node = graph.nodes.get(nodeId);
    const goal = graph.nodes.get(goalId);
    if (!node || !goal) return 0;
    return haversine(node.lat, node.lng, goal.lat, goal.lng);
  }

  // ── A* Core ────────────────────────────────────────────────
  const openSet  = new MinHeap();    // Nodes to explore, sorted by f score
  const gScore   = new Map();        // Best known cost from start to node
  const fScore   = new Map();        // g + h - scenic_bonus
  const cameFrom = new Map();        // For path reconstruction

  gScore.set(startId, 0);
  fScore.set(startId, heuristic(startId));
  openSet.push({ id: startId, f: fScore.get(startId) });

  let iterations = 0;
  // Scale iteration limit with graph size so large city graphs
  // don't time out before finding a path across town.
  // Cap at 150k to prevent runaway on pathological graphs.
  const MAX_ITER = Math.min(150000, Math.max(30000, graph.nodes.size * 1.2));
  const visited  = new Set(); // Prevent re-processing settled nodes

  while (!openSet.isEmpty() && iterations < MAX_ITER) {
    iterations++;
    const current = openSet.pop();

    // Skip if already settled (MinHeap can have stale entries)
    if (visited.has(current.id)) continue;
    visited.add(current.id);

    // Reached the goal — reconstruct path
    if (current.id === goalId) {
      return {
        path: reconstructPath(cameFrom, goalId),
        cost: gScore.get(goalId),
        iterations,
        scenicScores: Object.fromEntries(
          [...scenicCache.entries()].slice(0, 20) // Sample for debugging
        ),
      };
    }

    const currentNode = graph.nodes.get(current.id);
    if (!currentNode) continue;

    for (const edge of currentNode.edges) {
      const neighbor = edge.to;

      // ── Yugen scenic cost formula ───────────────────────
      // Total scenic bonus = vision ray score + road-type bonus
      // Road-type bonus is pre-computed (park paths, cycleways cheaper)
      // Vision ray bonus is computed live at each node
      const visionScore = getScenicScore(neighbor);
      const roadBonus   = edge.roadBonus ?? 0;
      const totalScenic = Math.min(1, visionScore + roadBonus);

      // Scenic roads are cheaper: a fully scenic 100m road costs
      // as little as 25m equivalent — strong enough to detour through parks
      const edgeCost = edge.dist * (1 - totalScenic * scenicWeight);
      // ────────────────────────────────────────────────────

      const tentativeG = gScore.get(current.id) + edgeCost;
      const neighborG  = gScore.get(neighbor) ?? Infinity;

      if (tentativeG < neighborG) {
        cameFrom.set(neighbor, current.id);
        gScore.set(neighbor, tentativeG);

        // Heuristic: pure straight-line distance (admissible — never overestimates)
        // Scenic influence is already in edgeCost above.
        // Mixing scenic into the heuristic risks breaking optimality guarantees.
        const f = tentativeG + heuristic(neighbor);
        fScore.set(neighbor, f);
        openSet.push({ id: neighbor, f });
      }
    }
  }

  // No path found
  return { path: [], cost: Infinity, iterations };
}

// ── Vision Ray System ─────────────────────────────────────────
// This is the "looking inward" described in the diagram.
// Cast rays in VISION_RAYS directions from the current node.
// Check what OSM features each ray hits within VISION_RADIUS.
// Return a 0-1 scenic score for this location.
function castVisionRays(node, features, weights) {
  const userWeights = {
    nature: (weights.nature ?? 7) / 10,
    water:  (weights.water  ?? 8) / 10,
    arch:   (weights.arch   ?? 6) / 10,
  };

  let totalScore = 0;
  let rayHits    = 0;

  // Cast rays evenly around the full 360°
  for (let i = 0; i < VISION_RAYS; i++) {
    const angle = (i / VISION_RAYS) * 2 * Math.PI;
    const rayScore = castSingleRay(node, angle, features, userWeights);
    if (rayScore > 0) {
      totalScore += rayScore;
      rayHits++;
    }
  }

  if (rayHits === 0) return 0;

  // Normalize: how many rays hit something scenic, and how scenic was it
  const coverage = rayHits / VISION_RAYS;   // 0-1: what % of directions are scenic
  const quality  = totalScore / rayHits;    // 0-1: avg quality of scenic hits
  return Math.min(1, coverage * 0.4 + quality * 0.6);
}

function castSingleRay(node, angle, features, weights) {
  // Ray endpoint
  const rayLng = node.lng + Math.cos(angle) * VISION_RADIUS;
  const rayLat = node.lat + Math.sin(angle) * VISION_RADIUS;

  let bestScore = 0;

  for (const feature of features) {
    // Is this feature on or near this ray?
    const onRay = isNearRay(
      node.lng, node.lat,
      rayLng, rayLat,
      feature.point[0], feature.point[1],
      VISION_RADIUS * 0.4  // tolerance: feature must be within 40% of radius of ray
    );

    if (!onRay) continue;

    const featureScore = getFeatureScore(feature, weights);
    if (featureScore > bestScore) bestScore = featureScore;
  }

  return bestScore;
}

// Check if a point is near a ray segment
function isNearRay(x1, y1, x2, y2, px, py, tolerance) {
  // Distance from point to line segment
  const dx = x2 - x1, dy = y2 - y1;
  const lenSq = dx*dx + dy*dy;
  if (lenSq === 0) return false;
  const t = Math.max(0, Math.min(1, ((px-x1)*dx + (py-y1)*dy) / lenSq));
  const nearX = x1 + t*dx;
  const nearY = y1 + t*dy;
  const dist = Math.sqrt((px-nearX)**2 + (py-nearY)**2);
  return dist < tolerance;
}

// Get the scenic score of an OSM feature, weighted by user preferences
function getFeatureScore(feature, weights) {
  const tags = feature.tags || {};
  let score = 0;

  // Nature features
  if (tags.leisure === 'park' || tags.leisure === 'garden')
    score = Math.max(score, FEATURE_SCORES.park * weights.nature);
  if (tags.leisure === 'nature_reserve')
    score = Math.max(score, FEATURE_SCORES.nature_reserve * weights.nature);
  if (tags.landuse === 'forest' || tags.natural === 'wood')
    score = Math.max(score, FEATURE_SCORES.forest * weights.nature);
  if (tags.landuse === 'grass' || tags.landuse === 'meadow')
    score = Math.max(score, FEATURE_SCORES.grass * weights.nature);

  // Water features
  if (tags.natural === 'water')
    score = Math.max(score, FEATURE_SCORES.lake * weights.water);
  if (tags.waterway === 'river')
    score = Math.max(score, FEATURE_SCORES.river * weights.water);
  if (tags.waterway === 'stream' || tags.waterway === 'canal')
    score = Math.max(score, FEATURE_SCORES.stream * weights.water);

  // Architecture / historic
  if (tags.tourism === 'viewpoint')
    score = Math.max(score, FEATURE_SCORES.viewpoint * weights.arch);
  if (tags.historic)
    score = Math.max(score, FEATURE_SCORES.historic * weights.arch);
  if (tags.tourism === 'attraction')
    score = Math.max(score, FEATURE_SCORES.attraction * weights.arch);
  if (tags.amenity === 'place_of_worship')
    score = Math.max(score, FEATURE_SCORES.place_of_worship * weights.arch);

  // Penalty features
  if (tags.landuse === 'industrial')
    score = Math.min(score, FEATURE_SCORES.industrial);
  if (tags.amenity === 'parking')
    score = Math.min(score, FEATURE_SCORES.parking);

  return Math.max(0, score); // Clamp negative to 0 for scoring purposes
}

// ── Path Reconstruction ───────────────────────────────────────
function reconstructPath(cameFrom, current) {
  const path = [current];
  while (cameFrom.has(current)) {
    current = cameFrom.get(current);
    path.unshift(current);
  }
  return path;
}

// ── Min-Heap for A* open set ──────────────────────────────────
// Standard A* needs a priority queue — this is a fast binary heap
class MinHeap {
  constructor() { this.heap = []; }

  push(item) {
    this.heap.push(item);
    this._bubbleUp(this.heap.length - 1);
  }

  pop() {
    const top = this.heap[0];
    const last = this.heap.pop();
    if (this.heap.length > 0) {
      this.heap[0] = last;
      this._sinkDown(0);
    }
    return top;
  }

  isEmpty() { return this.heap.length === 0; }

  _bubbleUp(i) {
    while (i > 0) {
      const parent = Math.floor((i - 1) / 2);
      if (this.heap[parent].f <= this.heap[i].f) break;
      [this.heap[parent], this.heap[i]] = [this.heap[i], this.heap[parent]];
      i = parent;
    }
  }

  _sinkDown(i) {
    const n = this.heap.length;
    while (true) {
      let smallest = i;
      const l = 2*i+1, r = 2*i+2;
      if (l < n && this.heap[l].f < this.heap[smallest].f) smallest = l;
      if (r < n && this.heap[r].f < this.heap[smallest].f) smallest = r;
      if (smallest === i) break;
      [this.heap[smallest], this.heap[i]] = [this.heap[i], this.heap[smallest]];
      i = smallest;
    }
  }
}

// ── Haversine distance (meters) ───────────────────────────────
function haversine(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat/2)**2 +
            Math.cos(lat1 * Math.PI/180) * Math.cos(lat2 * Math.PI/180) *
            Math.sin(dLng/2)**2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
}

// ── OSM Graph Builder ─────────────────────────────────────────
// Converts raw OSM way data into a graph for the algorithm
// Call this once per area, then run scenicAStar on it
export function buildGraph(osmWays, osmNodes) {
  const nodes = new Map();

  // Add all OSM nodes to graph
  for (const node of osmNodes) {
    nodes.set(node.id, {
      id:    node.id,
      lat:   node.lat,
      lng:   node.lon,
      edges: [],
    });
  }

  // Add edges from OSM ways (roads, paths, cycleways)
  for (const way of osmWays) {
    const refs = way.nodes;
    const tags = way.tags || {};

    // Skip ways that aren't navigable
    if (!tags.highway) continue;

    // One-way logic — cycling-aware:
    //  oneway:bicycle=no  → cyclists allowed contra-flow even on one-way car road
    //  cycleway=opposite  → explicit contra-flow cycle lane
    //  junction=roundabout → always one-way in way direction
    const carOneWay  = tags.oneway === 'yes' || tags.oneway === '1' || tags.junction === 'roundabout';
    const bikeCanContra = tags['oneway:bicycle'] === 'no' || tags.cycleway === 'opposite';
    // Effective one-way for this way: cars one-way but bikes not = bidirectional for bikes
    const oneWay = carOneWay && !bikeCanContra;

    for (let i = 0; i < refs.length - 1; i++) {
      const fromId = refs[i];
      const toId   = refs[i + 1];
      const from   = nodes.get(fromId);
      const to     = nodes.get(toId);
      if (!from || !to) continue;

      const dist = haversine(from.lat, from.lng, to.lat, to.lng);

      from.edges.push({ to: toId, dist });
      if (!oneWay) to.edges.push({ to: fromId, dist });
    }
  }

  return { nodes };
}
