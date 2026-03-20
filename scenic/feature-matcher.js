// ═══════════════════════════════════════════════════════════════
//  YUGEN FEATURE MATCHER
//
//  Estimates a scenic score for a road segment by:
//    1. Converting OSM tags → a 5-dimension feature vector
//    2. Fetching MongoDB locations that have known feature data
//    3. Scoring each candidate via dot-product similarity
//    4. Returning the weighted average of the top-10 matches
//
//  Feature dimensions (all numeric, 0–1):
//    waterProximity  — how close to water
//    treeCanopy      — density of tree cover
//    trafficNoise    — noise level (1 = very loud)
//    surfaceType     — 0 = unpaved/path, 1 = main road
//    openSky         — how open the sky feels
//
//  Used by graph-builder.js for segments that have no direct
//  MongoDB location within 300m (the direct-match threshold).
// ═══════════════════════════════════════════════════════════════

import { getDb } from '../db/client.js';

// ── Feature weights for dot-product similarity ────────────────
// waterProximity and treeCanopy are the strongest signals because
// they're reliably populated by the Wikidata seeder.
// surfaceType is lowest — almost always null in current data.
const WEIGHTS = {
  waterProximity: 0.32,
  treeCanopy:     0.28,
  openSky:        0.20,
  trafficNoise:   0.13,
  surfaceType:    0.07,
};

const DIMS = Object.keys(WEIGHTS);

// ── Candidate cache — fetched once, reused for 30 min ─────────
// Avoids a MongoDB round-trip per node during graph construction.
let _cache     = null;
let _cacheTime = 0;
const CACHE_TTL = 30 * 60 * 1000;

async function getCandidates() {
  if (_cache && Date.now() - _cacheTime < CACHE_TTL) return _cache;

  try {
    const db = await getDb();
    // Only fetch locations that have at least one feature dimension populated.
    // Wikidata locations have waterProximity, treeCanopy, or openSky set.
    _cache = await db.collection('locations').find(
      {
        $or: [
          { 'features.waterProximity': { $ne: null } },
          { 'features.treeCanopy':     { $ne: null } },
          { 'features.openSky':        { $ne: null } },
        ],
      },
      { projection: { scenicScore: 1, confidence: 1, features: 1 } }
    ).limit(500).toArray();

    _cacheTime = Date.now();
    return _cache;
  } catch {
    return [];
  }
}

// ── OSM tags → feature vector ─────────────────────────────────
// nearbyFeatures: flat array of { point, type, tags } from Overpass,
// used to enrich estimates with environmental context.
export function osmTagsToVector(osmTags, nearbyFeatures = []) {
  const hw = osmTags.highway ?? '';
  const lu = osmTags.landuse ?? '';
  const nat = osmTags.natural ?? '';
  const lei = osmTags.leisure ?? '';
  const ww  = osmTags.waterway ?? '';
  const sur = osmTags.surface ?? '';
  const tou = osmTags.tourism ?? '';

  // Check what's in the Overpass feature cloud around this node
  const hasWaterFeature = nearbyFeatures.some(f =>
    f.tags?.natural === 'water' ||
    f.tags?.waterway === 'river' ||
    f.tags?.waterway === 'stream' ||
    f.tags?.waterway === 'canal'
  );
  const hasParkFeature = nearbyFeatures.some(f =>
    f.tags?.leisure === 'park' ||
    f.tags?.leisure === 'nature_reserve' ||
    f.tags?.landuse === 'forest' ||
    f.tags?.natural === 'wood'
  );

  return {
    waterProximity: waterProximity(ww, nat, hasWaterFeature),
    treeCanopy:     treeCanopy(hw, lu, nat, lei, hasParkFeature),
    trafficNoise:   trafficNoise(hw),
    surfaceType:    surfaceType(hw, sur),
    openSky:        openSky(hw, lu, nat, lei, tou),
  };
}

// ── Dimension extractors ──────────────────────────────────────

function waterProximity(waterway, natural, hasNearbyWater) {
  if (waterway === 'river' || waterway === 'canal') return 1.0;
  if (waterway === 'stream' || waterway === 'brook') return 0.9;
  if (waterway || natural === 'water' || natural === 'bay')  return 0.85;
  if (hasNearbyWater) return 0.65;
  return 0.0;
}

function treeCanopy(highway, landuse, natural, leisure, hasParkNearby) {
  if (landuse === 'forest' || natural === 'wood')   return 1.0;
  if (leisure === 'nature_reserve')                  return 0.90;
  if (leisure === 'park' || leisure === 'garden')   return 0.70;
  if (landuse === 'meadow')                          return 0.45;
  if (landuse === 'grass')                           return 0.35;
  if (hasParkNearby) return 0.55;
  // Road types suggest tree presence
  if (highway === 'footway' || highway === 'path' || highway === 'cycleway') return 0.35;
  if (highway === 'residential' || highway === 'living_street')              return 0.20;
  if (highway === 'primary' || highway === 'secondary' || highway === 'trunk') return 0.05;
  return 0.10;
}

function trafficNoise(highway) {
  switch (highway) {
    case 'motorway': case 'trunk':                   return 1.00;
    case 'primary':                                   return 0.80;
    case 'secondary':                                 return 0.60;
    case 'tertiary':                                  return 0.40;
    case 'unclassified': case 'residential':          return 0.25;
    case 'living_street': case 'service':             return 0.15;
    case 'cycleway': case 'footway': case 'path':
    case 'pedestrian': case 'track': case 'bridleway': return 0.05;
    default:                                          return 0.35;
  }
}

function surfaceType(highway, surface) {
  // Explicit surface tag takes priority
  if (surface === 'unpaved' || surface === 'dirt' || surface === 'grass') return 0.0;
  if (surface === 'gravel' || surface === 'compacted')                    return 0.15;
  if (surface === 'fine_gravel' || surface === 'wood')                    return 0.25;
  if (surface === 'asphalt' || surface === 'paved')                       return 0.70;
  // Infer from highway type
  switch (highway) {
    case 'bridleway': case 'track':                  return 0.05;
    case 'footway': case 'path':                     return 0.25;
    case 'cycleway':                                  return 0.35;
    case 'pedestrian': case 'living_street':          return 0.45;
    case 'residential': case 'service': case 'unclassified': return 0.55;
    case 'tertiary':                                  return 0.65;
    case 'secondary':                                 return 0.80;
    case 'primary': case 'trunk': case 'motorway':   return 1.00;
    default:                                          return 0.50;
  }
}

function openSky(highway, landuse, natural, leisure, tourism) {
  if (tourism === 'viewpoint')                             return 0.95;
  if (landuse === 'grass' || landuse === 'meadow')         return 0.90;
  if (leisure === 'park' || leisure === 'garden')          return 0.85;
  if (natural === 'wood' || landuse === 'forest')          return 0.50; // canopy blocks sky
  if (highway === 'cycleway' || highway === 'path' ||
      highway === 'footway'  || highway === 'pedestrian') return 0.75;
  if (highway === 'residential' || highway === 'living_street') return 0.50;
  if (highway === 'tertiary' || highway === 'secondary')   return 0.40;
  if (highway === 'primary'  || highway === 'trunk')       return 0.30;
  if (landuse === 'commercial' || landuse === 'industrial') return 0.20;
  return 0.55;
}

// ── Dot-product similarity ────────────────────────────────────
// Similarity = weighted average of (1 - |dim_diff|) across all
// dimensions where the MongoDB location has a known value.
// Returns 0–1, where 1 = perfect match.
function similarity(queryVec, locFeatures) {
  let score       = 0;
  let totalWeight = 0;

  for (const dim of DIMS) {
    const locVal = locFeatures[dim];
    if (locVal == null) continue;          // skip unknown dims
    const queryVal = queryVec[dim] ?? 0.5; // default mid-range if unset
    const w = WEIGHTS[dim];
    score       += (1 - Math.abs(queryVal - locVal)) * w;
    totalWeight += w;
  }

  if (totalWeight === 0) return 0;
  return score / totalWeight; // normalize to 0–1
}

// ── Main export ───────────────────────────────────────────────
// osmTags:       raw OSM tag object for this road segment
// nearbyFeatures: Overpass feature array (optional but improves accuracy)
//
// Returns: estimated scenic score 0–10, or null if no data available
export async function estimateScoreFromFeatures(osmTags, nearbyFeatures = []) {
  const candidates = await getCandidates();
  if (!candidates.length) return null;

  // Build the query vector from OSM tags + nearby Overpass context
  const queryVec = osmTagsToVector(osmTags, nearbyFeatures);

  // Score every candidate
  const scored = candidates.map(loc => ({
    scenicScore: loc.scenicScore,
    confidence:  loc.confidence  ?? 0.5,
    sim:         similarity(queryVec, loc.features ?? {}),
  }));

  // Keep the 10 closest matches
  scored.sort((a, b) => b.sim - a.sim);
  const top10 = scored.slice(0, 10);

  // Weighted average: weight = similarity × confidence
  // High-confidence, high-similarity locations dominate the estimate.
  let weightedSum  = 0;
  let totalWeight  = 0;
  for (const loc of top10) {
    const w = loc.sim * loc.confidence;
    weightedSum += loc.scenicScore * w;
    totalWeight += w;
  }

  if (totalWeight === 0) return null;
  return weightedSum / totalWeight; // 0–10
}

// ── Cache management ──────────────────────────────────────────
// Call this if the locations collection has been updated and you
// want the next estimate to pick up the fresh data immediately.
export function invalidateFeatureCache() {
  _cache     = null;
  _cacheTime = 0;
}
