/* Service Worker de Bitácora — cachea el shell de la app (HTML/manifest,
   solo archivos propios de este sitio) para que la interfaz cargue aunque
   no haya conexión. NUNCA cachea las llamadas a Supabase ni a ningún otro
   origen externo: los datos del negocio (colaboradores, nómina, asistencia,
   etc.) siempre deben venir en vivo del servidor — antes se estaban
   cacheando también, lo que podía mostrar información vieja o una página
   en blanco a alguien que ya hubiera visitado el sitio antes de una
   actualización.

   CACHE_NAME cambió de v1 a v2 a propósito: eso hace que, en la próxima
   visita de cualquiera que ya tuviera el sitio instalado/cacheado, el
   navegador borre la caché vieja automáticamente (ver "activate" abajo) y
   quede con la versión actual. Cada vez que se publique un cambio grande,
   conviene subir este número de nuevo. */
const CACHE_NAME = 'bitacora-shell-v2';
const APP_SHELL = ['./', './index.html', './manifest.json'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(APP_SHELL))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);
  /* Solo se cachean archivos propios de este sitio (HTML, manifest, íconos).
     Cualquier otro origen (Supabase, fuentes de Google, CDNs, etc.) va
     siempre directo a la red, sin pasar por esta caché. */
  if (url.origin !== self.location.origin) return;

  /* "Network first": siempre se intenta traer la versión más nueva primero.
     Si no hay conexión, se usa la última copia guardada (para poder abrir
     la app sin internet). Antes era al revés (caché primero, red de
     fondo) y por eso una actualización publicada no se veía hasta la
     SIGUIENTE visita — quien entrara mientras tanto podía ver una versión
     vieja, o en blanco si esa copia vieja quedó de un momento roto. */
  event.respondWith(
    fetch(req)
      .then((response) => {
        if (response && response.ok) {
          const copy = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(req, copy));
        }
        return response;
      })
      .catch(() => caches.match(req))
  );
});
