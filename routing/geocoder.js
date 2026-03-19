import fetch from 'node-fetch';

export async function geocode(query, token) {
  const url = `https://api.mapbox.com/geocoding/v5/mapbox.places/${encodeURIComponent(query)}.json?access_token=${token}&limit=1`;
  const res = await fetch(url);
  if (!res.ok) throw new Error('Geocoding failed — check your Mapbox API key');
  const data = await res.json();
  if (!data.features?.length) throw new Error(`Location not found: "${query}"`);
  return data.features[0].center; // [lng, lat]
}
