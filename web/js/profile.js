// js/profile.js
// Profile page: user info, friends, bets, password change

import { get, post, clearCache } from './api.js';
import { 
  showToast, escapeHtml, formatDate, formatRelativeTime, 
  showSkeleton, $, debounce 
} from './ui.js';
import { getUser } from './auth.js';

// ============================================
// PROFILE INITIALIZATION
// ============================================

export async function hydrateProfile(profileData = null) {
  const headerEl = $('#profile-header');
  
  // If no data provided, fetch it
  if (!profileData) {
    const result = await get('profile.php');
    if (!result.ok) {
      if (headerEl) {
        headerEl.innerHTML = `
          <div class="empty-state">
            <div class="empty-state-icon">⚠️</div>
            <div class="empty-state-text">Could not load profile</div>
          </div>
        `;
      }
      return;
    }
    profileData = result.data;
  }
  
  // Render header
  renderProfileHeader(headerEl, profileData.user);
  
  // Render markets
  renderProfileMarkets(profileData.markets);
  
  // Render events
  renderProfileEvents(profileData.events_created);
  
  // Render bets
  renderProfileBets(profileData.bets);
  
  // Setup friends UI
  setupFriendsUI(profileData.friends);
  
  // Setup password form
  setupPasswordForm();
}

// ============================================
// PROFILE HEADER
// ============================================

function renderProfileHeader(container, user) {
  if (!container || !user) return;
  
  const initial = (user.name || user.username || '?').charAt(0).toUpperCase();
  const friendsCount = 0; // Will be updated by friends section
  const memberSince = user.created_at 
    ? new Date(user.created_at).toLocaleDateString('en-US', { month: 'short', year: 'numeric' })
    : '';
  
  const tokens = parseFloat(user.tokens_balance || 0);
  const tokensLabel = tokens.toFixed(2);
  
  container.innerHTML = `
    <div class="profile-avatar">${escapeHtml(initial)}</div>
    <div class="profile-meta">
      <div class="profile-name">${escapeHtml(user.name || '')}</div>
      <div class="profile-username">@${escapeHtml(user.username || '')}</div>
      <div class="profile-email">${escapeHtml(user.email || '')}</div>
      <div class="profile-stats">
        <span id="profile-friends-count">👥 0 friends</span>
        <span style="margin-left:1rem;">🪙 ${tokensLabel} tokens</span>
        ${memberSince ? `<span style="margin-left:1rem;">📅 Member since ${memberSince}</span>` : ''}
      </div>
    </div>
  `;
}

// ============================================
// MARKETS SECTION
// ============================================

function renderProfileMarkets(markets = []) {
  const container = $('#profile-markets');
  if (!container) return;
  
  container.innerHTML = '';
  
  if (markets.length === 0) {
    container.innerHTML = `
      <div class="empty-state">
        <div class="empty-state-icon">🎯</div>
        <div class="empty-state-text">No markets yet</div>
      </div>
    `;
    return;
  }
  
  for (const market of markets) {
    const card = document.createElement('div');
    card.className = 'market-card';
    card.innerHTML = `
      <div class="market-header">
        <div class="market-creator">
          <div class="creator-avatar">${escapeHtml(market.avatar_emoji || '🎯')}</div>
          <div>
            <div class="creator-name">${escapeHtml(market.name)}</div>
            <div class="market-meta">${market.members_count || 0} members · ${market.events_count || 0} events</div>
          </div>
        </div>
        ${market.role === 'owner' ? '<span class="role-badge">Owner</span>' : ''}
      </div>
      <div class="market-footer">
        <div class="market-volume"></div>
        <button class="btn-market btn-small">Open</button>
      </div>
    `;
    
    card.querySelector('.btn-market').addEventListener('click', () => {
      window.location.href = `market.php?id=${market.id}`;
    });
    
    container.appendChild(card);
  }
}

// ============================================
// EVENTS SECTION
// ============================================

function renderProfileEvents(events = []) {
  const container = $('#profile-events');
  if (!container) return;
  
  container.innerHTML = '';
  
  if (events.length === 0) {
    container.innerHTML = `
      <div class="empty-state">
        <div class="empty-state-icon">📅</div>
        <div class="empty-state-text">No events created yet</div>
      </div>
    `;
    return;
  }
  
  for (const event of events) {
    const row = document.createElement('div');
    row.className = 'event-row';
    row.innerHTML = `
      <div class="event-row-main">
        <div class="event-row-title">${escapeHtml(event.title)}</div>
        <div class="event-row-meta">
          ${escapeHtml(event.market_name || '')} · 
          <span class="status-badge ${event.status}">${escapeHtml(event.status)}</span> · 
          closes ${formatDate(event.closes_at)}
        </div>
      </div>
      <button class="btn-secondary btn-small">Open</button>
    `;
    
    row.querySelector('button').addEventListener('click', () => {
      window.location.href = `event.php?id=${event.id}`;
    });
    
    container.appendChild(row);
  }
}

// ============================================
// BETS SECTION
// ============================================

function renderProfileBets(bets = []) {
  const container = $('#profile-bets');
  if (!container) return;
  
  container.innerHTML = '';
  
  if (bets.length === 0) {
    container.innerHTML = `
      <div class="empty-state">
        <div class="empty-state-icon">💰</div>
        <div class="empty-state-text">No bets placed yet</div>
      </div>
    `;
    return;
  }
  
  for (const bet of bets) {
    const row = document.createElement('div');
    row.className = 'event-row';
    
    const side = bet.side || bet.outcome_id || '';
    const sideClass = side === 'YES' ? 'yes' : (side === 'NO' ? 'no' : '');
    
    row.innerHTML = `
      <div class="event-row-main">
        <div class="event-row-title">${escapeHtml(bet.event_title || 'Event')}</div>
        <div class="event-row-meta">
          ${escapeHtml(bet.market_name || '')} · 
          <strong class="bet-side ${sideClass}">${escapeHtml(side)}</strong> · 
          ${bet.shares} shares @ ${bet.price}¢
        </div>
      </div>
      <div class="bet-notional">$${parseFloat(bet.notional || 0).toFixed(2)}</div>
    `;
    
    container.appendChild(row);
  }
}

// ============================================
// FRIENDS SECTION
// ============================================

function setupFriendsUI(initialFriends = []) {
  const searchBtn = $('#friends-search-btn');
  const searchInput = $('#friends-search-input');
  const listEl = $('#friends-list');
  const reqEl = $('#friends-requests');
  const searchResultsEl = $('#friends-search-results');
  
  // Update friends count
  const acceptedCount = initialFriends.filter(f => f.status === 'accepted').length;
  const countEl = $('#profile-friends-count');
  if (countEl) {
    countEl.textContent = `👥 ${acceptedCount} friends`;
  }
  
  // Render initial friends
  renderFriendsList(listEl, initialFriends.filter(f => f.status === 'accepted'));
  renderFriendsRequests(reqEl, initialFriends.filter(f => f.status === 'pending'));
  
  // Search functionality
  const doSearch = debounce(async (query) => {
    if (!query) {
      if (searchResultsEl) searchResultsEl.innerHTML = '';
      return;
    }
    
    const result = await get(`friends.php?q=${encodeURIComponent(query)}`);
    
    if (!result.ok) {
      showToast(result.error || 'Could not search', 'error');
      return;
    }
    
    renderSearchResults(searchResultsEl, result.data.search || []);
  }, 300);
  
  searchBtn?.addEventListener('click', () => {
    doSearch(searchInput?.value.trim() || '');
  });
  
  searchInput?.addEventListener('input', (e) => {
    doSearch(e.target.value.trim());
  });
  
  searchInput?.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      doSearch(searchInput.value.trim());
    }
  });
}

function renderFriendsList(container, friends) {
  if (!container) return;
  
  container.innerHTML = '';
  
  if (friends.length === 0) {
    container.innerHTML = `
      <div class="empty-state">
        <div class="empty-state-text">No friends yet. Search to add some!</div>
      </div>
    `;
    return;
  }
  
  for (const friend of friends) {
    const initial = (friend.name || friend.username).charAt(0).toUpperCase();
    
    const item = document.createElement('div');
    item.className = 'friend-row';
    item.innerHTML = `
      <div class="friend-main">
        <div class="friend-avatar">${escapeHtml(initial)}</div>
        <div>
          <div class="friend-name">${escapeHtml(friend.name)}</div>
          <div class="friend-username">@${escapeHtml(friend.username)}</div>
        </div>
      </div>
      <button class="btn-secondary btn-small" data-action="unfriend" data-id="${friend.id}">Unfriend</button>
    `;
    
    item.querySelector('button').addEventListener('click', () => {
      mutateFriend('unfriend', friend.id);
    });
    
    container.appendChild(item);
  }
}

function renderFriendsRequests(container, requests) {
  if (!container) return;
  
  container.innerHTML = '';
  
  if (requests.length === 0) {
    return; // Hide empty requests section
  }
  
  const title = document.createElement('div');
  title.className = 'section-subtitle';
  title.textContent = 'Friend Requests';
  container.appendChild(title);
  
  for (const req of requests) {
    const initial = (req.name || req.username).charAt(0).toUpperCase();
    
    const item = document.createElement('div');
    item.className = 'friend-row';
    item.innerHTML = `
      <div class="friend-main">
        <div class="friend-avatar">${escapeHtml(initial)}</div>
        <div>
          <div class="friend-name">${escapeHtml(req.name)}</div>
          <div class="friend-username">@${escapeHtml(req.username)}</div>
        </div>
      </div>
      <div class="friend-actions">
        <button class="btn-primary btn-small" data-action="accept" data-id="${req.id}">Accept</button>
        <button class="btn-secondary btn-small" data-action="decline" data-id="${req.id}">Decline</button>
      </div>
    `;
    
    item.querySelectorAll('button').forEach(btn => {
      btn.addEventListener('click', () => {
        mutateFriend(btn.dataset.action, parseInt(btn.dataset.id, 10));
      });
    });
    
    container.appendChild(item);
  }
}

function renderSearchResults(container, users) {
  if (!container) return;
  
  container.innerHTML = '';
  
  if (users.length === 0) {
    container.innerHTML = `
      <div class="empty-state">
        <div class="empty-state-text">No users found</div>
      </div>
    `;
    return;
  }
  
  const title = document.createElement('div');
  title.className = 'section-subtitle';
  title.textContent = 'Search Results';
  container.appendChild(title);
  
  for (const user of users) {
    const initial = (user.name || user.username).charAt(0).toUpperCase();
    
    const item = document.createElement('div');
    item.className = 'friend-row';
    item.innerHTML = `
      <div class="friend-main">
        <div class="friend-avatar">${escapeHtml(initial)}</div>
        <div>
          <div class="friend-name">${escapeHtml(user.name)}</div>
          <div class="friend-username">@${escapeHtml(user.username)}</div>
        </div>
      </div>
      <button class="btn-primary btn-small" data-id="${user.id}">Add Friend</button>
    `;
    
    item.querySelector('button').addEventListener('click', async (e) => {
      const btn = e.target;
      btn.disabled = true;
      btn.textContent = 'Sending...';
      
      try {
        await mutateFriend('send_request', user.id);
        btn.textContent = 'Sent!';
      } catch {
        btn.disabled = false;
        btn.textContent = 'Add Friend';
      }
    });
    
    container.appendChild(item);
  }
}

async function mutateFriend(action, userId) {
  const result = await post('friends.php', { action, user_id: userId });
  
  if (!result.ok) {
    showToast(result.error || 'Could not update friends.', 'error');
    throw new Error(result.error);
  }
  
  const messages = {
    send_request: 'Friend request sent!',
    accept: 'Friend request accepted.',
    decline: 'Request declined.',
    unfriend: 'Friend removed.',
  };
  
  showToast(messages[action] || 'Done!', 'success');
  
  // Clear cache and refresh friends
  clearCache('friends');
  clearCache('profile');
  
  // Refresh the page to update friends list
  const profileResult = await get('profile.php');
  if (profileResult.ok) {
    const friends = profileResult.data.friends || [];
    const listEl = $('#friends-list');
    const reqEl = $('#friends-requests');
    const countEl = $('#profile-friends-count');
    
    const accepted = friends.filter(f => f.status === 'accepted');
    const pending = friends.filter(f => f.status === 'pending');
    
    if (countEl) {
      countEl.textContent = `👥 ${accepted.length} friends`;
    }
    
    renderFriendsList(listEl, accepted);
    renderFriendsRequests(reqEl, pending);
  }
}

// ============================================
// PASSWORD FORM
// ============================================

function setupPasswordForm() {
  const form = $('#password-form');
  if (!form) return;
  
  const currentEl = $('#password-current');
  const newEl = $('#password-new');
  const confirmEl = $('#password-new-confirm');
  const errEl = $('#password-error');
  const okEl = $('#password-success');
  
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
    
    const submitBtn = form.querySelector('button[type="submit"]');
    submitBtn.disabled = true;
    submitBtn.textContent = 'Updating...';
    
    const result = await post('password.php', {
      current_password,
      new_password,
      new_password_confirmation,
    });
    
    submitBtn.disabled = false;
    submitBtn.textContent = 'Update Password';
    
    if (!result.ok) {
      if (errEl) {
        errEl.textContent = result.error || 'Could not update password.';
        errEl.style.display = 'block';
      }
      return;
    }
    
    // Clear form
    if (currentEl) currentEl.value = '';
    if (newEl) newEl.value = '';
    if (confirmEl) confirmEl.value = '';
    
    if (okEl) {
      okEl.textContent = 'Password updated successfully.';
      okEl.style.display = 'block';
    }
    
    showToast('Password updated!', 'success');
  });
}

export default {
  hydrateProfile,
};

