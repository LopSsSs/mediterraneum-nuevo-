const CACHE = 'mediterraneum-v15';
const FILES = ['./index.html', './manifest.json'];

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
  // Red primero (contenido siempre fresco); si no hay conexión, usa la caché
  e.respondWith(fetch(e.request).catch(() => caches.match(e.request)));
});
