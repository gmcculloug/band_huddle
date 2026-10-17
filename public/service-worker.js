// Band Huddle service worker
// Static assets use Cache Storage; authenticated gig responses use memory only.

const CACHE_NAME = 'band-huddle-gig-mode-v2';
const LEGACY_CACHE_NAMES = ['band-huddle-gig-mode-v1', 'band-huddle-gig-data-v1'];
const OFFLINE_CAPABLE_HEADER = 'X-Band-Huddle-Offline-Capable';
const STATIC_ASSETS = ['/gig-mode.css', '/gig-mode.js', '/favicon.ico'];
const privateGigResponses = new Map();

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(STATIC_ASSETS))
      .then(() => self.skipWaiting())
      .catch((error) => console.error('[Service Worker] Static asset cache failed:', error))
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((cacheNames) => Promise.all(
        cacheNames
          .filter((cacheName) => cacheName !== CACHE_NAME && !LEGACY_CACHE_NAMES.includes(cacheName))
          .map((cacheName) => caches.delete(cacheName))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  if (url.pathname === '/logout' || url.pathname === '/select_band') {
    event.waitUntil(clearPrivateGigData());
  }

  if (isGigDataRequest(url) || isGigModePageRequest(url)) {
    event.respondWith(handlePrivateGigRequest(event.request));
    return;
  }

  if (isStaticAsset(url.pathname)) {
    event.respondWith(handleStaticAssetRequest(event.request));
    return;
  }

  event.respondWith(fetch(event.request));
});

async function handlePrivateGigRequest(request) {
  try {
    const networkResponse = await fetch(request);
    storePrivateGigResponse(request, networkResponse);
    return networkResponse;
  } catch (error) {
    const cachedResponse = privateGigResponses.get(request.url);
    if (cachedResponse) {
      return cachedResponse.clone();
    }

    return offlineResponse(request);
  }
}

function storePrivateGigResponse(request, response) {
  if (response.ok && response.headers.get(OFFLINE_CAPABLE_HEADER) === 'true') {
    privateGigResponses.set(request.url, response.clone());
  }
}

async function handleStaticAssetRequest(request) {
  const cache = await caches.open(CACHE_NAME);
  const cachedResponse = await cache.match(request);
  if (cachedResponse) {
    return cachedResponse;
  }

  try {
    const networkResponse = await fetch(request);
    if (networkResponse.ok && !isNoStore(networkResponse)) {
      await cache.put(request, networkResponse.clone());
    }
    return networkResponse;
  } catch (error) {
    console.error('[Service Worker] Static asset fetch failed:', error);
    return new Response('Asset not available offline', { status: 503 });
  }
}

function isNoStore(response) {
  return (response.headers.get('Cache-Control') || '').toLowerCase().includes('no-store');
}

function isGigDataRequest(url) {
  return url.pathname.includes('/api/gigs/') && url.pathname.endsWith('/gig_mode');
}

function isGigModePageRequest(url) {
  return url.pathname.includes('/gigs/') && url.pathname.endsWith('/gig_mode');
}

function isStaticAsset(pathname) {
  const staticExtensions = ['.css', '.js', '.ico', '.png', '.jpg', '.svg'];
  const gigModeAssets = ['/gig-mode.css', '/gig-mode.js'];
  return staticExtensions.some((extension) => pathname.endsWith(extension)) ||
    gigModeAssets.some((asset) => pathname.includes(asset));
}

function offlineResponse(request) {
  if (isGigDataRequest(new URL(request.url))) {
    return Response.json({ error: 'Offline and no cached data available' }, { status: 503 });
  }

  return new Response('Offline and no cached page available', {
    status: 503,
    headers: { 'Content-Type': 'text/html' }
  });
}

async function clearPrivateGigData(gigId) {
  if (gigId) {
    privateGigResponses.delete(`/api/gigs/${gigId}/gig_mode`);
    privateGigResponses.delete(`/gigs/${gigId}/gig_mode`);
    return;
  }

  privateGigResponses.clear();
  await clearAllPersistentCaches();
}

async function clearAllPersistentCaches() {
  const cacheNames = await caches.keys();
  await Promise.all(cacheNames.map((cacheName) => caches.delete(cacheName)));
}

self.addEventListener('message', (event) => {
  const { type, gigId } = event.data;

  if (type === 'CACHE_GIG_DATA') {
    event.waitUntil(cacheGigData(gigId));
  } else if (type === 'CLEAR_GIG_CACHE') {
    event.waitUntil(clearPrivateGigData(gigId));
  } else if (type === 'GET_CACHE_STATUS') {
    getCacheStatus(gigId).then((status) => event.ports[0].postMessage(status));
  }
});

async function cacheGigData(gigId) {
  const requests = [
    new Request(`/api/gigs/${gigId}/gig_mode`),
    new Request(`/gigs/${gigId}/gig_mode`)
  ];

  try {
    await Promise.all(requests.map(async (request) => {
      const response = await fetch(request);
      storePrivateGigResponse(request, response);
    }));

    notifyClients({ type: 'GIG_CACHED', gigId });
  } catch (error) {
    notifyClients({ type: 'GIG_CACHE_ERROR', gigId, error: error.message });
  }
}

function getCacheStatus(gigId) {
  return Promise.resolve({
    gigId,
    dataCached: privateGigResponses.has(`/api/gigs/${gigId}/gig_mode`),
    pageCached: privateGigResponses.has(`/gigs/${gigId}/gig_mode`)
  });
}

function notifyClients(message) {
  self.clients.matchAll().then((clients) => clients.forEach((client) => client.postMessage(message)));
}
