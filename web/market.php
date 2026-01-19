<?php
// market.php
// Page for a single Market (group) view with app shell

declare(strict_types=1);

require_once __DIR__ . '/api/security.php';

tyches_start_session();
$isLoggedIn = isset($_SESSION['user_id']) && is_int($_SESSION['user_id']);
$marketId   = isset($_GET['id']) ? (int)$_GET['id'] : 0;

// If not logged in, redirect to home
if (!$isLoggedIn) {
    header('Location: index.php');
    exit;
}

$activeTab = 'markets';
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <title>Tyches - Market</title>
  <?php include __DIR__ . '/includes/app-head.php'; ?>
</head>
<body class="app-shell" data-logged-in="1" data-market-id="<?php echo $marketId > 0 ? $marketId : 0; ?>">
  
  <?php include __DIR__ . '/includes/app-topbar.php'; ?>

  <main class="app-main">
    <?php include __DIR__ . '/includes/app-sidebar.php'; ?>

    <div class="app-content">
      <!-- Market Header -->
      <div class="market-detail-header" id="market-header">
        <div class="loading-placeholder">Loading market...</div>
      </div>

      <!-- Market Content Grid -->
      <div class="market-detail-grid">
        <!-- Events List -->
        <div class="market-detail-main">
          <div class="content-card">
            <div class="content-card-header">
              <h2>Events</h2>
              <a href="create-event.php?market_id=<?php echo $marketId; ?>" class="btn-primary" id="market-create-event">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                  <line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
                </svg>
                New Event
              </a>
            </div>
            <div id="market-events-list" class="market-events-grid">
              <div class="loading-placeholder">Loading events...</div>
            </div>
          </div>
        </div>

        <!-- Sidebar -->
        <aside class="market-detail-sidebar">
          <!-- Members Card -->
          <div class="content-card">
            <div class="content-card-header">
              <h3>Members</h3>
              <button class="btn-secondary btn-sm" id="open-invite-modal">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="8.5" cy="7" r="4"/><line x1="20" y1="8" x2="20" y2="14"/><line x1="23" y1="11" x2="17" y2="11"/>
                </svg>
                Invite
              </button>
            </div>
            <div id="market-members" class="members-list-app">
              <div class="loading-placeholder">Loading members...</div>
            </div>
          </div>

          <!-- Market Stats Card -->
          <div class="content-card">
            <h3>Market Stats</h3>
            <div class="market-stats-grid" id="market-stats">
              <div class="market-stat-item">
                <span class="stat-number" id="stat-events">0</span>
                <span class="stat-label">Events</span>
              </div>
              <div class="market-stat-item">
                <span class="stat-number" id="stat-members">0</span>
                <span class="stat-label">Members</span>
              </div>
              <div class="market-stat-item">
                <span class="stat-number" id="stat-volume">0</span>
                <span class="stat-label">Volume</span>
              </div>
            </div>
          </div>
        </aside>
      </div>
    </div>
  </main>

  <?php include __DIR__ . '/includes/app-bottomnav.php'; ?>

  <!-- Invite Members Modal -->
  <div class="modal-overlay" id="invite-members-modal" style="display:none;">
    <div class="modal invite-modal">
      <div class="modal-header">
        <h2>Invite Members</h2>
        <button class="modal-close" id="close-invite-modal">&times;</button>
      </div>
      <div class="modal-body">
        <p class="invite-description">Add people to this market so they can view and participate in all events.</p>
        
        <div class="invite-form">
          <div class="invite-input-group">
            <input type="email" 
                   id="market-invite-email-input" 
                   class="invite-email-input" 
                   placeholder="Enter email address" 
                   autocomplete="email">
            <button class="btn-primary btn-invite" id="market-add-email-btn" type="button">Add</button>
          </div>
          
          <div id="market-invite-emails-list" class="invite-emails-list">
            <!-- Email chips will be added here -->
          </div>
          
          <div id="market-invite-result" class="invite-result" style="display:none;"></div>
        </div>
      </div>
      <div class="modal-footer">
        <button class="btn-secondary" id="cancel-invite-modal">Cancel</button>
        <button class="btn-primary btn-send-invites" id="market-send-invites-btn" type="button" disabled>
          Send Invitations
        </button>
      </div>
    </div>
  </div>

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
