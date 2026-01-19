<?php
// profile.php
// User profile page with app shell

declare(strict_types=1);

require_once __DIR__ . '/api/security.php';

tyches_start_session();
$isLoggedIn = isset($_SESSION['user_id']) && is_int($_SESSION['user_id']);
if (!$isLoggedIn) {
    header('Location: index.php');
    exit;
}

$activeTab = 'profile';
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <title>Profile - Tyches</title>
  <?php include __DIR__ . '/includes/app-head.php'; ?>
</head>
<body class="app-shell" data-logged-in="1">
  
  <?php include __DIR__ . '/includes/app-topbar.php'; ?>

  <main class="app-main">
    <?php include __DIR__ . '/includes/app-sidebar.php'; ?>

    <div class="app-content">
      <!-- Profile Header -->
      <div class="profile-header-card" id="profile-header">
        <div class="loading-placeholder">Loading profile...</div>
      </div>

      <!-- Profile Content Grid -->
      <div class="profile-content-grid">
        <!-- Main Content -->
        <div class="profile-main-content">
          <!-- Friends Section - Social Media Style -->
          <div class="content-card friends-card">
            <div class="content-card-header">
              <h2>👥 Friends</h2>
            </div>
            
            <!-- Search Bar - Always Visible -->
            <div class="friends-search-bar">
              <div class="search-input-wrapper">
                <input type="text" id="friends-search-input" placeholder="Find friends by name, username, or email..." class="friends-search-input">
              </div>
            </div>
            
            <!-- Tabs -->
            <div class="friends-tabs">
              <button class="friends-tab active" data-tab="friends">
                <span class="tab-icon">👥</span>
                <span class="tab-label">Friends</span>
                <span class="tab-count" id="friends-count-badge">0</span>
              </button>
              <button class="friends-tab" data-tab="requests">
                <span class="tab-icon">📬</span>
                <span class="tab-label">Requests</span>
                <span class="tab-count tab-count-alert" id="requests-count-badge" style="display:none;">0</span>
              </button>
              <button class="friends-tab" data-tab="discover">
                <span class="tab-icon">🔍</span>
                <span class="tab-label">Discover</span>
              </button>
            </div>
            
            <!-- Tab Content: Friends List -->
            <div id="friends-tab-friends" class="friends-tab-content active">
              <div id="friends-list" class="friends-list-grid">
                <div class="loading-placeholder">Loading friends...</div>
              </div>
            </div>
            
            <!-- Tab Content: Friend Requests -->
            <div id="friends-tab-requests" class="friends-tab-content">
              <div id="friends-requests" class="friends-requests-list">
                <div class="empty-state-mini">
                  <div class="empty-state-icon">📭</div>
                  <div class="empty-state-text">No pending requests</div>
                </div>
              </div>
            </div>
            
            <!-- Tab Content: Discover / Suggestions -->
            <div id="friends-tab-discover" class="friends-tab-content">
              <!-- Search Results (when searching) -->
              <div id="friends-search-results" class="friends-search-results" style="display:none;"></div>
              
              <!-- Suggested Friends -->
              <div id="friends-suggested" class="friends-suggested-section">
                <div class="section-subtitle">People You May Know</div>
                <div id="suggested-friends-list" class="suggested-friends-grid">
                  <div class="loading-placeholder">Finding people you might know...</div>
                </div>
              </div>
            </div>
          </div>

          <!-- My Events Section -->
          <div class="content-card">
            <div class="content-card-header">
              <h2>📊 My Events</h2>
            </div>
            <div id="profile-events" class="profile-events-grid">
              <div class="loading-placeholder">Loading events...</div>
            </div>
          </div>
        </div>

        <!-- Sidebar -->
        <aside class="profile-sidebar-content">
          <!-- Security Section -->
          <div class="content-card">
            <h3>🔐 Security</h3>
            <form id="password-form" class="password-form-app">
              <div class="form-group">
                <label for="password-current">Current password</label>
                <input type="password" id="password-current" autocomplete="current-password" required>
              </div>
              <div class="form-group">
                <label for="password-new">New password</label>
                <input type="password" id="password-new" autocomplete="new-password" required minlength="8">
              </div>
              <div class="form-group">
                <label for="password-new-confirm">Confirm new password</label>
                <input type="password" id="password-new-confirm" autocomplete="new-password" required minlength="8">
              </div>
              <div id="password-error" class="form-error" style="display:none;"></div>
              <div id="password-success" class="form-success" style="display:none;"></div>
              <button type="submit" class="btn-primary btn-sm">Update password</button>
            </form>
          </div>

          <!-- My Markets Section -->
          <div class="content-card">
            <div class="content-card-header">
              <h3>🎯 My Markets</h3>
            </div>
            <div id="profile-markets" class="profile-markets-grid">
              <div class="loading-placeholder">Loading markets...</div>
            </div>
          </div>

          <!-- My Bets Section -->
          <div class="content-card">
            <div class="content-card-header">
              <h3>🎲 My Bets</h3>
            </div>
            <div id="profile-bets" class="profile-bets-list">
              <div class="loading-placeholder">Loading bets...</div>
            </div>
          </div>
        </aside>
      </div>
    </div>
  </main>

  <?php include __DIR__ . '/includes/app-bottomnav.php'; ?>

  <?php require_once __DIR__ . '/includes/asset-helpers.php'; js_script('js/core.js'); ?>
  <?php js_script('js/app.js'); ?></script>
  
  <!-- Cookie Banner -->
  <div id="cookie-banner" class="cookie-banner-mini">
    <span>We use cookies.</span>
    <a href="privacy.php#cookies">Learn more</a>
    <button onclick="acceptCookies(true)">OK</button>
  </div>
  <script>
    function acceptCookies(all) {
      const d = new Date();
      d.setFullYear(d.getFullYear() + 1);
      document.cookie = `cookiesAccepted=${all ? 'all' : 'essential'}; expires=${d.toUTCString()}; path=/`;
      document.getElementById('cookie-banner').style.display = 'none';
    }
    window.addEventListener('DOMContentLoaded', () => {
      if (document.cookie.includes('cookiesAccepted')) {
        document.getElementById('cookie-banner').style.display = 'none';
      }
    });
  </script>
</body>
</html>
