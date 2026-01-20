/**
 * Tyches Core JS - Shared utilities and helpers
 * This file should be loaded before app.js
 */

// Global CSRF token (set via <meta name="csrf-token"> in PHP templates)
window.TYCHES_CSRF_TOKEN = 
  document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '';

// ============================================
// UTILITY FUNCTIONS
// ============================================

/**
 * Format number with commas
 * @param {number} num - Number to format
 * @returns {string} Formatted number
 */
window.formatNumber = function(num) {
  return Math.floor(num).toLocaleString();
};

/**
 * Format relative time ago
 * @param {string} dateStr - ISO date string
 * @returns {string} Relative time string
 */
window.formatTimeAgo = function(dateStr) {
  const date = new Date(dateStr);
  const now = new Date();
  const diff = Math.floor((now - date) / 1000);
  
  if (diff < 60) return 'just now';
  if (diff < 3600) return Math.floor(diff / 60) + 'm ago';
  if (diff < 86400) return Math.floor(diff / 3600) + 'h ago';
  if (diff < 604800) return Math.floor(diff / 86400) + 'd ago';
  return date.toLocaleDateString();
};

/**
 * Format time remaining until a date
 * @param {string} dateStr - ISO date string
 * @returns {string} Time remaining string
 */
window.formatTimeRemaining = function(dateStr) {
  const date = new Date(dateStr);
  const now = new Date();
  const diff = Math.floor((date - now) / 1000);
  
  if (diff < 0) return 'Closed';
  if (diff < 3600) return Math.floor(diff / 60) + 'm left';
  if (diff < 86400) return Math.floor(diff / 3600) + 'h left';
  if (diff < 604800) return Math.floor(diff / 86400) + 'd left';
  return Math.floor(diff / 604800) + 'w left';
};

/**
 * Format relative time (alternative version)
 * @param {string} dateStr - ISO date string
 * @returns {string} Relative time string
 */
window.formatRelativeTime = function(dateStr) {
  if (!dateStr) return '';
  const date = new Date(dateStr);
  const now = new Date();
  const diffMs = now - date;
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMs / 3600000);
  const diffDays = Math.floor(diffMs / 86400000);
  
  if (diffMins < 1) return 'just now';
  if (diffMins < 60) return `${diffMins}m ago`;
  if (diffHours < 24) return `${diffHours}h ago`;
  if (diffDays < 7) return `${diffDays}d ago`;
  return date.toLocaleDateString();
};

/**
 * Format date for display
 * @param {string} dateStr - ISO date string
 * @returns {string} Formatted date
 */
window.formatDate = function(dateStr) {
  const d = new Date(dateStr);
  const options = { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' };
  return d.toLocaleDateString('en-US', options);
};

/**
 * Escape HTML entities in a string
 * @param {string} str - String to escape
 * @returns {string} Escaped string
 */
window.escapeHtml = function(str) {
  return String(str || '').replace(/[&<>"']/g, s => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[s]));
};

/**
 * Escape HTML for use in attributes
 * @param {string} str - String to escape
 * @returns {string} Escaped string
 */
window.escapeHtmlAttr = function(str) {
  return escapeHtml(str).replace(/"/g, '&quot;');
};

/**
 * Generate consistent avatar color based on name
 * @param {string} name - User name
 * @returns {string} CSS color value
 */
window.getAvatarColor = function(name) {
  const colors = [
    '#7c3aed', // purple
    '#10b981', // green
    '#f59e0b', // amber
    '#ec4899', // pink
    '#3b82f6', // blue
    '#ef4444', // red
    '#8b5cf6', // violet
    '#06b6d4', // cyan
  ];
  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = name.charCodeAt(i) + ((hash << 5) - hash);
  }
  return colors[Math.abs(hash) % colors.length];
};

/**
 * Show toast notification
 * @param {string} message - Message to display
 * @param {string} type - Type: 'info', 'success', 'error', 'warning'
 */
window.showToast = function(message, type = 'info') {
  const existing = document.querySelector('.toast');
  if (existing) existing.remove();
  
  const toast = document.createElement('div');
  toast.className = `toast toast-${type}`;
  toast.textContent = message;
  document.body.appendChild(toast);
  
  setTimeout(() => toast.classList.add('show'), 10);
  setTimeout(() => {
    toast.classList.remove('show');
    setTimeout(() => toast.remove(), 300);
  }, 3000);
};

// ============================================
// SERVICE WORKER REGISTRATION
// ============================================

if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js')
      .then((registration) => {
        console.log('[Tyches] Service Worker registered');
        
        // Check for updates
        registration.addEventListener('updatefound', () => {
          const newWorker = registration.installing;
          newWorker.addEventListener('statechange', () => {
            if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
              // New version available
              console.log('[Tyches] New version available');
              showToast('App updated! Refresh for latest version.', 'info');
            }
          });
        });
      })
      .catch((err) => {
        console.warn('[Tyches] Service Worker registration failed:', err);
      });
  });
}

// ============================================
// INITIALIZATION
// ============================================

// Mark core as loaded
window.TYCHES_CORE_LOADED = true;

console.log('[Tyches] Core utilities loaded');

