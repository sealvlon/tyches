// sw.js
// Tyches Service Worker - Push notifications and caching

const CACHE_NAME = 'tyches-v3';
const STATIC_ASSETS = [
  '/',
  '/index.php',
  '/styles.css',
  '/js/core.js',
  '/js/app.js',
  '/logo.webp',
  '/favicon.ico',
];

// ============================================
// INSTALLATION
// ============================================

self.addEventListener('install', (event) => {
  console.log('[SW] Installing...');
  
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('[SW] Caching static assets');
        return cache.addAll(STATIC_ASSETS);
      })
      .then(() => {
        console.log('[SW] Installed');
        return self.skipWaiting();
      })
  );
});

// ============================================
// ACTIVATION
// ============================================

self.addEventListener('activate', (event) => {
  console.log('[SW] Activating...');
  
  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames
            .filter((name) => name !== CACHE_NAME)
            .map((name) => {
              console.log('[SW] Deleting old cache:', name);
              return caches.delete(name);
            })
        );
      })
      .then(() => {
        console.log('[SW] Activated');
        return self.clients.claim();
      })
  );
});

// ============================================
// FETCH HANDLING
// ============================================

self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);
  
  // Skip non-GET requests
  if (request.method !== 'GET') {
    return;
  }
  
  // Skip API requests (let them go to network)
  if (url.pathname.startsWith('/api/')) {
    return;
  }
  
  // Skip external requests
  if (url.origin !== self.location.origin) {
    return;
  }
  
  // Cache-first strategy for static assets
  if (isStaticAsset(url.pathname)) {
    event.respondWith(
      caches.match(request)
        .then((cached) => {
          if (cached) {
            // Return cached, but also update in background
            event.waitUntil(
              fetch(request)
                .then((response) => {
                  if (response.ok) {
                    caches.open(CACHE_NAME)
                      .then((cache) => cache.put(request, response));
                  }
                })
                .catch(() => {})
            );
            return cached;
          }
          
          return fetch(request)
            .then((response) => {
              if (response.ok) {
                const clone = response.clone();
                caches.open(CACHE_NAME)
                  .then((cache) => cache.put(request, clone));
              }
              return response;
            });
        })
    );
    return;
  }
  
  // Network-first for HTML pages
  event.respondWith(
    fetch(request)
      .then((response) => {
        if (response.ok) {
          const clone = response.clone();
          caches.open(CACHE_NAME)
            .then((cache) => cache.put(request, clone));
        }
        return response;
      })
      .catch(() => {
        return caches.match(request)
          .then((cached) => {
            if (cached) {
              return cached;
            }
            
            // Return offline page for navigation requests
            if (request.mode === 'navigate') {
              return caches.match('/offline.html');
            }
            
            return new Response('Offline', { status: 503 });
          });
      })
  );
});

function isStaticAsset(pathname) {
  return pathname.endsWith('.css') ||
         pathname.endsWith('.js') ||
         pathname.endsWith('.png') ||
         pathname.endsWith('.jpg') ||
         pathname.endsWith('.webp') ||
         pathname.endsWith('.svg') ||
         pathname.endsWith('.ico') ||
         pathname.endsWith('.woff2');
}

// ============================================
// PUSH NOTIFICATIONS
// ============================================

self.addEventListener('push', (event) => {
  console.log('[SW] Push received');
  
  let data = {
    title: 'Tyches',
    body: 'You have a new notification',
    icon: '/icon-192.png',
    badge: '/badge-72.png',
    tag: 'tyches-notification',
    data: {},
  };
  
  try {
    if (event.data) {
      const payload = event.data.json();
      data = {
        ...data,
        ...payload,
      };
    }
  } catch (e) {
    console.warn('[SW] Push data parse error:', e);
  }
  
  const options = {
    body: data.body,
    icon: data.icon,
    badge: data.badge,
    tag: data.tag,
    data: data.data,
    requireInteraction: data.requireInteraction || false,
    actions: data.actions || [],
    vibrate: [100, 50, 100],
  };
  
  event.waitUntil(
    self.registration.showNotification(data.title, options)
  );
});

self.addEventListener('notificationclick', (event) => {
  console.log('[SW] Notification clicked');
  
  event.notification.close();
  
  const url = event.notification.data?.url || '/';
  
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then((windowClients) => {
        // Check if there's already an open window
        for (const client of windowClients) {
          if (client.url === url && 'focus' in client) {
            return client.focus();
          }
        }
        
        // Open new window
        if (clients.openWindow) {
          return clients.openWindow(url);
        }
      })
  );
});

// ============================================
// BACKGROUND SYNC
// ============================================

self.addEventListener('sync', (event) => {
  console.log('[SW] Background sync:', event.tag);
  
  if (event.tag === 'sync-bets') {
    event.waitUntil(syncPendingBets());
  }
});

async function syncPendingBets() {
  // Sync any pending bets stored in IndexedDB
  // This would be used for offline-first betting
  console.log('[SW] Syncing pending bets...');
}

// ============================================
// PERIODIC BACKGROUND SYNC
// ============================================

self.addEventListener('periodicsync', (event) => {
  console.log('[SW] Periodic sync:', event.tag);
  
  if (event.tag === 'check-updates') {
    event.waitUntil(checkForUpdates());
  }
});

async function checkForUpdates() {
  // Check for new events, bets, etc. in background
  console.log('[SW] Checking for updates...');
}

