<?php
// event.php
// Page for a single Event view with app shell

declare(strict_types=1);

require_once __DIR__ . '/api/security.php';

tyches_start_session();
$isLoggedIn = isset($_SESSION['user_id']) && is_int($_SESSION['user_id']);
$eventId    = isset($_GET['id']) ? (int)$_GET['id'] : 0;

// If not logged in, redirect to home
if (!$isLoggedIn) {
    header('Location: index.php');
    exit;
}

$activeTab = 'feed';
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <title>Tyches - Event</title>
  <?php include __DIR__ . '/includes/app-head.php'; ?>
</head>
<body class="app-shell" data-logged-in="1" data-event-id="<?php echo $eventId > 0 ? $eventId : 0; ?>">
  
  <?php include __DIR__ . '/includes/app-topbar.php'; ?>

  <main class="app-main">
    <?php include __DIR__ . '/includes/app-sidebar.php'; ?>

    <div class="app-content">
      <!-- Event Header -->
      <div class="event-detail-header" id="event-header">
        <div class="loading-placeholder">Loading event...</div>
      </div>

      <!-- Event Content Grid -->
      <div class="event-detail-grid">
        <!-- Main Content -->
        <div class="event-detail-main">
          <!-- Trade Card -->
          <div class="content-card" id="event-trade-card">
            <div class="loading-placeholder">Loading trading options...</div>
          </div>

          <!-- Gossip Section -->
          <div class="gossip-card-v2">
            <div class="gossip-header-v2">
              <span class="gossip-icon-v2">💬</span>
              <h3 class="gossip-title-v2">Gossip</h3>
            </div>
            <div id="gossip-list" class="gossip-list-v2">
              <div class="loading-placeholder">Loading comments...</div>
            </div>
            <div class="gossip-compose-v2" id="gossip-compose">
              <input type="text" id="gossip-message" class="gossip-compose-input-v2" placeholder="Drop a spicy take...">
              <button class="gossip-send-btn-v2" id="gossip-submit">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M22 2L11 13"/>
                  <path d="M22 2L15 22L11 13L2 9L22 2Z"/>
                </svg>
              </button>
            </div>
          </div>
        </div>

        <!-- Sidebar -->
        <aside class="event-detail-sidebar">
          <!-- Event Management (shown to resolver/creator/host) -->
          <div class="content-card event-management-card" id="event-management-section" style="display:none;">
            <div class="content-card-header">
              <h3>⚙️ Manage Event</h3>
            </div>
            <div class="event-management-status" id="event-management-status">
              <span class="status-badge open">Open</span>
              <span id="event-status-text">Trading is active</span>
            </div>
            <div class="event-management-actions" id="event-management-actions">
              <!-- Actions populated by JS based on status -->
            </div>
            <div id="event-management-result" class="form-message" style="display:none;"></div>
          </div>

          <!-- Invite Members (shown to creator) - PROMINENT -->
          <div class="content-card invite-card-prominent" id="invite-members-section" style="display:none;">
            <div class="invite-card-header">
              <div class="invite-icon-circle">👥</div>
              <div>
                <h3>Invite People</h3>
                <p class="invite-subtitle">Share this event with friends</p>
              </div>
            </div>
            
            <div class="invite-form">
              <div class="invite-input-group">
                <input type="text" 
                       id="invite-email-input" 
                       class="invite-email-input" 
                       placeholder="@username or email@example.com" 
                       autocomplete="off">
                <button class="btn-invite-add" id="add-email-btn" type="button">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                    <line x1="12" y1="5" x2="12" y2="19"></line>
                    <line x1="5" y1="12" x2="19" y2="12"></line>
                  </svg>
                </button>
              </div>
              
              <div id="invite-emails-list" class="invite-emails-list"></div>
              
              <button class="btn-primary btn-send-invites" id="send-invites-btn" type="button" disabled>
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M22 2L11 13"></path>
                  <path d="M22 2L15 22L11 13L2 9L22 2Z"></path>
                </svg>
                Send Invitations
              </button>
            </div>
            
            <div id="invite-result" class="invite-result" style="display:none;"></div>
          </div>

          <!-- Event Details -->
          <div class="content-card">
            <h3>📋 Details</h3>
            <div id="event-details" class="event-details-list">
              <div class="loading-placeholder">Loading...</div>
            </div>
          </div>

          <!-- Members -->
          <div class="content-card" id="event-members-section" style="display:none;">
            <h3>👤 Attendees</h3>
            <div id="event-members-list" class="members-list-app">
              <div class="loading-placeholder">Loading...</div>
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
