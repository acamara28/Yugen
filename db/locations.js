import { getDb } from './client.js';
import { ObjectId } from 'mongodb';

const COL = 'locations';

// Ensure indexes exist (call once at startup)
export async function ensureIndexes() {
  const db = await getDb();
  const col = db.collection(COL);
  // 2dsphere index for geo queries
  await col.createIndex({ coordinates: '2dsphere' });
  // Useful query indexes
  await col.createIndex({ category: 1 });
  await col.createIndex({ scenicScore: -1 });
  await col.createIndex({ source: 1 });
  await col.createIndex({ tags: 1 });
}

// ── Insert a new location ─────────────────────────────────
// Returns the inserted document's _id
export async function insertLocation({
  name,
  lng,
  lat,
  category,
  scenicScore = 0,
  confidence = 0,
  features = {},
  source = 'manual',
  tags = [],
  description = '',
}) {
  const db  = await getDb();
  const col = db.collection(COL);

  const doc = {
    name,
    coordinates: {
      type:        'Point',
      coordinates: [lng, lat],   // GeoJSON: [lng, lat]
    },
    category,
    scenicScore,
    confidence,
    features: {
      waterProximity: features.waterProximity ?? null,  // 0-1
      treeCanopy:     features.treeCanopy     ?? null,  // 0-1
      trafficNoise:   features.trafficNoise   ?? null,  // 0-1 (1 = loud)
      surfaceType:    features.surfaceType    ?? null,  // 'paved'|'unpaved'|'grass'
      openSky:        features.openSky        ?? null,  // 0-1
      crowdLevel:     features.crowdLevel     ?? null,  // 0-1 (1 = very crowded)
    },
    source,
    tags,
    description,
    feedbackCount: 0,
    createdAt:     new Date(),
    updatedAt:     new Date(),
  };

  const result = await col.insertOne(doc);
  return result.insertedId;
}

// ── Find locations within radiusMeters of a point ────────
// Returns array sorted by distance (nearest first)
export async function findLocationsNearby(lng, lat, radiusMeters = 500) {
  const db  = await getDb();
  const col = db.collection(COL);

  return col.find({
    coordinates: {
      $near: {
        $geometry:    { type: 'Point', coordinates: [lng, lat] },
        $maxDistance: radiusMeters,
      },
    },
  }).toArray();
}

// ── Update scenic score and confidence after feedback ─────
// Confidence grows with each piece of feedback, capped at 1
export async function updateLocationScore(id, score) {
  const db  = await getDb();
  const col = db.collection(COL);

  // First fetch current values to recalculate weighted average
  const loc = await col.findOne({ _id: new ObjectId(id) });
  if (!loc) throw new Error(`Location ${id} not found`);

  const prevCount = loc.feedbackCount;
  const prevScore = loc.scenicScore;

  // Running weighted average
  const newCount  = prevCount + 1;
  const newScore  = (prevScore * prevCount + score) / newCount;
  // Confidence: grows as √(feedbackCount/10), caps at 1
  const newConf   = Math.min(1, Math.sqrt(newCount / 10));

  await col.updateOne(
    { _id: new ObjectId(id) },
    {
      $set: {
        scenicScore:   +newScore.toFixed(2),
        confidence:    +newConf.toFixed(3),
        feedbackCount: newCount,
        updatedAt:     new Date(),
      },
    }
  );

  return { scenicScore: newScore, confidence: newConf, feedbackCount: newCount };
}

// ── Find locations matching a feature profile ─────────────
// featureObject keys are optional — only provided ones are matched.
// Numeric values match within ±tolerance (default 0.3).
// surfaceType is an exact match.
export async function findByFeatures(featureObject, { limit = 20, tolerance = 0.3 } = {}) {
  const db    = await getDb();
  const col   = db.collection(COL);
  const query = {};

  const numericFeatures = [
    'waterProximity', 'treeCanopy', 'trafficNoise', 'openSky', 'crowdLevel',
  ];

  for (const key of numericFeatures) {
    if (featureObject[key] != null) {
      const v = featureObject[key];
      query[`features.${key}`] = {
        $gte: Math.max(0, v - tolerance),
        $lte: Math.min(1, v + tolerance),
      };
    }
  }

  if (featureObject.surfaceType) {
    query['features.surfaceType'] = featureObject.surfaceType;
  }

  return col
    .find(query)
    .sort({ scenicScore: -1 })
    .limit(limit)
    .toArray();
}
