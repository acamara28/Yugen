import fetch from 'node-fetch';

// ── Routing backends ──────────────────────────────────────
// OSRM  — completely free, no API key, great for foot/running/walking
// GraphHopper — needs a key for cycling (get free key at graphhopper.com)
//
// Routing strategy:
//   walk / run  → OSRM  (free, no key needed)
//   bike        → OSRM  (free bike profile, swap for GH when you have a key)

const OSRM_BASE = 'https://router.project-osrm.org/route/v1';
const TIMEOUT   = 15000;

// OSRM profile per mode
function osrmProfile(mode) {
  return mode === 'bike' ? 'bike' : 'foot';
}

// ── Destination route: A → B ──────────────────────────────
export async function fetchRoute(origin, destination, mode = 'walk') {
  const profile = osrmProfile(mode);
  // OSRM expects lng,lat order
  const coords  = `${origin[0]},${origin[1]};${destination[0]},${destination[1]}`;
  const url     = `${OSRM_BASE}/${profile}/${coords}` +
    `?overview=full&geometries=geojson&steps=false`;

  const res  = await fetch(url, { signal: AbortSignal.timeout(TIMEOUT) });
  const data = await res.json();

  if (data.code !== 'Ok') throw new Error(`Routing failed: ${data.message || data.code}`);
  if (!data.routes?.length) throw new Error('No route found between these points');

  const route = data.routes[0];
  return {
    geometry: route.geometry,                    // GeoJSON LineString
    distance: route.distance,                    // metres
    duration: route.duration * 1000,             // convert seconds → ms (match GH format)
    coords:   route.geometry.coordinates,
  };
}

// ── Loop route: scenic round trip from one point ──────────
// OSRM doesn't have a native round_trip algorithm.
// Strategy: generate 3 waypoints arranged in a rough triangle/circle
// at the right radius to approximate the target distance, then route
// through them and back to start.
export async function fetchLoop(origin, distanceMeters, mode = 'walk', seed = 0) {
  const profile = osrmProfile(mode);

  // Radius of the loop circle in degrees (~111320m per degree latitude)
  // A circle with this radius has circumference ≈ distanceMeters
  const radiusDeg = (distanceMeters / (2 * Math.PI)) / 111320;

  // Generate 3 evenly-spaced waypoints around the origin
  // seed rotates the starting angle so retries produce different loops
  const seedAngle = (seed * 137.5) % 360; // golden angle spread for variety
  const waypoints = [0, 120, 240].map(offset => {
    const angle = ((seedAngle + offset) * Math.PI) / 180;
    return [
      origin[0] + Math.cos(angle) * radiusDeg,
      origin[1] + Math.sin(angle) * radiusDeg,
    ];
  });

  // Build route: origin → wp1 → wp2 → wp3 → origin
  const allPoints  = [origin, ...waypoints, origin];
  const coordStr   = allPoints.map(p => `${p[0]},${p[1]}`).join(';');
  const url        = `${OSRM_BASE}/${profile}/${coordStr}` +
    `?overview=full&geometries=geojson&steps=false`;

  const res  = await fetch(url, { signal: AbortSignal.timeout(TIMEOUT) });
  const data = await res.json();

  if (data.code !== 'Ok') throw new Error(`Loop routing failed: ${data.message || data.code}`);
  if (!data.routes?.length) throw new Error('No loop found — try a different start point');

  const route = data.routes[0];
  return {
    geometry: route.geometry,
    distance: route.distance,
    duration: route.duration * 1000,
    coords:   route.geometry.coordinates,
  };
}
