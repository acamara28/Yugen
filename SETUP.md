# Yugen Backend — Setup Guide

## Why the map wasn't loading

Opening yugen.html by double-clicking it uses the file:// protocol.
Mapbox GL JS requires http:// or https:// to load map tiles.
The fix: run the backend server and open http://localhost:3001/ instead.

## Project structure

yugen-backend/
├── public/
│   └── index.html        ← the Yugen frontend (served by Express)
├── scenic/
│   └── scorer.js         ← scenic scoring engine
├── routing/
│   ├── graphhopper.js    ← route fetching
│   └── geocoder.js       ← address → coordinates
├── server.js             ← Express API + static file server
├── package.json
├── .env                  ← your secrets (never commit this)
├── .env.example          ← template to share with collaborators
└── .gitignore

## Step 1 — Install Node.js

Download from https://nodejs.org (click LTS).
Verify: node --version   (should show v20+)

## Step 2 — Create your .env file

cp .env.example .env

Then open .env and paste your Mapbox token:
MAPBOX_TOKEN=pk.eyJ1IjoiYXNjMjgi...

## Step 3 — Install dependencies

npm install

## Step 4 — Start the server

npm run dev

You should see:
  Yugen running
  App    -> http://localhost:3001/
  Health -> http://localhost:3001/api/health

## Step 5 — Open the app

Open http://localhost:3001/ in your browser.
Do NOT open index.html directly — always use the http:// URL.

## Step 6 — Expose to the internet (ngrok)

In a NEW terminal tab:
ngrok http 3001

Copy the https://xxxx.ngrok-free.app URL.
Update CONFIG.BACKEND in public/index.html to that URL.

## Keep it running permanently

npm install -g pm2
pm2 start server.js --name yugen
pm2 startup
pm2 save

## Checklist before testing

[ ] Node.js installed (node --version shows v20+)
[ ] .env file exists with MAPBOX_TOKEN set
[ ] npm install completed (node_modules/ folder exists)
[ ] Server started (npm run dev)
[ ] Opening http://localhost:3001/ NOT file://
[ ] Map tiles load (outdoors style, beige terrain)
