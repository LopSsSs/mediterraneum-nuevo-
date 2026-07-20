const CACHE = 'mediterraneum-v19';
const FILES = [
  './index.html',
  './manifest.json',
  './supabase.js'
];

// Dominios cuyas respuestas GET se guardan en caché para poder abrir la app sin conexión.
// OJO: no se cachea *.supabase.co (datos de la base de datos, siempre frescos).
const CACHEABLE_HOSTS = ['cdn.jsdelivr.net', 'fonts.googleapis.com', 'fonts.gstatic.com'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(FILES)));
  // No llamamos a skipWaiting aquí: la nueva versión queda "en espera"
  // hasta que el usuario pulse "Actualizar" en la barra de aviso.
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

// La página pide activar la versión en espera al pulsar "Actualizar"
self.addEventListener('message', e => {
  if (e.data && e.data.type === 'SKIP_WAITING') self.skipWaiting();
});

self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  const url = new URL(e.request.url);
  const cacheable = url.origin === location.origin || CACHEABLE_HOSTS.includes(url.hostname);
  // Red primero (contenido siempre fresco); si no hay conexión, usa la caché
  e.respondWith(
    fetch(e.request).then(r => {
      if (cacheable && r.ok) {
        const copia = r.clone();
        caches.open(CACHE).then(c => c.put(e.request, copia)).catch(() => {});
      }
      return r;
    }).catch(() => caches.match(e.request))
  );
});
