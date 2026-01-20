<?php
// index.php
// Tyches landing page + logged-in dashboard shell.

declare(strict_types=1);

require_once __DIR__ . '/api/security.php';
require_once __DIR__ . '/includes/asset-helpers.php';

tyches_start_session();
$isLoggedIn = isset($_SESSION['user_id']) && is_int($_SESSION['user_id']);
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Tyches - Predict With Your Friends</title>
  <meta name="csrf-token" content="<?php echo e(tyches_get_csrf_token()); ?>">
  <meta name="description" content="Tyches - Private prediction markets for your friends. No real money, just tokens, gossip, and bragging rights.">
  
  <!-- Resource hints -->
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link rel="dns-prefetch" href="https://www.googletagmanager.com">
  
  <!-- Font - Plus Jakarta Sans only -->
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  
  <!-- Stylesheet -->
  <?php css_link('styles.css'); ?>
  
  <link rel="icon" href="favicon.ico">
  
  <!-- Google Analytics -->
  <script async src="https://www.googletagmanager.com/gtag/js?id=G-0000000000"></script><!-- Google Analytics -->
  <script>
    window.dataLayer = window.dataLayer || [];
    function gtag(){dataLayer.push(arguments);}
    gtag('js', new Date());
    gtag('config', 'G-0000000000'); // Google Analytics
  </script>
</head>
<body class="landing-page" data-logged-in="<?php echo $isLoggedIn ? '1' : '0'; ?>">
  <!-- Navigation (marketing only) -->
  <nav class="navbar-landing marketing-only">
    <div class="nav-container-landing">
      <a href="index.php" class="logo-landing">
        <div class="logo-icon">
          <svg width="40" height="40" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
            <rect width="32" height="32" rx="10" fill="url(#gradient-nav)"/>
            <path d="M16 8L20 14H24L18 20L20 26L16 22L12 26L14 20L8 14H12L16 8Z" fill="white"/>
            <defs>
              <linearGradient id="gradient-nav" x1="0" y1="0" x2="32" y2="32" gradientUnits="userSpaceOnUse">
                <stop stop-color="#6366F1"/>
                <stop offset="1" stop-color="#8B5CF6"/>
              </linearGradient>
            </defs>
          </svg>
        </div>
        <span>Tyches</span>
      </a>
      
      <div class="nav-right">
        <button class="btn-landing-primary logged-out-only" id="nav-login">Log In</button>
        <div class="user-pill auth-only" id="nav-user-pill" style="display:none;">
          <span id="nav-user-initial">U</span>
          <span id="nav-user-name">You</span>
          <div class="user-dropdown" id="nav-user-dropdown">
            <button id="nav-open-profile">Profile</button>
            <button id="nav-open-markets">My Markets</button>
            <button id="nav-logout">Log out</button>
          </div>
        </div>
      </div>
    </div>
  </nav>

  <!-- Hero Section -->
  <section class="hero-landing marketing-only" id="hero-section">
    <div class="hero-bg-shapes">
      <div class="shape shape-1"></div>
      <div class="shape shape-2"></div>
    </div>
    
    <div class="hero-container-landing">
      <div class="hero-content-landing">
        <div class="hero-eyebrow">
          <span class="eyebrow-icon">✨</span>
          <span>Private prediction markets</span>
        </div>
        
        <h1 class="hero-title-landing">
          Predict with<br>your friends.
        </h1>
        
        <p class="hero-subtitle-landing">
          Turn "I told you so" into actual odds. Create private markets, 
          bet with play-money tokens, and see who really knows the future.
        </p>
        
        <div class="hero-cta-landing">
          <button class="btn-hero-primary logged-out-only" id="hero-start-market">
            Start for free
            <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
              <path d="M4 10H16M16 10L11 5M16 10L11 15" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </button>
          <button class="btn-hero-secondary logged-out-only" id="hero-learn-more">
            Learn more
          </button>
        </div>
        
        <div class="hero-trust">
          <div class="trust-avatars">
            <div class="trust-avatar" style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);">S</div>
            <div class="trust-avatar" style="background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);">M</div>
            <div class="trust-avatar" style="background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);">A</div>
            <div class="trust-avatar" style="background: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%);">J</div>
          </div>
          <span class="trust-text">Join friends already predicting</span>
        </div>
      </div>
      
      <div class="hero-visual-landing">
        <div class="phone-frame">
          <div class="phone-notch"></div>
          <div class="phone-content">
            <div class="app-header">
              <span class="app-market-name">🎯 College Friends</span>
              <span class="app-live-badge">LIVE</span>
            </div>
            <div class="prediction-card-demo">
              <div class="prediction-question">Will Jake actually finish his thesis by May?</div>
              <div class="prediction-odds-demo">
                <div class="odds-option yes-option">
                  <span class="odds-label">YES</span>
                  <span class="odds-value">34%</span>
                  <div class="odds-bar-fill" style="width: 34%"></div>
                </div>
                <div class="odds-option no-option">
                  <span class="odds-label">NO</span>
                  <span class="odds-value">66%</span>
                  <div class="odds-bar-fill" style="width: 66%"></div>
                </div>
              </div>
              <div class="prediction-meta">
                <span>🪙 2,450 tokens</span>
                <span>👥 8 traders</span>
              </div>
            </div>
            <div class="gossip-preview">
              <div class="gossip-item">
                <div class="gossip-avatar">M</div>
                <div class="gossip-bubble">He hasn't even started chapter 3 😂</div>
              </div>
            </div>
          </div>
        </div>
        <div class="floating-card card-1">
          <span class="fc-emoji">🎉</span>
          <span class="fc-text">You won 500 tokens!</span>
        </div>
        <div class="floating-card card-2">
          <span class="fc-emoji">📈</span>
          <span class="fc-text">Odds shifted to 72%</span>
        </div>
      </div>
    </div>
  </section>

  <!-- Simple How It Works - Just 3 icons -->
  <section class="simple-steps marketing-only">
    <div class="container-landing">
      <div class="steps-row">
        <div class="step-item">
          <div class="step-icon">👥</div>
          <div class="step-text">
            <strong>Create a market</strong>
            <span>Invite your friends</span>
          </div>
        </div>
        <div class="step-divider"></div>
        <div class="step-item">
          <div class="step-icon">❓</div>
          <div class="step-text">
            <strong>Ask a question</strong>
            <span>Set the odds</span>
          </div>
        </div>
        <div class="step-divider"></div>
        <div class="step-item">
          <div class="step-icon">🏆</div>
          <div class="step-text">
            <strong>See who's right</strong>
            <span>Winners collect tokens</span>
          </div>
        </div>
      </div>
    </div>
  </section>

  <!-- Simple CTA -->
  <section class="simple-cta marketing-only">
    <div class="container-landing">
      <div class="cta-box">
        <p class="cta-tagline">No real money. No crypto. Just bragging rights.</p>
        <button class="btn-cta-dark logged-out-only" id="cta-get-started">
          Get Started — Sign up for free
        </button>
      </div>
    </div>
  </section>

  <!-- App Shell for logged-in users -->
  <div class="app-shell auth-only" id="app-shell" style="display:none;">
    
    <!-- App Header -->
    <header class="app-topbar">
      <div class="topbar-left">
        <a href="index.php" class="app-logo">
          <svg width="32" height="32" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
            <rect width="32" height="32" rx="8" fill="url(#gradient-app)"/>
            <path d="M16 8L20 14H24L18 20L20 26L16 22L12 26L14 20L8 14H12L16 8Z" fill="white"/>
            <defs>
              <linearGradient id="gradient-app" x1="0" y1="0" x2="32" y2="32" gradientUnits="userSpaceOnUse">
                <stop stop-color="#6366F1"/>
                <stop offset="1" stop-color="#8B5CF6"/>
              </linearGradient>
            </defs>
          </svg>
          <span>Tyches</span>
        </a>
      </div>
      
      <div class="topbar-center">
        <div class="search-bar" id="search-bar">
          <svg class="search-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/>
          </svg>
          <input type="text" placeholder="Search markets, events, users..." id="app-search">
        </div>
      </div>
      
      <div class="topbar-right">
        <button class="topbar-create-btn" id="header-create-btn">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
            <line x1="12" y1="5" x2="12" y2="19"></line>
            <line x1="5" y1="12" x2="19" y2="12"></line>
          </svg>
          <span>Create</span>
        </button>
        <div class="token-display" id="token-display">
          <span class="token-icon">🪙</span>
          <span class="token-amount" id="header-token-balance">0</span>
        </div>
        <button class="topbar-btn notification-btn" id="notifications-btn">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/>
          </svg>
          <span class="notification-badge" id="notification-count" style="display:none;">0</span>
        </button>
        <div class="user-menu" id="user-menu">
          <button class="user-avatar-btn" id="user-avatar-btn">
            <span id="app-user-initial">U</span>
          </button>
          <div class="user-dropdown-menu" id="user-dropdown-menu">
            <div class="dropdown-user-info">
              <span class="dropdown-user-name" id="dropdown-user-name">User</span>
              <span class="dropdown-user-email" id="dropdown-user-email">email@example.com</span>
            </div>
            <div class="dropdown-divider"></div>
            <a href="profile.php" class="dropdown-item">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
              Profile
            </a>
            <a href="#" class="dropdown-item" id="dropdown-settings">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>
              Settings
            </a>
            <div class="dropdown-divider"></div>
            <button class="dropdown-item dropdown-logout" id="dropdown-logout">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>
              Log out
            </button>
          </div>
        </div>
      </div>
    </header>

    <!-- Main App Content -->
    <main class="app-main">
      <!-- Sidebar Navigation (Desktop) -->
      <nav class="app-sidebar">
        <div class="sidebar-nav">
          <a href="index.php" class="nav-item active" data-tab="feed">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/>
            </svg>
            <span>Feed</span>
          </a>
          <a href="index.php#markets" class="nav-item" data-tab="markets">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>
            </svg>
            <span>Markets</span>
          </a>
          <a href="events.php" class="nav-item">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/><path d="m9 16 2 2 4-4"/>
            </svg>
            <span>Events</span>
          </a>
          <a href="index.php#leaderboard" class="nav-item" data-tab="leaderboard">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6"/><path d="M18 9h1.5a2.5 2.5 0 0 0 0-5H18"/><path d="M4 22h16"/><path d="M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22"/><path d="M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22"/><path d="M18 2H6v7a6 6 0 0 0 12 0V2Z"/>
            </svg>
            <span>Leaderboard</span>
          </a>
          <a href="profile.php" class="nav-item" data-tab="profile">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>
            </svg>
            <span>Profile</span>
          </a>
        </div>
        
        <div class="sidebar-actions">
          <button class="create-btn" id="sidebar-create-btn">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
              <line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
            </svg>
            <span>Create</span>
          </button>
        </div>
      </nav>

      <!-- Tab Content Area -->
      <div class="app-content">
        
        <!-- Feed Tab -->
        <div class="tab-panel active" id="tab-feed">
          <div class="content-header">
            <h1>Your Feed</h1>
            <p>Events that need your attention</p>
          </div>
          
          <!-- Verification Banner (if needed) -->
          <div class="verify-banner" id="verify-banner" style="display:none;">
            <div class="verify-banner-content">
              <span class="verify-banner-icon">📧</span>
              <div class="verify-banner-text">
                <strong>Verify your email</strong>
                <span>to create markets and place predictions</span>
              </div>
            </div>
            <button class="verify-banner-btn" id="verify-banner-btn">Resend Email</button>
          </div>
          
          <!-- Quick Stats -->
          <div class="quick-stats" id="quick-stats">
            <div class="stat-card">
              <div class="stat-icon">🪙</div>
              <div class="stat-info">
                <span class="stat-value" id="stat-tokens">0</span>
                <span class="stat-label">Tokens</span>
              </div>
            </div>
            <div class="stat-card">
              <div class="stat-icon">🎯</div>
              <div class="stat-info">
                <span class="stat-value" id="stat-markets">0</span>
                <span class="stat-label">Markets</span>
              </div>
            </div>
            <div class="stat-card">
              <div class="stat-icon">📊</div>
              <div class="stat-info">
                <span class="stat-value" id="stat-bets">0</span>
                <span class="stat-label">Active Bets</span>
              </div>
            </div>
            <div class="stat-card">
              <div class="stat-icon">🏆</div>
              <div class="stat-info">
                <span class="stat-value" id="stat-wins">0</span>
                <span class="stat-label">Wins</span>
              </div>
            </div>
          </div>
          
          <!-- Your Events Section -->
          <section class="feed-section">
            <div class="section-header-app">
              <h2>🎯 Your Events</h2>
            </div>
            <div class="events-scroll" id="your-events">
              <div class="loading-placeholder">Loading...</div>
            </div>
          </section>
          
          <!-- Your Positions -->
          <section class="feed-section">
            <div class="section-header-app">
              <h2>📊 Your Positions</h2>
            </div>
            <div class="positions-list" id="your-positions">
              <div class="loading-placeholder">Loading...</div>
            </div>
          </section>
          
          <!-- Recent Activity -->
          <section class="feed-section">
            <div class="section-header-app">
              <h2>💬 Recent Activity</h2>
            </div>
            <div class="activity-feed" id="activity-feed">
              <div class="loading-placeholder">Loading...</div>
            </div>
          </section>
        </div>

        <!-- Markets Tab -->
        <div class="tab-panel" id="tab-markets">
          <div class="content-header">
            <h1>Your Markets</h1>
            <button class="btn-primary" id="markets-create-btn">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                <line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
              </svg>
              New Market
            </button>
          </div>
          <div class="markets-list-app" id="markets-list">
            <div class="loading-placeholder">Loading...</div>
          </div>
        </div>

        <!-- Leaderboard Tab -->
        <div class="tab-panel" id="tab-leaderboard">
          <div class="content-header">
            <h1>Leaderboard</h1>
            <p>Top predictors across all markets</p>
          </div>
          <div class="leaderboard-container" id="leaderboard-container">
            <div class="loading-placeholder">Loading...</div>
          </div>
        </div>

        <!-- Profile Tab -->
        <div class="tab-panel" id="tab-profile">
          <div class="profile-header-app" id="profile-header">
            <div class="profile-avatar-large" id="profile-avatar-large">U</div>
            <div class="profile-info-app">
              <h1 id="profile-name">User</h1>
              <span class="profile-username" id="profile-username">@username</span>
            </div>
            <div class="profile-stats-row" id="profile-stats-row">
              <div class="profile-stat">
                <span class="profile-stat-value" id="profile-stat-tokens">0</span>
                <span class="profile-stat-label">Tokens</span>
              </div>
              <div class="profile-stat">
                <span class="profile-stat-value" id="profile-stat-accuracy">0%</span>
                <span class="profile-stat-label">Accuracy</span>
              </div>
              <div class="profile-stat">
                <span class="profile-stat-value" id="profile-stat-total-bets">0</span>
                <span class="profile-stat-label">Total Bets</span>
              </div>
            </div>
          </div>
          
          <div class="profile-content-app">
            <section class="profile-section">
              <h2>Recent Bets</h2>
              <div class="bets-list" id="profile-bets-list">
                <div class="loading-placeholder">Loading...</div>
              </div>
            </section>
            
            <section class="profile-section">
              <h2>Your Markets</h2>
              <div class="profile-markets-list" id="profile-markets-list">
                <div class="loading-placeholder">Loading...</div>
              </div>
            </section>
          </div>
        </div>

      </div>
    </main>

    <!-- Bottom Navigation (Mobile) -->
    <nav class="app-bottomnav">
      <a href="index.php" class="bottomnav-item active" data-tab="feed">
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/>
        </svg>
        <span>Feed</span>
      </a>
      <a href="events.php" class="bottomnav-item">
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/><path d="m9 16 2 2 4-4"/>
        </svg>
        <span>Events</span>
      </a>
      <button class="bottomnav-item create-btn-mobile" id="mobile-create-btn">
        <div class="create-btn-icon">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
            <line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
          </svg>
        </div>
      </button>
      <a href="index.php#leaderboard" class="bottomnav-item" data-tab="leaderboard">
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6"/><path d="M18 9h1.5a2.5 2.5 0 0 0 0-5H18"/><path d="M4 22h16"/><path d="M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22"/><path d="M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22"/><path d="M18 2H6v7a6 6 0 0 0 12 0V2Z"/>
        </svg>
        <span>Ranks</span>
      </a>
      <a href="index.php#markets" class="bottomnav-item" data-tab="markets">
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>
        </svg>
        <span>Markets</span>
      </a>
    </nav>

    <!-- Create Menu (FAB Menu) -->
    <div class="create-menu-backdrop" id="create-menu-backdrop" style="display:none;"></div>
    <div class="create-menu" id="create-menu" style="display:none;">
      <button class="create-menu-item" id="create-market-btn">
        <div class="create-menu-icon">👥</div>
        <div class="create-menu-text">
          <span class="create-menu-title">New Market</span>
          <span class="create-menu-desc">Create a group for predictions</span>
        </div>
      </button>
      <button class="create-menu-item" id="create-event-btn">
        <div class="create-menu-icon">📊</div>
        <div class="create-menu-text">
          <span class="create-menu-title">New Event</span>
          <span class="create-menu-desc">Ask a prediction question</span>
        </div>
      </button>
    </div>

  </div>

  <!-- Why Tyches -->
  <section class="why-tyches marketing-only">
    <div class="container-landing">
      <div class="why-content">
        <div class="why-icon">
          <svg width="40" height="40" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
            <rect width="32" height="32" rx="10" fill="url(#gradient-why)"/>
            <path d="M16 8L20 14H24L18 20L20 26L16 22L12 26L14 20L8 14H12L16 8Z" fill="white"/>
            <defs>
              <linearGradient id="gradient-why" x1="0" y1="0" x2="32" y2="32" gradientUnits="userSpaceOnUse">
                <stop stop-color="#6366F1"/>
                <stop offset="1" stop-color="#8B5CF6"/>
              </linearGradient>
            </defs>
          </svg>
        </div>
        <h3>Why "Tyches"?</h3>
        <p>Named after <a href="https://en.wikipedia.org/wiki/Tyche" target="_blank" rel="noopener">Tyche</a>, the Greek goddess of fortune and chance. Your markets are your group's little Tyche—a private place to write down predictions and see who's actually lucky.</p>
      </div>
    </div>
  </section>

  <!-- Compact Footer -->
  <footer class="footer-compact marketing-only">
    <div class="container-landing">
      <div class="footer-main-compact">
        <div class="footer-brand-compact">
          <div class="brand-row">
            <svg width="28" height="28" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
              <rect width="32" height="32" rx="8" fill="url(#gradient-footer)"/>
              <path d="M16 8L20 14H24L18 20L20 26L16 22L12 26L14 20L8 14H12L16 8Z" fill="white"/>
              <defs>
                <linearGradient id="gradient-footer" x1="0" y1="0" x2="32" y2="32" gradientUnits="userSpaceOnUse">
                  <stop stop-color="#6366F1"/>
                  <stop offset="1" stop-color="#8B5CF6"/>
                </linearGradient>
              </defs>
            </svg>
            <span class="brand-name">Tyches</span>
          </div>
          <p class="brand-tagline">Predict with your friends.</p>
        </div>
        <div class="footer-cols">
          <div class="footer-col-compact">
            <h4>Legal</h4>
            <a href="terms.php">Terms of Service</a>
            <a href="privacy.php">Privacy Policy</a>
          </div>
          <div class="footer-col-compact">
            <h4>Support</h4>
            <a href="contact.php">Contact Us</a>
            <a href="mailto:admin@tyches.us">admin@tyches.us</a>
          </div>
        </div>
      </div>
      <div class="footer-bottom-compact">
        <span>&copy; <?php echo date('Y'); ?> Tyches. All rights reserved.</span>
        <div class="footer-bottom-links">
          <a href="privacy.php">Privacy</a>
          <a href="terms.php">Terms</a>
        </div>
      </div>
    </div>
  </footer>

  <!-- Auth + create modals are injected/managed by app.js -->
  <?php js_script('js/core.js'); ?>
  <?php js_script('js/app.js'); ?>
  
  <!-- Simple Notifications Handler -->
  <script>
  (function() {
    // Self-contained notifications handler
    var panelOpen = false;
    var panel = null;
    
    function toggleNotifications() {
      if (!panel) {
        createPanel();
      }
      panelOpen = !panelOpen;
      panel.style.display = panelOpen ? 'block' : 'none';
      if (panelOpen) {
        loadNotifications();
      }
    }
    
    function createPanel() {
      panel = document.createElement('div');
      panel.id = 'simple-notifications-panel';
      panel.style.cssText = 'position:fixed;top:70px;right:20px;width:360px;max-width:90vw;background:#fff;border-radius:12px;box-shadow:0 10px 40px rgba(0,0,0,0.15);z-index:10000;display:none;max-height:70vh;overflow:hidden;';
      panel.innerHTML = '<div style="padding:16px;border-bottom:1px solid #eee;display:flex;justify-content:space-between;align-items:center;"><strong>Notifications</strong><button id="close-notif-panel" style="background:none;border:none;cursor:pointer;font-size:20px;">&times;</button></div><div id="notif-list" style="padding:8px;max-height:50vh;overflow-y:auto;"><div style="padding:20px;text-align:center;color:#888;">Loading...</div></div>';
      document.body.appendChild(panel);
      
      document.getElementById('close-notif-panel').onclick = function() {
        panelOpen = false;
        panel.style.display = 'none';
      };
      
      // Close on outside click
      document.addEventListener('click', function(e) {
        if (panelOpen && panel && !panel.contains(e.target) && !e.target.closest('#notifications-btn')) {
          panelOpen = false;
          panel.style.display = 'none';
        }
      });
    }
    
    function loadNotifications() {
      var list = document.getElementById('notif-list');
      fetch('api/notifications.php', { credentials: 'same-origin' })
        .then(function(r) { return r.json(); })
        .then(function(data) {
          if (!data.notifications || data.notifications.length === 0) {
            list.innerHTML = '<div style="padding:30px;text-align:center;"><div style="font-size:40px;margin-bottom:10px;">🔔</div><p style="color:#666;margin:0;">No notifications yet</p><small style="color:#999;">You\'re all caught up!</small></div>';
          } else {
            list.innerHTML = data.notifications.map(function(n) {
              var icon = n.type === 'welcome' ? '🎉' : n.type === 'tip' ? '💡' : '🔔';
              return '<div style="padding:12px;border-bottom:1px solid #f0f0f0;' + (n.is_read ? 'opacity:0.6;' : '') + '"><div style="display:flex;gap:10px;"><span style="font-size:20px;">' + icon + '</span><div><div style="font-weight:500;margin-bottom:4px;">' + (n.title || '') + '</div><div style="font-size:13px;color:#666;">' + (n.message || '') + '</div></div></div></div>';
            }).join('');
          }
        })
        .catch(function(err) {
          console.error('Notification error:', err);
          list.innerHTML = '<div style="padding:20px;text-align:center;color:#888;">Could not load notifications</div>';
        });
    }
    
    // Setup click handler after DOM is ready
    document.addEventListener('DOMContentLoaded', function() {
      var bell = document.getElementById('notifications-btn');
      if (bell) {
        bell.addEventListener('click', function(e) {
          e.preventDefault();
          e.stopPropagation();
          toggleNotifications();
        });
      }
    });
  })();
  </script>
  
  <!-- Cookie Banner (Black Theme) -->
  <div id="cookie-banner" class="cookie-banner-dark">
    <div class="cookie-banner-content">
      <div class="cookie-banner-text">
        This site uses cookies. Visit our 
        <a href="privacy.php#cookies">cookies policy page</a> 
        for more information or to change your preferences.
      </div>
      <div class="cookie-banner-buttons">
        <button onclick="acceptCookies(true)" class="cookie-btn-accept">Accept all</button>
        <button onclick="acceptCookies(false)" class="cookie-btn-essential">Essentials</button>
      </div>
    </div>
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
    
    // Learn more button scrolls to steps
    document.getElementById('hero-learn-more')?.addEventListener('click', () => {
      document.querySelector('.simple-steps')?.scrollIntoView({ behavior: 'smooth' });
    });
  </script>
</body>
</html>
