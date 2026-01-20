// Tyches main frontend logic
// Requires: js/core.js to be loaded first

// Use CSRF token from core.js or define fallback
const TYCHES_CSRF_TOKEN = window.TYCHES_CSRF_TOKEN || 
  document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '';

document.addEventListener('DOMContentLoaded', () => {
  hydrateUserFromDataset();
  setupNav();
  setupDashboardToggle();
  setupAuthModals();
  setupCreateEventUI();
  wirePageByContext();
});

// --- Global auth state (for UI only; server uses PHP sessions) ---
window.tychesUser = null;

function hydrateUserFromDataset() {
  const loggedIn = document.body.dataset.loggedIn === '1';
  console.log('[Tyches] loggedIn from body dataset:', loggedIn);
  if (!loggedIn) return;
  
  // We don't have full user fields in the DOM; fetch from profile API.
  console.log('[Tyches] Fetching profile...');
  fetch('api/profile.php', { credentials: 'same-origin' })
    .then(r => {
      console.log('[Tyches] Profile API response status:', r.status);
      if (!r.ok) {
        return r.text().then(t => { console.error('[Tyches] Profile API error:', t); return null; });
      }
      return r.json();
    })
    .then(data => {
      console.log('[Tyches] Profile data:', data);
      if (!data || !data.user) {
        console.warn('[Tyches] No user data in profile response');
        return;
      }
      window.tychesUser = data.user;
      window.tychesProfile = data;
      fillUserPill(data.user);
      
      // Initialize new app shell if present
      if (document.getElementById('app-shell')) {
        initAppShell(data);
      }
      // Fallback to old dashboard if present
      else if (document.getElementById('dashboard')) {
        console.log('[Tyches] Calling hydrateDashboard with', data.markets?.length, 'markets');
        hydrateDashboard(data);
      }
      // Hydrate profile page (standalone or embedded)
      const isProfilePage = document.querySelector('.profile-page') || window.location.pathname.includes('profile.php');
      console.log('[Tyches] Profile page check:', isProfilePage, 'pathname:', window.location.pathname);
      if (isProfilePage) {
        hydrateProfilePage(data);
      }
      
      // Initialize app topbar for any page using app shell (market.php, event.php, profile.php, create-event.php)
      if (document.querySelector('.app-topbar') && !document.getElementById('app-shell')) {
        initAppTopbar(data.user);
        initGlobalSearch();
        setupCreateMenu();
      }
    })
    .catch(err => {
      console.error('[Tyches] Profile fetch error:', err);
    });
}

// ============================================
// APP SHELL - New Tab-based Interface
// ============================================

function initAppShell(profileData) {
  const appShell = document.getElementById('app-shell');
  if (!appShell) return;
  
  appShell.style.display = 'block';
  
  // Initialize user info in topbar
  initAppTopbar(profileData.user);
  
  // Show verification banner if needed
  if (!profileData.user.is_verified) {
    const banner = document.getElementById('verify-banner');
    if (banner) banner.style.display = 'flex';
    
    const bannerBtn = document.getElementById('verify-banner-btn');
    if (bannerBtn) {
      bannerBtn.addEventListener('click', async () => {
        bannerBtn.disabled = true;
        bannerBtn.textContent = 'Sending...';
        try {
          const res = await fetch('api/profile.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': TYCHES_CSRF_TOKEN },
            credentials: 'same-origin',
            body: JSON.stringify({ action: 'resend_verification' }),
          });
          if (res.ok) {
            bannerBtn.textContent = 'Email Sent!';
          } else {
            bannerBtn.textContent = 'Try Again';
            bannerBtn.disabled = false;
          }
        } catch {
          bannerBtn.textContent = 'Try Again';
          bannerBtn.disabled = false;
        }
      });
    }
  }
  
  // Setup tab navigation
  setupTabNavigation();
  
  // Setup create menu
  setupCreateMenu();
  
  // Load initial data for feed
  loadFeedData(profileData);
  
  // Pre-cache markets data
  window.tychesMarketsData = profileData.markets || [];
}

function initAppTopbar(user) {
  // Token balance
  const tokenEl = document.getElementById('header-token-balance');
  if (tokenEl) tokenEl.textContent = formatNumber(user.tokens_balance || 0);
  
  // User avatar
  const avatarEl = document.getElementById('app-user-initial');
  if (avatarEl) {
    avatarEl.textContent = (user.name || user.username || '?').charAt(0).toUpperCase();
  }
  
  // Dropdown info
  const dropdownName = document.getElementById('dropdown-user-name');
  const dropdownEmail = document.getElementById('dropdown-user-email');
  if (dropdownName) dropdownName.textContent = user.name || user.username;
  if (dropdownEmail) dropdownEmail.textContent = user.email || '';
  
  // User dropdown toggle
  const avatarBtn = document.getElementById('user-avatar-btn');
  const dropdownMenu = document.getElementById('user-dropdown-menu');
  if (avatarBtn && dropdownMenu) {
    avatarBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      dropdownMenu.classList.toggle('open');
    });
    document.addEventListener('click', () => dropdownMenu.classList.remove('open'));
  }
  
  // Logout
  const logoutBtn = document.getElementById('dropdown-logout');
  if (logoutBtn) {
    logoutBtn.addEventListener('click', async () => {
      await fetch('api/logout.php', {
        method: 'POST',
        headers: { 'X-CSRF-Token': TYCHES_CSRF_TOKEN },
        credentials: 'same-origin',
      });
      window.location.href = 'index.php';
    });
  }
  
  // Notifications button - use event delegation for reliability
  setupNotificationsButton();
  
  // Settings button
  const settingsBtn = document.getElementById('dropdown-settings');
  if (settingsBtn) {
    settingsBtn.addEventListener('click', (e) => {
      e.preventDefault();
      dropdownMenu?.classList.remove('open');
      openSettingsModal(user);
    });
  }
  
  // Initialize search
  initGlobalSearch();
}

// ============================================
// NOTIFICATIONS PANEL
// ============================================

// Global flag to prevent multiple event delegation setups
let notificationsSetup = false;

function setupNotificationsButton() {
  if (notificationsSetup) return;
  notificationsSetup = true;
  
  // Use event delegation on document for maximum reliability
  document.addEventListener('click', (e) => {
    const btn = e.target.closest('#notifications-btn');
    if (btn) {
      e.preventDefault();
      e.stopPropagation();
      openNotificationsPanel();
    }
  });
}

function openNotificationsPanel() {
  // Check if panel already exists
  let panel = document.getElementById('notifications-panel');
  if (panel) {
    panel.classList.toggle('open');
    if (panel.classList.contains('open')) {
      loadNotifications();
    }
    return;
  }
  
  // Create notifications panel
  panel = document.createElement('div');
  panel.id = 'notifications-panel';
  panel.className = 'notifications-panel';
  panel.innerHTML = `
    <div class="notifications-header">
      <h3>Notifications</h3>
      <button class="notifications-close" id="notifications-close">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
        </svg>
      </button>
    </div>
    <div class="notifications-list" id="notifications-list">
      <div class="notifications-loading">Loading...</div>
    </div>
    <div class="notifications-footer">
      <button class="btn-ghost" id="mark-all-read">Mark all as read</button>
    </div>
  `;
  document.body.appendChild(panel);
  
  // Force reflow then add open class for animation
  panel.offsetHeight;
  panel.classList.add('open');
  
  // Close button
  document.getElementById('notifications-close').addEventListener('click', (e) => {
    e.stopPropagation();
    panel.classList.remove('open');
  });
  
  // Close when clicking outside - add with delay to prevent immediate close
  setTimeout(() => {
    document.addEventListener('click', function closeHandler(e) {
      if (!panel.contains(e.target) && !e.target.closest('#notifications-btn')) {
        panel.classList.remove('open');
      }
    });
  }, 10);
  
  // Load notifications
  loadNotifications();
  
  // Mark all as read
  document.getElementById('mark-all-read').addEventListener('click', markAllNotificationsRead);
}

async function loadNotifications() {
  const list = document.getElementById('notifications-list');
  if (!list) return;
  
  try {
    const res = await fetch('api/notifications.php', { credentials: 'same-origin' });
    
    // Check if response is ok first
    if (!res.ok) {
      const errorText = await res.text();
      console.error('Notifications API error:', res.status, errorText);
      list.innerHTML = `
        <div class="notifications-empty">
          <div class="notifications-empty-icon">🔔</div>
          <p>No notifications yet</p>
          <span>You're all caught up!</span>
        </div>
      `;
      return;
    }
    
    const data = await res.json();
    
    if (!data.notifications || data.notifications.length === 0) {
      list.innerHTML = `
        <div class="notifications-empty">
          <div class="notifications-empty-icon">🔔</div>
          <p>No notifications yet</p>
          <span>You're all caught up!</span>
        </div>
      `;
      return;
    }
    
    list.innerHTML = data.notifications.map(n => `
      <div class="notification-item ${n.is_read ? '' : 'unread'}" data-id="${n.id}">
        <div class="notification-icon">${getNotificationIcon(n.type)}</div>
        <div class="notification-content">
          <div class="notification-title">${escapeHtml(n.title || '')}</div>
          <div class="notification-message">${escapeHtml(n.message || '')}</div>
          <div class="notification-time">${formatTimeAgo(n.created_at)}</div>
        </div>
      </div>
    `).join('');
    
    // Update badge
    const unreadCount = data.notifications.filter(n => !n.is_read).length;
    updateNotificationBadge(unreadCount);
    
  } catch (err) {
    console.error('Failed to load notifications:', err);
    // Show empty state instead of error for better UX
    list.innerHTML = `
      <div class="notifications-empty">
        <div class="notifications-empty-icon">🔔</div>
        <p>No notifications yet</p>
        <span>You're all caught up!</span>
      </div>
    `;
  }
}

function getNotificationIcon(type) {
  const icons = {
    'welcome': '🎉',
    'tip': '💡',
    'bet': '💰',
    'bet_placed': '💰',
    'bet_won': '🏆',
    'bet_lost': '😢',
    'event': '📊',
    'event_created': '📊',
    'event_resolved': '✅',
    'market': '👥',
    'market_invite': '📨',
    'win': '🏆',
    'resolution': '✅',
    'invite': '📨',
    'comment': '💬',
    'gossip': '💬',
    'friend': '👋',
  };
  return icons[type] || '🔔';
}

function updateNotificationBadge(count) {
  const badge = document.getElementById('notification-count');
  if (badge) {
    if (count > 0) {
      badge.textContent = count > 99 ? '99+' : count;
      badge.style.display = 'flex';
    } else {
      badge.style.display = 'none';
    }
  }
}

async function markAllNotificationsRead() {
  try {
    await fetch('api/notifications.php', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': TYCHES_CSRF_TOKEN },
      credentials: 'same-origin',
      body: JSON.stringify({ action: 'mark_all_read' }),
    });
    
    // Update UI
    document.querySelectorAll('.notification-item.unread').forEach(el => {
      el.classList.remove('unread');
    });
    updateNotificationBadge(0);
    
  } catch (err) {
    console.error('Failed to mark notifications as read:', err);
  }
}

// ============================================
// SETTINGS MODAL
// ============================================

function openSettingsModal(user) {
  // Create settings modal
  const overlay = document.createElement('div');
  overlay.className = 'modal-overlay active';
  overlay.id = 'settings-modal-overlay';
  overlay.innerHTML = `
    <div class="modal settings-modal">
      <div class="modal-header">
        <h2>Settings</h2>
        <button class="modal-close" id="settings-close">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
          </svg>
        </button>
      </div>
      <div class="modal-body">
        <div class="settings-section">
          <h3>Account</h3>
          <div class="settings-item">
            <div class="settings-item-info">
              <span class="settings-item-label">Email</span>
              <span class="settings-item-value">${escapeHtml(user.email || '')}</span>
            </div>
            ${user.is_verified ? 
              '<span class="settings-badge verified">Verified</span>' : 
              '<button class="btn-ghost btn-sm" id="settings-verify-email">Verify Email</button>'
            }
          </div>
          <div class="settings-item">
            <div class="settings-item-info">
              <span class="settings-item-label">Password</span>
              <span class="settings-item-value">••••••••</span>
            </div>
            <button class="btn-ghost btn-sm" id="settings-change-password">Change</button>
          </div>
        </div>
        
        <div class="settings-section">
          <h3>Notifications</h3>
          <div class="settings-item">
            <div class="settings-item-info">
              <span class="settings-item-label">Email Notifications</span>
              <span class="settings-item-desc">Receive updates about your markets and bets</span>
            </div>
            <label class="toggle-switch">
              <input type="checkbox" id="settings-email-notif" checked>
              <span class="toggle-slider"></span>
            </label>
          </div>
          <div class="settings-item">
            <div class="settings-item-info">
              <span class="settings-item-label">Push Notifications</span>
              <span class="settings-item-desc">Get notified in your browser</span>
            </div>
            <label class="toggle-switch">
              <input type="checkbox" id="settings-push-notif">
              <span class="toggle-slider"></span>
            </label>
          </div>
        </div>
        
        <div class="settings-section">
          <h3>Privacy</h3>
          <div class="settings-item">
            <div class="settings-item-info">
              <span class="settings-item-label">Profile Visibility</span>
              <span class="settings-item-desc">Who can see your profile and stats</span>
            </div>
            <select class="settings-select" id="settings-privacy">
              <option value="public">Everyone</option>
              <option value="friends">Friends Only</option>
              <option value="private">Only Me</option>
            </select>
          </div>
        </div>
        
        <div class="settings-section danger-zone">
          <h3>Danger Zone</h3>
          <div class="settings-item">
            <div class="settings-item-info">
              <span class="settings-item-label">Delete Account</span>
              <span class="settings-item-desc">Permanently delete your account and all data</span>
            </div>
            <button class="btn-danger btn-sm" id="settings-delete-account">Delete</button>
          </div>
        </div>
      </div>
    </div>
  `;
  document.body.appendChild(overlay);
  
  // Close handlers
  const closeModal = () => overlay.remove();
  document.getElementById('settings-close').addEventListener('click', closeModal);
  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) closeModal();
  });
  
  // Verify email button
  const verifyBtn = document.getElementById('settings-verify-email');
  if (verifyBtn) {
    verifyBtn.addEventListener('click', async () => {
      verifyBtn.disabled = true;
      verifyBtn.textContent = 'Sending...';
      try {
        const res = await fetch('api/profile.php', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': TYCHES_CSRF_TOKEN },
          credentials: 'same-origin',
          body: JSON.stringify({ action: 'resend_verification' }),
        });
        if (res.ok) {
          verifyBtn.textContent = 'Email Sent!';
          showToast('Verification email sent!', 'success');
        } else {
          verifyBtn.textContent = 'Try Again';
          verifyBtn.disabled = false;
        }
      } catch {
        verifyBtn.textContent = 'Try Again';
        verifyBtn.disabled = false;
      }
    });
  }
  
  // Change password button
  document.getElementById('settings-change-password')?.addEventListener('click', () => {
    closeModal();
    window.location.href = 'profile.php#password';
  });
  
  // Delete account button
  document.getElementById('settings-delete-account')?.addEventListener('click', () => {
    closeModal();
    openDeleteAccountModal();
  });
}

function openDeleteAccountModal() {
  const overlay = document.createElement('div');
  overlay.className = 'modal-overlay active';
  overlay.id = 'delete-account-modal';
  overlay.innerHTML = `
    <div class="modal delete-account-modal">
      <div class="modal-header">
        <h2>Delete Account</h2>
        <button class="modal-close" id="delete-modal-close">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
          </svg>
        </button>
      </div>
      <div class="modal-body">
        <div class="delete-warning">
          <div class="delete-warning-icon">⚠️</div>
          <h3>This action cannot be undone</h3>
          <p>Deleting your account will permanently remove:</p>
          <ul>
            <li>Your profile and all personal information</li>
            <li>All your bets and prediction history</li>
            <li>Your token balance</li>
            <li>Your comments and activity</li>
            <li>Markets you own (transferred to other members or deleted)</li>
          </ul>
        </div>
        
        <form id="delete-account-form">
          <div class="form-group">
            <label for="delete-password">Enter your password to confirm</label>
            <input type="password" id="delete-password" required placeholder="Your password">
          </div>
          
          <div class="form-group">
            <label for="delete-confirmation">Type <strong>DELETE</strong> to confirm</label>
            <input type="text" id="delete-confirmation" required placeholder="DELETE" autocomplete="off">
          </div>
          
          <div id="delete-error" class="form-error" style="display:none;"></div>
          
          <div class="delete-actions">
            <button type="button" class="btn-secondary" id="delete-cancel">Cancel</button>
            <button type="submit" class="btn-danger-solid" id="delete-confirm">
              Delete My Account
            </button>
          </div>
        </form>
      </div>
    </div>
  `;
  document.body.appendChild(overlay);
  
  const closeModal = () => overlay.remove();
  
  document.getElementById('delete-modal-close').addEventListener('click', closeModal);
  document.getElementById('delete-cancel').addEventListener('click', closeModal);
  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) closeModal();
  });
  
  // Handle form submission
  document.getElementById('delete-account-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const password = document.getElementById('delete-password').value;
    const confirmation = document.getElementById('delete-confirmation').value;
    const errorEl = document.getElementById('delete-error');
    const submitBtn = document.getElementById('delete-confirm');
    
    // Validate confirmation
    if (confirmation !== 'DELETE') {
      errorEl.textContent = 'Please type DELETE exactly to confirm';
      errorEl.style.display = 'flex';
      return;
    }
    
    if (!password) {
      errorEl.textContent = 'Please enter your password';
      errorEl.style.display = 'flex';
      return;
    }
    
    // Disable button and show loading
    submitBtn.disabled = true;
    submitBtn.textContent = 'Deleting...';
    errorEl.style.display = 'none';
    
    try {
      const res = await fetch('api/delete-account.php', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': TYCHES_CSRF_TOKEN
        },
        credentials: 'same-origin',
        body: JSON.stringify({ password, confirmation })
      });
      
      const data = await res.json();
      
      if (res.ok && data.success) {
        // Account deleted successfully
        overlay.innerHTML = `
          <div class="modal delete-account-modal">
            <div class="modal-body" style="text-align: center; padding: 40px;">
              <div style="font-size: 3rem; margin-bottom: 16px;">👋</div>
              <h2>Account Deleted</h2>
              <p style="color: var(--text-secondary); margin: 16px 0;">Your account has been permanently deleted.</p>
              <p style="color: var(--text-tertiary); font-size: 0.875rem;">Redirecting to homepage...</p>
            </div>
          </div>
        `;
        
        // Redirect after a moment
        setTimeout(() => {
          window.location.href = 'index.php';
        }, 2000);
      } else {
        errorEl.textContent = data.error || 'Failed to delete account';
        errorEl.style.display = 'flex';
        submitBtn.disabled = false;
        submitBtn.textContent = 'Delete My Account';
      }
    } catch (err) {
      console.error('Delete account error:', err);
      errorEl.textContent = 'An error occurred. Please try again.';
      errorEl.style.display = 'flex';
      submitBtn.disabled = false;
      submitBtn.textContent = 'Delete My Account';
    }
  });
}

// ============================================
// GLOBAL SEARCH
// ============================================

function initGlobalSearch() {
  const searchInput = document.getElementById('app-search');
  const searchBar = document.getElementById('search-bar');
  if (!searchInput || !searchBar) return;
  
  // Create search results dropdown
  let resultsDropdown = document.getElementById('search-results-dropdown');
  if (!resultsDropdown) {
    resultsDropdown = document.createElement('div');
    resultsDropdown.id = 'search-results-dropdown';
    resultsDropdown.className = 'search-results-dropdown';
    searchBar.appendChild(resultsDropdown);
  }
  
  let searchTimeout = null;
  let currentQuery = '';
  
  searchInput.addEventListener('input', (e) => {
    const query = e.target.value.trim();
    currentQuery = query;
    
    // Clear previous timeout
    if (searchTimeout) clearTimeout(searchTimeout);
    
    // Hide if query too short
    if (query.length < 2) {
      resultsDropdown.style.display = 'none';
      return;
    }
    
    // Debounce search
    searchTimeout = setTimeout(() => performSearch(query, resultsDropdown), 300);
  });
  
  searchInput.addEventListener('focus', () => {
    if (currentQuery.length >= 2) {
      resultsDropdown.style.display = 'block';
    }
  });
  
  // Close on click outside
  document.addEventListener('click', (e) => {
    if (!searchBar.contains(e.target)) {
      resultsDropdown.style.display = 'none';
    }
  });
  
  // Keyboard navigation
  searchInput.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      resultsDropdown.style.display = 'none';
      searchInput.blur();
    }
  });
}

async function performSearch(query, dropdown) {
  dropdown.innerHTML = '<div class="search-loading">Searching...</div>';
  dropdown.style.display = 'block';
  
  try {
    const res = await fetch(`api/search.php?q=${encodeURIComponent(query)}`, {
      credentials: 'same-origin'
    });
    const data = await res.json();
    
    renderSearchResults(data, dropdown);
  } catch (err) {
    dropdown.innerHTML = '<div class="search-empty">Search failed</div>';
  }
}

function renderSearchResults(data, dropdown) {
  const { markets, events, users } = data;
  
  if (markets.length === 0 && events.length === 0 && users.length === 0) {
    dropdown.innerHTML = '<div class="search-empty">No results found</div>';
    return;
  }
  
  let html = '';
  
  // Markets section
  if (markets.length > 0) {
    html += '<div class="search-section">';
    html += '<div class="search-section-title">Markets</div>';
    markets.forEach(m => {
      html += `
        <a href="market.php?id=${m.id}" class="search-result-item">
          <div class="search-result-icon">${m.avatar_emoji || '🎯'}</div>
          <div class="search-result-info">
            <div class="search-result-title">${escapeHtml(m.name)}</div>
            <div class="search-result-meta">${m.members_count} members · ${m.events_count} events</div>
          </div>
        </a>
      `;
    });
    html += '</div>';
  }
  
  // Events section
  if (events.length > 0) {
    html += '<div class="search-section">';
    html += '<div class="search-section-title">Events</div>';
    events.forEach(e => {
      let statusBadge = '';
      if (e.status === 'open') {
        statusBadge = `<span class="search-badge open">${e.yes_percent}% YES</span>`;
      } else if (e.status === 'resolved' || e.status === 'closed') {
        let winner = e.event_type === 'binary' 
          ? (e.winning_side || '').toUpperCase() || 'TBD'
          : (e.winning_outcome_id || 'TBD');
        if (winner.length > 12) winner = winner.substring(0, 10) + '...';
        statusBadge = `<span class="search-badge ${e.status}">🏆 ${escapeHtml(winner)}</span>`;
      } else {
        statusBadge = `<span class="search-badge ${e.status}">${e.status}</span>`;
      }
      html += `
        <a href="event.php?id=${e.id}" class="search-result-item">
          <div class="search-result-icon">${e.market_emoji || '📊'}</div>
          <div class="search-result-info">
            <div class="search-result-title">${escapeHtml(e.title)}</div>
            <div class="search-result-meta">${escapeHtml(e.market_name)} ${statusBadge}</div>
          </div>
        </a>
      `;
    });
    html += '</div>';
  }
  
  // Users section
  if (users.length > 0) {
    html += '<div class="search-section">';
    html += '<div class="search-section-title">People</div>';
    users.forEach(u => {
      html += `
        <a href="profile.php?id=${u.id}" class="search-result-item">
          <div class="search-result-avatar">${(u.name || u.username || '?').charAt(0).toUpperCase()}</div>
          <div class="search-result-info">
            <div class="search-result-title">${escapeHtml(u.name || u.username)}</div>
            <div class="search-result-meta">@${escapeHtml(u.username)} · ${formatNumber(u.tokens_balance)} tokens</div>
          </div>
        </a>
      `;
    });
    html += '</div>';
  }
  
  dropdown.innerHTML = html;
}

function setupTabNavigation() {
  const navItems = document.querySelectorAll('.nav-item[data-tab], .bottomnav-item[data-tab]');
  const tabPanels = document.querySelectorAll('.tab-panel');
  
  // Only run tab navigation on index.php (where tab-panels exist)
  if (tabPanels.length === 0) return;
  
  // Function to switch to a tab
  function switchToTab(tabName) {
    if (!tabName) return;
    
    // Update active states
    navItems.forEach(n => n.classList.remove('active'));
    document.querySelectorAll(`[data-tab="${tabName}"]`).forEach(n => n.classList.add('active'));
    
    tabPanels.forEach(panel => {
      panel.classList.remove('active');
      if (panel.id === `tab-${tabName}`) {
        panel.classList.add('active');
        loadTabData(tabName);
      }
    });
    
    // Update URL hash without triggering scroll
    if (window.history.replaceState) {
      window.history.replaceState(null, '', tabName === 'feed' ? 'index.php' : `#${tabName}`);
    }
  }
  
  // Handle nav item clicks (only prevent default if we're handling tabs on this page)
  navItems.forEach(item => {
    item.addEventListener('click', (e) => {
      const tab = item.dataset.tab;
      if (!tab) return;
      
      // Check if we're on index.php (has tab panels)
      const isOnIndexPage = tabPanels.length > 0;
      
      if (isOnIndexPage) {
        e.preventDefault();
        switchToTab(tab);
      }
      // Otherwise, let the link navigate normally
    });
  });
  
  // Check URL hash on page load and switch to that tab
  const hash = window.location.hash.replace('#', '');
  if (hash && ['feed', 'markets', 'leaderboard', 'profile'].includes(hash)) {
    // Small delay to ensure DOM is ready
    setTimeout(() => switchToTab(hash), 50);
  }
  
  // Handle browser back/forward with hash changes
  window.addEventListener('hashchange', () => {
    const newHash = window.location.hash.replace('#', '');
    if (newHash && ['feed', 'markets', 'leaderboard', 'profile'].includes(newHash)) {
      switchToTab(newHash);
    }
  });
}

function loadTabData(tab) {
  switch (tab) {
    case 'feed':
      if (window.tychesProfile) loadFeedData(window.tychesProfile);
      break;
    case 'markets':
      loadMarketsTab();
      break;
    case 'leaderboard':
      loadLeaderboardTab();
      break;
    case 'profile':
      if (window.tychesProfile) loadProfileTab(window.tychesProfile);
      break;
  }
}

function setupCreateMenu() {
  const createBtns = [
    document.getElementById('sidebar-create-btn'),
    document.getElementById('mobile-create-btn'),
    document.getElementById('header-create-btn')
  ];
  const backdrop = document.getElementById('create-menu-backdrop');
  const menu = document.getElementById('create-menu');
  
  const openMenu = () => {
    if (backdrop) backdrop.style.display = 'block';
    if (menu) menu.style.display = 'block';
  };
  
  const closeMenu = () => {
    if (backdrop) backdrop.style.display = 'none';
    if (menu) menu.style.display = 'none';
  };
  
  createBtns.forEach(btn => {
    if (btn) btn.addEventListener('click', openMenu);
  });
  
  if (backdrop) backdrop.addEventListener('click', closeMenu);
  
  // Create market button
  const createMarketBtn = document.getElementById('create-market-btn');
  const marketsCreateBtn = document.getElementById('markets-create-btn');
  [createMarketBtn, marketsCreateBtn].forEach(btn => {
    if (btn) btn.addEventListener('click', () => {
      closeMenu();
      openCreateMarketModal();
    });
  });
  
  // Create event button
  const createEventBtn = document.getElementById('create-event-btn');
  if (createEventBtn) {
    createEventBtn.addEventListener('click', () => {
      closeMenu();
      window.location.href = 'create-event.php';
    });
  }
}

// Format number with commas
function formatNumber(num) {
  return Math.floor(num).toLocaleString();
}

// Format relative time
function formatTimeAgo(dateStr) {
  const date = new Date(dateStr);
  const now = new Date();
  const diff = Math.floor((now - date) / 1000);
  
  if (diff < 60) return 'just now';
  if (diff < 3600) return Math.floor(diff / 60) + 'm ago';
  if (diff < 86400) return Math.floor(diff / 3600) + 'h ago';
  if (diff < 604800) return Math.floor(diff / 86400) + 'd ago';
  return date.toLocaleDateString();
}

// Format time remaining
function formatTimeRemaining(dateStr) {
  const date = new Date(dateStr);
  const now = new Date();
  const diff = Math.floor((date - now) / 1000);
  
  if (diff < 0) return 'Closed';
  if (diff < 3600) return Math.floor(diff / 60) + 'm left';
  if (diff < 86400) return Math.floor(diff / 3600) + 'h left';
  if (diff < 604800) return Math.floor(diff / 86400) + 'd left';
  return Math.floor(diff / 604800) + 'w left';
}

// ============================================
// FEED TAB
// ============================================

function loadFeedData(profileData) {
  // Quick stats
  document.getElementById('stat-tokens').textContent = formatNumber(profileData.user.tokens_balance || 0);
  document.getElementById('stat-markets').textContent = (profileData.markets || []).length;
  document.getElementById('stat-bets').textContent = (profileData.bets || []).length;
  document.getElementById('stat-wins').textContent = profileData.user.total_wins || 0;
  
  // Load your events (active events where user is participant)
  loadYourEvents();
  
  // Load your positions (bets you've placed)
  renderPositions(profileData.bets || []);
  
  // Load activity
  loadActivityFeed();
}

async function loadYourEvents() {
  const container = document.getElementById('your-events');
  if (!container) return;
  
  try {
    // Fetch open events where user is a participant (member of the market or specifically invited)
    const res = await fetch('api/events.php?filter=participating', { credentials: 'same-origin' });
    const data = await res.json();
    const events = data.events || [];
    
    if (events.length === 0) {
      container.innerHTML = `
        <div class="empty-state-app">
          <div class="empty-state-icon-app">📅</div>
          <div class="empty-state-title">No active events</div>
          <div class="empty-state-text-app">Join a market or get invited to events to see them here</div>
        </div>
      `;
      return;
    }
    
    container.innerHTML = events.map(event => {
      const yesPercent = event.pools?.yes_percent || event.yes_percent || 50;
      const timeLeft = formatTimeRemaining(event.closes_at);
      const isUrgent = new Date(event.closes_at) - new Date() < 86400000 && event.status === 'open';
      const isResolved = event.status === 'resolved' || event.status === 'closed';
      
      // For resolved events, show the winner banner instead of odds bar
      let oddsOrResult = '';
      if (isResolved) {
        if (event.event_type === 'binary') {
          const winner = (event.winning_side || '').toUpperCase() || 'TBD';
          const winnerClass = winner === 'YES' ? 'winner-yes' : winner === 'NO' ? 'winner-no' : '';
          oddsOrResult = `
            <div class="event-result-banner ${winnerClass}">
              🏆 Winner: <strong>${winner}</strong>
            </div>
          `;
        } else {
          const winner = event.winning_outcome_id || 'TBD';
          const truncatedWinner = winner.length > 18 ? winner.substring(0, 15) + '...' : winner;
          oddsOrResult = `
            <div class="event-result-banner" title="${escapeHtml(winner)}">
              🏆 Winner: <strong>${escapeHtml(truncatedWinner)}</strong>
            </div>
          `;
        }
      } else {
        // Open events - show odds bar
        oddsOrResult = `
          <div class="event-odds-bar">
            <div class="odds-bar-track">
              <div class="odds-bar-yes" style="width: ${yesPercent}%"></div>
            </div>
            <div class="odds-labels-row">
              <span class="odds-label-app yes">YES ${yesPercent}%</span>
              <span class="odds-label-app no">NO ${100 - yesPercent}%</span>
            </div>
          </div>
        `;
      }
      
      return `
        <div class="event-card-app" onclick="window.location.href='event.php?id=${event.id}'">
          <div class="event-card-header">
            <div class="event-market-badge">
              <span class="event-market-emoji">${event.market_avatar_emoji || '🎯'}</span>
              <span>${event.market_name || 'Market'}</span>
            </div>
            ${isResolved 
              ? `<span class="status-badge ${event.status}">${event.status}</span>` 
              : `<div class="event-closing ${isUrgent ? 'urgent' : ''}">⏰ ${timeLeft}</div>`}
          </div>
          <div class="event-question">${escapeHtml(event.title)}</div>
          ${oddsOrResult}
          <div class="event-meta-row">
            <span>🪙 ${formatNumber(event.volume || 0)}</span>
            <span>👥 ${event.traders_count || 0} traders</span>
          </div>
        </div>
      `;
    }).join('');
    
  } catch (err) {
    console.error('Failed to load events:', err);
    container.innerHTML = '<div class="loading-placeholder">Failed to load events</div>';
  }
}


function renderPositions(bets) {
  const container = document.getElementById('your-positions');
  if (!container) return;
  
  if (bets.length === 0) {
    container.innerHTML = `
      <div class="empty-state-app">
        <div class="empty-state-icon-app">📊</div>
        <div class="empty-state-title">No positions yet</div>
        <div class="empty-state-text-app">Place a bet on an event to see it here</div>
      </div>
    `;
    return;
  }
  
  // Group bets by event
  const byEvent = {};
  bets.forEach(bet => {
    if (!byEvent[bet.event_id]) {
      byEvent[bet.event_id] = { ...bet, totalShares: 0 };
    }
    byEvent[bet.event_id].totalShares += bet.shares;
  });
  
  const positions = Object.values(byEvent).slice(0, 5);
  
  container.innerHTML = positions.map(pos => `
    <div class="position-card" onclick="window.location.href='event.php?id=${pos.event_id}'">
      <div class="position-info">
        <div class="position-question">${escapeHtml(pos.event_title || 'Event')}</div>
        <div class="position-market">${escapeHtml(pos.market_name || '')}</div>
      </div>
      <div class="position-side ${(pos.side || '').toLowerCase()}">${pos.side || pos.outcome_id || '?'}</div>
      <div class="position-stake">
        <div class="position-amount">${formatNumber(pos.totalShares)} tokens</div>
      </div>
    </div>
  `).join('');
}

async function loadActivityFeed() {
  const container = document.getElementById('activity-feed');
  if (!container) return;
  
  try {
    const res = await fetch('api/event-activity.php?limit=15', { credentials: 'same-origin' });
    const data = await res.json();
    const activities = data.activities || [];
    
    if (activities.length === 0) {
      container.innerHTML = `
        <div class="empty-state-app">
          <div class="empty-state-icon-app">💬</div>
          <div class="empty-state-title">No activity yet</div>
          <div class="empty-state-text-app">Activity from your markets will appear here</div>
        </div>
      `;
      return;
    }
    
    // Get activity type icon
    const getActivityIcon = (type) => {
      switch(type) {
        case 'bet': return '🎲';
        case 'event_created': return '📊';
        case 'event_resolved': return '✅';
        case 'member_joined': return '👋';
        default: return '💬';
      }
    };
    
    // Get link for activity
    const getActivityLink = (act) => {
      if (act.event_id) return `event.php?id=${act.event_id}`;
      if (act.market_id) return `market.php?id=${act.market_id}`;
      return '#';
    };
    
    container.innerHTML = activities.map(act => `
      <a href="${getActivityLink(act)}" class="activity-item" style="text-decoration:none;color:inherit;">
        <div class="activity-icon">${getActivityIcon(act.type)}</div>
        <div class="activity-avatar">${(act.user_name || '?').charAt(0).toUpperCase()}</div>
        <div class="activity-content">
          <div class="activity-text">
            <strong>${escapeHtml(act.user_name || 'Someone')}</strong> ${escapeHtml(act.description || '')}
          </div>
          <div class="activity-meta">
            <span class="activity-market">${act.market_emoji || '🎯'} ${escapeHtml(act.market_name || '')}</span>
            <span class="activity-time">${formatTimeAgo(act.created_at)}</span>
          </div>
        </div>
      </a>
    `).join('');
  } catch (err) {
    console.error('Activity feed error:', err);
    container.innerHTML = '<div class="loading-placeholder">No recent activity</div>';
  }
}

// ============================================
// MARKETS TAB
// ============================================

async function loadMarketsTab() {
  const container = document.getElementById('markets-list');
  if (!container) return;
  
  try {
    const res = await fetch('api/markets.php', { credentials: 'same-origin' });
    const data = await res.json();
    const markets = data.markets || [];
    
    if (markets.length === 0) {
      container.innerHTML = `
        <div class="empty-state-app">
          <div class="empty-state-icon-app">👥</div>
          <div class="empty-state-title">No markets yet</div>
          <div class="empty-state-text-app">Create your first market to start predicting with friends</div>
          <button class="btn-primary" onclick="openCreateMarketModal()">Create Market</button>
        </div>
      `;
      return;
    }
    
    container.innerHTML = markets.map(market => `
      <div class="market-card-app" onclick="window.location.href='market.php?id=${market.id}'">
        <div class="market-card-header">
          <div class="market-avatar-app" style="background: ${market.avatar_color || 'var(--bg-secondary)'}">
            ${market.avatar_emoji || '🎯'}
          </div>
          <div class="market-info-app">
            <h3>${escapeHtml(market.name)}</h3>
            <p>${market.description ? escapeHtml(market.description.substring(0, 60)) + '...' : 'No description'}</p>
          </div>
        </div>
        <div class="market-stats-app">
          <div class="market-stat-app">
            <span class="market-stat-value">${market.members_count || 1}</span>
            <span class="market-stat-label">Members</span>
          </div>
          <div class="market-stat-app">
            <span class="market-stat-value">${market.events_count || 0}</span>
            <span class="market-stat-label">Events</span>
          </div>
        </div>
      </div>
    `).join('');
  } catch {
    container.innerHTML = '<div class="loading-placeholder">Failed to load markets</div>';
  }
}

// ============================================
// LEADERBOARD TAB
// ============================================

async function loadLeaderboardTab() {
  const container = document.getElementById('leaderboard-container');
  if (!container) return;
  
  try {
    const res = await fetch('api/leaderboard.php', { credentials: 'same-origin' });
    const data = await res.json();
    const leaders = data.leaderboard || [];
    
    if (leaders.length === 0) {
      container.innerHTML = `
        <div class="empty-state-app">
          <div class="empty-state-icon-app">🏆</div>
          <div class="empty-state-title">No rankings yet</div>
          <div class="empty-state-text-app">Start trading to appear on the leaderboard</div>
        </div>
      `;
      return;
    }
    
    container.innerHTML = `
      <div class="leaderboard-header">
        <span>Rank</span>
        <span>User</span>
        <span>Tokens</span>
        <span>Accuracy</span>
      </div>
      ${leaders.map((leader, i) => {
        const rankClass = i === 0 ? 'gold' : i === 1 ? 'silver' : i === 2 ? 'bronze' : '';
        return `
          <div class="leaderboard-row">
            <span class="leaderboard-rank ${rankClass}">#${i + 1}</span>
            <div class="leaderboard-user">
              <div class="leaderboard-avatar">${(leader.name || '?').charAt(0).toUpperCase()}</div>
              <div>
                <div class="leaderboard-name">${escapeHtml(leader.name || 'User')}</div>
                <div class="leaderboard-username">@${escapeHtml(leader.username || '')}</div>
              </div>
            </div>
            <span class="leaderboard-tokens">${formatNumber(leader.tokens_balance || 0)}</span>
            <span class="leaderboard-accuracy">${leader.accuracy || 0}%</span>
          </div>
        `;
      }).join('')}
    `;
  } catch {
    container.innerHTML = '<div class="loading-placeholder">Failed to load leaderboard</div>';
  }
}

// ============================================
// PROFILE TAB
// ============================================

function loadProfileTab(profileData) {
  const user = profileData.user;
  
  // Avatar
  const avatarEl = document.getElementById('profile-avatar-large');
  if (avatarEl) avatarEl.textContent = (user.name || '?').charAt(0).toUpperCase();
  
  // Name and username
  const nameEl = document.getElementById('profile-name');
  const usernameEl = document.getElementById('profile-username');
  if (nameEl) nameEl.textContent = user.name || 'User';
  if (usernameEl) usernameEl.textContent = '@' + (user.username || '');
  
  // Stats
  document.getElementById('profile-stat-tokens').textContent = formatNumber(user.tokens_balance || 0);
  document.getElementById('profile-stat-accuracy').textContent = (user.accuracy || 0) + '%';
  document.getElementById('profile-stat-total-bets').textContent = (profileData.bets || []).length;
  
  // Recent bets
  const betsContainer = document.getElementById('profile-bets-list');
  if (betsContainer) {
    const bets = (profileData.bets || []).slice(0, 5);
    if (bets.length === 0) {
      betsContainer.innerHTML = '<div class="loading-placeholder">No bets yet</div>';
    } else {
      betsContainer.innerHTML = bets.map(bet => `
        <div class="position-card" onclick="window.location.href='event.php?id=${bet.event_id}'">
          <div class="position-info">
            <div class="position-question">${escapeHtml(bet.event_title || 'Event')}</div>
            <div class="position-market">${formatTimeAgo(bet.created_at)}</div>
          </div>
          <div class="position-side ${(bet.side || '').toLowerCase()}">${bet.side || bet.outcome_id || '?'}</div>
          <div class="position-stake">
            <div class="position-amount">${formatNumber(bet.shares)} tokens</div>
          </div>
        </div>
      `).join('');
    }
  }
  
  // Markets
  const marketsContainer = document.getElementById('profile-markets-list');
  if (marketsContainer) {
    const markets = (profileData.markets || []).slice(0, 4);
    if (markets.length === 0) {
      marketsContainer.innerHTML = '<div class="loading-placeholder">No markets yet</div>';
    } else {
      marketsContainer.innerHTML = markets.map(m => `
        <div class="position-card" onclick="window.location.href='market.php?id=${m.id}'">
          <div class="position-info">
            <div class="position-question">${m.avatar_emoji || '🎯'} ${escapeHtml(m.name)}</div>
            <div class="position-market">${m.members_count || 1} members</div>
          </div>
        </div>
      `).join('');
    }
  }
}


function fillUserPill(user) {
  const pill = document.getElementById('nav-user-pill');
  const initialEl = document.getElementById('nav-user-initial');
  const nameEl = document.getElementById('nav-user-name');
  if (!pill || !initialEl || !nameEl) return;
  const initial = (user.name || user.username || '?').trim().charAt(0).toUpperCase();
  initialEl.textContent = initial;
  nameEl.textContent = user.username || user.name || '';
  pill.style.display = 'flex';
}

function setupNav() {
  const mobileMenuBtn = document.querySelector('.mobile-menu-btn');
  const navLinks = document.getElementById('nav-links');
  if (mobileMenuBtn && navLinks) {
    mobileMenuBtn.addEventListener('click', () => {
      navLinks.classList.toggle('mobile-open');
    });
  }

  const userPill = document.getElementById('nav-user-pill');
  const dropdown = document.getElementById('nav-user-dropdown');
  if (userPill && dropdown) {
    userPill.addEventListener('click', (e) => {
      e.stopPropagation();
      dropdown.style.display = dropdown.style.display === 'flex' ? 'none' : 'flex';
    });
    document.addEventListener('click', () => {
      dropdown.style.display = 'none';
    });
  }

  const navLogin = document.getElementById('nav-login');
  if (navLogin) {
    navLogin.addEventListener('click', openLoginModal);
  }
  const navGetStarted = document.getElementById('nav-get-started');
  if (navGetStarted) {
    navGetStarted.addEventListener('click', openSignupModal);
  }

  const navLogout = document.getElementById('nav-logout');
  if (navLogout) {
    navLogout.addEventListener('click', async () => {
      await fetch('api/logout.php', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': TYCHES_CSRF_TOKEN,
        },
        credentials: 'same-origin',
      });
      window.location.href = 'index.php';
    });
  }

  // Profile nav buttons
  const navProfile = document.getElementById('nav-profile');
  if (navProfile) {
    navProfile.addEventListener('click', () => {
      window.location.href = 'profile.php';
    });
  }
  
  const navOpenProfile = document.getElementById('nav-open-profile');
  if (navOpenProfile) {
    navOpenProfile.addEventListener('click', () => {
      window.location.href = 'profile.php';
    });
  }
  
  const navOpenMarkets = document.getElementById('nav-open-markets');
  if (navOpenMarkets) {
    navOpenMarkets.addEventListener('click', () => {
      window.location.href = 'index.php';
    });
  }

  // Hero buttons
  const heroStart = document.getElementById('hero-start-market');
  if (heroStart) {
    heroStart.addEventListener('click', openSignupModal);
  }

  // CTA button
  const ctaGetStarted = document.getElementById('cta-get-started');
  if (ctaGetStarted) {
    ctaGetStarted.addEventListener('click', openSignupModal);
  }
}

function setupDashboardToggle() {
  const loggedIn = document.body.dataset.loggedIn === '1';
  console.log('[Tyches] setupDashboardToggle, loggedIn:', loggedIn);
  
  const marketingSections = document.querySelectorAll('.marketing-only');
  const authSections = document.querySelectorAll('.auth-only');
  const loggedOutEls = document.querySelectorAll('.logged-out-only');
  const dashboardEl = document.getElementById('dashboard');
  const appShellEl = document.getElementById('app-shell');

  marketingSections.forEach(el => {
    el.style.display = loggedIn ? 'none' : '';
  });
  authSections.forEach(el => {
    // Don't auto-show auth sections - let initAppShell handle it
    if (!el.id || (el.id !== 'app-shell' && el.id !== 'dashboard')) {
      el.style.display = loggedIn ? '' : 'none';
    }
  });
  loggedOutEls.forEach(el => {
    el.style.display = loggedIn ? 'none' : '';
  });
  
  // Explicitly show/hide dashboard or app shell
  if (appShellEl) {
    appShellEl.style.display = loggedIn ? 'block' : 'none';
  }
  if (dashboardEl && !appShellEl) {
    dashboardEl.style.display = loggedIn ? 'block' : 'none';
    console.log('[Tyches] Dashboard display set to:', dashboardEl.style.display);
  }
}

// --- Auth modals (simple inline implementation) ---
let loginModalEl = null;
let signupModalEl = null;
let resetModalEl = null;

function setupAuthModals() {
  // For brevity: simple dynamically-created modals.
  loginModalEl = createModalSkeleton('Login to Tyches', `
    <form id="login-form" class="auth-form">
      <div class="form-group">
        <label for="login-email">Email</label>
        <input type="email" id="login-email" required>
      </div>
      <div class="form-group">
        <label for="login-password">Password</label>
        <input type="password" id="login-password" required>
      </div>
      <div id="login-error" class="form-error" style="display:none;"></div>
      <button type="button" class="btn-ghost" id="login-forgot" style="margin-bottom:0.5rem;padding-left:0;margin-left:-0.25rem;">
        Forgot your password?
      </button>
      <button type="submit" class="btn-primary">Log in</button>
    </form>
  `);

  signupModalEl = createModalSkeleton('Create your Tyches account', `
    <form id="signup-form" class="auth-form">
      <div class="form-group">
        <label for="signup-name">Name</label>
        <input type="text" id="signup-name" required>
      </div>
      <div class="form-group">
        <label for="signup-username">Username</label>
        <input type="text" id="signup-username" required>
      </div>
      <div class="form-group">
        <label for="signup-email">Email</label>
        <input type="email" id="signup-email" required>
      </div>
      <div class="form-group">
        <label for="signup-phone">Phone (optional)</label>
        <input type="text" id="signup-phone">
      </div>
      <div class="form-group">
        <label for="signup-password">Password</label>
        <input type="password" id="signup-password" required minlength="8">
      </div>
      <div class="form-group">
        <label for="signup-password-confirm">Confirm password</label>
        <input type="password" id="signup-password-confirm" required minlength="8">
      </div>
      <div class="form-group form-checkbox">
        <input type="checkbox" id="signup-terms" required>
        <label for="signup-terms">I agree to the <a href="terms.php" target="_blank">Terms of Service</a> and <a href="privacy.php" target="_blank">Privacy Policy</a></label>
      </div>
      <div id="signup-error" class="form-error" style="display:none;"></div>
      <div id="signup-success" class="form-success" style="display:none;"></div>
      <button type="submit" class="btn-primary">Sign up</button>
    </form>
  `);

  bindLoginForm();
  bindSignupForm();

  // Password reset request modal
  resetModalEl = createModalSkeleton('Reset your password', `
    <form id="reset-request-form" class="auth-form">
      <div class="form-group">
        <label for="reset-email">Email</label>
        <input type="email" id="reset-email" required>
      </div>
      <div id="reset-error" class="form-error" style="display:none;"></div>
      <div id="reset-success" class="form-success" style="display:none;"></div>
      <button type="submit" class="btn-primary">Send reset link</button>
    </form>
  `);
  bindResetForm();
  
  // Verification required modal
  verifyModalEl = createModalSkeleton('Email Verification Required', `
    <div class="verify-prompt">
      <div class="verify-icon">📧</div>
      <p>You need to verify your email address before you can create markets, events, or place predictions.</p>
      <p class="verify-subtext">Check your inbox for the verification email we sent when you signed up.</p>
      <div class="verify-actions">
        <button type="button" class="btn-primary" id="resend-verify-btn">Resend verification email</button>
        <button type="button" class="btn-secondary" id="close-verify-btn">I'll do it later</button>
      </div>
      <div id="verify-message" class="form-success" style="display:none;"></div>
      <div id="verify-error" class="form-error" style="display:none;"></div>
    </div>
  `);
  bindVerifyModal();
}

let verifyModalEl = null;

function bindVerifyModal() {
  const resendBtn = document.getElementById('resend-verify-btn');
  const closeBtn = document.getElementById('close-verify-btn');
  const msgEl = document.getElementById('verify-message');
  const errEl = document.getElementById('verify-error');
  
  if (closeBtn) {
    closeBtn.addEventListener('click', () => {
      if (verifyModalEl) verifyModalEl.style.display = 'none';
    });
  }
  
  if (resendBtn) {
    resendBtn.addEventListener('click', async () => {
      msgEl.style.display = 'none';
      errEl.style.display = 'none';
      resendBtn.disabled = true;
      resendBtn.textContent = 'Sending...';
      
      try {
        const res = await fetch('api/profile.php', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': TYCHES_CSRF_TOKEN,
          },
          credentials: 'same-origin',
          body: JSON.stringify({ action: 'resend_verification' }),
        });
        const data = await res.json().catch(() => ({}));
        
        if (res.ok) {
          msgEl.textContent = 'Verification email sent! Check your inbox.';
          msgEl.style.display = 'block';
        } else {
          errEl.textContent = data.error || 'Unable to send email. Try again later.';
          errEl.style.display = 'block';
        }
      } catch {
        errEl.textContent = 'Network error. Try again.';
        errEl.style.display = 'block';
      }
      
      resendBtn.disabled = false;
      resendBtn.textContent = 'Resend verification email';
    });
  }
}

function showVerificationRequired() {
  if (verifyModalEl) verifyModalEl.style.display = 'flex';
}

// Global helper to check API responses for verification requirement
function handleApiError(data, res) {
  if (data?.code === 'EMAIL_NOT_VERIFIED' || data?.requires_verification) {
    showVerificationRequired();
    return true;
  }
  return false;
}

function createModalSkeleton(title, innerHtml) {
  const wrapper = document.createElement('div');
  wrapper.className = 'modal-backdrop';
  wrapper.style.display = 'none';
  wrapper.innerHTML = `
    <div class="modal">
      <div class="modal-header">
        <h2>${title}</h2>
        <button class="modal-close">&times;</button>
      </div>
      <div class="modal-body">${innerHtml}</div>
    </div>
  `;
  document.body.appendChild(wrapper);
  const closeBtn = wrapper.querySelector('.modal-close');
  closeBtn.addEventListener('click', () => wrapper.style.display = 'none');
  wrapper.addEventListener('click', e => {
    if (e.target === wrapper) wrapper.style.display = 'none';
  });
  return wrapper;
}

function openLoginModal() {
  if (loginModalEl) loginModalEl.style.display = 'flex';
}

function openSignupModal() {
  if (signupModalEl) signupModalEl.style.display = 'flex';
}

function bindLoginForm() {
  const form = document.getElementById('login-form');
  if (!form) return;
  const emailEl = document.getElementById('login-email');
  const passEl = document.getElementById('login-password');
  const errorEl = document.getElementById('login-error');
  const forgotBtn = document.getElementById('login-forgot');

  if (forgotBtn) {
    forgotBtn.addEventListener('click', () => {
      if (loginModalEl) loginModalEl.style.display = 'none';
      if (resetModalEl) resetModalEl.style.display = 'flex';
    });
  }

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    errorEl.style.display = 'none';
    const email = emailEl.value.trim();
    const password = passEl.value;
    if (!email || !password) {
      errorEl.textContent = 'Enter email and password.';
      errorEl.style.display = 'block';
      return;
    }
    try {
      const res = await fetch('api/login.php', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': TYCHES_CSRF_TOKEN,
        },
        credentials: 'same-origin',
        body: JSON.stringify({ email, password }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        errorEl.textContent = data.error || 'Unable to log in.';
        errorEl.style.display = 'block';
        return;
      }
      window.location.href = 'index.php';
    } catch (err) {
      errorEl.textContent = 'Network error. Try again.';
      errorEl.style.display = 'block';
    }
  });
}

function bindSignupForm() {
  const form = document.getElementById('signup-form');
  if (!form) return;
  const nameEl = document.getElementById('signup-name');
  const usernameEl = document.getElementById('signup-username');
  const emailEl = document.getElementById('signup-email');
  const phoneEl = document.getElementById('signup-phone');
  const passEl = document.getElementById('signup-password');
  const pass2El = document.getElementById('signup-password-confirm');
  const termsEl = document.getElementById('signup-terms');
  const errEl = document.getElementById('signup-error');
  const okEl = document.getElementById('signup-success');

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    errEl.style.display = 'none';
    okEl.style.display = 'none';

    const name = nameEl.value.trim();
    const username = usernameEl.value.trim();
    const email = emailEl.value.trim();
    const phone = phoneEl.value.trim();
    const password = passEl.value;
    const password_confirmation = pass2El.value;

    if (!name || !username || !email || !password) {
      errEl.textContent = 'Please fill in all required fields.';
      errEl.style.display = 'block';
      return;
    }
    if (password !== password_confirmation) {
      errEl.textContent = 'Passwords do not match.';
      errEl.style.display = 'block';
      return;
    }
    if (!termsEl.checked) {
      errEl.textContent = 'You must agree to the Terms of Service and Privacy Policy.';
      errEl.style.display = 'block';
      return;
    }

    try {
      const res = await fetch('api/users.php', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': TYCHES_CSRF_TOKEN,
        },
        credentials: 'same-origin',
        body: JSON.stringify({ name, username, email, phone, password, password_confirmation }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        errEl.textContent = data.error || 'Unable to sign up.';
        errEl.style.display = 'block';
        return;
      }
      
      // User is now auto-logged in after signup
      okEl.innerHTML = 'Account created! <strong>Check your email to verify</strong> — you can browse now but need to verify to create markets or place bets.';
      okEl.style.display = 'block';
      
      // Redirect to dashboard after a short delay
      setTimeout(() => {
        window.location.reload();
      }, 2500);
    } catch {
      errEl.textContent = 'Network error. Try again.';
      errEl.style.display = 'block';
    }
  });
}

function bindResetForm() {
  const form = document.getElementById('reset-request-form');
  if (!form) return;
  const emailEl = document.getElementById('reset-email');
  const errEl = document.getElementById('reset-error');
  const okEl = document.getElementById('reset-success');

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    errEl.style.display = 'none';
    okEl.style.display = 'none';

    const email = emailEl.value.trim();
    if (!email) {
      errEl.textContent = 'Please enter your email.';
      errEl.style.display = 'block';
      return;
    }

    try {
      const res = await fetch('api/password-reset-request.php', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': TYCHES_CSRF_TOKEN,
        },
        credentials: 'same-origin',
        body: JSON.stringify({ email }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        errEl.textContent = data.error || 'Could not send reset email.';
        errEl.style.display = 'block';
        return;
      }
      okEl.textContent = 'If that email exists, we\'ve sent you a reset link.';
      okEl.style.display = 'block';
    } catch {
      errEl.textContent = 'Network error. Try again.';
      errEl.style.display = 'block';
    }
  });
}

// --- Dashboard + markets/events ---
async function hydrateDashboard(profileData) {
  console.log('[Tyches] Hydrating dashboard with:', profileData);
  
  // Ensure dashboard is visible
  const dashboardEl = document.getElementById('dashboard');
  if (dashboardEl) {
    dashboardEl.style.display = 'block';
    console.log('[Tyches] Dashboard made visible');
  }
  
  const nameEl = document.getElementById('dashboard-user-name');
  if (nameEl && profileData.user) {
    nameEl.textContent = profileData.user.name || profileData.user.username || 'friend';
    console.log('[Tyches] Set dashboard name to:', nameEl.textContent);
  }

  const marketsEl = document.getElementById('dashboard-markets');
  const eventsEl = document.getElementById('dashboard-events');
  const activityEl = document.getElementById('dashboard-activity');
  
  console.log('[Tyches] Dashboard elements found:', {
    marketsEl: !!marketsEl,
    eventsEl: !!eventsEl,
    activityEl: !!activityEl
  });

  if (marketsEl) {
    marketsEl.innerHTML = '';
    const markets = profileData.markets || [];
    console.log('Dashboard markets:', markets);
    if (markets.length === 0) {
      marketsEl.innerHTML = `
        <div class="empty-state">
          <div class="empty-state-icon">🎯</div>
          <div class="empty-state-text">No markets yet. Create your first one!</div>
        </div>
      `;
    } else {
      markets.forEach(m => {
        const card = document.createElement('div');
        card.className = 'market-card';
        card.innerHTML = `
          <div class="market-header">
            <div class="market-creator">
              <div class="creator-avatar">${(m.avatar_emoji || '🎯')}</div>
              <div>
                <div class="creator-name">${escapeHtml(m.name)}</div>
                <div class="market-meta">${m.members_count || 0} members · ${m.events_count || 0} events</div>
              </div>
            </div>
          </div>
          <h3 class="market-question">${escapeHtml(m.description || 'No description')}</h3>
          <div class="market-footer">
            <div class="market-volume"></div>
            <button class="btn-market" data-market-id="${m.id}">Open</button>
          </div>
        `;
        card.querySelector('.btn-market').addEventListener('click', () => {
          window.location.href = 'market.php?id=' + encodeURIComponent(m.id);
        });
        marketsEl.appendChild(card);
      });
    }
  }

  if (eventsEl) {
    try {
      console.log('Fetching events...');
      const res = await fetch('api/events.php', { credentials: 'same-origin' });
      const data = await res.json();
      console.log('Events API response:', res.status, data);
      eventsEl.innerHTML = '';
      const events = data.events || [];
      if (events.length === 0) {
        eventsEl.innerHTML = `
          <div class="empty-state">
            <div class="empty-state-icon">📅</div>
            <div class="empty-state-text">No upcoming events. Create one in a market!</div>
          </div>
        `;
      } else {
        events.forEach(ev => {
          const row = document.createElement('div');
          row.className = 'event-row';
          row.innerHTML = `
            <div class="event-row-main">
              <div class="event-row-title">${escapeHtml(ev.title)}</div>
              <div class="event-row-meta">
                In ${escapeHtml(ev.market_name || '')} · closes ${formatDate(ev.closes_at)}
              </div>
            </div>
            <button class="btn-secondary btn-small">Open</button>
          `;
          row.querySelector('button').addEventListener('click', () => {
            window.location.href = 'event.php?id=' + encodeURIComponent(ev.id);
          });
          eventsEl.appendChild(row);
        });
      }
    } catch {
      eventsEl.innerHTML = '<div class="empty-state"><div class="empty-state-text">Could not load events.</div></div>';
    }
  }

  if (activityEl) {
    activityEl.innerHTML = `
      <div class="empty-state">
        <div class="empty-state-icon">👥</div>
        <div class="empty-state-text">Friends\' activity will appear here.</div>
      </div>
    `;
  }

  const createBtn = document.getElementById('dashboard-create-market');
  if (createBtn) {
    createBtn.addEventListener('click', openCreateMarketModal);
  }
}

// Simple date formatter
function formatDate(dateStr) {
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
  return d.toLocaleDateString();
}

// Create Market Modal
function openCreateMarketModal() {
  const existing = document.getElementById('create-market-modal');
  if (existing) {
    existing.style.display = 'flex';
    loadFriendsForMarketInvite();
    return;
  }

  const modal = createModalSkeleton('Create a new Market', `
    <form id="create-market-form" class="auth-form">
      <div class="form-group">
        <label for="market-name">Market name</label>
        <input type="text" id="market-name" required placeholder="NYC Degens">
      </div>
      <div class="form-group">
        <label for="market-description">Description</label>
        <textarea id="market-description" rows="3" maxlength="1000" placeholder="A group for betting on NYC happenings"></textarea>
        <span class="form-hint">Max 1000 characters</span>
      </div>
      
      <div class="form-group">
        <label>Invite friends</label>
        <div class="invite-friends-section" id="invite-friends-section">
          <div class="invite-friends-list" id="invite-friends-list">
            <div class="loading-placeholder" style="padding: 12px; font-size: 0.875rem;">Loading friends...</div>
          </div>
        </div>
        <span class="form-hint" style="margin-top: 8px; display: block;">Click to select friends to invite</span>
      </div>
      
      <div class="form-group">
        <label for="market-invites">Invite others (email or @username)</label>
        <input type="text" id="market-invites" placeholder="@john, friend@example.com">
        <span class="form-hint">Separate multiple invites with commas</span>
      </div>
      
      <div id="create-market-error" class="form-error" style="display:none;"></div>
      <div id="create-market-success" class="form-success" style="display:none;"></div>
      <button type="submit" class="btn-primary">Create Market</button>
    </form>
  `);
  modal.id = 'create-market-modal';
  
  // Load friends
  loadFriendsForMarketInvite();

  const form = modal.querySelector('#create-market-form');
  const errorEl = modal.querySelector('#create-market-error');
  const okEl = modal.querySelector('#create-market-success');

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    errorEl.style.display = 'none';
    okEl.style.display = 'none';

    const name = document.getElementById('market-name').value.trim();
    const description = document.getElementById('market-description').value.trim();
    const visibility = 'private'; // All markets are private by design
    const invitesStr = document.getElementById('market-invites').value.trim();
    
    // Get selected friend IDs
    const selectedFriends = document.querySelectorAll('#invite-friends-list .friend-invite-chip.selected');
    const friend_ids = Array.from(selectedFriends).map(el => parseInt(el.dataset.id, 10));
    
    // Parse comma-separated invites - separate emails from usernames
    const inviteItems = invitesStr ? invitesStr.split(',').map(e => e.trim()).filter(e => e) : [];
    const invites = []; // emails
    const usernames = []; // @usernames
    
    inviteItems.forEach(item => {
      if (item.startsWith('@')) {
        usernames.push(item.substring(1)); // Remove @ prefix
      } else if (item.includes('@')) {
        invites.push(item); // It's an email
      } else {
        usernames.push(item); // Assume it's a username without @
      }
    });

    if (!name) {
      errorEl.textContent = 'Please enter a market name.';
      errorEl.style.display = 'block';
      return;
    }

    try {
      const res = await fetch('api/markets.php', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': TYCHES_CSRF_TOKEN,
        },
        credentials: 'same-origin',
        body: JSON.stringify({ name, description, visibility, invites, friend_ids, usernames }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        // Check if verification is required
        if (handleApiError(data, res)) {
          modal.style.display = 'none';
          return;
        }
        errorEl.textContent = data.error || 'Could not create market.';
        errorEl.style.display = 'block';
        return;
      }
      okEl.textContent = 'Market created!';
      okEl.style.display = 'block';
      setTimeout(() => {
        window.location.href = 'market.php?id=' + encodeURIComponent(data.id);
      }, 800);
    } catch {
      errorEl.textContent = 'Network error. Try again.';
      errorEl.style.display = 'block';
    }
  });

  modal.style.display = 'flex';
}

// Load friends for market invite modal
async function loadFriendsForMarketInvite() {
  const container = document.getElementById('invite-friends-list');
  if (!container) return;
  
  try {
    const res = await fetch('api/friends.php', { credentials: 'same-origin' });
    const data = await res.json();
    
    const friends = (data.friends || []).filter(f => f.status === 'accepted');
    
    if (friends.length === 0) {
      container.innerHTML = `
        <div class="no-friends-hint">
          <span>No friends yet.</span>
          <a href="profile.php">Add friends first</a>
        </div>
      `;
      return;
    }
    
    container.innerHTML = '';
    friends.forEach(friend => {
      const chip = document.createElement('div');
      chip.className = 'friend-invite-chip';
      chip.dataset.id = friend.friend_id;
      chip.dataset.username = friend.username;
      
      const initial = (friend.name || friend.username || '?').charAt(0).toUpperCase();
      chip.innerHTML = `
        <div class="chip-avatar">${escapeHtml(initial)}</div>
        <span class="chip-name">${escapeHtml(friend.name || friend.username)}</span>
        <span class="chip-check">✓</span>
      `;
      
      chip.addEventListener('click', () => {
        chip.classList.toggle('selected');
      });
      
      container.appendChild(chip);
    });
  } catch (err) {
    console.error('Failed to load friends:', err);
    container.innerHTML = '<div class="no-friends-hint">Could not load friends</div>';
  }
}

// --- Profile page ---
// New profile page hydration for app shell layout
function hydrateProfilePage(profileData) {
  const u = profileData.user;
  if (!u) return;
  
  const initial = (u.name || u.username || '?').trim().charAt(0).toUpperCase();
  const friendsCount = (profileData.friends || []).filter(f => f.status === 'accepted').length;
  const betsCount = (profileData.bets || []).length;
  const rawTokens = typeof u.tokens_balance === 'number' ? u.tokens_balance : parseFloat(u.tokens_balance || '0');
  const tokens = isNaN(rawTokens) ? 0 : rawTokens;
  
  // Profile header
  const header = document.getElementById('profile-header');
  if (header) {
    header.innerHTML = `
      <div class="profile-avatar-xl">${initial}</div>
      <div class="profile-info-main">
        <h1>${escapeHtml(u.name || u.username || 'User')}</h1>
        <div class="profile-username">@${escapeHtml(u.username || '')}</div>
        <div class="profile-quick-stats">
          <div class="profile-quick-stat">
            <span class="stat-value">${formatNumber(tokens)}</span>
            <span class="stat-label">Tokens</span>
          </div>
          <div class="profile-quick-stat">
            <span class="stat-value">${friendsCount}</span>
            <span class="stat-label">Friends</span>
          </div>
          <div class="profile-quick-stat">
            <span class="stat-value">${betsCount}</span>
            <span class="stat-label">Bets</span>
          </div>
        </div>
      </div>
    `;
  }
  
  // Friends list
  const friendsEl = document.getElementById('friends-list');
  if (friendsEl) {
    const friends = (profileData.friends || []).filter(f => f.status === 'accepted');
    if (friends.length === 0) {
      friendsEl.innerHTML = '<div class="loading-placeholder">No friends yet</div>';
    } else {
      friendsEl.innerHTML = friends.map(f => `
        <div class="friend-item">
          <div class="member-avatar">${(f.name || f.username || '?').charAt(0).toUpperCase()}</div>
          <div>
            <div class="member-name">${escapeHtml(f.name || f.username)}</div>
            <div class="member-role">@${escapeHtml(f.username || '')}</div>
          </div>
        </div>
      `).join('');
    }
  }
  
  // Events
  const eventsEl = document.getElementById('profile-events');
  if (eventsEl) {
    const events = profileData.events_created || [];
    if (events.length === 0) {
      eventsEl.innerHTML = '<div class="loading-placeholder">No events created yet</div>';
    } else {
      eventsEl.innerHTML = events.map(ev => `
        <div class="market-event-item" onclick="window.location.href='event.php?id=${ev.id}'">
          <div>
            <div class="market-event-question">${escapeHtml(ev.title)}</div>
            <div class="market-event-meta">${escapeHtml(ev.market_name || '')} · ${ev.status}</div>
          </div>
        </div>
      `).join('');
    }
  }
  
  // Markets
  const marketsEl = document.getElementById('profile-markets');
  if (marketsEl) {
    const markets = profileData.markets || [];
    if (markets.length === 0) {
      marketsEl.innerHTML = '<div class="loading-placeholder">No markets yet</div>';
    } else {
      marketsEl.innerHTML = markets.map(m => `
        <div class="market-event-item" onclick="window.location.href='market.php?id=${m.id}'">
          <div>
            <div class="market-event-question">${m.avatar_emoji || '🎯'} ${escapeHtml(m.name)}</div>
            <div class="market-event-meta">${m.members_count || 1} members · ${m.events_count || 0} events</div>
          </div>
        </div>
      `).join('');
    }
  }
  
  // Bets
  const betsEl = document.getElementById('profile-bets');
  if (betsEl) {
    const bets = profileData.bets || [];
    if (bets.length === 0) {
      betsEl.innerHTML = '<div class="loading-placeholder">No bets yet</div>';
    } else {
      betsEl.innerHTML = bets.slice(0, 10).map(bet => `
        <div class="market-event-item" onclick="window.location.href='event.php?id=${bet.event_id}'">
          <div>
            <div class="market-event-question">${escapeHtml(bet.event_title || 'Event')}</div>
            <div class="market-event-meta">${bet.side || bet.outcome_id || '?'} · ${formatNumber(bet.shares)} tokens</div>
          </div>
        </div>
      `).join('');
    }
  }
  
  // Setup enhanced friends UI (tabs, search, suggestions)
  setupFriendsUI();
  
  // Setup password form
  setupPasswordForm();
}

function hydrateProfile(profileData) {
  const header = document.getElementById('profile-header');
  if (header && profileData.user) {
    const u = profileData.user;
    const initial = (u.name || u.username || '?').trim().charAt(0).toUpperCase();
    const friendsCount = (profileData.friends || []).filter(f => f.status === 'accepted').length;
    const memberSince = u.created_at ? new Date(u.created_at).toLocaleDateString('en-US', { month: 'short', year: 'numeric' }) : '';
    const rawTokens = typeof u.tokens_balance === 'number'
      ? u.tokens_balance
      : parseFloat(u.tokens_balance || '0');
    const tokens = isNaN(rawTokens) ? 0 : rawTokens;
    const tokensLabel = tokens.toFixed(2);
    header.innerHTML = `
      <div class="profile-avatar">${initial}</div>
      <div class="profile-meta">
        <div class="profile-name">${escapeHtml(u.name || '')}</div>
        <div class="profile-username">@${escapeHtml(u.username || '')}</div>
        <div class="profile-email">${escapeHtml(u.email || '')}</div>
        <div class="profile-stats">
          <span>👥 ${friendsCount} friends</span>
          <span style="margin-left:1rem;">🪙 ${tokensLabel} tokens</span>
          ${memberSince ? `<span style="margin-left:1rem;">📅 Member since ${memberSince}</span>` : ''}
        </div>
      </div>
    `;
  }

  const marketsEl = document.getElementById('profile-markets');
  if (marketsEl) {
    marketsEl.innerHTML = '';
    const markets = profileData.markets || [];
    if (markets.length === 0) {
      marketsEl.innerHTML = `
        <div class="empty-state">
          <div class="empty-state-icon">🎯</div>
          <div class="empty-state-text">No markets yet</div>
        </div>
      `;
    } else {
      markets.forEach(m => {
        const card = document.createElement('div');
        card.className = 'market-card';
        card.innerHTML = `
          <div class="market-header">
            <div class="market-creator">
              <div class="creator-avatar">${m.avatar_emoji || '🎯'}</div>
              <div>
                <div class="creator-name">${escapeHtml(m.name)}</div>
                <div class="market-meta">${m.members_count || 0} members · ${m.events_count || 0} events</div>
              </div>
            </div>
          </div>
          <div class="market-footer">
            <div class="market-volume"></div>
            <button class="btn-market btn-small">Open</button>
          </div>
        `;
        card.querySelector('.btn-market').addEventListener('click', () => {
          window.location.href = 'market.php?id=' + encodeURIComponent(m.id);
        });
        marketsEl.appendChild(card);
      });
    }
  }

  const eventsEl = document.getElementById('profile-events');
  if (eventsEl) {
    eventsEl.innerHTML = '';
    const events = profileData.events_created || [];
    if (events.length === 0) {
      eventsEl.innerHTML = `
        <div class="empty-state">
          <div class="empty-state-icon">📅</div>
          <div class="empty-state-text">No events created yet</div>
        </div>
      `;
    } else {
      events.forEach(ev => {
        const row = document.createElement('div');
        row.className = 'event-row';
        row.innerHTML = `
          <div class="event-row-main">
            <div class="event-row-title">${escapeHtml(ev.title)}</div>
            <div class="event-row-meta">
              ${escapeHtml(ev.market_name || '')} · ${escapeHtml(ev.status)} · closes ${formatDate(ev.closes_at)}
            </div>
          </div>
          <button class="btn-secondary btn-small">Open</button>
        `;
        row.querySelector('button').addEventListener('click', () => {
          window.location.href = 'event.php?id=' + encodeURIComponent(ev.id);
        });
        eventsEl.appendChild(row);
      });
    }
  }

  const betsEl = document.getElementById('profile-bets');
  if (betsEl) {
    betsEl.innerHTML = '';
    const bets = profileData.bets || [];
    if (bets.length === 0) {
      betsEl.innerHTML = `
        <div class="empty-state">
          <div class="empty-state-icon">💰</div>
          <div class="empty-state-text">No bets placed yet</div>
        </div>
      `;
    } else {
      bets.forEach(b => {
        const row = document.createElement('div');
        row.className = 'event-row';
        const side = b.side || b.outcome_id || '';
        row.innerHTML = `
          <div class="event-row-main">
            <div class="event-row-title">${escapeHtml(b.event_title || 'Event')}</div>
            <div class="event-row-meta">
              ${escapeHtml(b.market_name || '')} · <strong>${escapeHtml(side)}</strong> · ${b.shares} shares @ ${b.price}¢
            </div>
          </div>
        `;
        betsEl.appendChild(row);
      });
    }
  }

  setupFriendsUI();
  setupPasswordForm();
}

// --- Friends UI - Enhanced Social Media Style ---
function setupFriendsUI() {
  console.log('[Tyches] Setting up Friends UI...');
  
  const searchInput = document.getElementById('friends-search-input');
  const listEl = document.getElementById('friends-list');
  const reqEl = document.getElementById('friends-requests');
  const searchResultsEl = document.getElementById('friends-search-results');
  const suggestedEl = document.getElementById('suggested-friends-list');
  const suggestedSection = document.getElementById('friends-suggested');
  
  // Tab elements
  const tabs = document.querySelectorAll('.friends-tab');
  const tabContents = document.querySelectorAll('.friends-tab-content');
  const friendsCountBadge = document.getElementById('friends-count-badge');
  const requestsCountBadge = document.getElementById('requests-count-badge');

  console.log('[Tyches] Friends UI elements:', {
    searchInput: !!searchInput,
    listEl: !!listEl,
    tabs: tabs.length,
    tabContents: tabContents.length
  });

  // If no friends UI elements found, exit early
  if (!searchInput && !listEl && tabs.length === 0) {
    console.log('[Tyches] No friends UI elements found, skipping setup');
    return;
  }

  // Track sent requests to update UI
  const sentRequests = new Set();
  
  // Tab switching
  tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      const targetTab = tab.dataset.tab;
      
      // Update tab active states
      tabs.forEach(t => t.classList.remove('active'));
      tab.classList.add('active');
      
      // Update content active states
      tabContents.forEach(content => {
        content.classList.remove('active');
        if (content.id === `friends-tab-${targetTab}`) {
          content.classList.add('active');
        }
      });
      
      // If switching to discover tab and searching, trigger search
      if (targetTab === 'discover' && searchInput?.value.trim()) {
        refreshFriends(searchInput.value.trim());
      }
    });
  });

  // Debounced search
  let searchTimeout;
  searchInput?.addEventListener('input', (e) => {
    clearTimeout(searchTimeout);
    const query = e.target.value.trim();
    
    searchTimeout = setTimeout(() => {
      if (query) {
        // Switch to discover tab when searching
        const discoverTab = document.querySelector('.friends-tab[data-tab="discover"]');
        if (discoverTab && !discoverTab.classList.contains('active')) {
          discoverTab.click();
        }
      }
      refreshFriends(query);
    }, 300);
  });

  searchInput?.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      clearTimeout(searchTimeout);
      const query = searchInput.value.trim();
      if (query) {
        const discoverTab = document.querySelector('.friends-tab[data-tab="discover"]');
        if (discoverTab && !discoverTab.classList.contains('active')) {
          discoverTab.click();
        }
      }
      refreshFriends(query);
    }
  });

  async function refreshFriends(query = '') {
    console.log('[Tyches] refreshFriends called with query:', query);
    const url = query ? `api/friends.php?q=${encodeURIComponent(query)}` : 'api/friends.php';
    let data = {};
    try {
      const res = await fetch(url, { credentials: 'same-origin' });
      data = await res.json().catch(() => ({}));
      console.log('[Tyches] friends API response:', res.status, data);
      if (!res.ok) {
        console.error('[Tyches] friends API error:', data);
        showToast(data.error || 'Could not load friends.', 'error');
        return;
      }
    } catch (err) {
      console.error('[Tyches] friends API network error:', err);
      showToast('Network error loading friends.', 'error');
      return;
    }

    const friends = data.friends || [];
    const search = data.search || [];
    const suggested = data.suggested || [];
    console.log('[Tyches] Parsed friends data:', { friends: friends.length, search: search.length, suggested: suggested.length });
    
    const acceptedFriends = friends.filter(f => f.status === 'accepted');
    // Split pending requests: incoming (they sent to me) vs outgoing (I sent to them)
    const incomingRequests = friends.filter(f => f.status === 'pending' && f.is_incoming);
    const outgoingRequests = friends.filter(f => f.status === 'pending' && !f.is_incoming);
    
    // Track outgoing requests so we don't show "Add Friend" for them in search
    outgoingRequests.forEach(r => sentRequests.add(r.friend_id));

    // Update badges - only count INCOMING requests (ones I can act on)
    if (friendsCountBadge) {
      friendsCountBadge.textContent = acceptedFriends.length;
    }
    if (requestsCountBadge) {
      if (incomingRequests.length > 0) {
        requestsCountBadge.textContent = incomingRequests.length;
        requestsCountBadge.style.display = '';
      } else {
        requestsCountBadge.style.display = 'none';
      }
    }

    // Render friends list
    renderFriendsList(listEl, acceptedFriends);
    
    // Render pending requests (both incoming and outgoing, but with different UI)
    renderPendingRequests(reqEl, incomingRequests, outgoingRequests);
    
    // Render search results (if searching)
    renderSearchResults(searchResultsEl, search, query, friends);
    
    // Render suggested friends
    renderSuggestedFriends(suggestedEl, suggested, friends);
    
    // Show/hide suggested section based on search
    if (suggestedSection) {
      suggestedSection.style.display = query ? 'none' : '';
    }
  }

  function renderFriendsList(container, friends) {
    if (!container) return;
    
    if (friends.length === 0) {
      container.innerHTML = `
        <div class="empty-state-mini">
          <div class="empty-state-icon">👋</div>
          <div class="empty-state-text">No friends yet</div>
          <div class="empty-state-subtext">Search for people or check out suggestions!</div>
        </div>
      `;
      return;
    }
    
    container.innerHTML = '';
    friends.forEach(f => {
      const initial = (f.name || f.username || '?').trim().charAt(0).toUpperCase();
      const card = document.createElement('div');
      card.className = 'friend-card';
      card.innerHTML = `
        <div class="friend-avatar-lg">${escapeHtml(initial)}</div>
        <div class="friend-info">
          <div class="friend-name-lg">${escapeHtml(f.name || f.username)}</div>
          <div class="friend-username-lg">@${escapeHtml(f.username)}</div>
        </div>
        <button class="btn-unfriend" data-id="${f.friend_id}">Remove</button>
      `;
      card.querySelector('button').addEventListener('click', () => mutateFriend('unfriend', f.friend_id));
      container.appendChild(card);
    });
  }

  function renderPendingRequests(container, incomingRequests, outgoingRequests) {
    if (!container) return;
    
    const hasIncoming = incomingRequests.length > 0;
    const hasOutgoing = outgoingRequests.length > 0;
    
    if (!hasIncoming && !hasOutgoing) {
      container.innerHTML = `
        <div class="empty-state-mini">
          <div class="empty-state-icon">📭</div>
          <div class="empty-state-text">No pending requests</div>
        </div>
      `;
      return;
    }
    
    container.innerHTML = '';
    
    // Render INCOMING requests first (ones I can accept/decline)
    if (hasIncoming) {
      const incomingHeader = document.createElement('div');
      incomingHeader.className = 'requests-section-header';
      incomingHeader.innerHTML = `<span class="section-label">📬 Received</span>`;
      container.appendChild(incomingHeader);
      
      incomingRequests.forEach(req => {
        const initial = (req.name || req.username || '?').trim().charAt(0).toUpperCase();
        const timeSince = req.created_at ? formatRelativeTime(req.created_at) : '';
        
        const card = document.createElement('div');
        card.className = 'friend-request-card';
        card.innerHTML = `
          <div class="friend-avatar-lg">${escapeHtml(initial)}</div>
          <div class="friend-info">
            <div class="friend-name-lg">${escapeHtml(req.name || req.username)}</div>
            <div class="friend-username-lg">@${escapeHtml(req.username)}</div>
            ${timeSince ? `<div class="request-time">${timeSince}</div>` : ''}
          </div>
          <div class="request-actions">
            <button class="btn-accept" data-id="${req.friend_id}" data-action="accept">Accept</button>
            <button class="btn-decline" data-id="${req.friend_id}" data-action="decline">Decline</button>
          </div>
        `;
        card.querySelectorAll('button').forEach(btn => {
          btn.addEventListener('click', () => mutateFriend(btn.dataset.action, parseInt(btn.dataset.id, 10)));
        });
        container.appendChild(card);
      });
    }
    
    // Render OUTGOING requests (ones I sent, waiting for response)
    if (hasOutgoing) {
      const outgoingHeader = document.createElement('div');
      outgoingHeader.className = 'requests-section-header';
      outgoingHeader.innerHTML = `<span class="section-label">📤 Sent</span>`;
      container.appendChild(outgoingHeader);
      
      outgoingRequests.forEach(req => {
        const initial = (req.name || req.username || '?').trim().charAt(0).toUpperCase();
        const timeSince = req.created_at ? formatRelativeTime(req.created_at) : '';
        
        const card = document.createElement('div');
        card.className = 'friend-request-card outgoing';
        card.innerHTML = `
          <div class="friend-avatar-lg">${escapeHtml(initial)}</div>
          <div class="friend-info">
            <div class="friend-name-lg">${escapeHtml(req.name || req.username)}</div>
            <div class="friend-username-lg">@${escapeHtml(req.username)}</div>
            ${timeSince ? `<div class="request-time">${timeSince}</div>` : ''}
          </div>
          <div class="request-actions">
            <span class="pending-label">Pending</span>
            <button class="btn-cancel-request" data-id="${req.friend_id}" data-action="unfriend">Cancel</button>
          </div>
        `;
        card.querySelector('.btn-cancel-request').addEventListener('click', () => mutateFriend('unfriend', req.friend_id));
        container.appendChild(card);
      });
    }
  }

  function renderSearchResults(container, results, query, existingFriends) {
    if (!container) return;
    
    if (!query) {
      container.style.display = 'none';
      container.innerHTML = '';
      return;
    }
    
    container.style.display = '';
    
    // Filter out existing friends from search results
    const friendIds = new Set(existingFriends.map(f => f.friend_id));
    const filteredResults = results.filter(u => !friendIds.has(u.id));
    
    if (filteredResults.length === 0) {
      container.innerHTML = `
        <div class="search-results-header">
          <span class="search-results-title">Search Results</span>
          <button class="search-results-clear" onclick="document.getElementById('friends-search-input').value=''; document.getElementById('friends-search-input').dispatchEvent(new Event('input'));">Clear</button>
        </div>
        <div class="empty-state-mini">
          <div class="empty-state-icon">🔍</div>
          <div class="empty-state-text">No users found for "${escapeHtml(query)}"</div>
        </div>
      `;
      return;
    }
    
    container.innerHTML = `
      <div class="search-results-header">
        <span class="search-results-title">Search Results</span>
        <button class="search-results-clear" onclick="document.getElementById('friends-search-input').value=''; document.getElementById('friends-search-input').dispatchEvent(new Event('input'));">Clear</button>
      </div>
      <div class="search-results-grid"></div>
    `;
    
    const grid = container.querySelector('.search-results-grid');
    filteredResults.forEach(u => {
      const initial = (u.name || u.username || '?').trim().charAt(0).toUpperCase();
      const alreadySent = sentRequests.has(u.id);
      
      const card = document.createElement('div');
      card.className = 'search-result-card';
      card.innerHTML = `
        <div class="friend-avatar-lg">${escapeHtml(initial)}</div>
        <div class="friend-info">
          <div class="friend-name-lg">${escapeHtml(u.name || u.username)}</div>
          <div class="friend-username-lg">@${escapeHtml(u.username)}</div>
        </div>
        <button class="btn-add-friend ${alreadySent ? 'sent' : ''}" data-id="${u.id}" ${alreadySent ? 'disabled' : ''}>
          ${alreadySent ? 'Request Sent' : 'Add Friend'}
        </button>
      `;
      
      if (!alreadySent) {
        card.querySelector('button').addEventListener('click', async (e) => {
          const btn = e.currentTarget;
          btn.disabled = true;
          btn.textContent = 'Sending...';
          try {
            await mutateFriend('send_request', u.id);
            sentRequests.add(u.id);
            btn.textContent = 'Request Sent';
            btn.classList.add('sent');
          } catch {
            btn.disabled = false;
            btn.textContent = 'Add Friend';
          }
        });
      }
      
      grid.appendChild(card);
    });
  }

  function renderSuggestedFriends(container, suggested, existingFriends) {
    if (!container) return;
    
    // Filter out existing friends from suggestions
    const friendIds = new Set(existingFriends.map(f => f.friend_id));
    const filteredSuggestions = suggested.filter(s => !friendIds.has(s.id) && !sentRequests.has(s.id));
    
    if (filteredSuggestions.length === 0) {
      container.innerHTML = `
        <div class="empty-state-mini">
          <div class="empty-state-icon">🌟</div>
          <div class="empty-state-text">No suggestions right now</div>
          <div class="empty-state-subtext">Join more markets to discover people!</div>
        </div>
      `;
      return;
    }
    
    container.innerHTML = '';
    filteredSuggestions.forEach(s => {
      const initial = (s.name || s.username || '?').trim().charAt(0).toUpperCase();
      
      const card = document.createElement('div');
      card.className = 'suggested-friend-card';
      card.innerHTML = `
        <div class="friend-avatar-lg">${escapeHtml(initial)}</div>
        <div class="friend-info">
          <div class="friend-name-lg">${escapeHtml(s.name || s.username)}</div>
          <div class="friend-username-lg">@${escapeHtml(s.username)}</div>
          <div class="suggestion-reason">${escapeHtml(s.reason || 'Suggested for you')}</div>
        </div>
        <button class="btn-add-friend" data-id="${s.id}">Add</button>
      `;
      
      card.querySelector('button').addEventListener('click', async (e) => {
        const btn = e.currentTarget;
        btn.disabled = true;
        btn.textContent = 'Sending...';
        try {
          await mutateFriend('send_request', s.id);
          sentRequests.add(s.id);
          btn.textContent = 'Sent!';
          btn.classList.add('sent');
          // Fade out the card after successful request
          setTimeout(() => {
            card.style.opacity = '0.5';
          }, 500);
        } catch {
          btn.disabled = false;
          btn.textContent = 'Add';
        }
      });
      
      container.appendChild(card);
    });
  }

  function formatRelativeTime(dateStr) {
    try {
      const date = new Date(dateStr);
      const now = new Date();
      const diffMs = now - date;
      const diffMins = Math.floor(diffMs / 60000);
      const diffHours = Math.floor(diffMs / 3600000);
      const diffDays = Math.floor(diffMs / 86400000);
      
      if (diffMins < 1) return 'Just now';
      if (diffMins < 60) return `${diffMins}m ago`;
      if (diffHours < 24) return `${diffHours}h ago`;
      if (diffDays < 7) return `${diffDays}d ago`;
      return date.toLocaleDateString();
    } catch {
      return '';
    }
  }

  async function mutateFriend(action, userId) {
    try {
      const res = await fetch('api/friends.php', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': TYCHES_CSRF_TOKEN,
        },
        credentials: 'same-origin',
        body: JSON.stringify({ action, user_id: userId }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        console.error('[Tyches] friends mutate error:', data);
        showToast(data.error || 'Could not update friends.', 'error');
        throw new Error(data.error || 'friends_mutate_failed');
      }

      if (action === 'send_request') {
        showToast('Friend request sent! 🎉', 'success');
      } else if (action === 'accept') {
        showToast('You are now friends! 🤝', 'success');
      } else if (action === 'decline') {
        showToast('Request declined.', 'info');
      } else if (action === 'unfriend') {
        showToast('Friend removed.', 'info');
      }
    } catch (err) {
      console.error('[Tyches] friends mutate network error:', err);
      if (!err || err.message !== 'friends_mutate_failed') {
        showToast('Network error updating friends.', 'error');
      }
      throw err;
    } finally {
      // Don't refresh if we're sending a request - we handle UI locally
      if (action !== 'send_request') {
        await refreshFriends(searchInput?.value.trim() || '');
      }
    }
  }

  // Initial load
  console.log('[Tyches] Starting initial friends load...');
  refreshFriends('');
}

// --- Password change form on profile page ---
function setupPasswordForm() {
  const form = document.getElementById('password-form');
  if (!form) return;

  const currentEl = document.getElementById('password-current');
  const newEl = document.getElementById('password-new');
  const confirmEl = document.getElementById('password-new-confirm');
  const errEl = document.getElementById('password-error');
  const okEl = document.getElementById('password-success');

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (errEl) {
      errEl.style.display = 'none';
      errEl.textContent = '';
    }
    if (okEl) {
      okEl.style.display = 'none';
      okEl.textContent = '';
    }

    const current_password = currentEl?.value || '';
    const new_password = newEl?.value || '';
    const new_password_confirmation = confirmEl?.value || '';

    if (!current_password || !new_password || !new_password_confirmation) {
      if (errEl) {
        errEl.textContent = 'Please fill in all fields.';
        errEl.style.display = 'block';
      }
      return;
    }
    if (new_password.length < 8) {
      if (errEl) {
        errEl.textContent = 'New password must be at least 8 characters.';
        errEl.style.display = 'block';
      }
      return;
    }
    if (new_password !== new_password_confirmation) {
      if (errEl) {
        errEl.textContent = 'New passwords do not match.';
        errEl.style.display = 'block';
      }
      return;
    }

    try {
      const res = await fetch('api/password.php', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': TYCHES_CSRF_TOKEN,
        },
        credentials: 'same-origin',
        body: JSON.stringify({
          current_password,
          new_password,
          new_password_confirmation,
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        if (errEl) {
          errEl.textContent = data.error || 'Could not update password.';
          errEl.style.display = 'block';
        }
        return;
      }
      currentEl.value = '';
      newEl.value = '';
      confirmEl.value = '';
      if (okEl) {
        okEl.textContent = 'Password updated successfully.';
        okEl.style.display = 'block';
      }
    } catch (e) {
      if (errEl) {
        errEl.textContent = 'Network error. Try again.';
        errEl.style.display = 'block';
      }
    }
  });
}

// --- Create event page helpers ---
function setupCreateEventUI() {
  const form = document.getElementById('create-event-form');
  if (!form) return;

  // Get preselected market from URL/data attribute
  const preselectedMarket = parseInt(document.body.dataset.preselectMarket || '0', 10);
  
  // Store market members for later use
  let currentMarketMembers = [];
  
  // Set default closes_at to 1 week from now at 8:00 PM EST
  const closesAtInput = document.getElementById('event-closes-at');
  if (closesAtInput && !closesAtInput.value) {
    const oneWeekLater = new Date();
    oneWeekLater.setDate(oneWeekLater.getDate() + 7);
    // Set to 8:00 PM EST (20:00)
    // EST is UTC-5, so we need to calculate the local time equivalent
    const estOffset = -5 * 60; // EST offset in minutes
    const localOffset = oneWeekLater.getTimezoneOffset(); // Local offset in minutes (positive for west of UTC)
    const diffMinutes = localOffset + estOffset;
    oneWeekLater.setHours(20, 0, 0, 0); // Set to 8 PM
    oneWeekLater.setMinutes(oneWeekLater.getMinutes() - diffMinutes); // Adjust for timezone difference
    
    // Format for datetime-local input (YYYY-MM-DDTHH:MM)
    const year = oneWeekLater.getFullYear();
    const month = String(oneWeekLater.getMonth() + 1).padStart(2, '0');
    const day = String(oneWeekLater.getDate()).padStart(2, '0');
    const hours = String(oneWeekLater.getHours()).padStart(2, '0');
    const minutes = String(oneWeekLater.getMinutes()).padStart(2, '0');
    closesAtInput.value = `${year}-${month}-${day}T${hours}:${minutes}`;
  }

  // Populate Markets select and load members when market changes
  fetch('api/markets.php', { credentials: 'same-origin' })
    .then(r => r.json())
    .then(data => {
      const select = document.getElementById('event-market');
      if (!select) return;
      const markets = data.markets || [];
      if (markets.length === 0) {
        const opt = document.createElement('option');
        opt.value = '';
        opt.textContent = 'No markets available - create one first';
        select.appendChild(opt);
        return;
      }
      markets.forEach(m => {
        const opt = document.createElement('option');
        opt.value = m.id;
        opt.textContent = m.name;
        // Preselect if matching
        if (preselectedMarket && m.id === preselectedMarket) {
          opt.selected = true;
        }
        select.appendChild(opt);
      });
      
      // Load members for the selected market
      select.addEventListener('change', () => loadMarketMembers(select.value));
      if (select.value) loadMarketMembers(select.value);
    })
    .catch(() => {});
  
  // Function to load market members for resolver/participants
  async function loadMarketMembers(marketId) {
    if (!marketId) return;
    try {
      const res = await fetch(`api/markets.php?id=${marketId}`, { credentials: 'same-origin' });
      const data = await res.json();
      currentMarketMembers = data.members || [];
      populateResolverDropdown(currentMarketMembers);
      populateParticipantsList(currentMarketMembers);
    } catch (e) {
      console.error('Failed to load market members', e);
    }
  }
  
  // Populate resolver dropdown
  function populateResolverDropdown(members) {
    const resolverSelect = document.getElementById('event-resolver');
    if (!resolverSelect) return;
    
    // Clear existing options except first (Me)
    while (resolverSelect.options.length > 1) {
      resolverSelect.remove(1);
    }
    
    // Add market members
    members.forEach(m => {
      const memberId = m.id || m.user_id; // API returns 'id', not 'user_id'
      
      // Skip current user (they're already the default "Me" option)
      if (window.tychesUser && memberId === window.tychesUser.id) return;
      
      const opt = document.createElement('option');
      opt.value = memberId;
      opt.textContent = `${m.name || m.username} (@${m.username})`;
      resolverSelect.appendChild(opt);
    });
  }
  
  // Populate participants list
  function populateParticipantsList(members) {
    const participantsList = document.getElementById('participants-list');
    if (!participantsList) return;
    
    participantsList.innerHTML = '';
    
    // Filter out the current user and count valid members
    const otherMembers = members.filter(m => {
      const memberId = m.id || m.user_id;
      return !window.tychesUser || memberId !== window.tychesUser.id;
    });
    
    otherMembers.forEach(m => {
      const memberId = m.id || m.user_id; // API returns 'id', not 'user_id'
      
      const item = document.createElement('label');
      item.className = 'participant-checkbox-item';
      item.innerHTML = `
        <input type="checkbox" name="participants[]" value="${memberId}" checked>
        <div class="participant-avatar">${(m.name || m.username || '?').charAt(0).toUpperCase()}</div>
        <div class="participant-info">
          <div class="participant-name">${escapeHtml(m.name || m.username)}</div>
          <div class="participant-username">@${escapeHtml(m.username || '')}</div>
        </div>
      `;
      participantsList.appendChild(item);
    });
    
    if (otherMembers.length === 0) {
      participantsList.innerHTML = '<p class="help-text">No other members in this market yet.</p>';
    }
  }
  
  // Visibility toggle
  const visibilityToggle = document.getElementById('visibility-toggle');
  const visibilityInput = document.getElementById('event-visibility');
  const visibilityHelp = document.getElementById('visibility-help');
  const participantsSection = document.getElementById('participants-section');
  
  if (visibilityToggle) {
    visibilityToggle.querySelectorAll('button').forEach(btn => {
      btn.addEventListener('click', () => {
        visibilityToggle.querySelectorAll('button').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        const visibility = btn.dataset.visibility;
        visibilityInput.value = visibility;
        
        if (visibility === 'private') {
          visibilityHelp.textContent = 'Only selected participants can see this event';
          if (participantsSection) participantsSection.style.display = '';
        } else {
          visibilityHelp.textContent = 'All market members can see and participate';
          if (participantsSection) participantsSection.style.display = 'none';
        }
      });
    });
  }
  
  // Resolution type toggle
  const resolutionToggle = document.getElementById('resolution-toggle');
  const resolutionInput = document.getElementById('event-resolution-type');
  const resolutionHelp = document.getElementById('resolution-help');
  const resolverSection = document.getElementById('resolver-section');
  
  if (resolutionToggle) {
    resolutionToggle.querySelectorAll('button').forEach(btn => {
      btn.addEventListener('click', () => {
        resolutionToggle.querySelectorAll('button').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        const resolution = btn.dataset.resolution;
        resolutionInput.value = resolution;
        
        if (resolution === 'automatic') {
          resolutionHelp.textContent = 'Event resolves automatically based on highest odds';
          if (resolverSection) resolverSection.style.display = 'none';
        } else {
          resolutionHelp.textContent = 'You or the resolver will determine the outcome';
          if (resolverSection) resolverSection.style.display = '';
        }
      });
    });
  }

  const typeToggle = document.getElementById('event-type-toggle');
  const typeInput = document.getElementById('event-type');
  const binaryBox = document.getElementById('binary-settings');
  const multipleBox = document.getElementById('multiple-settings');
  const yesInput = document.getElementById('event-yes-percent');
  const noInput = document.getElementById('event-no-percent');
  const errorEl = document.getElementById('create-event-error');
  const okEl = document.getElementById('create-event-success');

  if (typeToggle) {
    typeToggle.querySelectorAll('button').forEach(btn => {
      btn.addEventListener('click', () => {
        typeToggle.querySelectorAll('button').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        const type = btn.dataset.type;
        typeInput.value = type;
        if (type === 'binary') {
          binaryBox.style.display = '';
          multipleBox.style.display = 'none';
        } else {
          binaryBox.style.display = 'none';
          multipleBox.style.display = '';
        }
        // Trigger preview update after type change
        setTimeout(() => {
          const previewEl = document.getElementById('create-event-preview-card');
          if (previewEl) previewEl.dispatchEvent(new Event('update'));
        }, 10);
      });
    });
  }

  if (yesInput && noInput) {
    yesInput.addEventListener('input', () => {
      let v = parseInt(yesInput.value || '0', 10);
      if (isNaN(v)) v = 50;
      v = Math.max(1, Math.min(99, v));
      yesInput.value = String(v);
      noInput.value = String(100 - v);
    });
  }

  const outcomesEl = document.getElementById('multiple-outcomes');
  const addOutcomeBtn = document.getElementById('add-outcome');
  if (outcomesEl && addOutcomeBtn) {
    // Helper to recalculate probabilities evenly
    const redistributeProbabilities = () => {
      const rows = outcomesEl.querySelectorAll('.multiple-outcome-row');
      const count = rows.length;
      if (count === 0) return;
      const evenProb = Math.floor(100 / count);
      const remainder = 100 - (evenProb * count);
      rows.forEach((row, i) => {
        const probInput = row.querySelector('.multi-prob');
        if (probInput) {
          // Give remainder to first row
          probInput.value = i === 0 ? evenProb + remainder : evenProb;
        }
      });
    };
    
    const addRow = (label = '', prob = '') => {
      const row = document.createElement('div');
      row.className = 'multiple-outcome-row';
      row.innerHTML = `
        <input type="text" class="multi-label" placeholder="Outcome label" value="${escapeHtmlAttr(label)}">
        <input type="number" class="multi-prob" min="1" max="99" placeholder="%" value="${escapeHtmlAttr(prob)}">
        <button type="button" class="remove-outcome">×</button>
      `;
      row.querySelector('.remove-outcome').addEventListener('click', () => {
        row.remove();
        redistributeProbabilities();
      });
      outcomesEl.appendChild(row);
    };
    
    addOutcomeBtn.addEventListener('click', () => {
      addRow();
      redistributeProbabilities();
    });
    
    // Start with two rows pre-loaded with 50/50 split
    addRow('Option A', '50');
    addRow('Option B', '50');
  }

  // Live preview
  const previewEl = document.getElementById('create-event-preview-card');
  function updatePreview() {
    if (!previewEl) return;
    const title = document.getElementById('event-title')?.value.trim() || 'Your question here...';
    const description = document.getElementById('event-description')?.value.trim() || '';
    const type = typeInput?.value || 'binary';
    const yesPct = parseInt(document.getElementById('event-yes-percent')?.value || '50', 10);
    const noPct = 100 - yesPct;
    
    // Description preview - show first 200 chars with proper formatting
    const descriptionHtml = description 
      ? `<p class="preview-description">${escapeHtml(description.substring(0, 200))}${description.length > 200 ? '...' : ''}</p>`
      : '';

    if (type === 'binary') {
      previewEl.innerHTML = `
        <div class="market-header">
          <div class="market-creator">
            <div class="creator-avatar">🎯</div>
            <div>
              <div class="creator-name">Preview</div>
              <div class="market-meta">Binary event</div>
            </div>
          </div>
        </div>
        <h3 class="market-question">${escapeHtml(title)}</h3>
        ${descriptionHtml}
        <div class="market-odds">
          <div class="odds-bar">
            <div class="odds-fill yes" style="width:${yesPct}%"></div>
            <div class="odds-fill no" style="width:${noPct}%"></div>
          </div>
          <div class="odds-labels">
            <span class="odds-label-yes">YES ${yesPct}¢</span>
            <span class="odds-label-no">NO ${noPct}¢</span>
          </div>
        </div>
      `;
    } else {
      const rows = document.querySelectorAll('#multiple-outcomes .multiple-outcome-row');
      let outcomesHtml = '';
      rows.forEach(row => {
        const label = row.querySelector('.multi-label')?.value.trim() || 'Option';
        const prob = row.querySelector('.multi-prob')?.value || '?';
        outcomesHtml += `<div class="outcome-pill"><span class="outcome-label">${escapeHtml(label)}</span><span class="outcome-prob">${prob}%</span></div>`;
      });
      previewEl.innerHTML = `
        <div class="market-header">
          <div class="market-creator">
            <div class="creator-avatar">🎯</div>
            <div>
              <div class="creator-name">Preview</div>
              <div class="market-meta">Multiple choice</div>
            </div>
          </div>
        </div>
        <h3 class="market-question">${escapeHtml(title)}</h3>
        ${descriptionHtml}
        <div class="outcomes-pills" style="margin-top:1rem;">${outcomesHtml}</div>
      `;
    }
  }

  // Attach preview updates
  document.getElementById('event-title')?.addEventListener('input', updatePreview);
  document.getElementById('event-description')?.addEventListener('input', updatePreview);
  yesInput?.addEventListener('input', updatePreview);
  if (outcomesEl) {
    outcomesEl.addEventListener('input', updatePreview);
  }
  updatePreview();

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    errorEl.style.display = 'none';
    okEl.style.display = 'none';

    const formData = new FormData(form);
    const market_id = parseInt(formData.get('market_id'), 10);
    const title = formData.get('title')?.toString().trim() || '';
    const description = formData.get('description')?.toString().trim() || '';
    const event_type = formData.get('event_type')?.toString() || 'binary';
    const closes_at = formData.get('closes_at')?.toString() || '';
    
    // New fields
    const visibility = formData.get('visibility')?.toString() || 'public';
    const resolution_type = formData.get('resolution_type')?.toString() || 'manual';
    const resolver_id = parseInt(formData.get('resolver_id') || '0', 10);

    if (!market_id || !title || !closes_at) {
      errorEl.textContent = 'Please fill in all required fields.';
      errorEl.style.display = 'block';
      return;
    }

    const payload = { 
      market_id, 
      title, 
      description, 
      event_type, 
      closes_at,
      visibility,
      resolution_type,
    };
    
    // Add resolver if specified
    if (resolver_id > 0) {
      payload.resolver_id = resolver_id;
    }
    
    // For private events, get selected participants
    if (visibility === 'private') {
      const participantCheckboxes = document.querySelectorAll('#participants-list input[type="checkbox"]:checked');
      const participants = Array.from(participantCheckboxes).map(cb => parseInt(cb.value, 10));
      payload.participants = participants;
    }

    if (event_type === 'binary') {
      const yesPct = parseInt(document.getElementById('event-yes-percent').value || '50', 10);
      payload.yes_percent = yesPct;
    } else {
      const rows = document.querySelectorAll('#multiple-outcomes .multiple-outcome-row');
      const outcomes = [];
      rows.forEach(row => {
        const l = row.querySelector('.multi-label').value.trim();
        const p = parseInt(row.querySelector('.multi-prob').value || '0', 10);
        if (l && p > 0) outcomes.push({ label: l, probability: p });
      });
      payload.outcomes = outcomes;
    }

    try {
      const res = await fetch('api/events.php', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': TYCHES_CSRF_TOKEN,
        },
        credentials: 'same-origin',
        body: JSON.stringify(payload),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        // Check if verification is required
        if (handleApiError(data, res)) {
          return;
        }
        errorEl.textContent = data.error || 'Could not create event.';
        errorEl.style.display = 'block';
        return;
      }
      okEl.textContent = 'Event created! Redirecting…';
      okEl.style.display = 'block';
      if (data.id) {
        setTimeout(() => {
          window.location.href = 'event.php?id=' + encodeURIComponent(data.id);
        }, 800);
      }
    } catch {
      errorEl.textContent = 'Network error. Try again.';
      errorEl.style.display = 'block';
    }
  });
}

// --- Market & Event pages wiring ---
function wirePageByContext() {
  const marketId = parseInt(document.body.dataset.marketId || '0', 10);
  const eventId = parseInt(document.body.dataset.eventId || '0', 10);
  const eventsListEl = document.getElementById('my-events-list');
  
  if (marketId) {
    loadMarketPage(marketId);
  } else if (eventId) {
    loadEventPage(eventId);
  } else if (eventsListEl) {
    loadMyEventsPage();
  }
}

async function loadMarketPage(id) {
  const headerEl = document.getElementById('market-header');
  const membersEl = document.getElementById('market-members');
  const eventsEl = document.getElementById('market-events-list');
  const createEventBtn = document.getElementById('market-create-event');

  // Wire up create event button
  if (createEventBtn) {
    createEventBtn.addEventListener('click', () => {
      window.location.href = 'create-event.php?market_id=' + encodeURIComponent(id);
    });
  }

  try {
    console.log('Loading market:', id);
    const res = await fetch('api/markets.php?id=' + encodeURIComponent(id), { credentials: 'same-origin' });
    const data = await res.json();
    console.log('Market API response:', res.status, data);
    
    if (!res.ok || !data.market) {
      const errorMsg = data.error || 'Market not found or you don\'t have access.';
      console.error('Market load error:', errorMsg);
      if (headerEl) {
        headerEl.innerHTML = `
          <div class="empty-state">
            <div class="empty-state-icon">❌</div>
            <div class="empty-state-text">${escapeHtml(errorMsg)}</div>
            <a href="index.php" class="btn-primary">Back to Home</a>
          </div>
        `;
      }
      return;
    }
    
    const m = data.market;
    
    // Update page title
    document.title = `${m.name} - Tyches`;
    
    if (headerEl) {
      headerEl.innerHTML = `
        <div class="market-header-card">
          <div class="market-page-title-row">
            <div class="market-page-avatar">${escapeHtml(m.avatar_emoji || '🎯')}</div>
            <div class="market-page-info">
              <h1 class="market-name">${escapeHtml(m.name)}</h1>
              <p class="market-desc">${escapeHtml(m.description || 'No description')}</p>
              <div class="market-page-stats">
                <span class="market-stat-item">👥 ${(data.members || []).length} members</span>
                <span class="market-stat-item">📊 ${(data.events || []).length} events</span>
              </div>
            </div>
          </div>
        </div>
      `;
    }
    
    if (membersEl) {
      membersEl.innerHTML = '';
      const members = data.members || [];
      if (members.length === 0) {
        membersEl.innerHTML = `
          <div class="empty-state">
            <div class="empty-state-text">No members yet</div>
          </div>
        `;
      } else {
        members.forEach(mem => {
          const item = document.createElement('div');
          item.className = 'member-row';
          const initial = (mem.name || mem.username || '?').trim().charAt(0).toUpperCase();
          const roleLabel = mem.role === 'owner' ? ' (Owner)' : '';
          item.innerHTML = `
            <div class="member-avatar">${initial}</div>
            <div class="member-info">
              <div class="member-name">${escapeHtml(mem.name || mem.username)}${roleLabel}</div>
              <div class="member-username">@${escapeHtml(mem.username || '')}</div>
            </div>
          `;
          membersEl.appendChild(item);
        });
      }
    }
    
    if (eventsEl) {
      eventsEl.innerHTML = '';
      const events = data.events || [];
      if (events.length === 0) {
        eventsEl.innerHTML = `
          <div class="empty-state">
            <div class="empty-state-icon">📅</div>
            <div class="empty-state-text">No events yet. Create the first one!</div>
          </div>
        `;
      } else {
        events.forEach(ev => {
          const row = document.createElement('div');
          row.className = 'event-row';
          const isResolved = ev.status === 'resolved' || ev.status === 'closed';
          
          // For resolved events, show winner - not odds
          let oddsDisplay = '';
          if (isResolved) {
            if (ev.event_type === 'binary') {
              const winner = (ev.winning_side || '').toUpperCase() || 'TBD';
              oddsDisplay = `🏆 ${winner}`;
            } else {
              const winner = ev.winning_outcome_id || 'TBD';
              const truncatedWinner = winner.length > 12 ? winner.substring(0, 10) + '...' : winner;
              oddsDisplay = `🏆 ${escapeHtml(truncatedWinner)}`;
            }
          } else {
            oddsDisplay = ev.event_type === 'binary' ? (ev.yes_percent || 50) + '% YES' : 'Multiple';
          }
          
          row.innerHTML = `
            <div class="event-row-main">
              <div class="event-row-title">${escapeHtml(ev.title)}</div>
              <div class="event-row-meta">
                <span class="status-badge ${ev.status}">${escapeHtml(ev.status)}</span>
                · closes ${formatDate(ev.closes_at)}
                · ${ev.traders_count || 0} traders
              </div>
            </div>
            <div class="event-row-odds ${isResolved ? 'resolved' : ''}">${oddsDisplay}</div>
            <button class="btn-secondary btn-small">Open</button>
          `;
          row.querySelector('button').addEventListener('click', () => {
            window.location.href = 'event.php?id=' + encodeURIComponent(ev.id);
          });
          eventsEl.appendChild(row);
        });
      }
    }
    
    // Setup invite functionality if user can invite
    setupMarketInviteSection(m, data.members || []);
    
  } catch (err) {
    console.error('Failed to load market:', err);
    if (headerEl) {
      headerEl.innerHTML = `
        <div class="empty-state">
          <div class="empty-state-icon">⚠️</div>
          <div class="empty-state-text">Failed to load market. Please try again.</div>
          <a href="index.php" class="btn-primary">Back to Home</a>
        </div>
      `;
    }
  }
}

// --- Market Invite Section ---
function setupMarketInviteSection(market, members) {
  const inviteBtn = document.getElementById('open-invite-modal');
  const inviteModal = document.getElementById('invite-members-modal');
  
  if (!inviteBtn || !inviteModal) return;
  
  // Only show for users who can invite
  if (!market.can_invite) {
    inviteBtn.style.display = 'none';
    return;
  }
  
  inviteBtn.style.display = 'inline-flex';
  
  const closeBtn = document.getElementById('close-invite-modal');
  const cancelBtn = document.getElementById('cancel-invite-modal');
  const emailInput = document.getElementById('market-invite-email-input');
  const addEmailBtn = document.getElementById('market-add-email-btn');
  const emailsList = document.getElementById('market-invite-emails-list');
  const sendInvitesBtn = document.getElementById('market-send-invites-btn');
  const inviteResult = document.getElementById('market-invite-result');
  
  // Track emails to invite
  let emailsToInvite = [];
  
  // Open modal
  inviteBtn.addEventListener('click', () => {
    inviteModal.style.display = 'flex';
    emailInput.focus();
  });
  
  // Close modal
  function closeModal() {
    inviteModal.style.display = 'none';
    emailsToInvite = [];
    emailsList.innerHTML = '';
    emailInput.value = '';
    inviteResult.style.display = 'none';
    updateSendButton();
  }
  
  closeBtn.addEventListener('click', closeModal);
  cancelBtn.addEventListener('click', closeModal);
  
  // Close on overlay click
  inviteModal.addEventListener('click', (e) => {
    if (e.target === inviteModal) closeModal();
  });
  
  // Close on Escape
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && inviteModal.style.display === 'flex') {
      closeModal();
    }
  });
  
  // Add email chip
  function addEmailChip(email) {
    email = email.trim().toLowerCase();
    if (!email || !isValidEmail(email)) {
      showToast('Please enter a valid email address', 'error');
      return false;
    }
    if (emailsToInvite.includes(email)) {
      showToast('Email already added', 'error');
      return false;
    }
    // Check if already a member
    const existingMember = members.find(m => m.email?.toLowerCase() === email);
    if (existingMember) {
      showToast(`${existingMember.name || email} is already a member`, 'error');
      return false;
    }
    
    emailsToInvite.push(email);
    
    const chip = document.createElement('div');
    chip.className = 'invite-email-chip';
    chip.innerHTML = `
      <span class="chip-email">${escapeHtml(email)}</span>
      <button type="button" class="chip-remove" title="Remove">×</button>
    `;
    
    chip.querySelector('.chip-remove').addEventListener('click', () => {
      emailsToInvite = emailsToInvite.filter(e => e !== email);
      chip.remove();
      updateSendButton();
    });
    
    emailsList.appendChild(chip);
    updateSendButton();
    return true;
  }
  
  function updateSendButton() {
    sendInvitesBtn.disabled = emailsToInvite.length === 0;
    sendInvitesBtn.textContent = emailsToInvite.length > 0 
      ? `Send ${emailsToInvite.length} Invitation${emailsToInvite.length > 1 ? 's' : ''}`
      : 'Send Invitations';
  }
  
  function isValidEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }
  
  // Handle add button click
  addEmailBtn.addEventListener('click', () => {
    if (addEmailChip(emailInput.value)) {
      emailInput.value = '';
      emailInput.focus();
    }
  });
  
  // Handle Enter key in email input
  emailInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      if (addEmailChip(emailInput.value)) {
        emailInput.value = '';
      }
    }
  });
  
  // Handle comma-separated or pasted emails
  emailInput.addEventListener('input', (e) => {
    const value = e.target.value;
    if (value.includes(',') || value.includes(' ')) {
      const emails = value.split(/[,\s]+/).filter(Boolean);
      let added = false;
      for (const email of emails) {
        if (isValidEmail(email)) {
          if (addEmailChip(email)) added = true;
        }
      }
      if (added) {
        emailInput.value = '';
      }
    }
  });
  
  // Handle send invites
  sendInvitesBtn.addEventListener('click', async () => {
    if (emailsToInvite.length === 0) return;
    
    sendInvitesBtn.disabled = true;
    sendInvitesBtn.textContent = 'Sending...';
    
    try {
      const res = await fetch('api/markets.php', {
        method: 'POST',
        credentials: 'same-origin',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': TYCHES_CSRF_TOKEN
        },
        body: JSON.stringify({
          action: 'invite',
          market_id: market.id,
          emails: emailsToInvite
        })
      });
      
      const data = await res.json();
      
      if (res.ok && data.ok) {
        // Clear the list
        emailsToInvite = [];
        emailsList.innerHTML = '';
        updateSendButton();
        
        // Show success
        inviteResult.style.display = 'block';
        inviteResult.className = 'invite-result success';
        inviteResult.innerHTML = `
          <span class="result-icon">✓</span>
          <span class="result-text">${escapeHtml(data.message || 'Invitations sent!')}</span>
        `;
        
        showToast(data.message || 'Invitations sent!', 'success');
        
        // Reload page to show new members
        setTimeout(() => {
          closeModal();
          window.location.reload();
        }, 1500);
      } else {
        throw new Error(data.error || 'Failed to send invitations');
      }
    } catch (err) {
      console.error('Invite error:', err);
      inviteResult.style.display = 'block';
      inviteResult.className = 'invite-result error';
      inviteResult.innerHTML = `
        <span class="result-icon">✕</span>
        <span class="result-text">${escapeHtml(err.message || 'Failed to send invitations')}</span>
      `;
      showToast(err.message || 'Failed to send invitations', 'error');
      updateSendButton();
    }
  });
}

// --- My Events Page ---
async function loadMyEventsPage() {
  const eventsListEl = document.getElementById('my-events-list');
  
  // Load events
  try {
    eventsListEl.innerHTML = '<div class="loading-placeholder">Loading your events...</div>';
    
    const res = await fetch('api/events.php?filter=my', { credentials: 'same-origin' });
    const data = await res.json();
    
    if (!res.ok) {
      throw new Error(data.error || 'Failed to load events');
    }
    
    const events = data.events || [];
    
    if (events.length === 0) {
      eventsListEl.innerHTML = `
        <div class="empty-state">
          <div class="empty-state-icon">📅</div>
          <div class="empty-state-text">No events found</div>
          <a href="create-event.php" class="btn-primary">Create an Event</a>
        </div>
      `;
      return;
    }
    
    // Render all events sorted by date (newest first - already sorted by API)
    eventsListEl.innerHTML = events.map(ev => {
      const yesPercent = ev.pools?.yes_percent || ev.yes_percent || 50;
      const timeLeft = formatTimeRemaining(ev.closes_at);
      const isUrgent = new Date(ev.closes_at) - new Date() < 86400000 && ev.status === 'open';
      const isPrivate = ev.visibility === 'private';
      const isResolved = ev.status === 'resolved' || ev.status === 'closed';
      
      // For resolved events, show the winner - not the odds
      let resultDisplay = '';
      if (isResolved) {
        if (ev.event_type === 'binary') {
          const winner = (ev.winning_side || '').toUpperCase() || 'TBD';
          const winnerClass = winner === 'YES' ? 'winner-yes' : winner === 'NO' ? 'winner-no' : '';
          resultDisplay = `<div class="event-result ${winnerClass}">🏆 Winner: <strong>${winner}</strong></div>`;
        } else {
          const winner = ev.winning_outcome_id || 'TBD';
          const truncatedWinner = winner.length > 18 ? winner.substring(0, 15) + '...' : winner;
          resultDisplay = `<div class="event-result" title="${escapeHtml(winner)}">🏆 Winner: <strong>${escapeHtml(truncatedWinner)}</strong></div>`;
        }
      } else {
        // Open events - show odds
        if (ev.event_type === 'binary') {
          resultDisplay = `<div class="event-odds-mini"><span class="yes-odds">${yesPercent}% YES</span></div>`;
        } else {
          resultDisplay = `<div class="event-odds-mini"><span class="multi-label">Multiple choices</span></div>`;
        }
      }
      
      return `
        <div class="event-card-page" onclick="window.location.href='event.php?id=${ev.id}'">
          <div class="event-card-header">
            <div class="event-market-badge">
              <span class="event-market-emoji">${ev.market_avatar_emoji || '🎯'}</span>
              <span>${escapeHtml(ev.market_name || 'Market')}</span>
            </div>
            <div class="event-badges">
              ${isPrivate ? '<span class="event-private-badge" title="Private Event">🔒</span>' : ''}
              <span class="status-badge ${ev.status}">${ev.status}</span>
            </div>
          </div>
          <h3 class="event-card-title">${escapeHtml(ev.title)}</h3>
          <div class="event-card-footer">
            ${resultDisplay}
            <div class="event-time ${isUrgent ? 'urgent' : ''}">
              ${ev.status === 'open' ? timeLeft : formatDate(ev.closes_at)}
            </div>
          </div>
          <div class="event-card-stats">
            <span>${formatNumber(ev.volume || 0)} tokens</span>
            <span>${ev.traders_count || 0} traders</span>
          </div>
        </div>
      `;
    }).join('');
    
  } catch (err) {
    console.error('Failed to load events:', err);
    eventsListEl.innerHTML = `
      <div class="empty-state">
        <div class="empty-state-icon">⚠️</div>
        <div class="empty-state-text">${escapeHtml(err.message || 'Failed to load events')}</div>
        <button class="btn-primary" onclick="location.reload()">Try Again</button>
      </div>
    `;
  }
}

async function loadEventPage(id) {
  const headerEl = document.getElementById('event-header');
  const tradeCard = document.getElementById('event-trade-card');
  const detailsEl = document.getElementById('event-details');

  try {
    const res = await fetch('api/events.php?id=' + encodeURIComponent(id), { credentials: 'same-origin' });
    const data = await res.json();
    
    if (!res.ok || !data.event) {
      if (headerEl) {
        headerEl.innerHTML = `
          <div class="empty-state">
            <div class="empty-state-icon">❌</div>
            <div class="empty-state-text">Event not found or you don't have access.</div>
            <a href="index.php" class="btn-primary">Back to Home</a>
          </div>
        `;
      }
      return;
    }
    
    const ev = data.event;
    
    if (headerEl) {
      const statusBadge = `<span class="status-badge ${ev.status}">${ev.status}</span>`;
      headerEl.innerHTML = `
        <div class="event-header-content">
          <div class="event-meta">
            <a href="market.php?id=${ev.market_id}" class="market-pill">🏠 ${escapeHtml(ev.market_name || 'Market')}</a>
            <span class="meta-sep">·</span>
            ${statusBadge}
            <span class="meta-sep">·</span>
            <span>closes ${formatDate(ev.closes_at)}</span>
          </div>
          <h1 class="event-title">${escapeHtml(ev.title)}</h1>
          <div class="event-stats-inline">
            <span><strong>${formatNumber(ev.volume || 0)}</strong> tokens wagered</span>
            <span><strong>${ev.traders_count || 0}</strong> traders</span>
          </div>
        </div>
      `;
    }
    
    if (tradeCard) {
      renderTradeCard(tradeCard, ev);
    }
    
    if (detailsEl) {
      // Convert newlines to <br> for proper paragraph display
      const formatDescription = (text) => {
        if (!text) return '';
        return escapeHtml(text).replace(/\n/g, '<br>');
      };
      
      // Build description section
      const descriptionHtml = ev.description ? `
        <div class="details-description-v2">
          <div class="description-label-v2">Description</div>
          <p class="description-text-v2">${formatDescription(ev.description)}</p>
        </div>
      ` : '';
      
      detailsEl.innerHTML = `
        <div class="event-detail-row">
          <span class="event-detail-label">Type</span>
          <span class="event-detail-value">${ev.event_type === 'binary' ? 'Binary (Yes/No)' : 'Multiple Choice'}</span>
        </div>
        <div class="event-detail-row">
          <span class="event-detail-label">Volume</span>
          <span class="event-detail-value">${formatNumber(ev.volume || 0)} 🪙</span>
        </div>
        <div class="event-detail-row">
          <span class="event-detail-label">Closes</span>
          <span class="event-detail-value">${formatDate(ev.closes_at)}</span>
        </div>
        ${descriptionHtml}
      `;
    }
    
    loadGossip(ev.id);
    // Activity chart removed - stats now shown inline in header
    
    // Show management section if user can resolve
    setupEventManagementSection(ev);
    
    // Show invite section if user is the event creator
    setupEventInviteSection(ev);
    
    // Load members/participants (for private events, only shows participants)
    loadEventMarketMembers(ev.market_id, ev);
  } catch (err) {
    console.error('Failed to load event:', err);
    if (headerEl) {
      headerEl.innerHTML = `
        <div class="empty-state">
          <div class="empty-state-icon">⚠️</div>
          <div class="empty-state-text">Failed to load event. Please try again.</div>
          <a href="index.php" class="btn-primary">Back to Home</a>
        </div>
      `;
    }
  }
}

// --- Event Management Section (Close/Resolve) ---
function setupEventManagementSection(event) {
  const section = document.getElementById('event-management-section');
  if (!section) return;
  
  // Only show for users who can manage OR resolve
  // can_manage = creator, hosts, market owner (can close/reopen)
  // can_resolve = creator, resolver, hosts, market owner (can determine outcome)
  const canManage = event.can_manage || false;
  const canResolve = event.can_resolve || false;
  
  if (!canManage && !canResolve) {
    section.style.display = 'none';
    return;
  }
  
  section.style.display = 'block';
  
  const statusEl = document.getElementById('event-management-status');
  const actionsEl = document.getElementById('event-management-actions');
  const resultEl = document.getElementById('event-management-result');
  
  function updateUI() {
    // Update status display
    const statusBadge = statusEl.querySelector('.status-badge');
    const statusText = document.getElementById('event-status-text');
    
    statusBadge.className = `status-badge ${event.status}`;
    statusBadge.textContent = event.status.charAt(0).toUpperCase() + event.status.slice(1);
    
    const statusMessages = {
      'open': 'Trading is active',
      'closed': 'Trading has ended - awaiting resolution',
      'resolved': `Resolved: ${event.winning_side || event.winning_outcome_id || 'Unknown'}`
    };
    statusText.textContent = statusMessages[event.status] || '';
    
    // Update actions based on status and permissions
    let actionsHtml = '';
    
    if (event.status === 'open') {
      if (canManage) {
        actionsHtml = `
          <button class="btn-secondary btn-full" id="close-event-btn">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect>
              <line x1="9" y1="9" x2="15" y2="15"></line>
              <line x1="15" y1="9" x2="9" y2="15"></line>
            </svg>
            Close Trading
          </button>
          <p class="help-text">Stop all trading before resolving the event</p>
        `;
      } else {
        actionsHtml = `<p class="help-text">Trading is open. Only the creator or hosts can close trading.</p>`;
      }
    } else if (event.status === 'closed') {
      // Resolve buttons - only if user can resolve
      if (canResolve) {
        if (event.event_type === 'binary') {
          actionsHtml = `
            <p class="form-label">Select the winning outcome:</p>
            <div class="resolve-buttons">
              <button class="btn-resolve btn-resolve-yes" data-outcome="YES">
                ✓ YES wins
              </button>
              <button class="btn-resolve btn-resolve-no" data-outcome="NO">
                ✗ NO wins
              </button>
            </div>
          `;
        } else {
          // Multiple choice
          const outcomes = event.outcomes || [];
          actionsHtml = `
            <p class="form-label">Select the winning outcome:</p>
            <div class="resolve-outcomes-list">
              ${outcomes.map(o => `
                <button class="btn-resolve-outcome" data-outcome-id="${escapeHtmlAttr(o.id)}">
                  ✓ ${escapeHtml(o.label)}
                </button>
              `).join('')}
            </div>
          `;
        }
      }
      
      // Reopen button - only if user can manage
      if (canManage) {
        actionsHtml += `
          ${canResolve ? '<div class="divider-text"><span>or</span></div>' : ''}
          <button class="btn-secondary btn-full" id="reopen-event-btn">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <polyline points="1 4 1 10 7 10"></polyline>
              <path d="M3.51 15a9 9 0 1 0 2.13-9.36L1 10"></path>
            </svg>
            Reopen Trading
          </button>
        `;
      }
      
      // If user can only resolve (not manage), show info about reopen
      if (canResolve && !canManage) {
        actionsHtml += `<p class="help-text">To reopen trading, contact the event creator.</p>`;
      }
    } else if (event.status === 'resolved') {
      actionsHtml = `
        <div class="resolved-info">
          <div class="resolved-winner">
            🏆 Winner: <strong>${event.winning_side || event.winning_outcome_id || 'Unknown'}</strong>
          </div>
        </div>
      `;
    }
    
    actionsEl.innerHTML = actionsHtml;
    
    // Attach event handlers
    attachActionHandlers();
  }
  
  function attachActionHandlers() {
    // Close event button
    const closeBtn = document.getElementById('close-event-btn');
    if (closeBtn) {
      closeBtn.addEventListener('click', async () => {
        if (!confirm('Close trading for this event? No more bets will be accepted.')) return;
        await performAction('close');
      });
    }
    
    // Reopen event button
    const reopenBtn = document.getElementById('reopen-event-btn');
    if (reopenBtn) {
      reopenBtn.addEventListener('click', async () => {
        await performAction('reopen');
      });
    }
    
    // Binary resolve buttons
    const resolveButtons = actionsEl.querySelectorAll('.btn-resolve');
    resolveButtons.forEach(btn => {
      btn.addEventListener('click', async () => {
        const outcome = btn.dataset.outcome;
        if (!confirm(`Resolve this event as ${outcome}? This cannot be undone.`)) return;
        await performAction('resolve', { winning_side: outcome });
      });
    });
    
    // Multiple choice resolve buttons
    const outcomeButtons = actionsEl.querySelectorAll('.btn-resolve-outcome');
    outcomeButtons.forEach(btn => {
      btn.addEventListener('click', async () => {
        const outcomeId = btn.dataset.outcomeId;
        const label = btn.textContent.trim().replace('✓ ', '');
        if (!confirm(`Resolve this event with "${label}" winning? This cannot be undone.`)) return;
        await performAction('resolve', { winning_outcome_id: outcomeId });
      });
    });
  }
  
  async function performAction(action, extraData = {}) {
    resultEl.style.display = 'none';
    
    try {
      const payload = {
        action,
        event_id: event.id,
        ...extraData
      };
      
      // For resolve action, map to the expected format
      if (action === 'resolve' && extraData.winning_side) {
        payload.outcome = extraData.winning_side;
      } else if (action === 'resolve' && extraData.winning_outcome_id) {
        payload.outcome = extraData.winning_outcome_id;
      }
      
      const res = await fetch('api/resolution.php', {
        method: 'POST',
        credentials: 'same-origin',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': TYCHES_CSRF_TOKEN
        },
        body: JSON.stringify(payload)
      });
      
      const data = await res.json();
      
      if (!res.ok || data.error) {
        throw new Error(data.error || 'Action failed');
      }
      
      // Update local event state and refresh UI
      if (action === 'close') {
        event.status = 'closed';
        showToast('Trading closed successfully', 'success');
      } else if (action === 'reopen') {
        event.status = 'open';
        showToast('Trading reopened', 'success');
      } else if (action === 'resolve') {
        event.status = 'resolved';
        event.winning_side = extraData.winning_side;
        event.winning_outcome_id = extraData.winning_outcome_id;
        showToast('Event resolved! Winnings have been distributed.', 'success');
      }
      
      updateUI();
      
      // Refresh the page after a moment to show updated data
      setTimeout(() => window.location.reload(), 1500);
      
    } catch (err) {
      resultEl.textContent = err.message;
      resultEl.className = 'form-message error';
      resultEl.style.display = 'block';
    }
  }
  
  updateUI();
}

// --- Event Invite Section ---
function setupEventInviteSection(event) {
  const inviteSection = document.getElementById('invite-members-section');
  if (!inviteSection) return;
  
  // Only show for logged-in users who can invite (creator or market owner)
  // The can_invite flag is set by the server
  if (!event.can_invite) {
    inviteSection.style.display = 'none';
    return;
  }
  
  inviteSection.style.display = 'block';
  
  // Store event ID for later use
  inviteSection.dataset.eventId = event.id;
  
  const emailInput = document.getElementById('invite-email-input');
  const addEmailBtn = document.getElementById('add-email-btn');
  const emailsList = document.getElementById('invite-emails-list');
  const sendInvitesBtn = document.getElementById('send-invites-btn');
  const inviteResult = document.getElementById('invite-result');
  
  // Track emails to invite
  let emailsToInvite = [];
  
  // Add email chip
  function addEmailChip(email) {
    email = email.trim().toLowerCase();
    if (!email || !isValidEmail(email)) {
      showToast('Please enter a valid email address', 'error');
      return false;
    }
    if (emailsToInvite.includes(email)) {
      showToast('Email already added', 'error');
      return false;
    }
    
    emailsToInvite.push(email);
    
    const chip = document.createElement('div');
    chip.className = 'invite-email-chip';
    chip.innerHTML = `
      <span class="chip-email">${escapeHtml(email)}</span>
      <button type="button" class="chip-remove" title="Remove">×</button>
    `;
    
    chip.querySelector('.chip-remove').addEventListener('click', () => {
      emailsToInvite = emailsToInvite.filter(e => e !== email);
      chip.remove();
      updateSendButton();
    });
    
    emailsList.appendChild(chip);
    updateSendButton();
    return true;
  }
  
  function updateSendButton() {
    sendInvitesBtn.disabled = emailsToInvite.length === 0;
    sendInvitesBtn.textContent = emailsToInvite.length > 0 
      ? `Send ${emailsToInvite.length} Invitation${emailsToInvite.length > 1 ? 's' : ''}`
      : 'Send Invitations';
  }
  
  function isValidEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }
  
  // Handle add button click
  addEmailBtn.addEventListener('click', () => {
    if (addEmailChip(emailInput.value)) {
      emailInput.value = '';
      emailInput.focus();
    }
  });
  
  // Handle Enter key in email input
  emailInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      if (addEmailChip(emailInput.value)) {
        emailInput.value = '';
      }
    }
  });
  
  // Handle comma-separated or pasted emails
  emailInput.addEventListener('input', (e) => {
    const value = e.target.value;
    if (value.includes(',') || value.includes(' ')) {
      const emails = value.split(/[,\s]+/).filter(Boolean);
      let added = false;
      for (const email of emails) {
        if (isValidEmail(email)) {
          if (addEmailChip(email)) added = true;
        }
      }
      if (added) {
        emailInput.value = '';
      }
    }
  });
  
  // Handle send invites
  sendInvitesBtn.addEventListener('click', async () => {
    if (emailsToInvite.length === 0) return;
    
    sendInvitesBtn.disabled = true;
    sendInvitesBtn.textContent = 'Sending...';
    
    try {
      const res = await fetch('api/events.php', {
        method: 'POST',
        credentials: 'same-origin',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': TYCHES_CSRF_TOKEN
        },
        body: JSON.stringify({
          action: 'invite',
          event_id: event.id,
          emails: emailsToInvite
        })
      });
      
      const data = await res.json();
      
      if (res.ok && data.ok) {
        // Clear the list
        emailsToInvite = [];
        emailsList.innerHTML = '';
        updateSendButton();
        
        // Show success
        inviteResult.style.display = 'block';
        inviteResult.className = 'invite-result success';
        inviteResult.innerHTML = `
          <span class="result-icon">✓</span>
          <span class="result-text">${escapeHtml(data.message || 'Invitations sent!')}</span>
        `;
        
        showToast(data.message || 'Invitations sent!', 'success');
        
        // Reload members list - for private events, re-fetch event to get updated participants
        if (event.visibility === 'private') {
          // Re-fetch event data to get updated participants
          fetch(`api/events.php?id=${encodeURIComponent(event.id)}`, { credentials: 'same-origin' })
            .then(r => r.json())
            .then(d => {
              if (d.event) {
                loadEventMarketMembers(d.event.market_id, d.event);
              }
            })
            .catch(() => {});
        } else {
          loadEventMarketMembers(event.market_id, event);
        }
        
        // Hide result after 5 seconds
        setTimeout(() => {
          inviteResult.style.display = 'none';
        }, 5000);
      } else {
        throw new Error(data.error || 'Failed to send invitations');
      }
    } catch (err) {
      console.error('Invite error:', err);
      inviteResult.style.display = 'block';
      inviteResult.className = 'invite-result error';
      inviteResult.innerHTML = `
        <span class="result-icon">✕</span>
        <span class="result-text">${escapeHtml(err.message || 'Failed to send invitations')}</span>
      `;
      showToast(err.message || 'Failed to send invitations', 'error');
    } finally {
      updateSendButton();
    }
  });
}

// Load members/participants for the event
// For private events, show only participants; for public events, show all market members
async function loadEventMarketMembers(marketId, event = null) {
  const membersSection = document.getElementById('event-members-section');
  const membersList = document.getElementById('event-members-list');
  if (!membersSection || !membersList) return;
  
  try {
    let members = [];
    
    // For private events, use the participants list from the event data
    if (event && event.visibility === 'private' && event.participants) {
      members = event.participants.map(p => ({
        id: p.user_id,
        name: p.name,
        username: p.username,
        role: p.role // 'host' or 'participant'
      }));
    } else {
      // For public events, fetch all market members
      const res = await fetch(`api/markets.php?id=${encodeURIComponent(marketId)}`, {
        credentials: 'same-origin'
      });
      const data = await res.json();
      
      if (!res.ok || !data.members) {
        return;
      }
      members = data.members;
    }
    
    membersSection.style.display = 'block';
    
    if (members.length === 0) {
      membersList.innerHTML = '<div class="empty-members">No attendees yet</div>';
      return;
    }
    
    membersList.className = 'attendees-list-v2';
    membersList.innerHTML = members.map(member => {
      const name = member.name || member.username || '?';
      const initial = name.charAt(0).toUpperCase();
      const avatarColor = getAvatarColor(name);
      // Show crown for owner/host
      const badge = (member.role === 'owner' || member.role === 'host') ? '<span class="attendee-badge-v2">👑</span>' : '';
      return `
        <div class="attendee-pill-v2">
          <div class="attendee-avatar" style="background: ${avatarColor}">${initial}</div>
          ${escapeHtml(name)}
          ${badge}
        </div>
      `;
    }).join('');
  } catch (err) {
    console.error('Failed to load members:', err);
  }
}

// --- Event activity chart (bets over time with avatars) ---
async function loadEventActivityChart(eventId) {
  const container = document.getElementById('event-activity-chart');
  if (!container) return;

  container.innerHTML = `
    <div class="activity-chart-header">
      <span class="activity-chart-title">Recent trading</span>
      <span class="activity-chart-subtitle">How your friends have been betting</span>
    </div>
    <div class="activity-chart-empty">Loading activity…</div>
  `;

  try {
    const res = await fetch(`api/event-activity.php?event_id=${encodeURIComponent(eventId)}`, {
      credentials: 'same-origin',
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      console.error('[Tyches] event-activity error:', data);
      container.querySelector('.activity-chart-empty').textContent = 'Could not load activity.';
      return;
    }
    const bets = Array.isArray(data.bets) ? data.bets : [];
    if (bets.length === 0) {
      container.querySelector('.activity-chart-empty').textContent = 'No bets yet. Be the first to trade!';
      return;
    }

    renderEventActivityChart(container, bets);
  } catch (err) {
    console.error('[Tyches] event-activity network error:', err);
    const empty = container.querySelector('.activity-chart-empty');
    if (empty) {
      empty.textContent = 'Could not load activity.';
    }
  }
}

function renderEventActivityChart(container, bets) {
  // Clear previous content but keep container element
  container.innerHTML = `
    <div class="activity-chart-header">
      <span class="activity-chart-title">Recent trading</span>
      <span class="activity-chart-subtitle">Most tokens used in this event</span>
    </div>
    <div class="activity-chart-bars"></div>
  `;

  const barsEl = container.querySelector('.activity-chart-bars');
  if (!barsEl) return;

  // Aggregate total notional per user so we can show a simple
  // "top traders" bar chart.
  const byUser = new Map();
  bets.forEach(bet => {
    const rawNotional = typeof bet.notional === 'number'
      ? bet.notional
      : parseFloat(bet.notional || '0');
    const notional = isNaN(rawNotional) ? 0 : rawNotional;
    if (notional <= 0) return;

    const name = bet.user_name || bet.user_username || '';
    const initial = (bet.user_initial || (name || '?')).toString().trim().charAt(0).toUpperCase() || '?';
    const key = name || initial;

    const existing = byUser.get(key) || { name, initial, total: 0 };
    existing.total += notional;
    byUser.set(key, existing);
  });

  const users = Array.from(byUser.values());
  // If there are no meaningful trades, show a small inline hint.
  if (users.length === 0) {
    container.innerHTML = '';
    const empty = document.createElement('div');
    empty.className = 'activity-chart-empty';
    empty.textContent = 'No bets yet.';
    container.appendChild(empty);
    return;
  }

  // Sort by total notional descending and show top N.
  users.sort((a, b) => b.total - a.total);
  const topUsers = users.slice(0, 5);
  const maxTotal = topUsers[0].total || 1;

  topUsers.forEach(u => {
    const pct = Math.max(15, (u.total / maxTotal) * 100); // ensure visible minimum height
    const tokenLabel = u.total >= 100
      ? u.total.toFixed(0)
      : u.total.toFixed(1);

    const bar = document.createElement('div');
    bar.className = 'activity-bar';
    bar.innerHTML = `
      <div class="activity-bar-value">${escapeHtml(tokenLabel)}</div>
      <div class="activity-bar-avatar">${escapeHtml(u.initial)}</div>
      <div class="activity-bar-column">
        <div class="activity-bar-fill" style="height:${pct}%"></div>
      </div>
      <div class="activity-bar-label">${escapeHtml(u.name || '')}</div>
    `;
    barsEl.appendChild(bar);
  });
}

function renderTradeCard(container, ev) {
  container.innerHTML = '';
  container.className = 'outcomes-card-v2';
  
  // Store event data for betting
  container.dataset.eventId = ev.id;
  container.dataset.eventType = ev.event_type;
  
  let outcomesHtml = '';
  let selectedOutcome = null;
  let selectedLabel = '';
  let selectedProb = 50;
  
  // Use dynamic pool data for real odds (falls back to initial values if not available)
  const pools = ev.pools || {};
  
  if (ev.event_type === 'binary') {
    // Use pool data for dynamic odds, fallback to initial values
    const yes = pools.yes_percent ?? ev.yes_percent ?? 50;
    const no = pools.no_percent ?? ev.no_percent ?? 50;
    const yesPool = pools.yes_pool ?? 0;
    const noPool = pools.no_pool ?? 0;
    
    // Get bettors for each side (if available)
    const yesBettors = ev.yes_bettors || [];
    const noBettors = ev.no_bettors || [];
    
    // Sort by probability - highest first
    const options = [
      { side: 'YES', label: 'Yes ✓', prob: yes, bettors: yesBettors, type: 'yes', pool: yesPool },
      { side: 'NO', label: 'No ✗', prob: no, bettors: noBettors, type: 'no', pool: noPool }
    ].sort((a, b) => b.prob - a.prob);
    
    // Select the highest probability option by default
    selectedOutcome = options[0].side;
    selectedLabel = options[0].label.replace(' ✓', '').replace(' ✗', '');
    selectedProb = options[0].prob;
    
    outcomesHtml = options.map((opt, idx) => `
      <div class="outcome-card-v2 ${idx === 0 ? 'selected' : ''}" data-outcome-type="${opt.type}" data-side="${opt.side}" data-prob="${opt.prob}">
        <div class="outcome-fill-v2" style="width: ${opt.prob}%"></div>
        <div class="outcome-content-v2">
          <div class="outcome-info-v2">
            <div class="outcome-name-v2">${opt.label}</div>
            <div class="outcome-bettors-v2">
              ${renderBettorAvatars(opt.bettors, opt.type, opt.pool)}
            </div>
          </div>
          <div class="outcome-odds-v2">
            <div class="odds-percent-v2">${opt.prob}%</div>
          </div>
        </div>
      </div>
    `).join('');
  } else {
    // Multi-choice: merge pool data with outcomes for dynamic percentages
    let outcomes = ev.outcomes || [];
    
    // If we have pool outcome data, use those percentages
    if (pools.outcomes && pools.outcomes.length > 0) {
      // Create a map of pool data by outcome ID
      const poolMap = {};
      pools.outcomes.forEach(p => {
        poolMap[p.id] = p;
      });
      
      // Update outcomes with pool data
      outcomes = outcomes.map(o => {
        const poolData = poolMap[o.id];
        return {
          ...o,
          probability: poolData?.percent ?? o.probability ?? 0,
          pool: poolData?.pool ?? 0,
          odds: poolData?.odds ?? 1
        };
      });
    }
    
    // Sort outcomes by probability (highest first)
    outcomes = outcomes.sort((a, b) => (b.probability || 0) - (a.probability || 0));
    
    if (outcomes.length > 0) {
      selectedOutcome = outcomes[0].id;
      selectedLabel = outcomes[0].label;
      selectedProb = outcomes[0].probability || 50;
    }
    
    outcomesHtml = outcomes.map((o, idx) => {
      const bettors = o.bettors || [];
      // Color coding: first=green (leading), others vary
      const outcomeType = idx === 0 ? 'yes' : (idx === 1 ? 'no' : 'other');
      const prob = o.probability || 0;
      const pool = o.pool || 0;
      return `
        <div class="outcome-card-v2 ${idx === 0 ? 'selected' : ''}" data-outcome-type="${outcomeType}" data-outcome-id="${o.id}" data-prob="${prob}">
          <div class="outcome-fill-v2" style="width: ${prob}%"></div>
          <div class="outcome-content-v2">
            <div class="outcome-info-v2">
              <div class="outcome-name-v2">${escapeHtml(o.label)}</div>
              <div class="outcome-bettors-v2">
                ${renderBettorAvatars(bettors, outcomeType, pool)}
              </div>
            </div>
            <div class="outcome-odds-v2">
              <div class="odds-percent-v2">${prob}%</div>
            </div>
          </div>
        </div>
      `;
    }).join('');
  }
  
  // Build the full card with inline betting
  container.innerHTML = `
    <h2 class="section-title">Pick your prediction</h2>
    <div class="outcomes-list-v2">
      ${outcomesHtml}
    </div>
    <div class="bet-section-v2">
      <div class="bet-row-v2">
        <span class="bet-label-v2">Bet on <strong id="bet-selection-label">${escapeHtml(selectedLabel)}</strong></span>
        <div class="bet-input-wrap-v2">
          <span>🪙</span>
          <input type="number" class="bet-input-v2" id="bet-amount-input" value="100" min="1">
        </div>
        <span class="bet-return-v2">→ Win <strong id="bet-return-value">${Math.round(100 * 100 / selectedProb)}</strong></span>
        <button class="bet-btn-v2" id="place-bet-btn">Place Bet</button>
      </div>
    </div>
  `;
  
  // Store current selection (use the selected outcome from sorted order)
  let currentSelection = { 
    side: ev.event_type === 'binary' ? selectedOutcome : null, 
    outcomeId: ev.event_type === 'binary' ? null : selectedOutcome, 
    prob: selectedProb 
  };
  
  // Add click handlers to outcome cards
  container.querySelectorAll('.outcome-card-v2').forEach(card => {
    card.addEventListener('click', () => {
      // Update selection UI
      container.querySelectorAll('.outcome-card-v2').forEach(c => c.classList.remove('selected'));
      card.classList.add('selected');
      
      // Update betting label and calculate return
      const prob = parseInt(card.dataset.prob) || 50;
      const label = card.querySelector('.outcome-name-v2').textContent;
      document.getElementById('bet-selection-label').textContent = label;
      
      // Store selection
      if (ev.event_type === 'binary') {
        currentSelection = { side: card.dataset.side, outcomeId: null, prob };
      } else {
        currentSelection = { side: null, outcomeId: card.dataset.outcomeId, prob };
      }
      
      updateBetReturn();
    });
  });
  
  // Update return calculation on input
  const amountInput = document.getElementById('bet-amount-input');
  if (amountInput) {
    amountInput.addEventListener('input', updateBetReturn);
  }
  
  function updateBetReturn() {
    const amount = parseInt(document.getElementById('bet-amount-input').value) || 0;
    const prob = currentSelection.prob || 50;
    const returns = Math.round(amount * 100 / prob);
    document.getElementById('bet-return-value').textContent = returns;
  }
  
  // Place bet button
  const betBtn = document.getElementById('place-bet-btn');
  if (betBtn) {
    betBtn.addEventListener('click', () => {
      const amount = parseInt(document.getElementById('bet-amount-input').value) || 0;
      if (amount <= 0) {
        showToast('Please enter a valid amount', 'error');
        return;
      }
      // Use existing trade prompt for confirmation or place directly
      openTradePrompt(ev, currentSelection.side, currentSelection.outcomeId, amount);
    });
  }
}

// Helper function to render bettor avatars or pool info
function renderBettorAvatars(bettors, type, poolAmount = 0) {
  // If we have pool amount but no bettor details, show the pool
  if ((!bettors || bettors.length === 0) && poolAmount > 0) {
    return `<span class="bettor-text-v2">${formatNumber(poolAmount)} tokens</span>`;
  }
  
  if (!bettors || bettors.length === 0) {
    return '<span class="bettor-text-v2">No bets yet</span>';
  }
  
  const colors = {
    yes: '#10b981',
    no: '#f87171',
    other: '#fbbf24'
  };
  const bgColor = colors[type] || '#7c3aed';
  
  const avatarsHtml = bettors.slice(0, 3).map(b => {
    const initial = (b.name || b.username || '?').charAt(0).toUpperCase();
    return `<div class="bettor-avatar" style="background: ${bgColor}">${initial}</div>`;
  }).join('');
  
  const remaining = bettors.length - 3;
  const countText = remaining > 0 ? `+${remaining} more` : `${bettors.length} betting`;
  
  return `${avatarsHtml}<span class="bettor-text-v2">${countText}</span>`;
}

function openTradePrompt(ev, side, outcomeId, prefillAmount = null) {
  // Remove any existing trade modal
  const existingModal = document.getElementById('trade-modal');
  if (existingModal) existingModal.remove();
  
  // Determine outcome label
  let outcomeLabel = '';
  if (ev.event_type === 'binary') {
    outcomeLabel = side;
  } else {
    const outcome = (ev.outcomes || []).find(o => o.id === outcomeId);
    if (outcome) {
      outcomeLabel = outcome.label;
    }
  }
  
  // Use prefilled amount if provided
  const defaultAmount = prefillAmount || 100;
  
  const modal = document.createElement('div');
  modal.id = 'trade-modal';
  modal.className = 'modal-backdrop';
  modal.innerHTML = `
    <div class="modal trade-modal">
      <button class="modal-close" id="trade-modal-close">&times;</button>
      <div class="modal-header">
        <h2>Place a Bet</h2>
      </div>
      <div class="modal-body">
        <div class="trade-modal-event">
          <div class="trade-modal-title">${escapeHtml(ev.title)}</div>
          <div class="trade-modal-outcome ${ev.event_type === 'binary' ? (side === 'YES' ? 'yes' : 'no') : 'multiple'}">
            ${escapeHtml(outcomeLabel)}
          </div>
        </div>
        <form id="trade-form" class="trade-form">
          <div class="form-group">
            <label for="trade-amount">Bet amount (tokens)</label>
            <input type="number" id="trade-amount" min="1" value="${defaultAmount}" required>
          </div>
          
          <div id="pool-info" class="pool-info" style="margin: 1rem 0; padding: 1rem; background: var(--bg-secondary); border-radius: 8px;">
            <div style="text-align: center; color: var(--text-tertiary);">Loading pool data...</div>
          </div>
          
          <div class="trade-summary">
            <div class="trade-summary-row">
              <span>Your bet:</span>
              <span id="trade-total">100 tokens</span>
            </div>
            <div class="trade-summary-row">
              <span>Current odds:</span>
              <span id="trade-odds">--</span>
            </div>
            <div class="trade-summary-row">
              <span>Potential payout if ${escapeHtml(outcomeLabel)} wins:</span>
              <span id="trade-payout" class="text-success">--</span>
            </div>
            <div class="trade-summary-row">
              <span>Potential profit:</span>
              <span id="trade-profit" class="text-success">--</span>
            </div>
          </div>
          
          <div id="pool-warning" class="form-hint" style="display:none; background: #fef3c7; color: #92400e; padding: 0.75rem; border-radius: 6px; margin-top: 0.5rem;">
            ⚠️ <strong>Low liquidity:</strong> Profits depend on others betting against you. If no one else bets, you only get your tokens back.
          </div>
          
          <div id="trade-error" class="form-error" style="display:none;"></div>
          <div class="trade-actions-modal">
            <button type="button" class="btn-secondary" id="trade-cancel">Cancel</button>
            <button type="submit" class="btn-primary" id="trade-submit">Place Bet</button>
          </div>
        </form>
      </div>
    </div>
  `;
  
  document.body.appendChild(modal);
  
  const amountInput = modal.querySelector('#trade-amount');
  const totalEl = modal.querySelector('#trade-total');
  const oddsEl = modal.querySelector('#trade-odds');
  const payoutEl = modal.querySelector('#trade-payout');
  const profitEl = modal.querySelector('#trade-profit');
  const poolInfoEl = modal.querySelector('#pool-info');
  const poolWarningEl = modal.querySelector('#pool-warning');
  
  // Store pool data for calculations
  let poolData = null;
  
  // Fetch current pool data
  async function fetchPoolData() {
    try {
      const res = await fetch(`api/odds.php?event_id=${ev.id}`, { credentials: 'same-origin' });
      const data = await res.json();
      if (res.ok && data.odds) {
        poolData = data.odds;
        renderPoolInfo();
        updateCalc();
      } else {
        poolInfoEl.innerHTML = '<div style="color: var(--text-tertiary);">Could not load pool data</div>';
      }
    } catch {
      poolInfoEl.innerHTML = '<div style="color: var(--text-tertiary);">Could not load pool data</div>';
    }
  }
  
  function renderPoolInfo() {
    if (!poolData) return;
    
    if (ev.event_type === 'binary') {
      const yesPool = poolData.yes_pool || 0;
      const noPool = poolData.no_pool || 0;
      const totalPool = yesPool + noPool;
      
      poolInfoEl.innerHTML = `
        <div style="font-size: 0.85rem; font-weight: 600; margin-bottom: 0.5rem;">Current Pool Sizes</div>
        <div style="display: flex; justify-content: space-between; margin-bottom: 0.5rem;">
          <span>YES Pool:</span>
          <span style="font-weight: 600; color: var(--success);">${yesPool.toLocaleString()} tokens</span>
        </div>
        <div style="display: flex; justify-content: space-between; margin-bottom: 0.5rem;">
          <span>NO Pool:</span>
          <span style="font-weight: 600; color: var(--danger);">${noPool.toLocaleString()} tokens</span>
        </div>
        <div style="display: flex; justify-content: space-between; border-top: 1px solid var(--border-light); padding-top: 0.5rem;">
          <span>Total Pool:</span>
          <span style="font-weight: 700;">${totalPool.toLocaleString()} tokens</span>
        </div>
      `;
    } else if (poolData.outcomes) {
      let html = '<div style="font-size: 0.85rem; font-weight: 600; margin-bottom: 0.5rem;">Current Pool Sizes</div>';
      poolData.outcomes.forEach(o => {
        html += `
          <div style="display: flex; justify-content: space-between; margin-bottom: 0.25rem;">
            <span>${escapeHtml(o.label)}:</span>
            <span style="font-weight: 600;">${(o.pool || 0).toLocaleString()} tokens</span>
          </div>
        `;
      });
      html += `
        <div style="display: flex; justify-content: space-between; border-top: 1px solid var(--border-light); padding-top: 0.5rem; margin-top: 0.5rem;">
          <span>Total Pool:</span>
          <span style="font-weight: 700;">${(poolData.total_pool || 0).toLocaleString()} tokens</span>
        </div>
      `;
      poolInfoEl.innerHTML = html;
    }
  }
  
  function updateCalc() {
    const amount = parseInt(amountInput.value) || 0;
    totalEl.textContent = amount.toLocaleString() + ' tokens';
    
    if (!poolData) {
      oddsEl.textContent = '--';
      payoutEl.textContent = '--';
      profitEl.textContent = '--';
      return;
    }
    
    // Calculate parimutuel payout
    // After your bet: your_side_pool + your_bet, total_pool + your_bet
    // Your share = your_bet / (your_side_pool + your_bet)
    // Your payout = your_share * (total_pool + your_bet)
    
    let yourSidePool, totalPool;
    
    if (ev.event_type === 'binary') {
      yourSidePool = side === 'YES' ? (poolData.yes_pool || 0) : (poolData.no_pool || 0);
      totalPool = (poolData.yes_pool || 0) + (poolData.no_pool || 0);
    } else {
      const outcome = (poolData.outcomes || []).find(o => o.id === outcomeId);
      yourSidePool = outcome ? (outcome.pool || 0) : 0;
      totalPool = poolData.total_pool || 0;
    }
    
    // After bet
    const newYourSidePool = yourSidePool + amount;
    const newTotalPool = totalPool + amount;
    
    // Your share and payout
    const yourShare = amount / newYourSidePool;
    const potentialPayout = yourShare * newTotalPool;
    const potentialProfit = potentialPayout - amount;
    
    // Implied odds (multiplier)
    const odds = newTotalPool / newYourSidePool;
    
    oddsEl.textContent = odds.toFixed(2) + 'x';
    payoutEl.textContent = Math.floor(potentialPayout).toLocaleString() + ' tokens';
    profitEl.textContent = (potentialProfit >= 0 ? '+' : '') + Math.floor(potentialProfit).toLocaleString() + ' tokens';
    
    // Color profit based on sign
    profitEl.style.color = potentialProfit > 0 ? 'var(--success)' : 'var(--text-secondary)';
    
    // Show warning if low liquidity (only you or nearly only you)
    const opposingPool = totalPool - yourSidePool;
    if (opposingPool < amount * 0.1 || totalPool < 100) {
      poolWarningEl.style.display = 'block';
    } else {
      poolWarningEl.style.display = 'none';
    }
  }
  
  amountInput.addEventListener('input', updateCalc);
  
  // Fetch pool data immediately
  fetchPoolData();
  
  // Close handlers
  const closeModal = () => modal.remove();
  modal.querySelector('#trade-modal-close').addEventListener('click', closeModal);
  modal.querySelector('#trade-cancel').addEventListener('click', closeModal);
  modal.addEventListener('click', (e) => {
    if (e.target === modal) closeModal();
  });
  
  // Submit handler
  const form = modal.querySelector('#trade-form');
  const errorEl = modal.querySelector('#trade-error');
  const submitBtn = modal.querySelector('#trade-submit');
  
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    errorEl.style.display = 'none';
    
    const amount = parseInt(amountInput.value) || 0;
    
    if (amount <= 0) {
      errorEl.textContent = 'Please enter a valid bet amount.';
      errorEl.style.display = 'block';
      return;
    }
    
    // Disable button
    submitBtn.disabled = true;
    submitBtn.textContent = 'Placing bet...';
    
    const payload = { event_id: ev.id, amount };
    if (ev.event_type === 'binary') {
      payload.side = side || 'YES';
    } else {
      payload.outcome_id = outcomeId;
    }
    
    try {
      const res = await fetch('api/bets.php', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': TYCHES_CSRF_TOKEN,
        },
        credentials: 'same-origin',
        body: JSON.stringify(payload),
      });
      const data = await res.json();
      
      if (!res.ok) {
        // Check if verification is required
        if (handleApiError(data, res)) {
          closeModal();
          return;
        }
        errorEl.textContent = data.error || 'Bet failed.';
        errorEl.style.display = 'block';
        submitBtn.disabled = false;
        submitBtn.textContent = 'Place Bet';
        return;
      }
      
      // Success - show toast and reload
      closeModal();
      showToast(`Bet placed! Potential payout: ${Math.floor(data.potential_return || 0)} tokens`, 'success');
      setTimeout(() => window.location.reload(), 1200);
    } catch {
      errorEl.textContent = 'Network error. Please try again.';
      errorEl.style.display = 'block';
      submitBtn.disabled = false;
      submitBtn.textContent = 'Place Bet';
    }
  });
}

// Toast notification
function showToast(message, type = 'info') {
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
}

// --- Gossip ---
// Track if gossip submit handler is already bound
let gossipHandlerBound = false;

async function loadGossip(eventId) {
  const listEl = document.getElementById('gossip-list');
  const compose = document.getElementById('gossip-compose');
  const loggedIn = document.body.dataset.loggedIn === '1';
  if (compose && loggedIn) compose.style.display = '';

  try {
    const res = await fetch(`api/gossip.php?event_id=${encodeURIComponent(eventId)}`, {
      credentials: 'same-origin'
    });
    const data = await res.json();
    if (!listEl) return;
    listEl.innerHTML = '';
    listEl.className = 'gossip-list-v2';
    const messages = data.messages || [];
    
    if (messages.length === 0) {
      listEl.innerHTML = `
        <div class="gossip-empty-v2">
          <div class="gossip-empty-icon-v2">💬</div>
          <p class="gossip-empty-text-v2">No gossip yet.<br>Be the first to drop a spicy take!</p>
        </div>
      `;
    } else {
      messages.forEach((msg) => {
        const item = document.createElement('div');
        item.className = 'gossip-item-v2';
        const name = msg.user_name || msg.user_username || 'User';
        const initial = name.trim().charAt(0).toUpperCase();
        const timeAgo = formatRelativeTime(msg.created_at);
        
        // Generate avatar color based on name
        const avatarColor = getAvatarColor(name);
        
        // Build bet tag if user has a bet on this event
        let betTagHtml = '';
        if (msg.user_bet_amount && msg.user_bet_side) {
          betTagHtml = `<span class="gossip-bet-tag-v2">🪙 Bet ${formatNumber(msg.user_bet_amount)} on ${escapeHtml(msg.user_bet_side)}</span>`;
        }
        
        item.innerHTML = `
          <div class="gossip-avatar-v2" style="background: ${avatarColor}">${initial}</div>
          <div class="gossip-body-v2">
            <div class="gossip-meta-v2">
              <span class="gossip-author-v2">${escapeHtml(name)}</span>
              <span class="gossip-time-v2">${timeAgo}</span>
            </div>
            <p class="gossip-text-v2">${escapeHtml(msg.message)}</p>
            ${betTagHtml}
          </div>
        `;
        listEl.appendChild(item);
      });
    }
  } catch {
    if (listEl) {
      listEl.innerHTML = '<div class="gossip-empty-v2"><div class="gossip-empty-text-v2">Could not load gossip.</div></div>';
    }
  }

  // Only bind the submit handler ONCE
  if (!gossipHandlerBound) {
    const submitBtn = document.getElementById('gossip-submit');
    const msgInput = document.getElementById('gossip-message');
    if (submitBtn && msgInput) {
      gossipHandlerBound = true;
      submitBtn.addEventListener('click', async () => {
        const message = msgInput.value.trim();
        if (!message) return;
        
        // Disable button to prevent double-clicks
        submitBtn.disabled = true;
        submitBtn.textContent = 'Posting...';
        
        try {
          const res = await fetch('api/gossip.php', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'X-CSRF-Token': TYCHES_CSRF_TOKEN,
            },
            credentials: 'same-origin',
            body: JSON.stringify({ event_id: eventId, message }),
          });
          const data = await res.json().catch(() => ({}));
          if (!res.ok) {
            showToast(data.error || 'Could not post.', 'error');
            return;
          }
          msgInput.value = '';
          showToast('Comment posted!', 'success');
          loadGossip(eventId);
        } catch {
          showToast('Network error.', 'error');
        } finally {
          submitBtn.disabled = false;
          submitBtn.textContent = 'Post';
        }
      });
    }
  }
}

// Generate consistent avatar color based on name
function getAvatarColor(name) {
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
}

// Format relative time
function formatRelativeTime(dateStr) {
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
}

// --- Utilities ---
function escapeHtml(str) {
  return String(str || '').replace(/[&<>"']/g, s => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[s]));
}

function escapeHtmlAttr(str) {
  return escapeHtml(str).replace(/"/g, '&quot;');
}




