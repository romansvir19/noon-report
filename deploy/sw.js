/* Сеть-первым для навигации и кода, кэш — запасной для офлайна.
   Свежая версия подхватывается сама при любой связи; без сети работает из кэша. */
const V = 'noon-report-v43';
const FILES = [
  './',
  './index.html',
  './manifest.json',
  './icon-192.png',
  './icon-512.png',
  './apple-touch-icon.png'
];

self.addEventListener('install', e => {
  // один недокачанный файл не должен ронять весь офлайн-кэш
  e.waitUntil(
    caches.open(V)
      .then(c => Promise.allSettled(FILES.map(f => c.add(f))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== V).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

/* сеть с таймаутом: на полуживом спутниковом канале не ждём вечно —
   нет ответа за 4 секунды → отдаём из кэша */
function fetchFresh(req){
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), 4000);
  return fetch(req, { signal: ctl.signal })
    .then(res => {
      clearTimeout(timer);
      if (res && res.ok && res.type === 'basic'){
        const copy = res.clone();
        caches.open(V).then(c => c.put(req, copy));
      }
      return res;
    })
    .catch(() => {
      clearTimeout(timer);
      return caches.match(req, { ignoreSearch: true })
        .then(hit => hit || caches.match('./index.html'));
    });
}

self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  const url = new URL(e.request.url);
  const fresh = e.request.mode === 'navigate'
             || /\.(html|js|json)$/.test(url.pathname)
             || url.pathname.endsWith('/');
  if (fresh){
    e.respondWith(fetchFresh(e.request));
  } else {
    // картинки и прочее — из кэша, сеть в фоне
    e.respondWith(
      caches.match(e.request, { ignoreSearch: true }).then(hit =>
        hit || fetch(e.request).then(res => {
          if (res && res.ok && res.type === 'basic'){
            const copy = res.clone();
            caches.open(V).then(c => c.put(e.request, copy));
          }
          return res;
        })
      )
    );
  }
});
