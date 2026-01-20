<?php
/**
 * Tyches Admin Panel
 * Comprehensive platform management dashboard
 */

declare(strict_types=1);

require_once __DIR__ . '/api/security.php';
require_once __DIR__ . '/includes/asset-helpers.php';

tyches_start_session();
$pdo = get_pdo();

// Check admin user
$current = fetch_current_user($pdo);
if (
    !$current ||
    (int)$current['is_admin'] !== 1 ||
    ($current['status'] ?? 'active') !== 'active'
) {
    http_response_code(403);
    header('Location: index.php');
    exit;
}

$adminName = $current['name'] ?? $current['username'] ?? 'Admin';
$adminInitial = strtoupper(substr($adminName, 0, 1));
$csrfToken = tyches_get_csrf_token();

// Quick stats for badges
$pendingDisputes = (int)$pdo->query("SELECT COUNT(*) FROM resolution_disputes WHERE status = 'pending'")->fetchColumn();
$unverifiedUsers = (int)$pdo->query("SELECT COUNT(*) FROM users WHERE email_verified_at IS NULL")->fetchColumn();
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Admin Panel - Tyches</title>
  <meta name="robots" content="noindex, nofollow">
  <meta name="csrf-token" content="<?php echo e($csrfToken); ?>">
  <?php css_link('admin-styles.css'); ?>
  <link rel="icon" href="favicon.ico">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
  <div class="admin-layout">
    <!-- Sidebar -->
    <aside class="admin-sidebar" id="admin-sidebar">
      <div class="admin-sidebar-header">
        <div class="admin-sidebar-logo">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M12 2L15 8H21L17 12L18 18L12 15L6 18L7 12L3 8H9L12 2Z"/>
          </svg>
        </div>
        <div class="admin-sidebar-brand">
          <span class="admin-sidebar-title">Tyches</span>
          <span class="admin-sidebar-subtitle">Admin Panel</span>
        </div>
      </div>

      <nav class="admin-nav">
        <!-- Main Navigation -->
        <div class="admin-nav-section">
          <div class="admin-nav-label">Main</div>
          <button class="admin-nav-item active" data-panel="overview">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <rect x="3" y="3" width="7" height="7" rx="1"/>
              <rect x="14" y="3" width="7" height="7" rx="1"/>
              <rect x="3" y="14" width="7" height="7" rx="1"/>
              <rect x="14" y="14" width="7" height="7" rx="1"/>
            </svg>
            <span>Overview</span>
          </button>
          <button class="admin-nav-item" data-panel="users">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
              <circle cx="9" cy="7" r="4"/>
              <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
              <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
            </svg>
            <span>Users</span>
            <?php if ($unverifiedUsers > 0): ?>
              <span class="admin-nav-badge"><?php echo $unverifiedUsers > 99 ? '99+' : $unverifiedUsers; ?></span>
            <?php endif; ?>
          </button>
          <button class="admin-nav-item" data-panel="markets">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <circle cx="12" cy="12" r="10"/>
              <path d="M8 14s1.5 2 4 2 4-2 4-2"/>
              <line x1="9" y1="9" x2="9.01" y2="9"/>
              <line x1="15" y1="9" x2="15.01" y2="9"/>
            </svg>
            <span>Markets</span>
          </button>
          <button class="admin-nav-item" data-panel="events">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10z"/>
              <path d="M12 6v6l4 2"/>
            </svg>
            <span>Events</span>
          </button>
          <button class="admin-nav-item" data-panel="bets">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/>
            </svg>
            <span>Bets & Tokens</span>
          </button>
        </div>

        <!-- Moderation -->
        <div class="admin-nav-section">
          <div class="admin-nav-label">Moderation</div>
          <button class="admin-nav-item" data-panel="disputes">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/>
              <line x1="12" y1="9" x2="12" y2="13"/>
              <line x1="12" y1="17" x2="12.01" y2="17"/>
            </svg>
            <span>Disputes</span>
            <?php if ($pendingDisputes > 0): ?>
              <span class="admin-nav-badge"><?php echo $pendingDisputes; ?></span>
            <?php endif; ?>
          </button>
          <button class="admin-nav-item" data-panel="gossip">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
            </svg>
            <span>Gossip / Chat</span>
          </button>
          <button class="admin-nav-item" data-panel="resolution">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
              <polyline points="22 4 12 14.01 9 11.01"/>
            </svg>
            <span>Resolution</span>
          </button>
        </div>

        <!-- Analytics -->
        <div class="admin-nav-section">
          <div class="admin-nav-label">Analytics</div>
          <button class="admin-nav-item" data-panel="analytics">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <line x1="18" y1="20" x2="18" y2="10"/>
              <line x1="12" y1="20" x2="12" y2="4"/>
              <line x1="6" y1="20" x2="6" y2="14"/>
            </svg>
            <span>Analytics</span>
          </button>
          <button class="admin-nav-item" data-panel="audit">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
              <polyline points="14 2 14 8 20 8"/>
              <line x1="16" y1="13" x2="8" y2="13"/>
              <line x1="16" y1="17" x2="8" y2="17"/>
              <polyline points="10 9 9 9 8 9"/>
            </svg>
            <span>Audit Log</span>
          </button>
        </div>

        <!-- Settings -->
        <div class="admin-nav-section">
          <div class="admin-nav-label">System</div>
          <button class="admin-nav-item" data-panel="settings">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <circle cx="12" cy="12" r="3"/>
              <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/>
            </svg>
            <span>Settings</span>
          </button>
        </div>
      </nav>

      <div class="admin-sidebar-footer">
        <div class="admin-user-card">
          <div class="admin-user-avatar"><?php echo e($adminInitial); ?></div>
          <div class="admin-user-info">
            <div class="admin-user-name"><?php echo e($adminName); ?></div>
            <div class="admin-user-role">Administrator</div>
          </div>
        </div>
      </div>
    </aside>

    <!-- Main Content -->
    <main class="admin-main">
      <!-- Top Bar -->
      <header class="admin-topbar">
        <button class="admin-btn admin-btn-icon admin-btn-secondary" id="sidebar-toggle" style="display: none;">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
            <line x1="3" y1="12" x2="21" y2="12"/>
            <line x1="3" y1="6" x2="21" y2="6"/>
            <line x1="3" y1="18" x2="21" y2="18"/>
          </svg>
        </button>
        <h1 class="admin-topbar-title" id="panel-title">Overview</h1>
        <div class="admin-topbar-search">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="11" cy="11" r="8"/>
            <line x1="21" y1="21" x2="16.65" y2="16.65"/>
          </svg>
          <input type="text" placeholder="Search users, markets, events..." id="global-search">
        </div>
        <div class="admin-topbar-actions">
          <a href="index.php" class="admin-btn admin-btn-secondary admin-btn-sm">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
              <path d="M19 12H5M12 19l-7-7 7-7"/>
            </svg>
            Back to App
          </a>
          <button class="admin-topbar-btn" id="refresh-btn" title="Refresh data">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
              <path d="M23 4v6h-6M1 20v-6h6"/>
              <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/>
            </svg>
          </button>
        </div>
      </header>

      <!-- Content Panels -->
      <div class="admin-content">
        <!-- Overview Panel -->
        <div class="admin-panel" id="panel-overview">
          <!-- KPI Grid -->
          <div class="admin-kpi-grid" id="kpi-grid">
            <div class="admin-kpi-card">
              <div class="admin-kpi-header">
                <div class="admin-kpi-icon primary">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                    <circle cx="9" cy="7" r="4"/>
                    <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
                    <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
                  </svg>
                </div>
                <span class="admin-kpi-trend up" id="kpi-users-trend">+0%</span>
              </div>
              <div class="admin-kpi-value" id="kpi-users">–</div>
              <div class="admin-kpi-label">Total Users</div>
              <div class="admin-kpi-meta">
                <span id="kpi-users-new">0 new this week</span>
              </div>
            </div>

            <div class="admin-kpi-card">
              <div class="admin-kpi-header">
                <div class="admin-kpi-icon success">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <circle cx="12" cy="12" r="10"/>
                    <path d="M8 14s1.5 2 4 2 4-2 4-2"/>
                    <line x1="9" y1="9" x2="9.01" y2="9"/>
                    <line x1="15" y1="9" x2="15.01" y2="9"/>
                  </svg>
                </div>
                <span class="admin-kpi-trend up" id="kpi-markets-trend">+0%</span>
              </div>
              <div class="admin-kpi-value" id="kpi-markets">–</div>
              <div class="admin-kpi-label">Active Markets</div>
              <div class="admin-kpi-meta">
                <span id="kpi-markets-events">0 total events</span>
              </div>
            </div>

            <div class="admin-kpi-card">
              <div class="admin-kpi-header">
                <div class="admin-kpi-icon warning">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/>
                  </svg>
                </div>
                <span class="admin-kpi-trend up" id="kpi-volume-trend">+0%</span>
              </div>
              <div class="admin-kpi-value" id="kpi-volume">$0</div>
              <div class="admin-kpi-label">Total Volume</div>
              <div class="admin-kpi-meta">
                <span id="kpi-volume-bets">0 bets placed</span>
              </div>
            </div>

            <div class="admin-kpi-card">
              <div class="admin-kpi-header">
                <div class="admin-kpi-icon info">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
                    <polyline points="22 4 12 14.01 9 11.01"/>
                  </svg>
                </div>
              </div>
              <div class="admin-kpi-value" id="kpi-events-status">–</div>
              <div class="admin-kpi-label">Events Status</div>
              <div class="admin-kpi-meta">
                <span class="admin-badge success" id="kpi-events-open">0 open</span>
                <span class="admin-badge warning" id="kpi-events-closed">0 closed</span>
                <span class="admin-badge neutral" id="kpi-events-resolved">0 resolved</span>
              </div>
            </div>
          </div>

          <!-- Charts Row -->
          <div class="admin-charts-row">
            <div class="admin-card">
              <div class="admin-card-header">
                <h3 class="admin-card-title">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                    <circle cx="9" cy="7" r="4"/>
                  </svg>
                  User Growth (30 days)
                </h3>
              </div>
              <div class="admin-card-body">
                <div class="admin-chart-container">
                  <canvas id="chart-users"></canvas>
                </div>
              </div>
            </div>

            <div class="admin-card">
              <div class="admin-card-header">
                <h3 class="admin-card-title">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <line x1="18" y1="20" x2="18" y2="10"/>
                    <line x1="12" y1="20" x2="12" y2="4"/>
                    <line x1="6" y1="20" x2="6" y2="14"/>
                  </svg>
                  Volume & Bets (30 days)
                </h3>
              </div>
              <div class="admin-card-body">
                <div class="admin-chart-container">
                  <canvas id="chart-volume"></canvas>
                </div>
              </div>
            </div>
          </div>

          <!-- Tables Row -->
          <div class="admin-charts-row">
            <div class="admin-card">
              <div class="admin-card-header">
                <h3 class="admin-card-title">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M12 2L15 8H21L17 12L18 18L12 15L6 18L7 12L3 8H9L12 2Z"/>
                  </svg>
                  Top Markets
                </h3>
                <button class="admin-btn admin-btn-sm admin-btn-secondary" data-panel="markets">View All</button>
              </div>
              <div class="admin-card-body" style="padding: 0;">
                <div class="admin-table-wrapper">
                  <table class="admin-table">
                    <thead>
                      <tr>
                        <th>Market</th>
                        <th>Members</th>
                        <th>Events</th>
                      </tr>
                    </thead>
                    <tbody id="top-markets-table">
                      <tr><td colspan="3" class="admin-text-center">Loading...</td></tr>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>

            <div class="admin-card">
              <div class="admin-card-header">
                <h3 class="admin-card-title">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10z"/>
                    <path d="M12 6v6l4 2"/>
                  </svg>
                  Top Events by Volume
                </h3>
                <button class="admin-btn admin-btn-sm admin-btn-secondary" data-panel="events">View All</button>
              </div>
              <div class="admin-card-body" style="padding: 0;">
                <div class="admin-table-wrapper">
                  <table class="admin-table">
                    <thead>
                      <tr>
                        <th>Event</th>
                        <th>Volume</th>
                        <th>Status</th>
                      </tr>
                    </thead>
                    <tbody id="top-events-table">
                      <tr><td colspan="3" class="admin-text-center">Loading...</td></tr>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          </div>

          <!-- Recent Activity -->
          <div class="admin-charts-row">
            <div class="admin-card">
              <div class="admin-card-header">
                <h3 class="admin-card-title">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <circle cx="12" cy="12" r="10"/>
                    <polyline points="12 6 12 12 16 14"/>
                  </svg>
                  Recent Activity
                </h3>
              </div>
              <div class="admin-card-body">
                <div class="admin-activity-list" id="recent-activity">
                  <div class="admin-text-center admin-text-muted">Loading...</div>
                </div>
              </div>
            </div>

            <div class="admin-card">
              <div class="admin-card-header">
                <h3 class="admin-card-title">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                    <circle cx="9" cy="7" r="4"/>
                  </svg>
                  New Users
                </h3>
                <button class="admin-btn admin-btn-sm admin-btn-secondary" data-panel="users">View All</button>
              </div>
              <div class="admin-card-body">
                <div class="admin-activity-list" id="recent-users">
                  <div class="admin-text-center admin-text-muted">Loading...</div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Users Panel -->
        <div class="admin-panel admin-hidden" id="panel-users">
          <div class="admin-card">
            <div class="admin-card-header">
              <h3 class="admin-card-title">User Management</h3>
              <div class="admin-filters">
                <div class="admin-filter-group">
                  <label class="admin-filter-label">Status:</label>
                  <select class="admin-filter-select" id="users-filter-status">
                    <option value="">All</option>
                    <option value="active">Active</option>
                    <option value="restricted">Restricted</option>
                    <option value="suspended">Suspended</option>
                  </select>
                </div>
                <div class="admin-filter-group">
                  <label class="admin-filter-label">Role:</label>
                  <select class="admin-filter-select" id="users-filter-role">
                    <option value="">All</option>
                    <option value="admin">Admin</option>
                    <option value="user">User</option>
                  </select>
                </div>
                <div class="admin-search-box">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <circle cx="11" cy="11" r="8"/>
                    <line x1="21" y1="21" x2="16.65" y2="16.65"/>
                  </svg>
                  <input type="text" placeholder="Search users..." id="users-search">
                </div>
              </div>
            </div>
            <div class="admin-card-body" style="padding: 0;">
              <div class="admin-table-wrapper">
                <table class="admin-table">
                  <thead>
                    <tr>
                      <th>User</th>
                      <th>Email</th>
                      <th>Status</th>
                      <th>Balance</th>
                      <th>Markets</th>
                      <th>Bets</th>
                      <th>Joined</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody id="users-table">
                    <tr><td colspan="8" class="admin-text-center">Loading...</td></tr>
                  </tbody>
                </table>
              </div>
            </div>
            <div class="admin-card-footer">
              <div class="admin-pagination" id="users-pagination"></div>
            </div>
          </div>
        </div>

        <!-- Markets Panel -->
        <div class="admin-panel admin-hidden" id="panel-markets">
          <div class="admin-card">
            <div class="admin-card-header">
              <h3 class="admin-card-title">Market Management</h3>
              <div class="admin-filters">
                <div class="admin-filter-group">
                  <label class="admin-filter-label">Visibility:</label>
                  <select class="admin-filter-select" id="markets-filter-visibility">
                    <option value="">All</option>
                    <option value="private">Private</option>
                    <option value="invite_only">Invite Only</option>
                    <option value="link_only">Link Only</option>
                  </select>
                </div>
                <div class="admin-search-box">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <circle cx="11" cy="11" r="8"/>
                    <line x1="21" y1="21" x2="16.65" y2="16.65"/>
                  </svg>
                  <input type="text" placeholder="Search markets..." id="markets-search">
                </div>
              </div>
            </div>
            <div class="admin-card-body" style="padding: 0;">
              <div class="admin-table-wrapper">
                <table class="admin-table">
                  <thead>
                    <tr>
                      <th>Market</th>
                      <th>Owner</th>
                      <th>Visibility</th>
                      <th>Members</th>
                      <th>Events</th>
                      <th>Created</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody id="markets-table">
                    <tr><td colspan="7" class="admin-text-center">Loading...</td></tr>
                  </tbody>
                </table>
              </div>
            </div>
            <div class="admin-card-footer">
              <div class="admin-pagination" id="markets-pagination"></div>
            </div>
          </div>
        </div>

        <!-- Events Panel -->
        <div class="admin-panel admin-hidden" id="panel-events">
          <div class="admin-card">
            <div class="admin-card-header">
              <h3 class="admin-card-title">Event Management</h3>
              <div class="admin-filters">
                <div class="admin-filter-group">
                  <label class="admin-filter-label">Status:</label>
                  <select class="admin-filter-select" id="events-filter-status">
                    <option value="">All</option>
                    <option value="open">Open</option>
                    <option value="closed">Closed</option>
                    <option value="resolved">Resolved</option>
                  </select>
                </div>
                <div class="admin-filter-group">
                  <label class="admin-filter-label">Type:</label>
                  <select class="admin-filter-select" id="events-filter-type">
                    <option value="">All</option>
                    <option value="binary">Binary</option>
                    <option value="multiple">Multiple Choice</option>
                  </select>
                </div>
                <div class="admin-search-box">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <circle cx="11" cy="11" r="8"/>
                    <line x1="21" y1="21" x2="16.65" y2="16.65"/>
                  </svg>
                  <input type="text" placeholder="Search events..." id="events-search">
                </div>
              </div>
            </div>
            <div class="admin-card-body" style="padding: 0;">
              <div class="admin-table-wrapper">
                <table class="admin-table">
                  <thead>
                    <tr>
                      <th>Event</th>
                      <th>Market</th>
                      <th>Type</th>
                      <th>Status</th>
                      <th>Volume</th>
                      <th>Closes</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody id="events-table">
                    <tr><td colspan="7" class="admin-text-center">Loading...</td></tr>
                  </tbody>
                </table>
              </div>
            </div>
            <div class="admin-card-footer">
              <div class="admin-pagination" id="events-pagination"></div>
            </div>
          </div>
        </div>

        <!-- Bets & Tokens Panel -->
        <div class="admin-panel admin-hidden" id="panel-bets">
          <div class="admin-kpi-grid" style="grid-template-columns: repeat(3, 1fr);">
            <div class="admin-kpi-card">
              <div class="admin-kpi-header">
                <div class="admin-kpi-icon success">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/>
                  </svg>
                </div>
              </div>
              <div class="admin-kpi-value" id="bets-total-volume">$0</div>
              <div class="admin-kpi-label">Total Betting Volume</div>
            </div>
            <div class="admin-kpi-card">
              <div class="admin-kpi-header">
                <div class="admin-kpi-icon primary">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <rect x="1" y="4" width="22" height="16" rx="2" ry="2"/>
                    <line x1="1" y1="10" x2="23" y2="10"/>
                  </svg>
                </div>
              </div>
              <div class="admin-kpi-value" id="bets-total-count">0</div>
              <div class="admin-kpi-label">Total Bets Placed</div>
            </div>
            <div class="admin-kpi-card">
              <div class="admin-kpi-header">
                <div class="admin-kpi-icon warning">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <circle cx="12" cy="12" r="10"/>
                    <path d="M12 6v6l4 2"/>
                  </svg>
                </div>
              </div>
              <div class="admin-kpi-value" id="bets-tokens-circulating">$0</div>
              <div class="admin-kpi-label">Tokens in Circulation</div>
            </div>
          </div>

          <div class="admin-card">
            <div class="admin-card-header">
              <h3 class="admin-card-title">Recent Bets</h3>
              <div class="admin-search-box">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <circle cx="11" cy="11" r="8"/>
                  <line x1="21" y1="21" x2="16.65" y2="16.65"/>
                </svg>
                <input type="text" placeholder="Search by user or event..." id="bets-search">
              </div>
            </div>
            <div class="admin-card-body" style="padding: 0;">
              <div class="admin-table-wrapper">
                <table class="admin-table">
                  <thead>
                    <tr>
                      <th>User</th>
                      <th>Event</th>
                      <th>Side/Outcome</th>
                      <th>Shares</th>
                      <th>Price</th>
                      <th>Total</th>
                      <th>Time</th>
                    </tr>
                  </thead>
                  <tbody id="bets-table">
                    <tr><td colspan="7" class="admin-text-center">Loading...</td></tr>
                  </tbody>
                </table>
              </div>
            </div>
            <div class="admin-card-footer">
              <div class="admin-pagination" id="bets-pagination"></div>
            </div>
          </div>
        </div>

        <!-- Disputes Panel -->
        <div class="admin-panel admin-hidden" id="panel-disputes">
          <div class="admin-card">
            <div class="admin-card-header">
              <h3 class="admin-card-title">Resolution Disputes</h3>
              <div class="admin-filters">
                <div class="admin-filter-group">
                  <label class="admin-filter-label">Status:</label>
                  <select class="admin-filter-select" id="disputes-filter-status">
                    <option value="">All</option>
                    <option value="pending" selected>Pending</option>
                    <option value="reviewed">Reviewed</option>
                    <option value="resolved">Resolved</option>
                    <option value="rejected">Rejected</option>
                  </select>
                </div>
              </div>
            </div>
            <div class="admin-card-body" style="padding: 0;">
              <div class="admin-table-wrapper">
                <table class="admin-table">
                  <thead>
                    <tr>
                      <th>Event</th>
                      <th>User</th>
                      <th>Reason</th>
                      <th>Status</th>
                      <th>Created</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody id="disputes-table">
                    <tr><td colspan="6" class="admin-text-center">Loading...</td></tr>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>

        <!-- Gossip Panel -->
        <div class="admin-panel admin-hidden" id="panel-gossip">
          <div class="admin-card">
            <div class="admin-card-header">
              <h3 class="admin-card-title">Gossip / Chat Moderation</h3>
              <div class="admin-search-box">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <circle cx="11" cy="11" r="8"/>
                  <line x1="21" y1="21" x2="16.65" y2="16.65"/>
                </svg>
                <input type="text" placeholder="Search messages..." id="gossip-search">
              </div>
            </div>
            <div class="admin-card-body" style="padding: 0;">
              <div class="admin-table-wrapper">
                <table class="admin-table">
                  <thead>
                    <tr>
                      <th>User</th>
                      <th>Event</th>
                      <th>Message</th>
                      <th>Time</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody id="gossip-table">
                    <tr><td colspan="5" class="admin-text-center">Loading...</td></tr>
                  </tbody>
                </table>
              </div>
            </div>
            <div class="admin-card-footer">
              <div class="admin-pagination" id="gossip-pagination"></div>
            </div>
          </div>
        </div>

        <!-- Resolution Panel -->
        <div class="admin-panel admin-hidden" id="panel-resolution">
          <div class="admin-card">
            <div class="admin-card-header">
              <h3 class="admin-card-title">Event Resolution</h3>
              <div class="admin-filters">
                <div class="admin-filter-group">
                  <label class="admin-filter-label">Status:</label>
                  <select class="admin-filter-select" id="resolution-filter-status">
                    <option value="closed" selected>Needs Resolution</option>
                    <option value="open">Open (can close)</option>
                    <option value="resolved">Resolved</option>
                  </select>
                </div>
              </div>
            </div>
            <div class="admin-card-body" style="padding: 0;">
              <div class="admin-table-wrapper">
                <table class="admin-table">
                  <thead>
                    <tr>
                      <th>Event</th>
                      <th>Market</th>
                      <th>Type</th>
                      <th>Volume</th>
                      <th>Current</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody id="resolution-table">
                    <tr><td colspan="6" class="admin-text-center">Loading...</td></tr>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>

        <!-- Analytics Panel -->
        <div class="admin-panel admin-hidden" id="panel-analytics">
          <div class="admin-kpi-grid" style="grid-template-columns: repeat(4, 1fr);">
            <div class="admin-kpi-card">
              <div class="admin-kpi-value" id="analytics-dau">–</div>
              <div class="admin-kpi-label">Daily Active Users</div>
            </div>
            <div class="admin-kpi-card">
              <div class="admin-kpi-value" id="analytics-wau">–</div>
              <div class="admin-kpi-label">Weekly Active Users</div>
            </div>
            <div class="admin-kpi-card">
              <div class="admin-kpi-value" id="analytics-mau">–</div>
              <div class="admin-kpi-label">Monthly Active Users</div>
            </div>
            <div class="admin-kpi-card">
              <div class="admin-kpi-value" id="analytics-retention">–</div>
              <div class="admin-kpi-label">7-Day Retention</div>
            </div>
          </div>

          <div class="admin-charts-row">
            <div class="admin-card">
              <div class="admin-card-header">
                <h3 class="admin-card-title">Activity Heatmap</h3>
              </div>
              <div class="admin-card-body">
                <div class="admin-chart-container">
                  <canvas id="chart-activity"></canvas>
                </div>
              </div>
            </div>

            <div class="admin-card">
              <div class="admin-card-header">
                <h3 class="admin-card-title">Events by Outcome</h3>
              </div>
              <div class="admin-card-body">
                <div class="admin-chart-container">
                  <canvas id="chart-outcomes"></canvas>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Audit Panel -->
        <div class="admin-panel admin-hidden" id="panel-audit">
          <div class="admin-card">
            <div class="admin-card-header">
              <h3 class="admin-card-title">Audit Log</h3>
              <div class="admin-filters">
                <div class="admin-filter-group">
                  <label class="admin-filter-label">Action:</label>
                  <select class="admin-filter-select" id="audit-filter-action">
                    <option value="">All</option>
                    <option value="user_update">User Updates</option>
                    <option value="event_resolve">Event Resolution</option>
                    <option value="token_adjust">Token Adjustments</option>
                  </select>
                </div>
              </div>
            </div>
            <div class="admin-card-body" style="padding: 0;">
              <div class="admin-table-wrapper">
                <table class="admin-table">
                  <thead>
                    <tr>
                      <th>Time</th>
                      <th>Admin</th>
                      <th>Action</th>
                      <th>Target</th>
                      <th>Details</th>
                    </tr>
                  </thead>
                  <tbody id="audit-table">
                    <tr><td colspan="5" class="admin-text-center">Audit log coming soon...</td></tr>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>

        <!-- Settings Panel -->
        <div class="admin-panel admin-hidden" id="panel-settings">
          <div class="admin-charts-row">
            <div class="admin-card">
              <div class="admin-card-header">
                <h3 class="admin-card-title">Token Economy</h3>
              </div>
              <div class="admin-card-body">
                <div class="admin-form-group">
                  <label class="admin-form-label">Signup Bonus (tokens)</label>
                  <input type="number" class="admin-form-input" value="10000" id="setting-signup-bonus" readonly>
                  <small class="admin-form-hint">Configured in api/helpers.php</small>
                </div>
                <div class="admin-form-group">
                  <label class="admin-form-label">Market Creation Bonus</label>
                  <input type="number" class="admin-form-input" value="1000" id="setting-market-bonus" readonly>
                </div>
                <div class="admin-form-group">
                  <label class="admin-form-label">Event Creation Bonus</label>
                  <input type="number" class="admin-form-input" value="5000" id="setting-event-bonus" readonly>
                </div>
                <div class="admin-form-group">
                  <label class="admin-form-label">Invitation Bonus</label>
                  <input type="number" class="admin-form-input" value="2000" id="setting-referral-bonus" readonly>
                </div>
              </div>
            </div>

            <div class="admin-card">
              <div class="admin-card-header">
                <h3 class="admin-card-title">Platform Settings</h3>
              </div>
              <div class="admin-card-body">
                <div class="admin-form-group">
                  <label class="admin-form-label">Maintenance Mode</label>
                  <select class="admin-form-select" id="setting-maintenance">
                    <option value="off">Off</option>
                    <option value="on">On</option>
                  </select>
                </div>
                <div class="admin-form-group">
                  <label class="admin-form-label">New Registrations</label>
                  <select class="admin-form-select" id="setting-registrations">
                    <option value="open">Open</option>
                    <option value="invite">Invite Only</option>
                    <option value="closed">Closed</option>
                  </select>
                </div>
                <div class="admin-form-group">
                  <label class="admin-form-label">Email Verification Required</label>
                  <select class="admin-form-select" id="setting-email-verify">
                    <option value="no">No</option>
                    <option value="yes" selected>Yes</option>
                  </select>
                </div>
                <button class="admin-btn admin-btn-primary">Save Platform Settings</button>
              </div>
            </div>
          </div>

          <!-- Nuclear Reset Section -->
          <?php if ((int)$current['id'] === 1): ?>
          <div class="admin-charts-row" style="margin-top: 24px;">
            <div class="admin-card" style="border: 2px solid #ef4444;">
              <div class="admin-card-header" style="background: linear-gradient(135deg, #fee2e2 0%, #fecaca 100%);">
                <h3 class="admin-card-title" style="color: #dc2626;">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20" style="vertical-align: -4px; margin-right: 8px;">
                    <path d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/>
                  </svg>
                  ☢️ Nuclear Reset - DANGER ZONE
                </h3>
              </div>
              <div class="admin-card-body">
                <div class="admin-alert admin-alert-danger" style="margin-bottom: 16px;">
                  <strong>⚠️ WARNING:</strong> This will permanently delete ALL data from the platform except your admin account (ID=1). This action <strong>CANNOT be undone</strong>.
                </div>
                <p style="margin-bottom: 16px; color: #64748b;">This will delete:</p>
                <ul style="margin-bottom: 20px; padding-left: 24px; color: #64748b;">
                  <li>All users (except you)</li>
                  <li>All markets and market memberships</li>
                  <li>All events and bets</li>
                  <li>All gossip messages</li>
                  <li>All notifications and friendships</li>
                  <li>All achievements and streaks</li>
                </ul>
                <p style="margin-bottom: 16px; color: #64748b;">Your account will be preserved with 10,000 tokens.</p>
                <button class="admin-btn admin-btn-danger" id="nuclear-reset-btn" style="background: linear-gradient(135deg, #dc2626 0%, #b91c1c 100%); font-weight: 600;">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16" style="margin-right: 8px;">
                    <path d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/>
                  </svg>
                  ☢️ Perform Nuclear Reset
                </button>
              </div>
            </div>
          </div>
          <?php endif; ?>
        </div>
      </div>
    </main>
  </div>

  <!-- User Modal -->
  <div class="admin-modal-overlay" id="user-modal-overlay">
    <div class="admin-modal wide">
      <div class="admin-modal-header">
        <h3 class="admin-modal-title">User Details</h3>
        <button class="admin-modal-close" id="user-modal-close">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
            <line x1="18" y1="6" x2="6" y2="18"/>
            <line x1="6" y1="6" x2="18" y2="18"/>
          </svg>
        </button>
      </div>
      <div class="admin-modal-body" id="user-modal-body">
        <!-- Dynamic content -->
      </div>
      <div class="admin-modal-footer">
        <button class="admin-btn admin-btn-secondary" id="user-modal-cancel">Close</button>
        <button class="admin-btn admin-btn-primary" id="user-modal-save">Save Changes</button>
      </div>
    </div>
  </div>

  <!-- Event Resolution Modal -->
  <div class="admin-modal-overlay" id="resolve-modal-overlay">
    <div class="admin-modal">
      <div class="admin-modal-header">
        <h3 class="admin-modal-title">Resolve Event</h3>
        <button class="admin-modal-close" id="resolve-modal-close">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
            <line x1="18" y1="6" x2="6" y2="18"/>
            <line x1="6" y1="6" x2="18" y2="18"/>
          </svg>
        </button>
      </div>
      <div class="admin-modal-body" id="resolve-modal-body">
        <!-- Dynamic content -->
      </div>
      <div class="admin-modal-footer">
        <button class="admin-btn admin-btn-secondary" id="resolve-modal-cancel">Cancel</button>
        <button class="admin-btn admin-btn-primary" id="resolve-modal-confirm">Resolve Event</button>
      </div>
    </div>
  </div>

  <!-- Toast Container -->
  <div class="admin-toast-container" id="toast-container"></div>

  <?php js_script('admin.js'); ?>
</body>
</html>
