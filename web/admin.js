/**
 * Tyches Admin Panel JavaScript
 * Comprehensive admin dashboard functionality
 */

(function() {
  'use strict';

  // ===========================================
  // CONFIGURATION & STATE
  // ===========================================
  
  const CSRF_TOKEN = document.querySelector('meta[name="csrf-token"]')?.content || '';
  
  const state = {
    currentPanel: 'overview',
    users: { page: 1, data: [], total: 0 },
    markets: { page: 1, data: [], total: 0 },
    events: { page: 1, data: [], total: 0 },
    bets: { page: 1, data: [], total: 0 },
    gossip: { page: 1, data: [], total: 0 },
    charts: {}
  };

  // ===========================================
  // UTILITY FUNCTIONS
  // ===========================================

  function escapeHtml(str) {
    if (str === null || str === undefined) return '';
    return String(str).replace(/[&<>"']/g, s => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    })[s]);
  }

  function formatNumber(n) {
    if (typeof n !== 'number') n = parseInt(n || '0', 10) || 0;
    return n.toLocaleString();
  }

  function formatMoney(v) {
    const num = typeof v === 'number' ? v : parseFloat(v || '0');
    return isNaN(num) ? '0.00' : num.toFixed(2);
  }

  function formatDate(dateStr) {
    if (!dateStr) return '–';
    const d = new Date(dateStr);
    return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
  }

  function formatDateTime(dateStr) {
    if (!dateStr) return '–';
    const d = new Date(dateStr);
    return d.toLocaleDateString('en-US', { 
      month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' 
    });
  }

  function timeAgo(dateStr) {
    if (!dateStr) return '–';
    const d = new Date(dateStr);
    const now = new Date();
    const diff = Math.floor((now - d) / 1000);
    
    if (diff < 60) return 'just now';
    if (diff < 3600) return Math.floor(diff / 60) + 'm ago';
    if (diff < 86400) return Math.floor(diff / 3600) + 'h ago';
    if (diff < 604800) return Math.floor(diff / 86400) + 'd ago';
    return formatDate(dateStr);
  }

  function debounce(fn, delay) {
    let timeout;
    return function(...args) {
      clearTimeout(timeout);
      timeout = setTimeout(() => fn.apply(this, args), delay);
    };
  }

  // ===========================================
  // API HELPERS
  // ===========================================

  async function apiGet(url) {
    try {
      const res = await fetch(url, { credentials: 'same-origin' });
      const data = await res.json();
      return { ok: res.ok, data };
    } catch (err) {
      console.error('API GET error:', err);
      return { ok: false, data: { error: 'Network error' } };
    }
  }

  async function apiPost(url, body) {
    try {
      const res = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': CSRF_TOKEN
        },
        credentials: 'same-origin',
        body: JSON.stringify(body)
      });
      const data = await res.json();
      return { ok: res.ok, data };
    } catch (err) {
      console.error('API POST error:', err);
      return { ok: false, data: { error: 'Network error' } };
    }
  }

  // ===========================================
  // TOAST NOTIFICATIONS
  // ===========================================

  function showToast(message, type = 'info') {
    const container = document.getElementById('toast-container');
    if (!container) return;

    const toast = document.createElement('div');
    toast.className = `admin-toast ${type}`;
    toast.innerHTML = `
      <span>${escapeHtml(message)}</span>
    `;
    container.appendChild(toast);

    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transform = 'translateX(100px)';
      setTimeout(() => toast.remove(), 300);
    }, 4000);
  }

  // ===========================================
  // NAVIGATION
  // ===========================================

  function initNavigation() {
    const navItems = document.querySelectorAll('.admin-nav-item[data-panel]');
    const panels = document.querySelectorAll('.admin-panel');
    const panelTitle = document.getElementById('panel-title');
    const viewAllBtns = document.querySelectorAll('[data-panel]');

    function switchPanel(panelId) {
      // Update nav
      navItems.forEach(item => {
        item.classList.toggle('active', item.dataset.panel === panelId);
      });

      // Update panels
      panels.forEach(panel => {
        panel.classList.toggle('admin-hidden', panel.id !== `panel-${panelId}`);
      });

      // Update title
      const titles = {
        overview: 'Overview',
        users: 'User Management',
        markets: 'Market Management',
        events: 'Event Management',
        bets: 'Bets & Tokens',
        disputes: 'Resolution Disputes',
        gossip: 'Gossip / Chat',
        resolution: 'Event Resolution',
        analytics: 'Analytics',
        audit: 'Audit Log',
        settings: 'Settings'
      };
      if (panelTitle) {
        panelTitle.textContent = titles[panelId] || 'Admin';
      }

      state.currentPanel = panelId;
      
      // Load panel data
      loadPanelData(panelId);
    }

    navItems.forEach(item => {
      item.addEventListener('click', () => switchPanel(item.dataset.panel));
    });

    viewAllBtns.forEach(btn => {
      if (!btn.classList.contains('admin-nav-item')) {
        btn.addEventListener('click', () => switchPanel(btn.dataset.panel));
      }
    });

    // Mobile sidebar toggle
    const sidebarToggle = document.getElementById('sidebar-toggle');
    const sidebar = document.getElementById('admin-sidebar');
    if (sidebarToggle && sidebar) {
      sidebarToggle.addEventListener('click', () => {
        sidebar.classList.toggle('open');
      });
    }
  }

  function loadPanelData(panelId) {
    switch (panelId) {
      case 'overview':
        loadOverviewData();
        break;
      case 'users':
        loadUsers();
        break;
      case 'markets':
        loadMarkets();
        break;
      case 'events':
        loadEvents();
        break;
      case 'bets':
        loadBets();
        break;
      case 'disputes':
        loadDisputes();
        break;
      case 'gossip':
        loadGossip();
        break;
      case 'resolution':
        loadResolution();
        break;
      case 'analytics':
        loadAnalytics();
        break;
      case 'audit':
        loadAuditLog();
        break;
    }
  }

  // ===========================================
  // OVERVIEW PANEL
  // ===========================================

  async function loadOverviewData() {
    const res = await apiGet('api/admin-stats.php');
    if (!res.ok) {
      showToast('Failed to load dashboard data', 'error');
      return;
    }

    const data = res.data;
    const kpis = data.kpis || {};

    // KPIs
    setText('kpi-users', formatNumber(kpis.total_users));
    setText('kpi-users-new', `${kpis.new_users_7d || 0} new this week`);
    setText('kpi-markets', formatNumber(kpis.total_markets));
    setText('kpi-markets-events', `${formatNumber(kpis.total_events)} total events`);
    setText('kpi-volume', '$' + formatMoney(kpis.total_volume));
    setText('kpi-volume-bets', `${formatNumber(kpis.total_bets)} bets placed`);
    setText('kpi-events-status', formatNumber(kpis.total_events));
    setText('kpi-events-open', `${kpis.events_open || 0} open`);
    setText('kpi-events-closed', `${kpis.events_closed || 0} closed`);
    setText('kpi-events-resolved', `${kpis.events_resolved || 0} resolved`);

    // Charts
    renderUsersChart(data.series?.signups || []);
    renderVolumeChart(data.series?.bets || []);

    // Tables
    renderTopMarkets(data.top_markets || []);
    renderTopEvents(data.top_events || []);
    renderRecentActivity(data.recent_bets || [], data.recent_events || []);
    renderRecentUsers(data.recent_users || []);
  }

  function setText(id, value) {
    const el = document.getElementById(id);
    if (el) el.textContent = value;
  }

  function renderUsersChart(series) {
    const ctx = document.getElementById('chart-users');
    if (!ctx || !window.Chart) return;

    if (state.charts.users) {
      state.charts.users.destroy();
    }

    const labels = series.map(p => p.date);
    const counts = series.map(p => p.count);

    state.charts.users = new Chart(ctx, {
      type: 'line',
      data: {
        labels,
        datasets: [{
          label: 'New Users',
          data: counts,
          borderColor: '#6366f1',
          backgroundColor: 'rgba(99, 102, 241, 0.1)',
          tension: 0.4,
          fill: true
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false }
        },
        scales: {
          x: {
            grid: { color: 'rgba(255,255,255,0.05)' },
            ticks: { color: '#6b6b78', maxTicksLimit: 7 }
          },
          y: {
            beginAtZero: true,
            grid: { color: 'rgba(255,255,255,0.05)' },
            ticks: { color: '#6b6b78', precision: 0 }
          }
        }
      }
    });
  }

  function renderVolumeChart(series) {
    const ctx = document.getElementById('chart-volume');
    if (!ctx || !window.Chart) return;

    if (state.charts.volume) {
      state.charts.volume.destroy();
    }

    const labels = series.map(p => p.date);
    const bets = series.map(p => p.bets);
    const volume = series.map(p => p.volume);

    state.charts.volume = new Chart(ctx, {
      type: 'bar',
      data: {
        labels,
        datasets: [
          {
            label: 'Volume ($)',
            data: volume,
            backgroundColor: 'rgba(16, 185, 129, 0.6)',
            yAxisID: 'y'
          },
          {
            label: 'Bets',
            data: bets,
            type: 'line',
            borderColor: '#6366f1',
            backgroundColor: 'transparent',
            tension: 0.4,
            yAxisID: 'y1'
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { 
            display: true,
            labels: { color: '#9898a6' }
          }
        },
        scales: {
          x: {
            grid: { color: 'rgba(255,255,255,0.05)' },
            ticks: { color: '#6b6b78', maxTicksLimit: 7 }
          },
          y: {
            position: 'left',
            beginAtZero: true,
            grid: { color: 'rgba(255,255,255,0.05)' },
            ticks: { color: '#6b6b78' }
          },
          y1: {
            position: 'right',
            beginAtZero: true,
            grid: { display: false },
            ticks: { color: '#6b6b78', precision: 0 }
          }
        }
      }
    });
  }

  function renderTopMarkets(markets) {
    const tbody = document.getElementById('top-markets-table');
    if (!tbody) return;

    if (!markets.length) {
      tbody.innerHTML = '<tr><td colspan="3" class="admin-text-center">No markets yet</td></tr>';
      return;
    }

    tbody.innerHTML = markets.map(m => `
      <tr>
        <td>
          <div class="admin-table-user">
            <span style="font-size: 1.25rem;">${escapeHtml(m.avatar_emoji || '🎯')}</span>
            <span class="admin-table-name">${escapeHtml(m.name)}</span>
          </div>
        </td>
        <td>${formatNumber(m.members_count)}</td>
        <td>${formatNumber(m.events_count)}</td>
      </tr>
    `).join('');
  }

  function renderTopEvents(events) {
    const tbody = document.getElementById('top-events-table');
    if (!tbody) return;

    if (!events.length) {
      tbody.innerHTML = '<tr><td colspan="3" class="admin-text-center">No events yet</td></tr>';
      return;
    }

    tbody.innerHTML = events.slice(0, 5).map(e => `
      <tr>
        <td>
          <div class="admin-table-name">${escapeHtml(e.title)}</div>
          <div class="admin-table-sub">${escapeHtml(e.market_name)}</div>
        </td>
        <td>$${formatMoney(e.volume)}</td>
        <td><span class="admin-badge ${getStatusClass(e.status)}">${escapeHtml(e.status)}</span></td>
      </tr>
    `).join('');
  }

  function renderRecentActivity(bets, events) {
    const container = document.getElementById('recent-activity');
    if (!container) return;

    const activities = [];
    
    bets.slice(0, 5).forEach(b => {
      activities.push({
        type: 'bet',
        icon: 'bet',
        title: `@${b.username} placed ${b.shares} shares on ${b.side || b.outcome_id}`,
        meta: timeAgo(b.created_at),
        time: new Date(b.created_at)
      });
    });

    events.slice(0, 5).forEach(e => {
      activities.push({
        type: 'event',
        icon: 'event',
        title: `New event: ${e.title}`,
        meta: timeAgo(e.created_at),
        time: new Date(e.created_at)
      });
    });

    activities.sort((a, b) => b.time - a.time);

    if (!activities.length) {
      container.innerHTML = '<div class="admin-empty"><p class="admin-empty-text">No recent activity</p></div>';
      return;
    }

    container.innerHTML = activities.slice(0, 8).map(a => `
      <div class="admin-activity-item">
        <div class="admin-activity-icon ${a.icon}">
          ${a.icon === 'bet' ? 
            '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>' :
            '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg>'
          }
        </div>
        <div class="admin-activity-content">
          <div class="admin-activity-title">${escapeHtml(a.title)}</div>
          <div class="admin-activity-meta">${escapeHtml(a.meta)}</div>
        </div>
      </div>
    `).join('');
  }

  function renderRecentUsers(users) {
    const container = document.getElementById('recent-users');
    if (!container) return;

    if (!users.length) {
      container.innerHTML = '<div class="admin-empty"><p class="admin-empty-text">No users yet</p></div>';
      return;
    }

    container.innerHTML = users.map(u => {
      const initial = (u.name || u.username || '?').charAt(0).toUpperCase();
      return `
        <div class="admin-activity-item">
          <div class="admin-activity-icon user">
            <span style="font-size: 0.875rem; font-weight: 600;">${escapeHtml(initial)}</span>
          </div>
          <div class="admin-activity-content">
            <div class="admin-activity-title">
              ${escapeHtml(u.name || u.username)}
              ${u.is_admin ? '<span class="admin-badge primary" style="margin-left: 6px;">Admin</span>' : ''}
            </div>
            <div class="admin-activity-meta">@${escapeHtml(u.username)} · ${timeAgo(u.created_at)}</div>
          </div>
        </div>
      `;
    }).join('');
  }

  function getStatusClass(status) {
    switch (status) {
      case 'open': return 'success';
      case 'closed': return 'warning';
      case 'resolved': return 'neutral';
      case 'active': return 'success';
      case 'restricted': return 'warning';
      case 'suspended': return 'danger';
      case 'pending': return 'warning';
      default: return 'neutral';
    }
  }

  // ===========================================
  // USERS PANEL
  // ===========================================

  async function loadUsers(page = 1) {
    const tbody = document.getElementById('users-table');
    if (tbody) {
      tbody.innerHTML = '<tr><td colspan="8" class="admin-text-center">Loading users...</td></tr>';
    }

    const search = document.getElementById('users-search')?.value || '';
    const status = document.getElementById('users-filter-status')?.value || '';
    const role = document.getElementById('users-filter-role')?.value || '';

    let url = `api/admin-users.php?page=${page}`;
    if (search) url += `&q=${encodeURIComponent(search)}`;
    if (status) url += `&status=${encodeURIComponent(status)}`;
    if (role) url += `&role=${encodeURIComponent(role)}`;

    console.log('[Admin] Loading users from:', url);

    const res = await apiGet(url);
    
    console.log('[Admin] Users API response:', res);
    
    if (!res.ok) {
      const errorMsg = res.data?.error || 'Unknown error';
      console.error('[Admin] Failed to load users:', errorMsg);
      showToast('Failed to load users: ' + errorMsg, 'error');
      if (tbody) {
        tbody.innerHTML = `<tr><td colspan="8" class="admin-text-center" style="color: #ef4444;">Error: ${escapeHtml(errorMsg)}</td></tr>`;
      }
      return;
    }

    state.users = {
      page: res.data.pagination?.page || 1,
      data: res.data.users || [],
      total: res.data.pagination?.total || 0,
      pageSize: res.data.pagination?.page_size || 25
    };

    console.log('[Admin] Loaded', state.users.data.length, 'users');

    renderUsersTable();
    renderUsersPagination();
  }

  function renderUsersTable() {
    const tbody = document.getElementById('users-table');
    if (!tbody) return;

    if (!state.users.data.length) {
      tbody.innerHTML = '<tr><td colspan="8" class="admin-text-center">No users found</td></tr>';
      return;
    }

    tbody.innerHTML = state.users.data.map(u => {
      const initial = (u.name || u.username || '?').charAt(0).toUpperCase();
      return `
        <tr>
          <td>
            <div class="admin-table-user">
              <div class="admin-table-avatar">${escapeHtml(initial)}</div>
              <div>
                <div class="admin-table-name">
                  ${escapeHtml(u.name || u.username)}
                  ${u.is_admin ? '<span class="admin-badge primary" style="margin-left: 4px; font-size: 0.625rem;">ADMIN</span>' : ''}
                </div>
                <div class="admin-table-sub">@${escapeHtml(u.username)}</div>
              </div>
            </div>
          </td>
          <td>${escapeHtml(u.email)}</td>
          <td><span class="admin-badge ${getStatusClass(u.status)}">${escapeHtml(u.status)}</span></td>
          <td class="admin-font-mono">$${formatMoney(u.tokens_balance)}</td>
          <td>${formatNumber(u.markets_member)}</td>
          <td>${formatNumber(u.bets_count)}</td>
          <td>${formatDate(u.created_at)}</td>
          <td>
            <div class="admin-flex admin-gap-2">
              <button class="admin-btn admin-btn-sm admin-btn-secondary" onclick="adminViewUser(${u.id})">View</button>
              <button class="admin-btn admin-btn-sm admin-btn-secondary" onclick="adminToggleUserStatus(${u.id}, '${u.status}')">Toggle</button>
            </div>
          </td>
        </tr>
      `;
    }).join('');
  }

  function renderUsersPagination() {
    const container = document.getElementById('users-pagination');
    if (!container) return;

    const { page, total, pageSize } = state.users;
    const totalPages = Math.max(1, Math.ceil(total / pageSize));

    container.innerHTML = `
      <div class="admin-pagination-info">
        Showing ${((page - 1) * pageSize) + 1}–${Math.min(page * pageSize, total)} of ${formatNumber(total)}
      </div>
      <div class="admin-pagination-btns">
        <button class="admin-pagination-btn" ${page <= 1 ? 'disabled' : ''} onclick="adminUsersPage(${page - 1})">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <polyline points="15 18 9 12 15 6"/>
          </svg>
        </button>
        <span style="padding: 0 12px; color: var(--admin-text-secondary);">${page} / ${totalPages}</span>
        <button class="admin-pagination-btn" ${page >= totalPages ? 'disabled' : ''} onclick="adminUsersPage(${page + 1})">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <polyline points="9 18 15 12 9 6"/>
          </svg>
        </button>
      </div>
    `;
  }

  window.adminUsersPage = function(page) {
    loadUsers(page);
  };

  window.adminViewUser = async function(userId) {
    // Find user in loaded data
    const user = state.users.data.find(u => u.id === userId);
    if (!user) {
      showToast('User not found in loaded data. Try refreshing the page.', 'error');
      return;
    }

    const modalBody = document.getElementById('user-modal-body');
    if (!modalBody) return;

    modalBody.innerHTML = `
      <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 24px;">
        <div>
          <h4 style="margin-bottom: 16px; color: var(--admin-text-secondary);">Profile</h4>
          <div class="admin-form-group">
            <label class="admin-form-label">Name</label>
            <input type="text" class="admin-form-input" value="${escapeHtml(user.name)}" id="edit-user-name">
          </div>
          <div class="admin-form-group">
            <label class="admin-form-label">Username</label>
            <input type="text" class="admin-form-input" value="${escapeHtml(user.username)}" id="edit-user-username" disabled>
          </div>
          <div class="admin-form-group">
            <label class="admin-form-label">Email</label>
            <input type="email" class="admin-form-input" value="${escapeHtml(user.email)}" id="edit-user-email">
          </div>
          <div class="admin-form-group">
            <label class="admin-form-label">Status</label>
            <select class="admin-form-select" id="edit-user-status">
              <option value="active" ${user.status === 'active' ? 'selected' : ''}>Active</option>
              <option value="restricted" ${user.status === 'restricted' ? 'selected' : ''}>Restricted</option>
              <option value="suspended" ${user.status === 'suspended' ? 'selected' : ''}>Suspended</option>
            </select>
          </div>
          <div class="admin-form-group">
            <label class="admin-form-label">Role</label>
            <select class="admin-form-select" id="edit-user-admin">
              <option value="0" ${!user.is_admin ? 'selected' : ''}>User</option>
              <option value="1" ${user.is_admin ? 'selected' : ''}>Admin</option>
            </select>
          </div>
        </div>
        <div>
          <h4 style="margin-bottom: 16px; color: var(--admin-text-secondary);">Tokens & Stats</h4>
          <div class="admin-form-group">
            <label class="admin-form-label">Token Balance</label>
            <input type="number" class="admin-form-input" value="${user.tokens_balance || 0}" id="edit-user-tokens" step="0.01">
          </div>
          <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-top: 16px;">
            <div class="admin-kpi-card" style="padding: 12px;">
              <div class="admin-kpi-value" style="font-size: 1.5rem;">${formatNumber(user.markets_member || 0)}</div>
              <div class="admin-kpi-label">Markets Joined</div>
            </div>
            <div class="admin-kpi-card" style="padding: 12px;">
              <div class="admin-kpi-value" style="font-size: 1.5rem;">${formatNumber(user.events_created || 0)}</div>
              <div class="admin-kpi-label">Events Created</div>
            </div>
            <div class="admin-kpi-card" style="padding: 12px;">
              <div class="admin-kpi-value" style="font-size: 1.5rem;">${formatNumber(user.bets_count || 0)}</div>
              <div class="admin-kpi-label">Bets Placed</div>
            </div>
            <div class="admin-kpi-card" style="padding: 12px;">
              <div class="admin-kpi-value" style="font-size: 1.5rem;">${formatDate(user.created_at)}</div>
              <div class="admin-kpi-label">Joined</div>
            </div>
          </div>
          <div class="admin-form-group" style="margin-top: 16px;">
            <label class="admin-form-label">Add Admin Note</label>
            <textarea class="admin-form-textarea" id="edit-user-note" placeholder="Internal note about this user..."></textarea>
          </div>
        </div>
      </div>
    `;

    // Store user ID for save
    modalBody.dataset.userId = userId;

    // Show modal
    document.getElementById('user-modal-overlay').classList.add('active');
  };

  window.adminToggleUserStatus = async function(userId, currentStatus) {
    const nextStatus = currentStatus === 'active' ? 'restricted' : 
                       currentStatus === 'restricted' ? 'suspended' : 'active';
    
    if (!confirm(`Change user status from ${currentStatus} to ${nextStatus}?`)) return;

    const res = await apiPost('api/admin-users.php', {
      action: 'set_status',
      user_id: userId,
      status: nextStatus
    });

    if (res.ok) {
      showToast('User status updated', 'success');
      loadUsers(state.users.page);
    } else {
      showToast(res.data.error || 'Failed to update status', 'error');
    }
  };

  // ===========================================
  // MARKETS PANEL
  // ===========================================

  async function loadMarkets(page = 1) {
    const search = document.getElementById('markets-search')?.value || '';
    const visibility = document.getElementById('markets-filter-visibility')?.value || '';

    let url = `api/admin-markets.php?page=${page}`;
    if (search) url += `&q=${encodeURIComponent(search)}`;
    if (visibility) url += `&visibility=${encodeURIComponent(visibility)}`;

    const res = await apiGet(url);
    if (!res.ok) {
      // Fallback to basic markets data
      const tbody = document.getElementById('markets-table');
      if (tbody) {
        tbody.innerHTML = '<tr><td colspan="7" class="admin-text-center">Markets API coming soon</td></tr>';
      }
      return;
    }

    state.markets = {
      page: res.data.pagination?.page || 1,
      data: res.data.markets || [],
      total: res.data.pagination?.total || 0,
      pageSize: res.data.pagination?.page_size || 25
    };

    renderMarketsTable();
  }

  function renderMarketsTable() {
    const tbody = document.getElementById('markets-table');
    if (!tbody) return;

    if (!state.markets.data.length) {
      tbody.innerHTML = '<tr><td colspan="7" class="admin-text-center">No markets found</td></tr>';
      return;
    }

    tbody.innerHTML = state.markets.data.map(m => `
      <tr>
        <td>
          <div class="admin-table-user">
            <span style="font-size: 1.5rem;">${escapeHtml(m.avatar_emoji || '🎯')}</span>
            <div>
              <div class="admin-table-name">${escapeHtml(m.name)}</div>
              <div class="admin-table-sub">${escapeHtml(m.description || '').substring(0, 50)}</div>
            </div>
          </div>
        </td>
        <td>@${escapeHtml(m.owner_username || m.owner_id)}</td>
        <td><span class="admin-badge neutral">${escapeHtml(m.visibility)}</span></td>
        <td>${formatNumber(m.members_count)}</td>
        <td>${formatNumber(m.events_count)}</td>
        <td>${formatDate(m.created_at)}</td>
        <td>
          <button class="admin-btn admin-btn-sm admin-btn-secondary" onclick="window.open('market.php?id=${m.id}', '_blank')">View</button>
        </td>
      </tr>
    `).join('');
  }

  // ===========================================
  // EVENTS PANEL
  // ===========================================

  async function loadEvents(page = 1) {
    const search = document.getElementById('events-search')?.value || '';
    const status = document.getElementById('events-filter-status')?.value || '';
    const type = document.getElementById('events-filter-type')?.value || '';

    let url = `api/admin-events.php?page=${page}`;
    if (search) url += `&q=${encodeURIComponent(search)}`;
    if (status) url += `&status=${encodeURIComponent(status)}`;
    if (type) url += `&type=${encodeURIComponent(type)}`;

    const res = await apiGet(url);
    if (!res.ok) {
      const tbody = document.getElementById('events-table');
      if (tbody) {
        tbody.innerHTML = '<tr><td colspan="7" class="admin-text-center">Events API coming soon</td></tr>';
      }
      return;
    }

    state.events = {
      page: res.data.pagination?.page || 1,
      data: res.data.events || [],
      total: res.data.pagination?.total || 0,
      pageSize: res.data.pagination?.page_size || 25
    };

    renderEventsTable();
  }

  function renderEventsTable() {
    const tbody = document.getElementById('events-table');
    if (!tbody) return;

    if (!state.events.data.length) {
      tbody.innerHTML = '<tr><td colspan="7" class="admin-text-center">No events found</td></tr>';
      return;
    }

    tbody.innerHTML = state.events.data.map(e => {
      let actionsHtml = `<button class="admin-btn admin-btn-sm admin-btn-secondary" onclick="window.open('event.php?id=${e.id}', '_blank')">View</button>`;
      
      if (e.status === 'open') {
        actionsHtml += `
          <button class="admin-btn admin-btn-sm admin-btn-warning" onclick="adminCloseEvent(${e.id})" title="Close trading">Close</button>
          <button class="admin-btn admin-btn-sm admin-btn-primary" onclick="adminResolveEvent(${e.id})" title="Resolve event">Resolve</button>
        `;
      } else if (e.status === 'closed') {
        actionsHtml += `
          <button class="admin-btn admin-btn-sm admin-btn-secondary" onclick="adminReopenEvent(${e.id})" title="Reopen trading">Reopen</button>
          <button class="admin-btn admin-btn-sm admin-btn-primary" onclick="adminResolveEvent(${e.id})" title="Resolve event">Resolve</button>
        `;
      } else if (e.status === 'resolved') {
        actionsHtml += `<span class="admin-badge success">✓ Settled</span>`;
      }
      
      // Add delete button for non-resolved events or events with no bets
      if (e.status !== 'resolved') {
        actionsHtml += `<button class="admin-btn admin-btn-sm admin-btn-danger" onclick="adminDeleteEvent(${e.id})" title="Delete event">🗑</button>`;
      }
      
      return `
        <tr>
          <td>
            <div class="admin-table-name">${escapeHtml(e.title)}</div>
          </td>
          <td>${escapeHtml(e.market_name)}</td>
          <td><span class="admin-badge ${e.event_type === 'binary' ? 'primary' : 'info'}">${escapeHtml(e.event_type)}</span></td>
          <td><span class="admin-badge ${getStatusClass(e.status)}">${escapeHtml(e.status)}</span></td>
          <td class="admin-font-mono">$${formatMoney(e.volume)}</td>
          <td>${formatDateTime(e.closes_at)}</td>
          <td>
            <div class="admin-flex admin-gap-2 admin-flex-wrap">
              ${actionsHtml}
            </div>
          </td>
        </tr>
      `;
    }).join('');
  }

  // ===========================================
  // BETS PANEL
  // ===========================================

  async function loadBets() {
    // Use admin-stats for now
    const res = await apiGet('api/admin-stats.php');
    if (!res.ok) return;

    const data = res.data;
    const kpis = data.kpis || {};

    setText('bets-total-volume', '$' + formatMoney(kpis.total_volume));
    setText('bets-total-count', formatNumber(kpis.total_bets));
    
    // Calculate tokens in circulation (sum of user balances)
    setText('bets-tokens-circulating', '$' + formatMoney(kpis.total_volume * 0.5)); // Approximation

    // Render bets table
    const bets = data.recent_bets || [];
    const tbody = document.getElementById('bets-table');
    if (!tbody) return;

    if (!bets.length) {
      tbody.innerHTML = '<tr><td colspan="7" class="admin-text-center">No bets yet</td></tr>';
      return;
    }

    tbody.innerHTML = bets.map(b => `
      <tr>
        <td>@${escapeHtml(b.username)}</td>
        <td>
          <div class="admin-table-name" style="max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
            ${escapeHtml(b.event_title)}
          </div>
        </td>
        <td><span class="admin-badge ${b.side === 'YES' ? 'success' : b.side === 'NO' ? 'danger' : 'info'}">${escapeHtml(b.side || b.outcome_id)}</span></td>
        <td>${formatNumber(b.shares)}</td>
        <td>${b.price}¢</td>
        <td class="admin-font-mono">$${formatMoney(b.notional)}</td>
        <td>${timeAgo(b.created_at)}</td>
      </tr>
    `).join('');
  }

  // ===========================================
  // DISPUTES PANEL
  // ===========================================

  async function loadDisputes() {
    const status = document.getElementById('disputes-filter-status')?.value || 'pending';
    
    const res = await apiGet(`api/admin-disputes.php?status=${status}`);
    if (!res.ok) {
      const tbody = document.getElementById('disputes-table');
      if (tbody) {
        tbody.innerHTML = '<tr><td colspan="6" class="admin-text-center">Disputes API coming soon</td></tr>';
      }
      return;
    }

    const disputes = res.data.disputes || [];
    const tbody = document.getElementById('disputes-table');
    if (!tbody) return;

    if (!disputes.length) {
      tbody.innerHTML = '<tr><td colspan="6" class="admin-text-center">No disputes found</td></tr>';
      return;
    }

    tbody.innerHTML = disputes.map(d => `
      <tr>
        <td>${escapeHtml(d.event_title)}</td>
        <td>@${escapeHtml(d.username)}</td>
        <td style="max-width: 300px;">${escapeHtml(d.reason)}</td>
        <td><span class="admin-badge ${getStatusClass(d.status)}">${escapeHtml(d.status)}</span></td>
        <td>${formatDateTime(d.created_at)}</td>
        <td>
          <button class="admin-btn admin-btn-sm admin-btn-primary">Review</button>
        </td>
      </tr>
    `).join('');
  }

  // ===========================================
  // GOSSIP PANEL
  // ===========================================

  async function loadGossip() {
    const res = await apiGet('api/admin-gossip.php');
    if (!res.ok) {
      const tbody = document.getElementById('gossip-table');
      if (tbody) {
        tbody.innerHTML = '<tr><td colspan="5" class="admin-text-center">Gossip API coming soon</td></tr>';
      }
      return;
    }

    const messages = res.data.messages || [];
    const tbody = document.getElementById('gossip-table');
    if (!tbody) return;

    if (!messages.length) {
      tbody.innerHTML = '<tr><td colspan="5" class="admin-text-center">No messages found</td></tr>';
      return;
    }

    tbody.innerHTML = messages.map(g => `
      <tr>
        <td>@${escapeHtml(g.username)}</td>
        <td>${escapeHtml(g.event_title)}</td>
        <td style="max-width: 300px;">${escapeHtml(g.message)}</td>
        <td>${timeAgo(g.created_at)}</td>
        <td>
          <button class="admin-btn admin-btn-sm admin-btn-danger" onclick="adminDeleteGossip(${g.id})">Delete</button>
        </td>
      </tr>
    `).join('');
  }

  window.adminDeleteGossip = async function(gossipId) {
    if (!confirm('Delete this message?')) return;
    
    const res = await apiPost('api/admin-gossip.php', {
      action: 'delete',
      gossip_id: gossipId
    });
    
    if (res.ok) {
      showToast('Message deleted', 'success');
      loadGossip();
    } else {
      showToast('Failed to delete: ' + (res.data?.error || 'Unknown error'), 'error');
    }
  };

  // ===========================================
  // RESOLUTION PANEL
  // ===========================================

  async function loadResolution() {
    const tbody = document.getElementById('resolution-table');
    if (tbody) {
      tbody.innerHTML = '<tr><td colspan="6" class="admin-text-center">Loading events...</td></tr>';
    }

    const status = document.getElementById('resolution-filter-status')?.value || 'closed';
    
    const res = await apiGet(`api/admin-events.php?status=${status}`);
    if (!res.ok) {
      if (tbody) {
        tbody.innerHTML = `<tr><td colspan="6" class="admin-text-center" style="color: #ef4444;">Error: ${escapeHtml(res.data?.error || 'Failed to load')}</td></tr>`;
      }
      return;
    }

    const events = res.data.events || [];
    if (!tbody) return;

    if (!events.length) {
      const statusText = status === 'closed' ? 'closed (pending resolution)' : status;
      tbody.innerHTML = `<tr><td colspan="6" class="admin-text-center">No ${statusText} events found</td></tr>`;
      return;
    }

    tbody.innerHTML = events.map(e => {
      let actionsHtml = '';
      
      if (e.status === 'open') {
        actionsHtml = `
          <div class="admin-flex admin-gap-2">
            <button class="admin-btn admin-btn-sm admin-btn-secondary" onclick="adminCloseEvent(${e.id})">Close</button>
            <button class="admin-btn admin-btn-sm admin-btn-primary" onclick="adminResolveEvent(${e.id})">Resolve</button>
          </div>
        `;
      } else if (e.status === 'closed') {
        actionsHtml = `
          <div class="admin-flex admin-gap-2">
            <button class="admin-btn admin-btn-sm admin-btn-secondary" onclick="adminReopenEvent(${e.id})">Reopen</button>
            <button class="admin-btn admin-btn-sm admin-btn-primary" onclick="adminResolveEvent(${e.id})">Resolve</button>
          </div>
        `;
      } else {
        actionsHtml = `
          <span class="admin-badge success" style="font-weight: 600;">
            Winner: ${escapeHtml(e.winning_side || e.winning_outcome_id || 'N/A')}
          </span>
        `;
      }

      return `
        <tr>
          <td>
            <div class="admin-table-name">${escapeHtml(e.title)}</div>
            <div class="admin-table-sub">ID: ${e.id} · Created: ${formatDate(e.created_at)}</div>
          </td>
          <td>${escapeHtml(e.market_name || 'Unknown')}</td>
          <td><span class="admin-badge ${e.event_type === 'binary' ? 'primary' : 'info'}">${escapeHtml(e.event_type)}</span></td>
          <td class="admin-font-mono">$${formatMoney(e.volume)}</td>
          <td>
            ${e.event_type === 'binary' ? 
              `<span style="color: #22c55e;">YES ${e.yes_percent || 50}%</span> / <span style="color: #ef4444;">NO ${e.no_percent || 50}%</span>` :
              `${getOutcomesPreview(e.outcomes_json)}`
            }
          </td>
          <td>${actionsHtml}</td>
        </tr>
      `;
    }).join('');
  }

  function getOutcomesPreview(outcomesJson) {
    if (!outcomesJson) return 'No outcomes';
    try {
      const outcomes = JSON.parse(outcomesJson);
      if (Array.isArray(outcomes) && outcomes.length > 0) {
        return outcomes.slice(0, 2).map(o => `${escapeHtml(o.label)} (${o.probability}%)`).join(', ') + 
          (outcomes.length > 2 ? ` +${outcomes.length - 2} more` : '');
      }
    } catch (e) {}
    return 'Multiple outcomes';
  }

  window.adminCloseEvent = async function(eventId) {
    if (!confirm('Close this event for trading? Users will no longer be able to place bets.')) return;
    
    const res = await apiPost('api/admin-events.php', {
      action: 'close',
      event_id: eventId
    });
    
    if (res.ok) {
      showToast('Event closed successfully', 'success');
      loadEvents(state.events.page); // Reload events table
      loadResolution();
    } else {
      showToast('Failed to close event: ' + (res.data?.error || 'Unknown error'), 'error');
    }
  };

  window.adminReopenEvent = async function(eventId) {
    if (!confirm('Reopen this event for trading?')) return;
    
    const res = await apiPost('api/admin-events.php', {
      action: 'reopen',
      event_id: eventId
    });
    
    if (res.ok) {
      showToast('Event reopened successfully', 'success');
      loadEvents(state.events.page); // Reload events table
      loadResolution();
    } else {
      showToast('Failed to reopen event: ' + (res.data?.error || 'Unknown error'), 'error');
    }
  };

  window.adminDeleteEvent = async function(eventId) {
    if (!confirm('⚠️ DELETE this event permanently? This cannot be undone.')) return;
    if (!confirm('Are you REALLY sure? All bets on this event will be lost!')) return;
    
    const res = await apiPost('api/admin-events.php', {
      action: 'delete',
      event_id: eventId
    });
    
    if (res.ok) {
      showToast('Event deleted successfully', 'success');
      loadEvents(state.events.page); // Reload events table
      loadResolution();
    } else {
      showToast('Failed to delete event: ' + (res.data?.error || 'Unknown error'), 'error');
    }
  };

  window.adminResolveEvent = async function(eventId) {
    // Fetch event details using admin API
    const res = await apiGet(`api/admin-events.php?event_id=${eventId}`);
    if (!res.ok) {
      showToast('Failed to load event: ' + (res.data?.error || 'Unknown error'), 'error');
      return;
    }

    const event = res.data.event || res.data;
    const modalBody = document.getElementById('resolve-modal-body');
    if (!modalBody) return;

    const isBinary = event.event_type === 'binary';
    
    // Parse outcomes for multiple choice events
    let outcomesHtml = '';
    if (!isBinary && event.outcomes_json) {
      try {
        const outcomes = JSON.parse(event.outcomes_json);
        if (Array.isArray(outcomes) && outcomes.length > 0) {
          outcomesHtml = `
            <div class="admin-form-group">
              <label class="admin-form-label">Select Winning Outcome</label>
              <div style="display: flex; flex-direction: column; gap: 8px;">
                ${outcomes.map(o => `
                  <label style="display: flex; align-items: center; gap: 8px; cursor: pointer; padding: 8px; border: 1px solid var(--admin-border); border-radius: 6px;">
                    <input type="radio" name="winning_outcome" value="${escapeHtml(o.id)}" ${event.winning_outcome_id === o.id ? 'checked' : ''}>
                    <span>${escapeHtml(o.label)} (${o.probability}%)</span>
                  </label>
                `).join('')}
              </div>
            </div>
          `;
        }
      } catch (e) {
        console.error('Failed to parse outcomes:', e);
      }
    }

    modalBody.innerHTML = `
      <div style="margin-bottom: 16px;">
        <h4 style="color: var(--admin-text); margin-bottom: 8px;">${escapeHtml(event.title)}</h4>
        <p style="color: var(--admin-text-secondary); font-size: 0.875rem;">${escapeHtml(event.description || 'No description')}</p>
        <div style="margin-top: 12px; display: flex; gap: 12px;">
          <span class="admin-badge ${event.status === 'open' ? 'success' : event.status === 'closed' ? 'warning' : 'neutral'}">
            ${escapeHtml(event.status)}
          </span>
          <span class="admin-badge ${isBinary ? 'primary' : 'info'}">${isBinary ? 'Binary' : 'Multiple Choice'}</span>
          <span style="color: var(--admin-text-secondary);">Volume: $${formatMoney(event.volume)}</span>
        </div>
      </div>
      
      ${isBinary ? `
        <div class="admin-form-group">
          <label class="admin-form-label">Select Winning Side</label>
          <div style="display: flex; gap: 12px;">
            <label style="display: flex; align-items: center; gap: 8px; cursor: pointer; padding: 12px 20px; border: 2px solid ${event.winning_side === 'YES' ? '#22c55e' : 'var(--admin-border)'}; border-radius: 8px; background: ${event.winning_side === 'YES' ? 'rgba(34, 197, 94, 0.1)' : 'transparent'};">
              <input type="radio" name="winning_side" value="YES" ${event.winning_side === 'YES' ? 'checked' : ''}>
              <span style="font-weight: 600; color: #22c55e; font-size: 1.1rem;">✓ YES</span>
            </label>
            <label style="display: flex; align-items: center; gap: 8px; cursor: pointer; padding: 12px 20px; border: 2px solid ${event.winning_side === 'NO' ? '#ef4444' : 'var(--admin-border)'}; border-radius: 8px; background: ${event.winning_side === 'NO' ? 'rgba(239, 68, 68, 0.1)' : 'transparent'};">
              <input type="radio" name="winning_side" value="NO" ${event.winning_side === 'NO' ? 'checked' : ''}>
              <span style="font-weight: 600; color: #ef4444; font-size: 1.1rem;">✗ NO</span>
            </label>
          </div>
        </div>
      ` : outcomesHtml || `
        <div class="admin-form-group">
          <label class="admin-form-label">Winning Outcome ID</label>
          <input type="text" class="admin-form-input" id="resolve-outcome" value="${escapeHtml(event.winning_outcome_id || '')}" placeholder="Enter outcome ID">
        </div>
      `}
      
      <div class="admin-alert admin-alert-info" style="margin-top: 16px;">
        <strong>Note:</strong> Resolving this event will distribute tokens to winners based on the parimutuel pool system.
      </div>
    `;

    modalBody.dataset.eventId = eventId;
    modalBody.dataset.eventType = event.event_type;
    modalBody.dataset.eventStatus = event.status;

    document.getElementById('resolve-modal-overlay').classList.add('active');
  };

  // ===========================================
  // ANALYTICS PANEL
  // ===========================================

  async function loadAnalytics() {
    const res = await apiGet('api/admin-stats.php');
    if (!res.ok) return;

    const data = res.data;
    const kpis = data.kpis || {};

    // Update KPIs
    setText('analytics-dau', formatNumber(kpis.dau || 0));
    setText('analytics-wau', formatNumber(kpis.wau || 0));
    setText('analytics-mau', formatNumber(kpis.mau || 0));
    
    // Calculate retention (WAU/MAU ratio as a simple metric)
    const retention = kpis.mau > 0 ? Math.round((kpis.wau / kpis.mau) * 100) : 0;
    setText('analytics-retention', retention + '%');

    // Render Activity Chart (bets over time)
    renderActivityChart(data.series?.bets || []);
    
    // Render Outcomes Chart (events by status)
    renderOutcomesChart(kpis);
  }

  function renderActivityChart(series) {
    const ctx = document.getElementById('chart-activity');
    if (!ctx || !window.Chart) return;

    if (state.charts.activity) {
      state.charts.activity.destroy();
    }

    const labels = series.map(p => p.date);
    const bets = series.map(p => p.bets);

    state.charts.activity = new Chart(ctx, {
      type: 'bar',
      data: {
        labels,
        datasets: [{
          label: 'Bets per Day',
          data: bets,
          backgroundColor: 'rgba(99, 102, 241, 0.6)',
          borderColor: '#6366f1',
          borderWidth: 1,
          borderRadius: 4
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          title: {
            display: true,
            text: 'Daily Betting Activity',
            color: '#9898a6',
            font: { size: 14 }
          }
        },
        scales: {
          x: {
            grid: { color: 'rgba(255,255,255,0.05)' },
            ticks: { color: '#6b6b78', maxTicksLimit: 10 }
          },
          y: {
            beginAtZero: true,
            grid: { color: 'rgba(255,255,255,0.05)' },
            ticks: { color: '#6b6b78', precision: 0 }
          }
        }
      }
    });
  }

  function renderOutcomesChart(kpis) {
    const ctx = document.getElementById('chart-outcomes');
    if (!ctx || !window.Chart) return;

    if (state.charts.outcomes) {
      state.charts.outcomes.destroy();
    }

    const openEvents = kpis.events_open || 0;
    const closedEvents = kpis.events_closed || 0;
    const resolvedEvents = kpis.events_resolved || 0;

    state.charts.outcomes = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: ['Open', 'Closed', 'Resolved'],
        datasets: [{
          data: [openEvents, closedEvents, resolvedEvents],
          backgroundColor: [
            'rgba(16, 185, 129, 0.8)',  // green for open
            'rgba(245, 158, 11, 0.8)',  // yellow for closed
            'rgba(99, 102, 241, 0.8)'   // purple for resolved
          ],
          borderColor: [
            'rgba(16, 185, 129, 1)',
            'rgba(245, 158, 11, 1)',
            'rgba(99, 102, 241, 1)'
          ],
          borderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'bottom',
            labels: { color: '#9898a6', padding: 16 }
          },
          title: {
            display: true,
            text: 'Events by Status',
            color: '#9898a6',
            font: { size: 14 }
          }
        },
        cutout: '60%'
      }
    });
  }

  // ===========================================
  // AUDIT LOG PANEL
  // ===========================================

  async function loadAuditLog() {
    const actionFilter = document.getElementById('audit-filter-action')?.value || '';
    
    let url = 'api/admin-audit.php';
    if (actionFilter) url += `?action=${encodeURIComponent(actionFilter)}`;
    
    const res = await apiGet(url);
    
    const tbody = document.getElementById('audit-table');
    if (!tbody) return;
    
    if (!res.ok) {
      // Audit log might not exist yet, show helpful message
      tbody.innerHTML = `
        <tr><td colspan="5" class="admin-text-center">
          <div style="padding: 24px;">
            <p style="color: var(--admin-text-secondary); margin-bottom: 8px;">
              No audit entries yet.
            </p>
            <p style="color: var(--admin-text-muted); font-size: 0.875rem;">
              Admin actions like user updates, event resolutions, and token adjustments will be logged here.
            </p>
          </div>
        </td></tr>
      `;
      return;
    }

    const entries = res.data.entries || [];
    
    if (!entries.length) {
      tbody.innerHTML = `
        <tr><td colspan="5" class="admin-text-center">
          <div style="padding: 24px;">
            <p style="color: var(--admin-text-secondary);">No audit entries found.</p>
          </div>
        </td></tr>
      `;
      return;
    }

    tbody.innerHTML = entries.map(e => `
      <tr>
        <td>${formatDateTime(e.created_at)}</td>
        <td>
          <div class="admin-table-user">
            <div class="admin-table-avatar" style="width: 28px; height: 28px; font-size: 0.75rem;">
              ${escapeHtml((e.admin_name || 'A').charAt(0).toUpperCase())}
            </div>
            <span>@${escapeHtml(e.admin_username || 'admin')}</span>
          </div>
        </td>
        <td><span class="admin-badge ${getAuditActionClass(e.action)}">${escapeHtml(formatAuditAction(e.action))}</span></td>
        <td>${escapeHtml(e.target_type ? `${e.target_type} #${e.target_id}` : '–')}</td>
        <td style="max-width: 300px;">
          <span style="color: var(--admin-text-secondary);">${escapeHtml(e.details || '')}</span>
        </td>
      </tr>
    `).join('');
  }

  function formatAuditAction(action) {
    const map = {
      'user_update': 'User Update',
      'user_status_change': 'Status Change',
      'user_role_change': 'Role Change',
      'event_resolve': 'Event Resolution',
      'event_close': 'Event Closed',
      'token_adjust': 'Token Adjustment',
      'market_delete': 'Market Deleted',
      'gossip_delete': 'Gossip Deleted',
      'dispute_resolve': 'Dispute Resolved'
    };
    return map[action] || action;
  }

  function getAuditActionClass(action) {
    if (action.includes('delete') || action.includes('suspend')) return 'danger';
    if (action.includes('resolve') || action.includes('approve')) return 'success';
    if (action.includes('update') || action.includes('change')) return 'warning';
    return 'info';
  }

  // ===========================================
  // MODAL HANDLERS
  // ===========================================

  function initModals() {
    // User modal
    const userModalOverlay = document.getElementById('user-modal-overlay');
    const userModalClose = document.getElementById('user-modal-close');
    const userModalCancel = document.getElementById('user-modal-cancel');
    const userModalSave = document.getElementById('user-modal-save');

    if (userModalClose) {
      userModalClose.addEventListener('click', () => {
        userModalOverlay.classList.remove('active');
      });
    }

    if (userModalCancel) {
      userModalCancel.addEventListener('click', () => {
        userModalOverlay.classList.remove('active');
      });
    }

    if (userModalSave) {
      userModalSave.addEventListener('click', async () => {
        const modalBody = document.getElementById('user-modal-body');
        const userId = parseInt(modalBody.dataset.userId, 10);
        if (!userId) return;

        const status = document.getElementById('edit-user-status')?.value;
        const isAdmin = document.getElementById('edit-user-admin')?.value === '1';
        const tokens = parseFloat(document.getElementById('edit-user-tokens')?.value) || 0;
        const note = document.getElementById('edit-user-note')?.value;

        // Update status
        if (status) {
          await apiPost('api/admin-users.php', {
            action: 'set_status',
            user_id: userId,
            status
          });
        }

        // Update admin role
        await apiPost('api/admin-users.php', {
          action: isAdmin ? 'set_admin' : 'unset_admin',
          user_id: userId
        });

        // Add note if provided
        if (note) {
          await apiPost('api/admin-users.php', {
            action: 'add_note',
            user_id: userId,
            note
          });
        }

        showToast('User updated successfully', 'success');
        userModalOverlay.classList.remove('active');
        loadUsers(state.users.page);
      });
    }

    // Resolution modal
    const resolveModalOverlay = document.getElementById('resolve-modal-overlay');
    const resolveModalClose = document.getElementById('resolve-modal-close');
    const resolveModalCancel = document.getElementById('resolve-modal-cancel');
    const resolveModalConfirm = document.getElementById('resolve-modal-confirm');

    if (resolveModalClose) {
      resolveModalClose.addEventListener('click', () => {
        resolveModalOverlay.classList.remove('active');
      });
    }

    if (resolveModalCancel) {
      resolveModalCancel.addEventListener('click', () => {
        resolveModalOverlay.classList.remove('active');
      });
    }

    if (resolveModalConfirm) {
      resolveModalConfirm.addEventListener('click', async () => {
        const modalBody = document.getElementById('resolve-modal-body');
        const eventId = parseInt(modalBody.dataset.eventId, 10);
        const eventType = modalBody.dataset.eventType;
        const eventStatus = modalBody.dataset.eventStatus;
        if (!eventId) return;

        let winningSide = null;
        let winningOutcome = null;

        if (eventType === 'binary') {
          winningSide = document.querySelector('input[name="winning_side"]:checked')?.value;
          if (!winningSide) {
            showToast('Please select a winning side (YES or NO)', 'error');
            return;
          }
        } else {
          // Check for radio button selection first
          winningOutcome = document.querySelector('input[name="winning_outcome"]:checked')?.value;
          // Fall back to text input
          if (!winningOutcome) {
            winningOutcome = document.getElementById('resolve-outcome')?.value;
          }
          if (!winningOutcome) {
            showToast('Please select or enter a winning outcome', 'error');
            return;
          }
        }

        // Disable button and show loading
        resolveModalConfirm.disabled = true;
        resolveModalConfirm.innerHTML = '<span class="admin-spinner"></span> Resolving...';

        try {
          // If event is open, close it first
          if (eventStatus === 'open') {
            const closeRes = await apiPost('api/admin-events.php', {
              action: 'close',
              event_id: eventId
            });
            if (!closeRes.ok) {
              throw new Error(closeRes.data?.error || 'Failed to close event');
            }
          }

          // Now resolve the event
          const resolveRes = await apiPost('api/admin-events.php', {
            action: 'resolve',
            event_id: eventId,
            winning_side: winningSide,
            winning_outcome_id: winningOutcome
          });

          if (resolveRes.ok) {
            showToast('Event resolved successfully! Tokens distributed to winners.', 'success');
            resolveModalOverlay.classList.remove('active');
            loadEvents(state.events.page); // Reload events table
            loadResolution();
          } else {
            throw new Error(resolveRes.data?.error || 'Failed to resolve event');
          }
        } catch (err) {
          showToast('Error: ' + err.message, 'error');
        } finally {
          resolveModalConfirm.disabled = false;
          resolveModalConfirm.innerHTML = 'Resolve Event';
        }
      });
    }

    // Close on overlay click
    [userModalOverlay, resolveModalOverlay].forEach(overlay => {
      if (overlay) {
        overlay.addEventListener('click', (e) => {
          if (e.target === overlay) {
            overlay.classList.remove('active');
          }
        });
      }
    });
  }

  // ===========================================
  // SEARCH & FILTERS
  // ===========================================

  function initFilters() {
    // Users filters
    const usersSearch = document.getElementById('users-search');
    const usersFilterStatus = document.getElementById('users-filter-status');
    const usersFilterRole = document.getElementById('users-filter-role');

    if (usersSearch) {
      usersSearch.addEventListener('input', debounce(() => loadUsers(1), 300));
    }
    if (usersFilterStatus) {
      usersFilterStatus.addEventListener('change', () => loadUsers(1));
    }
    if (usersFilterRole) {
      usersFilterRole.addEventListener('change', () => loadUsers(1));
    }

    // Markets filters
    const marketsSearch = document.getElementById('markets-search');
    const marketsFilterVisibility = document.getElementById('markets-filter-visibility');

    if (marketsSearch) {
      marketsSearch.addEventListener('input', debounce(() => loadMarkets(1), 300));
    }
    if (marketsFilterVisibility) {
      marketsFilterVisibility.addEventListener('change', () => loadMarkets(1));
    }

    // Events filters
    const eventsSearch = document.getElementById('events-search');
    const eventsFilterStatus = document.getElementById('events-filter-status');
    const eventsFilterType = document.getElementById('events-filter-type');

    if (eventsSearch) {
      eventsSearch.addEventListener('input', debounce(() => loadEvents(1), 300));
    }
    if (eventsFilterStatus) {
      eventsFilterStatus.addEventListener('change', () => loadEvents(1));
    }
    if (eventsFilterType) {
      eventsFilterType.addEventListener('change', () => loadEvents(1));
    }

    // Disputes filter
    const disputesFilterStatus = document.getElementById('disputes-filter-status');
    if (disputesFilterStatus) {
      disputesFilterStatus.addEventListener('change', () => loadDisputes());
    }

    // Resolution filter
    const resolutionFilterStatus = document.getElementById('resolution-filter-status');
    if (resolutionFilterStatus) {
      resolutionFilterStatus.addEventListener('change', () => loadResolution());
    }

    // Audit log filter
    const auditFilterAction = document.getElementById('audit-filter-action');
    if (auditFilterAction) {
      auditFilterAction.addEventListener('change', () => loadAuditLog());
    }

    // Refresh button
    const refreshBtn = document.getElementById('refresh-btn');
    if (refreshBtn) {
      refreshBtn.addEventListener('click', () => {
        loadPanelData(state.currentPanel);
        showToast('Data refreshed', 'info');
      });
    }

    // Nuclear Reset button
    const nuclearResetBtn = document.getElementById('nuclear-reset-btn');
    if (nuclearResetBtn) {
      nuclearResetBtn.addEventListener('click', handleNuclearReset);
    }
  }

  // ===========================================
  // NUCLEAR RESET
  // ===========================================

  async function handleNuclearReset() {
    // First confirmation
    const confirm1 = confirm(
      '☢️ NUCLEAR RESET WARNING ☢️\n\n' +
      'This will permanently DELETE all data from the platform:\n' +
      '• All users (except your admin account)\n' +
      '• All markets and events\n' +
      '• All bets and gossip\n' +
      '• All notifications and friendships\n\n' +
      'This action CANNOT be undone!\n\n' +
      'Are you ABSOLUTELY sure you want to proceed?'
    );
    
    if (!confirm1) {
      showToast('Nuclear reset cancelled', 'info');
      return;
    }

    // Second confirmation with typed input
    const confirm2 = prompt(
      '⚠️ FINAL CONFIRMATION ⚠️\n\n' +
      'Type "RESET_ALL_DATA" (without quotes) to confirm the nuclear reset:'
    );
    
    if (confirm2 !== 'RESET_ALL_DATA') {
      showToast('Nuclear reset cancelled - confirmation text did not match', 'warning');
      return;
    }

    // Show loading state
    const btn = document.getElementById('nuclear-reset-btn');
    if (btn) {
      btn.disabled = true;
      btn.innerHTML = '<span class="admin-spinner"></span> Resetting...';
    }

    try {
      const res = await apiPost('api/admin-reset.php', {
        action: 'nuclear_reset',
        confirmation: 'RESET_ALL_DATA'
      });

      if (res.ok) {
        const deleted = res.data.deleted || {};
        showToast(
          `☢️ Nuclear reset complete! Deleted: ${deleted.users || 0} users, ${deleted.markets || 0} markets, ${deleted.events || 0} events, ${deleted.bets || 0} bets`,
          'success'
        );
        
        // Refresh all data
        setTimeout(() => {
          loadOverviewData();
        }, 1000);
      } else {
        showToast('Reset failed: ' + (res.data.error || 'Unknown error'), 'error');
      }
    } catch (err) {
      console.error('Nuclear reset error:', err);
      showToast('Reset failed: Network error', 'error');
    } finally {
      if (btn) {
        btn.disabled = false;
        btn.innerHTML = `
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16" style="margin-right: 8px;">
            <path d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/>
          </svg>
          ☢️ Perform Nuclear Reset
        `;
      }
    }
  }

  // ===========================================
  // INITIALIZATION
  // ===========================================

  function init() {
    initNavigation();
    initModals();
    initFilters();
    
    // Load initial data
    loadOverviewData();
  }

  // Start when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();

