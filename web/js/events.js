// js/events.js
// Event page: trading, gossip, activity chart

import { get, post, clearCache } from './api.js';
import { 
  showToast, createModal, closeModal, escapeHtml, escapeHtmlAttr,
  formatDate, formatRelativeTime, showSkeleton, $, $$
} from './ui.js';
import { isLoggedIn, getUser } from './auth.js';
import { subscribeToEvent, unsubscribe } from './realtime.js';

let currentEvent = null;
let eventSubscription = null;

// ============================================
// EVENT PAGE INITIALIZATION
// ============================================

export async function loadEventPage(eventId) {
  if (!eventId) return;
  
  const headerEl = $('#event-header');
  const tradeCard = $('#event-trade-card');
  const detailsEl = $('#event-details');
  
  // Show loading state
  if (headerEl) {
    headerEl.innerHTML = '<div class="loading-state">Loading event...</div>';
  }
  
  const result = await get(`events.php?id=${eventId}`);
  
  if (!result.ok || !result.data?.event) {
    if (headerEl) {
      headerEl.innerHTML = `
        <div class="empty-state">
          <div class="empty-state-icon">❌</div>
          <div class="empty-state-text">${escapeHtml(result.error || 'Event not found')}</div>
          <a href="index.php" class="btn-primary">Back to Home</a>
        </div>
      `;
    }
    return;
  }
  
  currentEvent = result.data.event;
  
  // Update page title
  document.title = `${currentEvent.title} - Tyches`;
  
  // Render header
  renderEventHeader(headerEl, currentEvent);
  
  // Render trade card
  if (tradeCard) {
    renderTradeCard(tradeCard, currentEvent);
  }
  
  // Render details
  if (detailsEl) {
    renderEventDetails(detailsEl, currentEvent);
  }
  
  // Load gossip
  loadGossip(eventId);
  
  // Load activity chart
  loadEventActivityChart(eventId);
  
  // Subscribe to real-time updates
  eventSubscription = subscribeToEvent(eventId, handleEventUpdate);
}

function handleEventUpdate(data) {
  if (data.type === 'bet' || data.type === 'odds_update') {
    // Refresh odds display
    const tradeCard = $('#event-trade-card');
    if (tradeCard && currentEvent) {
      // Update current event data
      if (data.yes_percent !== undefined) {
        currentEvent.yes_percent = data.yes_percent;
        currentEvent.no_percent = 100 - data.yes_percent;
      }
      renderTradeCard(tradeCard, currentEvent);
    }
    
    // Refresh activity chart
    loadEventActivityChart(currentEvent.id);
  }
  
  if (data.type === 'gossip') {
    // Append new gossip message
    appendGossipMessage(data.message);
  }
}

export function cleanupEventPage() {
  if (eventSubscription) {
    unsubscribe(eventSubscription);
    eventSubscription = null;
  }
  currentEvent = null;
}

// ============================================
// EVENT HEADER
// ============================================

function renderEventHeader(container, event) {
  if (!container) return;
  
  const statusClass = event.status;
  
  container.innerHTML = `
    <div class="event-header-content">
      <h1 class="event-title">${escapeHtml(event.title)}</h1>
      <div class="event-meta">
        <a href="market.php?id=${event.market_id}" class="event-market-link">
          📊 ${escapeHtml(event.market_name || 'Market')}
        </a>
        <span class="separator">·</span>
        <span class="status-badge ${statusClass}">${escapeHtml(event.status)}</span>
        <span class="separator">·</span>
        <span>Closes ${formatDate(event.closes_at)}</span>
        <span class="separator">·</span>
        <span>${event.traders_count || 0} traders</span>
      </div>
      <div id="event-activity-chart" class="event-activity-chart"></div>
    </div>
  `;
}

// ============================================
// TRADE CARD
// ============================================

function renderTradeCard(container, event) {
  if (!container) return;
  
  container.innerHTML = '';
  
  if (event.status !== 'open') {
    container.innerHTML = `
      <div class="trade-card-closed">
        <h3>Trading Closed</h3>
        <p>This event is ${event.status}.</p>
        ${event.winning_side ? `<p class="winning-result">Result: <strong>${event.winning_side}</strong></p>` : ''}
      </div>
    `;
    return;
  }
  
  if (event.event_type === 'binary') {
    renderBinaryTradeCard(container, event);
  } else {
    renderMultipleTradeCard(container, event);
  }
}

function renderBinaryTradeCard(container, event) {
  const yes = event.yes_percent ?? 50;
  const no = event.no_percent ?? 50;
  
  container.innerHTML = `
    <h3 class="trade-card-title">Place your bet</h3>
    <div class="binary-odds-display">
      <div class="odds-button yes" data-side="YES">
        <div class="odds-side">YES</div>
        <div class="odds-price">${yes}¢</div>
        <div class="odds-chance">${yes}% chance</div>
      </div>
      <div class="odds-button no" data-side="NO">
        <div class="odds-side">NO</div>
        <div class="odds-price">${no}¢</div>
        <div class="odds-chance">${no}% chance</div>
      </div>
    </div>
    <div class="odds-bar-container">
      <div class="odds-bar">
        <div class="odds-fill yes" style="width:${yes}%"></div>
        <div class="odds-fill no" style="width:${no}%"></div>
      </div>
    </div>
  `;
  
  $$('.odds-button', container).forEach(btn => {
    btn.addEventListener('click', () => {
      if (!isLoggedIn()) {
        showToast('Please log in to trade', 'warning');
        return;
      }
      openTradeModal(event, btn.dataset.side);
    });
  });
}

function renderMultipleTradeCard(container, event) {
  const outcomes = event.outcomes || [];
  
  container.innerHTML = `<h3 class="trade-card-title">Choose an outcome</h3>`;
  
  const list = document.createElement('div');
  list.className = 'outcomes-list';
  
  for (const outcome of outcomes) {
    const pill = document.createElement('button');
    pill.className = 'outcome-pill';
    pill.innerHTML = `
      <div class="outcome-info">
        <span class="outcome-label">${escapeHtml(outcome.label)}</span>
      </div>
      <div class="outcome-odds">
        <span class="outcome-prob">${outcome.probability}%</span>
        <span class="outcome-price">${outcome.probability}¢</span>
      </div>
    `;
    
    pill.addEventListener('click', () => {
      if (!isLoggedIn()) {
        showToast('Please log in to trade', 'warning');
        return;
      }
      openTradeModal(event, null, outcome.id);
    });
    
    list.appendChild(pill);
  }
  
  container.appendChild(list);
}

// ============================================
// TRADE MODAL
// ============================================

function openTradeModal(event, side = null, outcomeId = null) {
  let defaultPrice = 50;
  let outcomeLabel = '';
  
  if (event.event_type === 'binary') {
    defaultPrice = side === 'YES' ? (event.yes_price || 50) : (event.no_price || 50);
    outcomeLabel = side;
  } else {
    const outcome = (event.outcomes || []).find(o => o.id === outcomeId);
    if (outcome) {
      defaultPrice = outcome.probability || 50;
      outcomeLabel = outcome.label;
    }
  }
  
  const outcomeClass = event.event_type === 'binary' 
    ? (side === 'YES' ? 'yes' : 'no') 
    : 'multiple';
  
  const content = `
    <div class="trade-modal-event">
      <div class="trade-modal-title">${escapeHtml(event.title)}</div>
      <div class="trade-modal-outcome ${outcomeClass}">${escapeHtml(outcomeLabel)}</div>
    </div>
    <form id="trade-form" class="trade-form">
      <div class="form-group">
        <label for="trade-shares">Number of shares</label>
        <input type="number" id="trade-shares" min="1" value="10" required>
      </div>
      <div class="form-group">
        <label for="trade-price">Price per share (1–100¢)</label>
        <input type="number" id="trade-price" min="1" max="100" value="${defaultPrice}" required>
        <div class="form-hint">Current implied probability: ${defaultPrice}%</div>
      </div>
      <div class="trade-summary">
        <div class="trade-summary-row">
          <span>Total cost:</span>
          <span id="trade-total">$${(10 * defaultPrice / 100).toFixed(2)}</span>
        </div>
        <div class="trade-summary-row">
          <span>Potential profit:</span>
          <span id="trade-profit" class="text-success">$${(10 * (100 - defaultPrice) / 100).toFixed(2)}</span>
        </div>
      </div>
      <div id="trade-error" class="form-error" style="display:none;"></div>
      <div class="trade-actions-modal">
        <button type="button" class="btn-secondary" id="trade-cancel">Cancel</button>
        <button type="submit" class="btn-primary">Confirm Trade</button>
      </div>
    </form>
  `;
  
  createModal('trade', 'Place a Trade', content);
  
  const sharesInput = $('#trade-shares');
  const priceInput = $('#trade-price');
  const totalEl = $('#trade-total');
  const profitEl = $('#trade-profit');
  
  function updateCalc() {
    const shares = parseInt(sharesInput.value) || 0;
    const price = parseInt(priceInput.value) || 0;
    totalEl.textContent = `$${(shares * price / 100).toFixed(2)}`;
    profitEl.textContent = `$${(shares * (100 - price) / 100).toFixed(2)}`;
  }
  
  sharesInput.addEventListener('input', updateCalc);
  priceInput.addEventListener('input', updateCalc);
  
  $('#trade-cancel')?.addEventListener('click', () => closeModal('trade'));
  
  $('#trade-form')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const errorEl = $('#trade-error');
    errorEl.style.display = 'none';
    
    const shares = parseInt(sharesInput.value) || 0;
    const price = parseInt(priceInput.value) || 0;
    
    if (shares <= 0) {
      errorEl.textContent = 'Please enter a valid number of shares.';
      errorEl.style.display = 'block';
      return;
    }
    
    if (price < 1 || price > 100) {
      errorEl.textContent = 'Price must be between 1 and 100 cents.';
      errorEl.style.display = 'block';
      return;
    }
    
    const payload = { event_id: event.id, shares, price };
    if (event.event_type === 'binary') {
      payload.side = side || 'YES';
    } else {
      payload.outcome_id = outcomeId;
    }
    
    const submitBtn = e.target.querySelector('button[type="submit"]');
    submitBtn.disabled = true;
    submitBtn.textContent = 'Placing trade...';
    
    const result = await post('bets.php', payload);
    
    if (!result.ok) {
      errorEl.textContent = result.error || 'Trade failed.';
      errorEl.style.display = 'block';
      submitBtn.disabled = false;
      submitBtn.textContent = 'Confirm Trade';
      return;
    }
    
    closeModal('trade');
    showToast('Trade placed successfully!', 'success');
    
    // Clear cache and refresh
    clearCache('events');
    clearCache('profile');
    
    // Update UI
    setTimeout(() => window.location.reload(), 1000);
  });
}

// ============================================
// EVENT DETAILS
// ============================================

function renderEventDetails(container, event) {
  if (!container) return;
  
  const description = event.description 
    ? `<p class="event-description">${escapeHtml(event.description)}</p>` 
    : '';
  
  container.innerHTML = `
    ${description}
    <div class="event-stats-grid">
      <div class="event-stat-box">
        <div class="event-stat-label">Type</div>
        <div class="event-stat-value">${event.event_type === 'binary' ? 'Yes/No' : 'Multiple Choice'}</div>
      </div>
      <div class="event-stat-box">
        <div class="event-stat-label">Volume</div>
        <div class="event-stat-value">$${parseFloat(event.volume || 0).toFixed(2)}</div>
      </div>
      <div class="event-stat-box">
        <div class="event-stat-label">Traders</div>
        <div class="event-stat-value">${event.traders_count || 0}</div>
      </div>
      <div class="event-stat-box">
        <div class="event-stat-label">Created</div>
        <div class="event-stat-value">${formatRelativeTime(event.created_at)}</div>
      </div>
    </div>
  `;
}

// ============================================
// ACTIVITY CHART
// ============================================

async function loadEventActivityChart(eventId) {
  const container = $('#event-activity-chart');
  if (!container) return;
  
  container.innerHTML = `
    <div class="activity-chart-header">
      <span class="activity-chart-title">Recent trading</span>
      <span class="activity-chart-subtitle">Top traders in this event</span>
    </div>
    <div class="activity-chart-empty">Loading...</div>
  `;
  
  const result = await get(`event-activity.php?event_id=${eventId}`);
  
  if (!result.ok) {
    container.querySelector('.activity-chart-empty').textContent = 'Could not load activity.';
    return;
  }
  
  const bets = result.data.bets || [];
  
  if (bets.length === 0) {
    container.querySelector('.activity-chart-empty').textContent = 'No bets yet. Be the first!';
    return;
  }
  
  renderActivityChart(container, bets);
}

function renderActivityChart(container, bets) {
  container.innerHTML = `
    <div class="activity-chart-header">
      <span class="activity-chart-title">Recent trading</span>
      <span class="activity-chart-subtitle">Top traders</span>
    </div>
    <div class="activity-chart-bars"></div>
  `;
  
  const barsEl = container.querySelector('.activity-chart-bars');
  
  // Aggregate by user
  const byUser = new Map();
  for (const bet of bets) {
    const notional = parseFloat(bet.notional) || 0;
    if (notional <= 0) continue;
    
    const name = bet.user_name || bet.user_username || '';
    const initial = (name || '?').charAt(0).toUpperCase();
    const key = name || initial;
    
    const existing = byUser.get(key) || { name, initial, total: 0 };
    existing.total += notional;
    byUser.set(key, existing);
  }
  
  const users = Array.from(byUser.values());
  if (users.length === 0) {
    container.innerHTML += '<div class="activity-chart-empty">No trades yet.</div>';
    return;
  }
  
  users.sort((a, b) => b.total - a.total);
  const topUsers = users.slice(0, 5);
  const maxTotal = topUsers[0].total || 1;
  
  for (const user of topUsers) {
    const pct = Math.max(15, (user.total / maxTotal) * 100);
    const tokenLabel = user.total >= 100 ? user.total.toFixed(0) : user.total.toFixed(1);
    
    const bar = document.createElement('div');
    bar.className = 'activity-bar';
    bar.innerHTML = `
      <div class="activity-bar-value">${escapeHtml(tokenLabel)}</div>
      <div class="activity-bar-avatar">${escapeHtml(user.initial)}</div>
      <div class="activity-bar-column">
        <div class="activity-bar-fill" style="height:${pct}%"></div>
      </div>
      <div class="activity-bar-label">${escapeHtml(user.name)}</div>
    `;
    barsEl.appendChild(bar);
  }
}

// ============================================
// GOSSIP
// ============================================

let gossipHandlerBound = false;

async function loadGossip(eventId) {
  const listEl = $('#gossip-list');
  const compose = $('#gossip-compose');
  
  // Show compose if logged in
  if (compose && isLoggedIn()) {
    compose.style.display = '';
  }
  
  if (!listEl) return;
  
  showSkeleton(listEl, 3, 'row');
  
  const result = await get(`gossip.php?event_id=${eventId}`);
  
  listEl.innerHTML = '';
  
  if (!result.ok) {
    listEl.innerHTML = '<div class="empty-state"><div class="empty-state-text">Could not load gossip.</div></div>';
    return;
  }
  
  const messages = result.data.messages || [];
  
  if (messages.length === 0) {
    listEl.innerHTML = `
      <div class="empty-state">
        <div class="empty-state-text">No gossip yet. Be the first to drop a take!</div>
      </div>
    `;
  } else {
    for (const msg of messages) {
      appendGossipMessage(msg);
    }
  }
  
  // Bind submit handler once
  if (!gossipHandlerBound) {
    gossipHandlerBound = true;
    
    const submitBtn = $('#gossip-submit');
    const msgInput = $('#gossip-message');
    
    submitBtn?.addEventListener('click', async () => {
      const message = msgInput.value.trim();
      if (!message) return;
      
      submitBtn.disabled = true;
      submitBtn.textContent = 'Posting...';
      
      const result = await post('gossip.php', { event_id: eventId, message });
      
      submitBtn.disabled = false;
      submitBtn.textContent = 'Post';
      
      if (!result.ok) {
        showToast(result.error || 'Could not post.', 'error');
        return;
      }
      
      msgInput.value = '';
      showToast('Comment posted!', 'success');
      
      // Append the new message
      appendGossipMessage({
        user_name: getUser()?.name || getUser()?.username,
        message,
        created_at: new Date().toISOString(),
      });
    });
  }
}

function appendGossipMessage(msg) {
  const listEl = $('#gossip-list');
  if (!listEl) return;
  
  // Remove empty state if present
  const emptyState = listEl.querySelector('.empty-state');
  if (emptyState) emptyState.remove();
  
  const name = msg.user_name || msg.user_username || 'User';
  const initial = name.charAt(0).toUpperCase();
  
  const item = document.createElement('div');
  item.className = 'gossip-item';
  item.innerHTML = `
    <div class="gossip-avatar">${escapeHtml(initial)}</div>
    <div class="gossip-content">
      <div class="gossip-header">
        <span class="gossip-name">${escapeHtml(name)}</span>
        <span class="gossip-time">${formatRelativeTime(msg.created_at)}</span>
      </div>
      <div class="gossip-message">${escapeHtml(msg.message)}</div>
    </div>
  `;
  
  listEl.appendChild(item);
  
  // Scroll to bottom
  listEl.scrollTop = listEl.scrollHeight;
}

export default {
  loadEventPage,
  cleanupEventPage,
};

