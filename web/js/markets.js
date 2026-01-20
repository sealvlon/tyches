// js/markets.js
// Market page: market details, members, events list

import { get, post } from './api.js';
import { 
  showToast, escapeHtml, formatDate, showSkeleton, $ 
} from './ui.js';

let currentMarket = null;

// ============================================
// MARKET PAGE INITIALIZATION
// ============================================

export async function loadMarketPage(marketId) {
  if (!marketId) return;
  
  const headerEl = $('#market-header');
  const membersEl = $('#market-members');
  const eventsEl = $('#market-events-list');
  
  // Wire up create event button
  const createEventBtn = $('#market-create-event');
  if (createEventBtn) {
    createEventBtn.addEventListener('click', () => {
      window.location.href = `create-event.php?market_id=${marketId}`;
    });
  }
  
  // Show loading state
  if (headerEl) {
    headerEl.innerHTML = '<div class="loading-state">Loading market...</div>';
  }
  
  const result = await get(`markets.php?id=${marketId}`);
  
  if (!result.ok || !result.data?.market) {
    if (headerEl) {
      headerEl.innerHTML = `
        <div class="empty-state">
          <div class="empty-state-icon">❌</div>
          <div class="empty-state-text">${escapeHtml(result.error || 'Market not found')}</div>
          <a href="index.php" class="btn-primary">Back to Home</a>
        </div>
      `;
    }
    return;
  }
  
  currentMarket = result.data.market;
  const members = result.data.members || [];
  const events = result.data.events || [];
  
  // Update page title
  document.title = `${currentMarket.name} - Tyches`;
  
  // Render header
  renderMarketHeader(headerEl, currentMarket, members, events);
  
  // Render members
  renderMarketMembers(membersEl, members);
  
  // Render events
  renderMarketEvents(eventsEl, events);
}

// ============================================
// MARKET HEADER
// ============================================

function renderMarketHeader(container, market, members, events) {
  if (!container) return;
  
  container.innerHTML = `
    <div class="market-header-card">
      <div class="market-page-title-row">
        <div class="market-page-avatar">${escapeHtml(market.avatar_emoji || '🎯')}</div>
        <div class="market-page-info">
          <h1 class="market-name">${escapeHtml(market.name)}</h1>
          <p class="market-desc">${escapeHtml(market.description || 'No description')}</p>
          <div class="market-page-stats">
            <span class="market-stat-item">👥 ${members.length} members</span>
            <span class="market-stat-item">📊 ${events.length} events</span>
            <span class="market-stat-item visibility-badge">${getVisibilityLabel(market.visibility)}</span>
          </div>
        </div>
      </div>
      <div class="market-actions">
        <button class="btn-primary" id="market-create-event-header">Create Event</button>
        <button class="btn-secondary" id="market-invite-members">Invite</button>
      </div>
    </div>
  `;
  
  // Wire up buttons
  $('#market-create-event-header')?.addEventListener('click', () => {
    window.location.href = `create-event.php?market_id=${market.id}`;
  });
  
  $('#market-invite-members')?.addEventListener('click', () => {
    openInviteModal(market.id);
  });
}

function getVisibilityLabel(visibility) {
  const labels = {
    private: '🔒 Private',
    invite_only: '✉️ Invite Only',
    link_only: '🔗 Link Only',
  };
  return labels[visibility] || visibility;
}

// ============================================
// MEMBERS LIST
// ============================================

function renderMarketMembers(container, members) {
  if (!container) return;
  
  container.innerHTML = '';
  
  if (members.length === 0) {
    container.innerHTML = `
      <div class="empty-state">
        <div class="empty-state-text">No members yet</div>
      </div>
    `;
    return;
  }
  
  for (const member of members) {
    const initial = (member.name || member.username || '?').charAt(0).toUpperCase();
    const roleLabel = member.role === 'owner' ? ' (Owner)' : '';
    
    const item = document.createElement('div');
    item.className = 'member-row';
    item.innerHTML = `
      <div class="member-avatar">${escapeHtml(initial)}</div>
      <div class="member-info">
        <div class="member-name">${escapeHtml(member.name || member.username)}${roleLabel}</div>
        <div class="member-username">@${escapeHtml(member.username || '')}</div>
      </div>
    `;
    
    container.appendChild(item);
  }
}

// ============================================
// EVENTS LIST
// ============================================

function renderMarketEvents(container, events) {
  if (!container) return;
  
  container.innerHTML = '';
  
  if (events.length === 0) {
    container.innerHTML = `
      <div class="empty-state">
        <div class="empty-state-icon">📅</div>
        <div class="empty-state-text">No events yet. Create the first one!</div>
      </div>
    `;
    return;
  }
  
  for (const event of events) {
    const row = document.createElement('div');
    row.className = 'event-row';
    row.dataset.eventId = event.id;
    
    const yesPercent = event.yes_percent || 50;
    
    row.innerHTML = `
      <div class="event-row-main">
        <div class="event-row-title">${escapeHtml(event.title)}</div>
        <div class="event-row-meta">
          <span class="status-badge ${event.status}">${escapeHtml(event.status)}</span>
          · closes ${formatDate(event.closes_at)}
          · ${event.traders_count || 0} traders
        </div>
      </div>
      <div class="event-row-odds">
        ${event.event_type === 'binary' ? `${yesPercent}% YES` : 'Multiple'}
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
    
    container.appendChild(row);
  }
}

// ============================================
// INVITE MODAL
// ============================================

import { createModal, closeModal } from './ui.js';

function openInviteModal(marketId) {
  const content = `
    <form id="invite-form" class="auth-form">
      <div class="form-group">
        <label for="invite-emails">Email addresses</label>
        <textarea id="invite-emails" rows="3" placeholder="friend@example.com, buddy@example.com"></textarea>
        <div class="form-hint">Separate multiple emails with commas</div>
      </div>
      <div id="invite-error" class="form-error" style="display:none;"></div>
      <div id="invite-success" class="form-success" style="display:none;"></div>
      <button type="submit" class="btn-primary btn-block">Send Invites</button>
    </form>
  `;
  
  createModal('invite', 'Invite Members', content);
  
  const form = $('#invite-form');
  
  form?.addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const errorEl = $('#invite-error');
    const okEl = $('#invite-success');
    errorEl.style.display = 'none';
    okEl.style.display = 'none';
    
    const emailsStr = $('#invite-emails').value.trim();
    const emails = emailsStr.split(',').map(e => e.trim()).filter(e => e);
    
    if (emails.length === 0) {
      errorEl.textContent = 'Please enter at least one email.';
      errorEl.style.display = 'block';
      return;
    }
    
    const submitBtn = form.querySelector('button[type="submit"]');
    submitBtn.disabled = true;
    submitBtn.textContent = 'Sending...';
    
    const result = await post('markets.php', {
      action: 'invite',
      market_id: marketId,
      emails,
    });
    
    submitBtn.disabled = false;
    submitBtn.textContent = 'Send Invites';
    
    if (!result.ok) {
      errorEl.textContent = result.error || 'Could not send invites.';
      errorEl.style.display = 'block';
      return;
    }
    
    okEl.textContent = `Sent ${emails.length} invite(s)!`;
    okEl.style.display = 'block';
    
    setTimeout(() => closeModal('invite'), 1500);
  });
}

export default {
  loadMarketPage,
};

