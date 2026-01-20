// js/realtime.js
// Real-time updates using Server-Sent Events (SSE) with polling fallback

const SSE_ENDPOINT = 'api/sse.php';
const POLL_ENDPOINT = 'api/poll.php';
const POLL_INTERVAL = 5000; // 5 seconds fallback polling

// Connection state
let eventSource = null;
let isSSESupported = typeof EventSource !== 'undefined';
let pollTimer = null;
let subscriptions = new Map();
let lastEventId = null;

// ============================================
// SSE CONNECTION
// ============================================

export function connect() {
  if (!isSSESupported) {
    console.log('[Realtime] SSE not supported, using polling');
    startPolling();
    return;
  }
  
  // Don't connect if not logged in
  if (document.body.dataset.loggedIn !== '1') {
    return;
  }
  
  if (eventSource) {
    return; // Already connected
  }
  
  try {
    const url = lastEventId 
      ? `${SSE_ENDPOINT}?lastEventId=${encodeURIComponent(lastEventId)}`
      : SSE_ENDPOINT;
    
    eventSource = new EventSource(url, { withCredentials: true });
    
    eventSource.onopen = () => {
      console.log('[Realtime] SSE connected');
      stopPolling();
    };
    
    eventSource.onerror = (err) => {
      console.warn('[Realtime] SSE error, falling back to polling', err);
      disconnect();
      startPolling();
    };
    
    eventSource.onmessage = (e) => {
      handleMessage(e.data, e.lastEventId);
    };
    
    // Custom event types
    eventSource.addEventListener('bet', (e) => {
      handleMessage(e.data, e.lastEventId, 'bet');
    });
    
    eventSource.addEventListener('gossip', (e) => {
      handleMessage(e.data, e.lastEventId, 'gossip');
    });
    
    eventSource.addEventListener('odds', (e) => {
      handleMessage(e.data, e.lastEventId, 'odds_update');
    });
    
    eventSource.addEventListener('notification', (e) => {
      handleMessage(e.data, e.lastEventId, 'notification');
    });
    
  } catch (err) {
    console.error('[Realtime] Failed to connect SSE:', err);
    startPolling();
  }
}

export function disconnect() {
  if (eventSource) {
    eventSource.close();
    eventSource = null;
  }
  stopPolling();
}

// ============================================
// POLLING FALLBACK
// ============================================

function startPolling() {
  if (pollTimer) return;
  
  console.log('[Realtime] Starting polling');
  poll();
  pollTimer = setInterval(poll, POLL_INTERVAL);
}

function stopPolling() {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }
}

async function poll() {
  if (document.body.dataset.loggedIn !== '1') {
    return;
  }
  
  const eventIds = [];
  for (const [key, sub] of subscriptions) {
    if (key.startsWith('event:')) {
      eventIds.push(key.split(':')[1]);
    }
  }
  
  if (eventIds.length === 0) {
    return; // Nothing to poll for
  }
  
  try {
    const params = new URLSearchParams();
    params.set('event_ids', eventIds.join(','));
    if (lastEventId) {
      params.set('since', lastEventId);
    }
    
    const response = await fetch(`${POLL_ENDPOINT}?${params}`, {
      credentials: 'same-origin',
    });
    
    if (!response.ok) {
      return;
    }
    
    const data = await response.json();
    
    if (data.updates && Array.isArray(data.updates)) {
      for (const update of data.updates) {
        handleMessage(JSON.stringify(update), update.id, update.type);
      }
    }
    
    if (data.lastEventId) {
      lastEventId = data.lastEventId;
    }
    
  } catch (err) {
    console.warn('[Realtime] Poll error:', err);
  }
}

// ============================================
// MESSAGE HANDLING
// ============================================

function handleMessage(data, eventId, type = null) {
  if (eventId) {
    lastEventId = eventId;
  }
  
  let parsed;
  try {
    parsed = typeof data === 'string' ? JSON.parse(data) : data;
  } catch (e) {
    console.warn('[Realtime] Failed to parse message:', data);
    return;
  }
  
  const messageType = type || parsed.type;
  const eventIdFromData = parsed.event_id || parsed.eventId;
  
  // Dispatch to subscribed handlers
  if (eventIdFromData) {
    const key = `event:${eventIdFromData}`;
    const sub = subscriptions.get(key);
    if (sub) {
      sub.callback({ ...parsed, type: messageType });
    }
  }
  
  // Global handlers
  const globalSub = subscriptions.get('global');
  if (globalSub) {
    globalSub.callback({ ...parsed, type: messageType });
  }
  
  // Notification handling
  if (messageType === 'notification') {
    showNotification(parsed);
  }
}

// ============================================
// SUBSCRIPTION API
// ============================================

let subscriptionCounter = 0;

export function subscribeToEvent(eventId, callback) {
  const id = ++subscriptionCounter;
  const key = `event:${eventId}`;
  
  subscriptions.set(key, { id, callback });
  
  // Ensure we're connected
  if (!eventSource && !pollTimer) {
    connect();
  }
  
  return id;
}

export function subscribeGlobal(callback) {
  const id = ++subscriptionCounter;
  subscriptions.set('global', { id, callback });
  
  if (!eventSource && !pollTimer) {
    connect();
  }
  
  return id;
}

export function unsubscribe(subscriptionId) {
  for (const [key, sub] of subscriptions) {
    if (sub.id === subscriptionId) {
      subscriptions.delete(key);
      break;
    }
  }
  
  // Disconnect if no more subscriptions
  if (subscriptions.size === 0) {
    disconnect();
  }
}

// ============================================
// NOTIFICATIONS
// ============================================

import { showToast } from './ui.js';

function showNotification(data) {
  const { title, message, type = 'info', url } = data;
  
  // Browser notification (if permitted)
  if (Notification.permission === 'granted') {
    const notification = new Notification(title || 'Tyches', {
      body: message,
      icon: '/favicon.ico',
      tag: data.id || Date.now().toString(),
    });
    
    if (url) {
      notification.onclick = () => {
        window.focus();
        window.location.href = url;
      };
    }
  }
  
  // In-app toast
  showToast(message, type);
}

// Request notification permission
export async function requestNotificationPermission() {
  if (!('Notification' in window)) {
    return 'unsupported';
  }
  
  if (Notification.permission === 'granted') {
    return 'granted';
  }
  
  if (Notification.permission !== 'denied') {
    const permission = await Notification.requestPermission();
    return permission;
  }
  
  return Notification.permission;
}

// ============================================
// VISIBILITY HANDLING
// ============================================

// Pause updates when tab is hidden
document.addEventListener('visibilitychange', () => {
  if (document.hidden) {
    // Tab is hidden - disconnect to save resources
    if (eventSource) {
      disconnect();
    }
    stopPolling();
  } else {
    // Tab is visible - reconnect
    if (subscriptions.size > 0) {
      connect();
    }
  }
});

// Reconnect on online
window.addEventListener('online', () => {
  if (subscriptions.size > 0) {
    connect();
  }
});

export default {
  connect,
  disconnect,
  subscribeToEvent,
  subscribeGlobal,
  unsubscribe,
  requestNotificationPermission,
};

