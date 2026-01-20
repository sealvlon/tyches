// js/ui.js
// UI utilities: modals, toasts, loading states, animations

// ============================================
// TOAST NOTIFICATIONS
// ============================================

let toastContainer = null;

function ensureToastContainer() {
  if (!toastContainer) {
    toastContainer = document.createElement('div');
    toastContainer.className = 'toast-container';
    toastContainer.setAttribute('aria-live', 'polite');
    document.body.appendChild(toastContainer);
  }
  return toastContainer;
}

export function showToast(message, type = 'info', duration = 3000) {
  const container = ensureToastContainer();
  
  const toast = document.createElement('div');
  toast.className = `toast toast-${type}`;
  toast.setAttribute('role', 'alert');
  
  const icon = getToastIcon(type);
  toast.innerHTML = `
    <span class="toast-icon">${icon}</span>
    <span class="toast-message">${escapeHtml(message)}</span>
    <button class="toast-close" aria-label="Dismiss">&times;</button>
  `;
  
  container.appendChild(toast);
  
  // Trigger animation
  requestAnimationFrame(() => {
    toast.classList.add('show');
  });
  
  const closeBtn = toast.querySelector('.toast-close');
  const dismiss = () => {
    toast.classList.remove('show');
    toast.classList.add('hiding');
    setTimeout(() => toast.remove(), 300);
  };
  
  closeBtn.addEventListener('click', dismiss);
  
  if (duration > 0) {
    setTimeout(dismiss, duration);
  }
  
  return { dismiss };
}

function getToastIcon(type) {
  const icons = {
    success: '✓',
    error: '✕',
    warning: '⚠',
    info: 'ℹ',
  };
  return icons[type] || icons.info;
}

// ============================================
// MODAL SYSTEM
// ============================================

const modals = new Map();

export function createModal(id, title, content, options = {}) {
  const {
    closable = true,
    size = 'medium', // small, medium, large, fullscreen
    onClose = null,
  } = options;
  
  // Remove existing modal with same ID
  if (modals.has(id)) {
    closeModal(id);
  }
  
  const backdrop = document.createElement('div');
  backdrop.className = 'modal-backdrop';
  backdrop.id = `modal-${id}`;
  backdrop.setAttribute('role', 'dialog');
  backdrop.setAttribute('aria-modal', 'true');
  backdrop.setAttribute('aria-labelledby', `modal-title-${id}`);
  
  backdrop.innerHTML = `
    <div class="modal modal-${size}">
      <div class="modal-header">
        <h2 id="modal-title-${id}">${escapeHtml(title)}</h2>
        ${closable ? '<button class="modal-close" aria-label="Close">&times;</button>' : ''}
      </div>
      <div class="modal-body">${content}</div>
    </div>
  `;
  
  document.body.appendChild(backdrop);
  
  // Focus trap
  const focusableElements = backdrop.querySelectorAll(
    'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
  );
  const firstFocusable = focusableElements[0];
  const lastFocusable = focusableElements[focusableElements.length - 1];
  
  if (firstFocusable) {
    firstFocusable.focus();
  }
  
  const handleKeydown = (e) => {
    if (e.key === 'Escape' && closable) {
      closeModal(id);
    }
    if (e.key === 'Tab') {
      if (e.shiftKey && document.activeElement === firstFocusable) {
        e.preventDefault();
        lastFocusable?.focus();
      } else if (!e.shiftKey && document.activeElement === lastFocusable) {
        e.preventDefault();
        firstFocusable?.focus();
      }
    }
  };
  
  backdrop.addEventListener('keydown', handleKeydown);
  
  if (closable) {
    const closeBtn = backdrop.querySelector('.modal-close');
    closeBtn?.addEventListener('click', () => closeModal(id));
    
    backdrop.addEventListener('click', (e) => {
      if (e.target === backdrop) {
        closeModal(id);
      }
    });
  }
  
  modals.set(id, { backdrop, onClose });
  
  // Animate in
  requestAnimationFrame(() => {
    backdrop.classList.add('show');
  });
  
  return backdrop;
}

export function closeModal(id) {
  const modal = modals.get(id);
  if (!modal) return;
  
  modal.backdrop.classList.remove('show');
  modal.backdrop.classList.add('hiding');
  
  setTimeout(() => {
    modal.backdrop.remove();
    modals.delete(id);
    modal.onClose?.();
  }, 200);
}

export function closeAllModals() {
  for (const id of modals.keys()) {
    closeModal(id);
  }
}

export function getModal(id) {
  return modals.get(id)?.backdrop || null;
}

// ============================================
// LOADING STATES
// ============================================

export function showLoading(element, text = 'Loading...') {
  if (!element) return;
  
  element.dataset.originalContent = element.innerHTML;
  element.classList.add('loading');
  element.innerHTML = `
    <div class="loading-spinner">
      <div class="spinner"></div>
      <span>${escapeHtml(text)}</span>
    </div>
  `;
}

export function hideLoading(element) {
  if (!element) return;
  
  element.classList.remove('loading');
  if (element.dataset.originalContent) {
    element.innerHTML = element.dataset.originalContent;
    delete element.dataset.originalContent;
  }
}

export function showSkeleton(container, count = 3, type = 'card') {
  if (!container) return;
  
  const skeletons = {
    card: `
      <div class="skeleton-card">
        <div class="skeleton-header">
          <div class="skeleton-avatar"></div>
          <div class="skeleton-lines">
            <div class="skeleton-line w-40"></div>
            <div class="skeleton-line w-20"></div>
          </div>
        </div>
        <div class="skeleton-line w-80"></div>
        <div class="skeleton-line w-60"></div>
        <div class="skeleton-bar"></div>
      </div>
    `,
    row: `
      <div class="skeleton-row">
        <div class="skeleton-line w-60"></div>
        <div class="skeleton-line w-20"></div>
      </div>
    `,
    text: `<div class="skeleton-line"></div>`,
  };
  
  container.innerHTML = Array(count).fill(skeletons[type] || skeletons.card).join('');
}

// ============================================
// UTILITY FUNCTIONS
// ============================================

export function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = String(str || '');
  return div.innerHTML;
}

export function escapeHtmlAttr(str) {
  return escapeHtml(str).replace(/"/g, '&quot;');
}

export function formatDate(dateStr) {
  if (!dateStr) return '';
  const d = new Date(dateStr);
  if (isNaN(d.getTime())) return dateStr;
  
  const now = new Date();
  const diff = d - now;
  const days = Math.ceil(diff / (1000 * 60 * 60 * 24));
  
  if (days < 0) return 'closed';
  if (days === 0) return 'today';
  if (days === 1) return 'tomorrow';
  if (days < 7) return `in ${days} days`;
  
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

export function formatRelativeTime(dateStr) {
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
  
  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

export function formatNumber(num, decimals = 0) {
  if (num >= 1000000) {
    return (num / 1000000).toFixed(1).replace(/\.0$/, '') + 'M';
  }
  if (num >= 1000) {
    return (num / 1000).toFixed(1).replace(/\.0$/, '') + 'K';
  }
  return num.toFixed(decimals);
}

export function formatCurrency(cents) {
  return `$${(cents / 100).toFixed(2)}`;
}

export function debounce(fn, delay) {
  let timeoutId;
  return function (...args) {
    clearTimeout(timeoutId);
    timeoutId = setTimeout(() => fn.apply(this, args), delay);
  };
}

export function throttle(fn, limit) {
  let inThrottle;
  return function (...args) {
    if (!inThrottle) {
      fn.apply(this, args);
      inThrottle = true;
      setTimeout(() => (inThrottle = false), limit);
    }
  };
}

// ============================================
// DOM HELPERS
// ============================================

export function $(selector, context = document) {
  return context.querySelector(selector);
}

export function $$(selector, context = document) {
  return Array.from(context.querySelectorAll(selector));
}

export function createElement(tag, attrs = {}, children = []) {
  const el = document.createElement(tag);
  
  for (const [key, value] of Object.entries(attrs)) {
    if (key === 'class' || key === 'className') {
      el.className = value;
    } else if (key === 'style' && typeof value === 'object') {
      Object.assign(el.style, value);
    } else if (key.startsWith('on') && typeof value === 'function') {
      el.addEventListener(key.slice(2).toLowerCase(), value);
    } else if (key === 'html') {
      el.innerHTML = value;
    } else if (key === 'text') {
      el.textContent = value;
    } else {
      el.setAttribute(key, value);
    }
  }
  
  for (const child of children) {
    if (typeof child === 'string') {
      el.appendChild(document.createTextNode(child));
    } else if (child instanceof Node) {
      el.appendChild(child);
    }
  }
  
  return el;
}

// Smooth scroll to element
export function scrollTo(element, offset = 0) {
  if (!element) return;
  const y = element.getBoundingClientRect().top + window.pageYOffset + offset;
  window.scrollTo({ top: y, behavior: 'smooth' });
}

// Copy to clipboard
export async function copyToClipboard(text) {
  try {
    await navigator.clipboard.writeText(text);
    showToast('Copied to clipboard!', 'success');
    return true;
  } catch (err) {
    showToast('Failed to copy', 'error');
    return false;
  }
}

export default {
  showToast,
  createModal,
  closeModal,
  closeAllModals,
  getModal,
  showLoading,
  hideLoading,
  showSkeleton,
  escapeHtml,
  escapeHtmlAttr,
  formatDate,
  formatRelativeTime,
  formatNumber,
  formatCurrency,
  debounce,
  throttle,
  $,
  $$,
  createElement,
  scrollTo,
  copyToClipboard,
};

