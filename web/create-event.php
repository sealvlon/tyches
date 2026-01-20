<?php
// create-event.php
// Event creation page with app shell

declare(strict_types=1);

require_once __DIR__ . '/api/security.php';

tyches_start_session();
$isLoggedIn = isset($_SESSION['user_id']) && is_int($_SESSION['user_id']);
if (!$isLoggedIn) {
    header('Location: index.php');
    exit;
}

// Get pre-selected market ID from URL if provided
$preselectedMarketId = isset($_GET['market_id']) ? (int)$_GET['market_id'] : 0;
$activeTab = 'feed';
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <title>Create Event - Tyches</title>
  <?php include __DIR__ . '/includes/app-head.php'; ?>
</head>
<body class="app-shell" data-logged-in="1" data-preselect-market="<?php echo $preselectedMarketId; ?>">
  
  <?php include __DIR__ . '/includes/app-topbar.php'; ?>

  <main class="app-main">
    <?php include __DIR__ . '/includes/app-sidebar.php'; ?>

    <div class="app-content">
      <div class="content-header">
        <div>
          <h1>Create Event</h1>
          <p>Ask a prediction question in one of your markets</p>
        </div>
      </div>

      <div class="create-event-grid">
        <!-- Form Section -->
        <div class="create-event-form-section">
          <form id="create-event-form" class="content-card">
            <div class="form-group">
              <label for="event-market">Market</label>
              <select id="event-market" name="market_id" required class="form-select"></select>
              <p class="help-text">Select which group this event belongs to</p>
            </div>

            <div class="form-group">
              <label for="event-title">Event question</label>
              <input type="text" id="event-title" name="title" maxlength="255" required placeholder="Will Alex get married by April 30?" class="form-input" />
            </div>

            <div class="form-group">
              <label for="event-description">Description (optional)</label>
              <textarea id="event-description" name="description" rows="4" maxlength="1000" placeholder="Define what counts as YES vs NO, and any resolution sources.

Example: If Alex proposes to Jamie before Dec 31, 2025, resolves YES. Must be on one knee with a ring." class="form-textarea wysiwyg-textarea"></textarea>
              <p class="help-text">Max 1000 characters. Line breaks are preserved.</p>
            </div>

            <div class="form-group">
              <label>Event Type</label>
              <div class="pill-toggle" id="event-type-toggle">
                <button type="button" data-type="binary" class="active">Binary (Yes/No)</button>
                <button type="button" data-type="multiple">Multiple Choice</button>
              </div>
              <input type="hidden" id="event-type" name="event_type" value="binary" />
            </div>

            <div class="form-group" id="binary-settings">
              <label>Starting Probability</label>
              <div class="probability-row">
                <div class="prob-input">
                  <label for="event-yes-percent" class="prob-label yes">YES</label>
                  <div class="prob-input-wrap">
                    <input type="number" id="event-yes-percent" name="yes_percent" min="1" max="99" value="62" />
                    <span class="prob-unit">%</span>
                  </div>
                </div>
                <div class="prob-input">
                  <label class="prob-label no">NO</label>
                  <div class="prob-input-wrap">
                    <input type="number" id="event-no-percent" value="38" readonly />
                    <span class="prob-unit">%</span>
                  </div>
                </div>
              </div>
              <p class="help-text">Set the initial odds for this prediction</p>
            </div>

            <div class="form-group" id="multiple-settings" style="display:none;">
              <label>Outcomes</label>
              <div id="multiple-outcomes"></div>
              <button type="button" class="btn-secondary btn-sm" id="add-outcome">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
                </svg>
                Add Outcome
              </button>
              <p class="help-text">Totals will normalize to 100%</p>
            </div>

            <div class="form-group">
              <label for="event-closes-at">Closes At</label>
              <input type="datetime-local" id="event-closes-at" name="closes_at" required class="form-input" />
              <p class="help-text">When trading will stop and the event can be resolved</p>
            </div>

            <!-- Divider -->
            <div class="form-divider">
              <span>Advanced Options</span>
            </div>

            <!-- Visibility -->
            <div class="form-group">
              <label>Visibility</label>
              <div class="pill-toggle" id="visibility-toggle">
                <button type="button" data-visibility="public" class="active">
                  🌐 Public
                </button>
                <button type="button" data-visibility="private">
                  🔒 Private
                </button>
              </div>
              <input type="hidden" id="event-visibility" name="visibility" value="public" />
              <p class="help-text" id="visibility-help">All market members can see and participate</p>
            </div>

            <!-- Private Event Participants (shown when private is selected) -->
            <div class="form-group" id="participants-section" style="display:none;">
              <label>Select Participants</label>
              <p class="help-text">Choose who can see and participate in this event</p>
              <div id="participants-list" class="participants-checkbox-list">
                <!-- Populated by JS with market members -->
              </div>
            </div>

            <!-- Resolution Type -->
            <div class="form-group">
              <label>Resolution</label>
              <div class="pill-toggle" id="resolution-toggle">
                <button type="button" data-resolution="automatic" class="active">
                  🤖 Automatic
                </button>
                <button type="button" data-resolution="manual">
                  👤 Manual
                </button>
              </div>
              <input type="hidden" id="event-resolution-type" name="resolution_type" value="automatic" />
              <p class="help-text" id="resolution-help">Event resolves automatically based on highest odds when closed</p>
            </div>

            <!-- Resolver Selection (hidden by default, shown when manual is selected) -->
            <div class="form-group" id="resolver-section" style="display:none;">
              <label for="event-resolver">Resolver</label>
              <select id="event-resolver" name="resolver_id" class="form-select">
                <option value="">Me (I'll resolve this event)</option>
                <!-- Populated by JS with market members -->
              </select>
              <p class="help-text">Who will determine the final outcome</p>
            </div>

            <div id="create-event-error" class="form-error" style="display:none;"></div>
            <div id="create-event-success" class="form-success" style="display:none;"></div>

            <div class="form-actions">
              <button type="submit" class="btn-primary">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M12 5v14M5 12h14"/>
                </svg>
                Create Event
              </button>
            </div>
          </form>
        </div>

        <!-- Preview Section -->
        <aside class="create-event-preview-section">
          <div class="content-card">
            <h3>📱 Preview</h3>
            <div id="create-event-preview-card" class="event-preview-card">
              <div class="preview-placeholder">
                <span>Your event will appear here</span>
              </div>
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
