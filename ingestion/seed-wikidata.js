import 'dotenv/config';
import { getDb } from '../db/client.js';
import { ensureIndexes } from '../db/locations.js';

const SPARQL_ENDPOINT = 'https://query.wikidata.org/sparql';
const USER_AGENT      = 'YugenScenicRouter/1.0 (scenic routing app)';
const COL             = 'locations';

// ── Scenic scores by category ─────────────────────────────
const CATEGORY_SCORES = {
  nature_reserve: 8.5,
  viewpoint:      9.0,
  waterway:       8.0,
  park:           7.5,
  garden:         7.5,
  monument:       7.0,
  landmark:       7.0,
};

// ── NYC bounding box ──────────────────────────────────────
// Using wikibase:around is faster than recursive P131 traversal
const NYC = { lat: 40.7128, lng: -74.0060, radius: 30 }; // 30km covers all 5 boroughs

// ── Queries using geographic bounding box ─────────────────
const QUERIES = [
  {
    label:    'Parks',
    category: 'park',
    sparql: `
      SELECT DISTINCT ?item ?itemLabel ?lat ?lng ?description WHERE {
        SERVICE wikibase:around {
          ?item wdt:P625 ?coord.
          bd:serviceParam wikibase:center "Point(${NYC.lng} ${NYC.lat})"^^geo:wktLiteral.
          bd:serviceParam wikibase:radius "${NYC.radius}".
        }
        ?item wdt:P31/wdt:P279* wd:Q22698.
        BIND(geof:latitude(?coord)  AS ?lat)
        BIND(geof:longitude(?coord) AS ?lng)
        OPTIONAL { ?item schema:description ?description. FILTER(LANG(?description)="en") }
        SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
      } LIMIT 500
    `,
  },
  {
    label:    'Nature Reserves',
    category: 'nature_reserve',
    sparql: `
      SELECT DISTINCT ?item ?itemLabel ?lat ?lng ?description WHERE {
        SERVICE wikibase:around {
          ?item wdt:P625 ?coord.
          bd:serviceParam wikibase:center "Point(${NYC.lng} ${NYC.lat})"^^geo:wktLiteral.
          bd:serviceParam wikibase:radius "${NYC.radius}".
        }
        ?item wdt:P31/wdt:P279* wd:Q179049.
        BIND(geof:latitude(?coord)  AS ?lat)
        BIND(geof:longitude(?coord) AS ?lng)
        OPTIONAL { ?item schema:description ?description. FILTER(LANG(?description)="en") }
        SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
      } LIMIT 300
    `,
  },
  {
    label:    'Gardens',
    category: 'garden',
    sparql: `
      SELECT DISTINCT ?item ?itemLabel ?lat ?lng ?description WHERE {
        SERVICE wikibase:around {
          ?item wdt:P625 ?coord.
          bd:serviceParam wikibase:center "Point(${NYC.lng} ${NYC.lat})"^^geo:wktLiteral.
          bd:serviceParam wikibase:radius "${NYC.radius}".
        }
        { ?item wdt:P31/wdt:P279* wd:Q1107656. } UNION
        { ?item wdt:P31/wdt:P279* wd:Q167346.  }
        BIND(geof:latitude(?coord)  AS ?lat)
        BIND(geof:longitude(?coord) AS ?lng)
        OPTIONAL { ?item schema:description ?description. FILTER(LANG(?description)="en") }
        SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
      } LIMIT 300
    `,
  },
  {
    label:    'Monuments & Memorials',
    category: 'monument',
    sparql: `
      SELECT DISTINCT ?item ?itemLabel ?lat ?lng ?description WHERE {
        SERVICE wikibase:around {
          ?item wdt:P625 ?coord.
          bd:serviceParam wikibase:center "Point(${NYC.lng} ${NYC.lat})"^^geo:wktLiteral.
          bd:serviceParam wikibase:radius "${NYC.radius}".
        }
        { ?item wdt:P31/wdt:P279* wd:Q4989906. } UNION
        { ?item wdt:P31/wdt:P279* wd:Q5003624. } UNION
        { ?item wdt:P31/wdt:P279* wd:Q179700.  }
        BIND(geof:latitude(?coord)  AS ?lat)
        BIND(geof:longitude(?coord) AS ?lng)
        OPTIONAL { ?item schema:description ?description. FILTER(LANG(?description)="en") }
        SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
      } LIMIT 500
    `,
  },
  {
    label:    'Viewpoints',
    category: 'viewpoint',
    sparql: `
      SELECT DISTINCT ?item ?itemLabel ?lat ?lng ?description WHERE {
        SERVICE wikibase:around {
          ?item wdt:P625 ?coord.
          bd:serviceParam wikibase:center "Point(${NYC.lng} ${NYC.lat})"^^geo:wktLiteral.
          bd:serviceParam wikibase:radius "${NYC.radius}".
        }
        ?item wdt:P31/wdt:P279* wd:Q1070990.
        BIND(geof:latitude(?coord)  AS ?lat)
        BIND(geof:longitude(?coord) AS ?lng)
        OPTIONAL { ?item schema:description ?description. FILTER(LANG(?description)="en") }
        SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
      } LIMIT 200
    `,
  },
  {
    label:    'Waterways & Lakes',
    category: 'waterway',
    sparql: `
      SELECT DISTINCT ?item ?itemLabel ?lat ?lng ?description WHERE {
        SERVICE wikibase:around {
          ?item wdt:P625 ?coord.
          bd:serviceParam wikibase:center "Point(${NYC.lng} ${NYC.lat})"^^geo:wktLiteral.
          bd:serviceParam wikibase:radius "${NYC.radius}".
        }
        { ?item wdt:P31/wdt:P279* wd:Q4022.  } UNION
        { ?item wdt:P31/wdt:P279* wd:Q23397. } UNION
        { ?item wdt:P31/wdt:P279* wd:Q12284. } UNION
        { ?item wdt:P31/wdt:P279* wd:Q283.   }
        BIND(geof:latitude(?coord)  AS ?lat)
        BIND(geof:longitude(?coord) AS ?lng)
        OPTIONAL { ?item schema:description ?description. FILTER(LANG(?description)="en") }
        SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
      } LIMIT 300
    `,
  },
  {
    label:    'Landmarks & Historic Sites',
    category: 'landmark',
    sparql: `
      SELECT DISTINCT ?item ?itemLabel ?lat ?lng ?description WHERE {
        SERVICE wikibase:around {
          ?item wdt:P625 ?coord.
          bd:serviceParam wikibase:center "Point(${NYC.lng} ${NYC.lat})"^^geo:wktLiteral.
          bd:serviceParam wikibase:radius "${NYC.radius}".
        }
        { ?item wdt:P31/wdt:P279* wd:Q570116. } UNION
        { ?item wdt:P31/wdt:P279* wd:Q839954. } UNION
        { ?item wdt:P31/wdt:P279* wd:Q747074. }
        BIND(geof:latitude(?coord)  AS ?lat)
        BIND(geof:longitude(?coord) AS ?lng)
        OPTIONAL { ?item schema:description ?description. FILTER(LANG(?description)="en") }
        SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
      } LIMIT 500
    `,
  },
];

// ── Fetch SPARQL with retry ───────────────────────────────
async function fetchSparql(sparql, label) {
  const url = `${SPARQL_ENDPOINT}?query=${encodeURIComponent(sparql)}&format=json`;

  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const res = await fetch(url, {
        headers: { 'User-Agent': USER_AGENT, 'Accept': 'application/sparql-results+json' },
        signal:  AbortSignal.timeout(45000),
      });
      if (res.status === 429) {
        const wait = attempt * 15000;
        console.log(`  Rate limited — waiting ${wait/1000}s...`);
        await sleep(wait);
        continue;
      }
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      return data.results.bindings;
    } catch (err) {
      if (attempt === 3) throw err;
      console.log(`  Attempt ${attempt} failed: ${err.message} — retrying in ${attempt * 5}s...`);
      await sleep(attempt * 5000);
    }
  }
  return [];
}

// ── Transform Wikidata result → MongoDB doc ───────────────
function transform(binding, category) {
  const lat = parseFloat(binding.lat?.value);
  const lng = parseFloat(binding.lng?.value);
  if (isNaN(lat) || isNaN(lng)) return null;

  // NYC bounding box check
  if (lat < 40.4 || lat > 41.0 || lng < -74.3 || lng > -73.6) return null;

  const name = binding.itemLabel?.value || '';
  if (!name || /^Q\d+$/.test(name)) return null; // skip unlabelled items

  return {
    name,
    coordinates:   { type: 'Point', coordinates: [lng, lat] },
    category,
    scenicScore:   CATEGORY_SCORES[category] ?? 7.0,
    confidence:    0.5,
    features: {
      waterProximity: category === 'waterway'                                    ? 0.9 : null,
      treeCanopy:     ['park','nature_reserve','garden'].includes(category)       ? 0.7 : null,
      trafficNoise:   null,
      surfaceType:    null,
      openSky:        category === 'viewpoint'                                   ? 0.9 : null,
      crowdLevel:     null,
    },
    source:        'wikidata',
    tags:          [category],
    description:   binding.description?.value || '',
    feedbackCount: 0,
    wikidataId:    binding.item?.value?.split('/').pop() || '',
    createdAt:     new Date(),
    updatedAt:     new Date(),
  };
}

// ── Main ──────────────────────────────────────────────────
async function main() {
  console.log('\n🌿 Yugen — Wikidata NYC Seeder\n');

  await ensureIndexes();
  const db  = await getDb();
  const col = db.collection(COL);

  // Index wikidataId for fast dedup checks
  await col.createIndex({ wikidataId: 1 }, { sparse: true });

  let totalSaved = 0;
  let totalSkipped = 0;

  for (const query of QUERIES) {
    console.log(`\n📍 ${query.label}...`);
    let bindings;
    try {
      bindings = await fetchSparql(query.sparql, query.label);
    } catch (err) {
      console.error(`  ✗ Failed: ${err.message}`);
      continue;
    }
    console.log(`  ${bindings.length} results from Wikidata`);

    let saved = 0, skipped = 0;
    const batch = [];

    for (let i = 0; i < bindings.length; i++) {
      const doc = transform(bindings[i], query.category);
      if (!doc) { skipped++; continue; }

      // Dedup by wikidataId
      if (doc.wikidataId) {
        const exists = await col.findOne({ wikidataId: doc.wikidataId }, { projection: { _id: 1 } });
        if (exists) { skipped++; continue; }
      }

      batch.push(doc);

      if (batch.length >= 50) {
        try {
          await col.insertMany(batch, { ordered: false });
        } catch (e) { /* ignore duplicate key errors */ }
        saved += batch.length;
        totalSaved += batch.length;
        batch.length = 0;
      }

      if ((i + 1) % 100 === 0) {
        console.log(`  Progress: ${i + 1}/${bindings.length} processed, ${saved} saved...`);
      }
    }

    if (batch.length > 0) {
      try {
        await col.insertMany(batch, { ordered: false });
      } catch (e) { /* ignore duplicate key errors */ }
      saved += batch.length;
      totalSaved += batch.length;
    }

    totalSkipped += skipped;
    console.log(`  ✓ ${saved} saved, ${skipped} skipped`);

    await sleep(3000); // be respectful to Wikidata
  }

  console.log('\n──────────────────────────────────');
  console.log(`✅ Done — ${totalSaved} locations saved to MongoDB`);
  console.log(`   Skipped (dupes/out of bounds): ${totalSkipped}`);
  console.log('──────────────────────────────────\n');
  process.exit(0);
}

const sleep = ms => new Promise(r => setTimeout(r, ms));
main().catch(err => { console.error('Fatal:', err); process.exit(1); });
