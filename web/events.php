<?php
// events.php
// Events page - shows all events where user is a participant

declare(strict_types=1);

require_once __DIR__ . '/api/security.php';

tyches_start_session();
$isLoggedIn = isset($_SESSION['user_id']) && is_int($_SESSION['user_id']);
if (!$isLoggedIn) {
    header('Location: index.php');
    exit;
}

$activeTab = 'events';
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <title>My Events - Tyches</title>
  <?php include __DIR__ . '/includes/app-head.php'; ?>
</head>
<body class="app-shell" data-logged-in="1">
  
  <?php include __DIR__ . '/includes/app-topbar.php'; ?>

  <main class="app-main">
    <?php include __DIR__ . '/includes/app-sidebar.php'; ?>

    <div class="app-content">
      <!-- Page Header -->
      <div class="page-header-card">
        <div class="page-header-content">
          <div class="page-header-icon">📅</div>
          <div class="page-header-text">
            <h1>My Events</h1>
            <p>All events from your markets</p>
          </div>
        </div>
        <a href="create-event.php" class="btn-primary">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
            <line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
          </svg>
          New Event
        </a>
      </div>

      <!-- Events Grid -->
      <div class="content-card">
        <div id="my-events-list" class="events-grid-page">
          <div class="loading-placeholder">Loading your events...</div>
        </div>
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

