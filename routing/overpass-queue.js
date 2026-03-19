// ── Overpass request queue ────────────────────────────────────
// Overpass API rate-limits aggressive clients with 429/504.
// This module serialises all Overpass calls: only one goes out
// at a time, with a 1-second gap between each.
// Both graph-builder.js and scorer.js use this instead of
// calling fetch directly.

import fetch from 'node-fetch';

const OVERPASS_URL = 'https://overpass-api.de/api/interpreter';
const MIN_GAP_MS   = 1100;  // minimum ms between requests
const TIMEOUT_MS   = 25000;
const MAX_RETRIES  = 2;

let lastRequestTime = 0;
let queue = Promise.resolve(); // serialise all requests through this chain

export async function overpassFetch(query) {
  // Chain onto the queue — each call waits for the previous to finish
  // then waits for the minimum gap before sending
  return queue = queue.then(() => _send(query));
}

async function _send(query, attempt = 0) {
  // Enforce minimum gap between requests
  const now     = Date.now();
  const elapsed = now - lastRequestTime;
  if (elapsed < MIN_GAP_MS) {
    await sleep(MIN_GAP_MS - elapsed);
  }
  lastRequestTime = Date.now();

  try {
    const res = await fetch(OVERPASS_URL, {
      method:  'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body:    `data=${encodeURIComponent(query)}`,
      signal:  AbortSignal.timeout(TIMEOUT_MS),
    });

    // Retry on 429 (rate limit) or 504 (gateway timeout) with backoff
    if (res.status === 429 || res.status === 504) {
      if (attempt < MAX_RETRIES) {
        const backoff = (attempt + 1) * 3000; // 3s, 6s
        console.log(`[Overpass] ${res.status} — retrying in ${backoff/1000}s (attempt ${attempt+1})`);
        await sleep(backoff);
        return _send(query, attempt + 1);
      }
      throw new Error(`Overpass API error: ${res.status} after ${MAX_RETRIES} retries`);
    }

    if (!res.ok) throw new Error(`Overpass API error: ${res.status}`);
    return await res.json();

  } catch (err) {
    if (err.name === 'TimeoutError' && attempt < MAX_RETRIES) {
      console.log(`[Overpass] timeout — retrying (attempt ${attempt+1})`);
      await sleep(2000);
      return _send(query, attempt + 1);
    }
    throw err;
  }
}

const sleep = ms => new Promise(r => setTimeout(r, ms));
