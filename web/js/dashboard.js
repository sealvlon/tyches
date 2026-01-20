// js/dashboard.js
// Dashboard: markets list, events list, activity feed

import { get, post, clearCache } from './api.js';
import { showToast, createModal, closeModal, escapeHtml, formatDate, showSkeleton, $ } from './ui.js';
import { getUser } from './auth.js';

// ============================================
// DASHBOARD INITIALIZATION
// ============================================

export async function hydrateDashboard(profileData = null) {
  const dashboard = $('#dashboard');
  if (!dashboard) return;
  
  // Show dashboard
  dashboard.style.display = 'block';
  
  // Set user name
  const nameEl = $('#dashboard-user-name');
  const user = profileData?.user || getUser();
  if (nameEl && user) {
    nameEl.textContent = user.name || user.username || 'friend';
  }
  
  // Load markets
  await loadDashboardMarkets(profileData?.markets);
  
  // Load events
  await loadDashboardEvents();
  
  // Load activity
  loadDashboardActivity();
  
  // Wire up create market button
  $('#dashboard-create-market')?.addEventListener('click', openCreateMarketModal);
}

// ============================================
// MARKETS SECTION
// ============================================

async function loadDashboardMarkets(marketsData = null) {
  const container = $('#dashboard-markets');
  if (!container) return;
  
  // Show skeleton while loading
  if (!marketsData) {
    showSkeleton(container, 2, 'card');
    
    const result = await get('profile.php', { useCache: true });
    if (!result.ok) {
      container.innerHTML = `
        <div class="empty-state">
          <div class="empty-state-icon">⚠️</div>
          <div class="empty-state-text">Could not load markets</div>
        </div>
      `;
      return;
    }
    marketsData = result.data.markets || [];
  }
  
  container.innerHTML = '';
  
  if (marketsData.length === 0) {
    container.innerHTML = `
      <div class="empty-state">
        <div class="empty-state-icon">🎯</div>
        <div class="empty-state-text">No markets yet. Create your first one!</div>
        <button class="btn-primary btn-small" id="empty-create-market">Create Market</button>
      </div>
    `;
    $('#empty-create-market')?.addEventListener('click', openCreateMarketModal);
    return;
  }
  
  for (const market of marketsData) {
    const card = createMarketCard(market);
    container.appendChild(card);
  }
}

function createMarketCard(market) {
  const card = document.createElement('div');
  card.className = 'market-card';
  card.dataset.marketId = market.id;
  
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
    <p class="market-description">${escapeHtml(market.description || 'No description')}</p>
    <div class="market-footer">
      <div class="market-volume"></div>
      <button class="btn-market">Open</button>
    </div>
  `;
  
  card.querySelector('.btn-market').addEventListener('click', (e) => {
    e.stopPropagation();
    window.location.href = `market.php?id=${market.id}`;
  });
  
  card.addEventListener('click', () => {
    window.location.href = `market.php?id=${market.id}`;
  });
  
  return card;
}

// ============================================
// EVENTS SECTION
// ============================================

async function loadDashboardEvents() {
  const container = $('#dashboard-events');
  if (!container) return;
  
  showSkeleton(container, 3, 'row');
  
  const result = await get('events.php', { useCache: true, cacheTTL: 15000 });
  
  container.innerHTML = '';
  
  if (!result.ok) {
    container.innerHTML = `
      <div class="empty-state">
        <div class="empty-state-icon">⚠️</div>
        <div class="empty-state-text">Could not load events</div>
      </div>
    `;
    return;
  }
  
  const events = result.data.events || [];
  
  if (events.length === 0) {
    container.innerHTML = `
      <div class="empty-state">
        <div class="empty-state-icon">📅</div>
        <div class="empty-state-text">No upcoming events</div>
      </div>
    `;
    return;
  }
  
  for (const event of events) {
    const row = createEventRow(event);
    container.appendChild(row);
  }
}

function createEventRow(event) {
  const row = document.createElement('div');
  row.className = 'event-row';
  row.dataset.eventId = event.id;
  
  const yesPercent = event.yes_percent || 50;
  
  row.innerHTML = `
    <div class="event-row-main">
      <div class="event-row-title">${escapeHtml(event.title)}</div>
      <div class="event-row-meta">
        In ${escapeHtml(event.market_name || '')} · closes ${formatDate(event.closes_at)}
      </div>
    </div>
    <div class="event-row-odds">
      ${event.event_type === 'binary' ? `<span class="odds-badge">${yesPercent}%</span>` : '<span class="type-badge">Multi</span>'}
    </div>
    <button class="btn-secondary btn-small">Open</button>
  `;
  
  row.querySelector('button').addEventListener('click', (e) => {
    e.stopPropagation();
    window.location.href = `event.php?id=${event.id}`;
  });
  
  row.addEventListener('click', () => {
    window.location.href = `event.php?id=${event.id}`;
  });
  
  return row;
}

// ============================================
// ACTIVITY SECTION
// ============================================

async function loadDashboardActivity() {
  const container = $('#dashboard-activity');
  if (!container) return;
  
  // For now, show placeholder
  // TODO: Implement real activity feed with SSE
  container.innerHTML = `
    <div class="empty-state">
      <div class="empty-state-icon">👥</div>
      <div class="empty-state-text">Friends' activity will appear here</div>
    </div>
  `;
}

// ============================================
// CREATE MARKET MODAL
// ============================================

export function openCreateMarketModal() {
  const content = `
    <form id="create-market-form" class="auth-form">
      <div class="form-group">
        <label for="market-name">Market name</label>
        <input type="text" id="market-name" required placeholder="NYC Degens" maxlength="150">
      </div>
      <div class="form-group">
        <label for="market-description">Description</label>
        <textarea id="market-description" rows="3" placeholder="A group for betting on NYC happenings"></textarea>
      </div>
      <div class="form-row">
        <div class="form-group">
          <label for="market-emoji">Emoji</label>
          <input type="text" id="market-emoji" placeholder="🎯" maxlength="2" class="emoji-input">
        </div>
        <div class="form-group flex-grow">
          <label for="market-visibility">Visibility</label>
          <select id="market-visibility">
            <option value="private">Private</option>
            <option value="invite_only">Invite only</option>
          </select>
        </div>
      </div>
      <div class="form-group">
        <label for="market-invites">Invite friends by email</label>
        <input type="text" id="market-invites" placeholder="friend@example.com, buddy@example.com">
        <div class="form-hint">Separate multiple emails with commas</div>
      </div>
      <div id="create-market-error" class="form-error" style="display:none;"></div>
      <div id="create-market-success" class="form-success" style="display:none;"></div>
      <button type="submit" class="btn-primary btn-block">Create Market</button>
    </form>
  `;
  
  createModal('create-market', 'Create a new Market', content);
  
  const form = $('#create-market-form');
  const errorEl = $('#create-market-error');
  const okEl = $('#create-market-success');
  
  form?.addEventListener('submit', async (e) => {
    e.preventDefault();
    errorEl.style.display = 'none';
    okEl.style.display = 'none';
    
    const name = $('#market-name').value.trim();
    const description = $('#market-description').value.trim();
    const avatar_emoji = $('#market-emoji').value.trim() || '🎯';
    const visibility = $('#market-visibility').value;
    const invitesStr = $('#market-invites').value.trim();
    const invites = invitesStr ? invitesStr.split(',').map(e => e.trim()).filter(e => e) : [];
    
    if (!name) {
      errorEl.textContent = 'Please enter a market name.';
      errorEl.style.display = 'block';
      return;
    }
    
    const submitBtn = form.querySelector('button[type="submit"]');
    submitBtn.disabled = true;
    submitBtn.textContent = 'Creating...';
    
    const result = await post('markets.php', { name, description, visibility, avatar_emoji, invites });
    
    if (!result.ok) {
      errorEl.textContent = result.error || 'Could not create market.';
      errorEl.style.display = 'block';
      submitBtn.disabled = false;
      submitBtn.textContent = 'Create Market';
      return;
    }
    
    okEl.textContent = 'Market created!';
    okEl.style.display = 'block';
    
    // Clear cache and redirect
    clearCache('profile');
    clearCache('markets');
    
    setTimeout(() => {
      window.location.href = `market.php?id=${result.data.id}`;
    }, 800);
  });
}

export default {
  hydrateDashboard,
  openCreateMarketModal,
};

