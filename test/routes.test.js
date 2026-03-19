// ── Yugen Backend — Quick smoke test ─────────────────────
// Run: node test/routes.test.js
// Tests all endpoints against a running local server.
// Make sure `npm run dev` is running first.

const BASE = 'http://localhost:3001';

async function req(method, path, body) {
  const opts = { method, headers: { 'Content-Type': 'application/json' } };
  if (body) opts.body = JSON.stringify(body);
  const r = await fetch(`${BASE}${path}`, opts);
  return { status: r.status, data: await r.json() };
}

const pass = (label) => console.log(`  ✓  ${label}`);
const fail = (label, detail) => console.error(`  ✗  ${label}\n     ${detail}`);

async function run() {
  console.log('\n🗺  Yugen backend smoke tests\n');
  let allPassed = true;

  // 1. Health check
  try {
    const { status, data } = await req('GET', '/api/health');
    if (status === 200 && data.status === 'ok') pass('Health check');
    else { fail('Health check', JSON.stringify(data)); allPassed = false; }
  } catch (e) {
    fail('Health check — is the server running? (npm run dev)', e.message);
    allPassed = false;
    process.exit(1); // no point continuing
  }

  // 2. Config (Mapbox token)
  try {
    const { status, data } = await req('GET', '/api/config');
    if (status === 200 && data.mapboxToken?.startsWith('pk.'))
      pass('Config — Mapbox token loaded from .env');
    else
      fail('Config — MAPBOX_TOKEN missing from .env', JSON.stringify(data));
  } catch (e) { fail('Config', e.message); allPassed = false; }

  // 3. Destination route — walking, NYC
  console.log('\n  Running walking route test (Central Park → Brooklyn Bridge)…');
  try {
    const { status, data } = await req('POST', '/api/route', {
      origin:      'Central Park, New York',
      destination: 'Brooklyn Bridge, New York',
      mode:        'walk',
      weights:     { nature: 8, arch: 6, water: 7, elev: 5, quiet: 6 },
    });
    if (status === 200 && data.route?.distance > 0) {
      pass(`Walk route  ${(data.route.distance/1000).toFixed(1)}km  scenic:${data.scenicScore}/10`);
      if (data.highlights?.length) pass(`Highlights: ${data.highlights.join(', ')}`);
    } else { fail('Walk route', JSON.stringify(data)); allPassed = false; }
  } catch (e) { fail('Walk route', e.message); allPassed = false; }

  // 4. Destination route — running
  console.log('\n  Running route test (Times Square → High Line)…');
  try {
    const { status, data } = await req('POST', '/api/route', {
      origin:      'Times Square, New York',
      destination: 'The High Line, New York',
      mode:        'run',
      weights:     { nature: 7, arch: 7, water: 5, elev: 5, quiet: 5 },
    });
    if (status === 200 && data.route?.distance > 0)
      pass(`Run route  ${(data.route.distance/1000).toFixed(1)}km  scenic:${data.scenicScore}/10`);
    else { fail('Run route', JSON.stringify(data)); allPassed = false; }
  } catch (e) { fail('Run route', e.message); allPassed = false; }

  // 5. Loop route — 5km walk from Central Park
  console.log('\n  Running loop test (5km walk from Central Park)…');
  try {
    const { status, data } = await req('POST', '/api/loop', {
      origin:         'Central Park, New York',
      distanceMeters: 5000,
      mode:           'walk',
      seed:           42,
      weights:        { nature: 9, arch: 4, water: 7, elev: 5, quiet: 8 },
    });
    if (status === 200 && data.route?.distance > 0) {
      pass(`Loop  actual:${data.matchInfo.actualKm}km  target:${data.matchInfo.requestedKm}km  diff:${data.matchInfo.diffKm}km`);
      pass(`Loop scenic:${data.scenicScore}/10`);
    } else { fail('Loop', JSON.stringify(data)); allPassed = false; }
  } catch (e) { fail('Loop', e.message); allPassed = false; }

  // 6. Score endpoint with dummy coords (NYC block)
  try {
    const coords = [
      [-73.9857, 40.7484], [-73.9850, 40.7490],
      [-73.9840, 40.7495], [-73.9830, 40.7500],
    ];
    const { status, data } = await req('POST', '/api/score', {
      coords, weights: { nature: 7, arch: 6, water: 8, elev: 5, quiet: 6 },
    });
    if (status === 200 && typeof data.composite === 'number')
      pass(`Score endpoint  composite:${data.composite}/10`);
    else { fail('Score endpoint', JSON.stringify(data)); allPassed = false; }
  } catch (e) { fail('Score endpoint', e.message); allPassed = false; }

  console.log(allPassed
    ? '\n✅  All tests passed — backend is ready\n'
    : '\n❌  Some tests failed — check errors above\n'
  );
}

run().catch(console.error);

  // 7. Panoramic A* scenic route — the real algorithm
  console.log('\n  Running Panoramic A* scenic route test (Central Park → High Line)…');
  console.log('  (this may take 10-15s — fetching road graph from Overpass)');
  try {
    const { status, data } = await req('POST', '/api/scenic-route', {
      origin:      'Central Park, New York',
      destination: 'The High Line, New York',
      mode:        'walk',
      weights:     { nature: 9, arch: 5, water: 7, elev: 5, quiet: 8 },
    });
    if (status === 200 && data.route?.distance > 0) {
      pass(`Panoramic A*  ${(data.route.distance/1000).toFixed(1)}km  score:${data.scenicScore}/10  iterations:${data.iterations}`);
      if (data.highlights?.length) pass(`Highlights: ${data.highlights.join(', ')}`);
    } else { fail('Panoramic A*', JSON.stringify(data)); allPassed = false; }
  } catch (e) { fail('Panoramic A*', e.message); allPassed = false; }

  console.log(allPassed
    ? '\n✅  All tests passed — backend is ready\n'
    : '\n❌  Some tests failed — check errors above\n'
  );
