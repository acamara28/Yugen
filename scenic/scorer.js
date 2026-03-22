import { overpassFetch } from '../routing/overpass-queue.js';
import { scoreBikeInfrastructure, detectGreenways, loadBikeLanes } from '../routing/bike-lanes.js';
import { scoreTreeCanopy, detectNotableSpecies, loadTrees } from '../routing/trees.js';
import { scoreRouteVisually, detectionsToHighlights } from './mapillary.js';
import { getDb } from '../db/client.js';

const SEARCH_RADIUS    = 400; // metres
const MONGO_MULTIPLIER = 1.3; // human-verified locations score 30% higher

const scoreCache = new Map();
const mongoCache = new Map(); // separate cache for MongoDB results

// ── Seasonal multipliers ──────────────────────────────────────
// Parks and nature score higher in spring/autumn (peak beauty).
// Water scores higher year-round with a summer peak.
// All scores pull back slightly in deep winter.
function getSeasonalMultiplier(category) {
  const month = new Date().getMonth(); // 0=Jan … 11=Dec
  const season = {
    // spring: Mar-May (2-4), summer: Jun-Aug (5-7), autumn: Sep-Nov (8-10), winter: Dec-Feb (11,0,1)
    nature: [0.80, 0.82, 1.00, 1.10, 1.15, 0.95, 0.90, 0.92, 1.15, 1.20, 1.10, 0.78][month],
    water:  [0.85, 0.85, 0.90, 1.00, 1.05, 1.10, 1.10, 1.10, 1.05, 1.00, 0.90, 0.85][month],
    arch:   [0.90, 0.90, 0.95, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 0.95, 0.90][month],
  };
  return season[category] ?? 1.0;
}

// ── Main export ───────────────────────────────────────────────
export async function scoreRoute(coords, userWeights = {}, mapillaryToken = null) {
  const weights = {
    nature: (userWeights.nature ?? 7) / 10,
    arch:   (userWeights.arch   ?? 6) / 10,
    water:  (userWeights.water  ?? 8) / 10,
    quiet:  (userWeights.quiet  ?? 6) / 10,
  };

  const bbox     = getBoundingBox(coords);
  const cacheKey = bboxToKey(bbox);

  let features;
  if (scoreCache.has(cacheKey)) {
    features = scoreCache.get(cacheKey);
  } else {
    // Fetch Overpass and MongoDB in parallel
    const [overpass, mongo] = await Promise.all([
      queryOverpass(bbox),
      queryMongoLocations(bbox),
    ]);
    features = mergeFeatures(overpass, mongo);
    scoreCache.set(cacheKey, features);
    setTimeout(() => scoreCache.delete(cacheKey), 60 * 60 * 1000);
  }

  const scores = computeScores(coords, features);

  // Bike infrastructure score from official NYC DOT data
  // loadBikeLanes() is called once at server startup — not here
  const bikeScore  = scoreBikeInfrastructure(coords);
  const greenways  = detectGreenways(coords);
  scores.bike      = bikeScore;

  // Tree canopy score from NYC Parks 2015 Street Tree Census
  const treeCanopy  = scoreTreeCanopy(coords);
  const treeSpecies = detectNotableSpecies(coords);
  scores.trees      = treeCanopy;

  // Mapillary visual score — ground truth from street-level photos
  // Runs concurrently with other scoring, fails gracefully if API is down
  const mToken = mapillaryToken || process.env?.MAPILLARY_TOKEN;
  const visual = mToken
    ? await scoreRouteVisually(coords, mToken)
    : { score: 0, confidence: 0, detections: [] };
  scores.visual = visual.score;

  // Apply seasonal multipliers and user weights
  const sNature = scores.nature       * weights.nature * getSeasonalMultiplier('nature');
  const sArch   = scores.architecture * weights.arch   * getSeasonalMultiplier('arch');
  const sWater  = scores.water        * weights.water  * getSeasonalMultiplier('water');
  const sQuiet  = scores.quiet        * weights.quiet;

  // Bike infrastructure bonus: good cycling infra boosts the composite
  const bikeBonus   = scores.bike   * 0.5;
  // Visual bonus: weight by confidence so low-coverage areas don't over-score
  const visualBonus = scores.visual * visual.confidence * 0.8;
  const treeBonus = scores.trees * 0.3; // tree canopy is a nature sub-score

  const totalW  = weights.nature + weights.arch + weights.water + weights.quiet;
  const weighted = sNature + sArch + sWater + sQuiet;
  const composite = Math.min(10, (weighted / Math.max(totalW, 0.1)) * 10 * 1.5 + bikeBonus + treeBonus + visualBonus);

  const highlights = inferHighlights(features, scores, greenways, treeSpecies, visual.detections);
  const description = generateDescription(features, scores, coords, greenways, treeSpecies);

  return {
    composite:    +composite.toFixed(1),
    nature:       +(scores.nature       * 10).toFixed(1),
    architecture: +(scores.architecture * 10).toFixed(1),
    water:        +(scores.water        * 10).toFixed(1),
    quiet:        +(scores.quiet        * 10).toFixed(1),
    bike:         +(scores.bike         * 10).toFixed(1),
    visual:       +(scores.visual        * 10).toFixed(1),
    visualConf:   +visual.confidence.toFixed(2),
    featureCount: features.totalCount,
    highlights,
    description,
    scoreDrivers: buildScoreDrivers(features, scores, greenways, treeSpecies, visual),
  };
}

// ── Overpass query — full feature set ────────────────────────
async function queryOverpass(bbox) {
  const { south, west, north, east } = bbox;
  const b = `${south},${west},${north},${east}`;

  const query = `
    [out:json][timeout:25];
    (
      way["leisure"="park"](${b});
      way["leisure"="garden"](${b});
      way["leisure"="nature_reserve"](${b});
      way["leisure"="recreation_ground"](${b});
      way["landuse"="forest"](${b});
      way["landuse"="grass"](${b});
      way["landuse"="meadow"](${b});
      way["landuse"="greenfield"](${b});
      way["natural"="wood"](${b});
      way["natural"="scrub"](${b});
      way["natural"="heath"](${b});
      way["natural"="water"](${b});
      way["natural"="beach"](${b});
      way["waterway"~"river|stream|canal"](${b});
      relation["natural"="water"](${b});
      way["tourism"~"viewpoint|attraction"](${b});
      node["tourism"="viewpoint"](${b});
      way["historic"~"monument|memorial|building|district"](${b});
      node["historic"~"monument|memorial"](${b});
      way["amenity"~"place_of_worship"](${b});
      way["highway"~"footway|cycleway|path|pedestrian"](${b});
      way["surface"~"unpaved|gravel|dirt|grass|pebblestone|cobblestone"](${b});
      way["bicycle"="designated"](${b});
      way["bicycle"="yes"](${b});
      node["natural"~"tree$"](${b});
      way["natural"="tree_row"](${b});
      node["tourism"="artwork"](${b});
      way["landuse"="allotments"](${b});
      node["natural"="peak"](${b});
    );
    out center;
  `;

  try {
    const data = await overpassFetch(query);
    return categorizeFeatures(data.elements);
  } catch (err) {
    console.error('[Overpass]', err.message);
    return { parks: [], water: [], historic: [], paths: [], trees: [], art: [], quiet: [], totalCount: 0 };
  }
}

// ── MongoDB locations query ───────────────────────────────────
// Returns locations within the bbox, grouped by category.
// Results are cached for 30 minutes — location data rarely changes.
export async function queryMongoLocations(bbox) {
  const key = bboxToKey(bbox);
  if (mongoCache.has(key)) return mongoCache.get(key);

  try {
    const db  = await getDb();
    const col = db.collection('locations');

    const docs = await col.find({
      coordinates: {
        $geoWithin: {
          $box: [
            [bbox.west,  bbox.south],
            [bbox.east,  bbox.north],
          ],
        },
      },
    }).toArray();

    // Group into the same shape as Overpass features, tagged as mongo-verified
    const result = {
      parks:    [],
      water:    [],
      historic: [],
      paths:    [],
      trees:    [],
      art:      [],
      quiet:    [],
      mongo:    docs,   // raw docs available for description/highlights
      totalCount: docs.length,
    };

    for (const doc of docs) {
      const point   = doc.coordinates.coordinates; // [lng, lat]
      const entry   = { point, name: doc.name, scenicScore: doc.scenicScore, mongo: true, tags: {} };

      switch (doc.category) {
        case 'park':
        case 'nature_reserve':
        case 'garden':
          result.parks.push(entry);
          break;
        case 'waterway':
          result.water.push(entry);
          break;
        case 'viewpoint':
        case 'landmark':
        case 'monument':
          result.historic.push(entry);
          break;
        default:
          result.parks.push(entry);
      }
    }

    mongoCache.set(key, result);
    setTimeout(() => mongoCache.delete(key), 30 * 60 * 1000);
    console.log(`[MongoDB] ${docs.length} locations loaded for bbox`);
    return result;

  } catch (err) {
    console.error('[MongoDB] queryMongoLocations error:', err.message);
    return { parks: [], water: [], historic: [], paths: [], trees: [], art: [], quiet: [], mongo: [], totalCount: 0 };
  }
}

// ── Merge Overpass + MongoDB features ────────────────────────
// MongoDB entries are flagged so computeScores can apply the multiplier.
function mergeFeatures(overpass, mongo) {
  return {
    parks:      [...overpass.parks,    ...mongo.parks],
    water:      [...overpass.water,    ...mongo.water],
    historic:   [...overpass.historic, ...mongo.historic],
    paths:      [...overpass.paths,    ...mongo.paths],
    trees:      [...overpass.trees,    ...mongo.trees],
    art:        [...overpass.art,      ...mongo.art],
    quiet:      [...overpass.quiet,    ...mongo.quiet],
    mongo:      mongo.mongo ?? [],
    totalCount: overpass.totalCount + mongo.totalCount,
  };
}

// ── Feature categorization ────────────────────────────────────
function categorizeFeatures(elements) {
  const f = { parks: [], water: [], historic: [], paths: [], trees: [], art: [], quiet: [], totalCount: elements.length };

  for (const el of elements) {
    const point = el.center
      ? [el.center.lon, el.center.lat]
      : el.type === 'node' ? [el.lon, el.lat] : null;
    if (!point) continue;
    const tags = el.tags || {};

    if (tags.leisure || tags.landuse === 'forest' || tags.landuse === 'grass' ||
        tags.landuse === 'meadow' || tags.landuse === 'greenfield' ||
        tags.natural === 'wood' || tags.natural === 'scrub' ||
        tags.natural === 'heath' || tags.natural === 'beach' ||
        tags.leisure === 'recreation_ground')
      f.parks.push({ point, tags });

    if (tags.natural === 'water' || tags.waterway || tags.natural === 'beach')
      f.water.push({ point, tags });

    if (tags.historic || tags.tourism === 'viewpoint' || tags.tourism === 'attraction' || tags.amenity === 'place_of_worship')
      f.historic.push({ point, tags });

    const scenicSurface = ['unpaved','gravel','dirt','grass','pebblestone','cobblestone'].includes(tags.surface);
    if (tags.highway === 'footway' || tags.highway === 'cycleway' || tags.highway === 'path' ||
        tags.highway === 'pedestrian' || (scenicSurface && tags.highway) || tags.bicycle === 'designated')
      f.paths.push({ point, tags });

    if (tags.natural === 'tree' || tags.natural === 'tree_row' || tags.landuse === 'allotments')
      f.trees.push({ point, tags });

    if (tags.tourism === 'artwork')
      f.art.push({ point, tags });

    if (tags.maxspeed && parseInt(tags.maxspeed) <= 20)
      f.quiet.push({ point, tags });
  }
  return f;
}

// ── Compute per-category scores ───────────────────────────────
// MongoDB-verified locations (f.mongo === true) get a 1.3x hit weight.
function computeScores(routeCoords, features) {
  if (!routeCoords.length) return { nature: 0, architecture: 0, water: 0, quiet: 0 };

  const sampleEvery = Math.max(1, Math.floor(routeCoords.length / 50));
  const sampled     = routeCoords.filter((_, i) => i % sampleEvery === 0);
  const r           = SEARCH_RADIUS / 111320;
  const rTree       = (SEARCH_RADIUS * 0.5) / 111320;

  // Returns hit weight: 1.3 for mongo-verified, 1.0 for Overpass
  function hitWeight(f) { return f.mongo ? MONGO_MULTIPLIER : 1.0; }

  let natureScore = 0, waterScore = 0, archScore = 0, quietHits = 0;

  for (const coord of sampled) {
    // Nature — parks and trees, weighted by source
    let bestNature = 0;
    for (const f of features.parks) {
      if (distance(coord, f.point) < r)
        bestNature = Math.max(bestNature, hitWeight(f));
    }
    for (const f of features.trees) {
      if (distance(coord, f.point) < rTree)
        bestNature = Math.max(bestNature, hitWeight(f) * 0.8);
    }
    natureScore += bestNature;

    // Water — wider search radius
    let bestWater = 0;
    for (const f of features.water) {
      if (distance(coord, f.point) < r * 1.5)
        bestWater = Math.max(bestWater, hitWeight(f));
    }
    waterScore += bestWater;

    // Architecture — historic sites and art
    let bestArch = 0;
    for (const f of features.historic) {
      if (distance(coord, f.point) < r)
        bestArch = Math.max(bestArch, hitWeight(f));
    }
    for (const f of features.art) {
      if (distance(coord, f.point) < rTree)
        bestArch = Math.max(bestArch, hitWeight(f) * 0.8);
    }
    archScore += bestArch;

    // Quiet — binary (no multiplier needed, Overpass-only)
    const nearQuiet = features.quiet.some(f => distance(coord, f.point) < r);
    const nearPath  = features.paths.some(f => {
      const t = f.tags || {};
      return distance(coord, f.point) < rTree &&
        (t.highway === 'cycleway' || t.highway === 'path' ||
         t.highway === 'footway'  || t.bicycle === 'designated');
    });
    if (nearQuiet || nearPath) quietHits++;
  }

  const total = sampled.length;
  return {
    nature:       Math.min(1, (natureScore / total) * 1.4),
    water:        Math.min(1, (waterScore  / total) * 2.0),
    architecture: Math.min(1, (archScore   / total) * 2.5),
    quiet:        Math.min(1, (quietHits   / total) * 2.0),
  };
}

// ── Natural language description ──────────────────────────────
function generateDescription(features, scores, coords, greenways = [], treeSpecies = []) {
  const parts = [];
  const distKm = routeDistanceKm(coords);

  // Nature
  const parkNames = [...new Set(
    features.parks.filter(f => f.tags?.name).map(f => f.tags.name).slice(0, 2)
  )];
  if (parkNames.length)
    parts.push(`passes ${parkNames.join(' and ')}`);
  else if (scores.nature > 0.5)
    parts.push('travels through green, tree-lined streets');

  // Water
  const riverNames = [...new Set(
    features.water.filter(f => f.tags.name).map(f => f.tags.name).slice(0, 1)
  )];
  if (riverNames.length)
    parts.push(`follows the ${riverNames[0]}`);
  else if (scores.water > 0.4)
    parts.push('runs along a waterfront');

  // Cycling infrastructure
  const hasCycleway = features.paths.some(f => f.tags.highway === 'cycleway' || f.tags.bicycle === 'designated');
  if (hasCycleway)
    parts.push('uses dedicated cycle paths');

  // Architecture
  const landmarks = features.historic.filter(f => f.tags.name).map(f => f.tags.name).slice(0, 2);
  if (landmarks.length)
    parts.push(`passes near ${landmarks.join(' and ')}`);

  // Street art
  if (features.art.length > 2)
    parts.push(`${features.art.length} public artworks along the way`);

  // Quiet streets
  if (scores.quiet > 0.5)
    parts.push('mostly on quiet, low-traffic streets');

  // Named greenway systems
  for (const gw of greenways.slice(0, 1)) {
    parts.push(`follows the ${gw}`);
  }
  // Quality bike infrastructure
  if (scores.bike > 0.6 && !greenways.length)
    parts.push('travels on protected cycling infrastructure');

  if (treeSpecies.includes('london planetree') || treeSpecies.includes('american elm'))
    parts.push('lined with large shade trees');
  else if (scores.trees > 0.4)
    parts.push('with strong tree canopy');
  if (treeSpecies.some(s => s.includes('cherry')))
    parts.push('past cherry blossom trees');

  if (!parts.length)
    return `A ${distKm.toFixed(1)}km route through the area.`;

  return `A ${distKm.toFixed(1)}km route that ${parts.join(', ')}.`;
}

// ── Score transparency — what drove the score ─────────────────
function buildScoreDrivers(features, scores, greenways = [], treeSpecies = [], visual = null) {
  const drivers = [];

  if (scores.nature > 0.5) {
    const names = features.parks.filter(f => f.tags.name).map(f => f.tags.name).slice(0, 3);
    drivers.push(names.length
      ? `Nature boosted by ${names.join(', ')}`
      : 'Nature score from parks and green space nearby');
  }
  if (scores.water > 0.3) {
    const names = features.water.filter(f => f.tags.name).map(f => f.tags.name).slice(0, 2);
    drivers.push(names.length
      ? `Water score from ${names.join(', ')}`
      : 'Water score from nearby waterway');
  }
  if (scores.architecture > 0.3) {
    const names = features.historic.filter(f => f.tags.name).map(f => f.tags.name).slice(0, 2);
    drivers.push(names.length
      ? `Architecture score from ${names.join(', ')}`
      : 'Architecture score from historic sites');
  }
  if (features.trees.length > 5)
    drivers.push(`${features.trees.length} trees mapped along the route`);
  if (features.art.length > 0)
    drivers.push(`${features.art.length} public artwork${features.art.length > 1 ? 's' : ''} nearby`);
  if (scores.visual > 0.3 && visual?.confidence > 0.4)
    drivers.push(`Visual score: ${(scores.visual*10).toFixed(1)}/10 from Mapillary street-level photos (confidence: ${Math.round((visual?.confidence??0)*100)}%)`);
  if (scores.trees > 0.3)
    drivers.push(`Tree canopy: ${(scores.trees*10).toFixed(1)}/10 from NYC Parks census (683k trees mapped)`);
  if (treeSpecies.length)
    drivers.push(`Notable species: ${treeSpecies.join(', ')}`);
  if (scores.bike > 0.3)
    drivers.push(`Cycling infrastructure score: ${(scores.bike*10).toFixed(1)}/10 from NYC DOT bike lane data`);
  for (const gw of greenways)
    drivers.push(`Greenway: ${gw}`);
  const season = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][new Date().getMonth()];
  drivers.push(`Seasonal adjustment applied for ${season}`);

  return drivers;
}

// ── Highlight tags ────────────────────────────────────────────
function inferHighlights(features, scores, greenways = [], treeSpecies = [], visualDetections = []) {
  const h = [];
  if (scores.nature > 0.4)       h.push('🌿 Tree-lined streets');
  if (scores.water  > 0.3)       h.push('💧 Waterfront path');
  if (scores.architecture > 0.3) h.push('🏛 Historic district');
  if (scores.nature > 0.6)       h.push('🏞 Park passage');
  if (scores.water  > 0.6)       h.push('🌊 River views');
  if (scores.quiet  > 0.5)       h.push('🔇 Quiet streets');
  const hasViewpoint = features.historic.some(f => f.tags?.tourism === 'viewpoint');
  const hasRiver     = features.water.some(f => f.tags?.waterway === 'river');
  const hasNatureRes = features.parks.some(f => f.tags?.leisure === 'nature_reserve');
  const hasCycleway  = features.paths.some(f => f.tags?.highway === 'cycleway' || f.tags?.bicycle === 'designated');
  const hasMonument  = features.historic.some(f => f.tags.historic === 'monument');
  const hasArtwork   = features.art.length > 0;
  const hasTrees     = features.trees.length > 10;
  if (hasViewpoint)  h.push('🌅 Scenic viewpoint');
  if (hasRiver)      h.push('🏞 River crossing');
  if (hasNatureRes)  h.push('🌲 Nature reserve');
  if (hasCycleway)   h.push('🚴 Dedicated cycle path');
  if (hasMonument)   h.push('🗿 Monument nearby');
  if (hasArtwork)    h.push('🎨 Street art');
  if (hasTrees)      h.push('🌳 Tree canopy');
  if (scores.bike  > 0.5) h.push('🚴 Protected bike infrastructure');
  if (scores.trees > 0.4) h.push('🌳 Tree-canopied streets');
  // Named notable species (cherry = spring blossom event)
  if (treeSpecies.some(s => s.includes('cherry'))) h.push('🌸 Cherry blossoms nearby');
  if (treeSpecies.some(s => s.includes('ginkgo'))) h.push('🍂 Ginkgo corridor');
  // Visual confirmations from Mapillary photo analysis
  for (const vh of detectionsToHighlights(visualDetections)) h.push(vh);
  // Named greenways
  for (const gw of greenways.slice(0, 2)) h.push(`🛤 ${gw}`);
  return [...new Set(h)].slice(0, 8);
}

// ── Adaptive scenic weight for A* ────────────────────────────
// Exported so the server can pass it to scenicAStar.
// Short routes (<2km): gentle pull, stay efficient.
// Long routes (>10km): strong pull, big scenic detours worthwhile.
export function adaptiveScenicWeight(distanceMeters, userWeights = {}) {
  const km         = distanceMeters / 1000;
  const lenFactor  = Math.min(1, Math.max(0.3, km / 10)); // 0.3 at 3km → 1.0 at 10km+
  const userPref   = ((userWeights.nature ?? 7) + (userWeights.water ?? 8)) / 20;
  return 0.75 * lenFactor * (0.5 + userPref * 0.5);
}

// ── Flat features for A* vision rays ─────────────────────────
// MongoDB locations included so the A* algorithm is pulled toward
// human-verified scenic spots as well as OSM features.
export async function fetchFeaturesFlat(bbox) {
  const [overpass, mongo] = await Promise.all([
    queryOverpass(bbox),
    queryMongoLocations(bbox),
  ]);
  const merged = mergeFeatures(overpass, mongo);
  return [
    ...merged.parks,
    ...merged.water,
    ...merged.historic,
    ...merged.paths,
    ...merged.trees,
    ...merged.art,
  ];
}

// ── Helpers ───────────────────────────────────────────────────
function getBoundingBox(coords) {
  let south = Infinity, west = Infinity, north = -Infinity, east = -Infinity;
  for (const [lng, lat] of coords) {
    if (lat < south) south = lat; if (lat > north) north = lat;
    if (lng < west)  west  = lng; if (lng > east)  east  = lng;
  }
  const pad = 0.004;
  return { south: south-pad, west: west-pad, north: north+pad, east: east+pad };
}

function distance([lng1, lat1], [lng2, lat2]) {
  return Math.sqrt((lng1-lng2)**2 + (lat1-lat2)**2);
}

function bboxToKey({ south, west, north, east }) {
  return `${south.toFixed(3)},${west.toFixed(3)},${north.toFixed(3)},${east.toFixed(3)}`;
}

function routeDistanceKm(coords) {
  let d = 0;
  for (let i = 0; i < coords.length - 1; i++) {
    const dx = (coords[i][0] - coords[i+1][0]) * 111320 * Math.cos(coords[i][1] * Math.PI/180);
    const dy = (coords[i][1] - coords[i+1][1]) * 111320;
    d += Math.sqrt(dx*dx + dy*dy);
  }
  return d / 1000;
}
