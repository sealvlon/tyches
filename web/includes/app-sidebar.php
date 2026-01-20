<?php
/**
 * App Shell - Sidebar Navigation (Desktop)
 * $activeTab should be set before including: 'feed', 'markets', 'events', 'leaderboard', 'profile'
 */
$activeTab = $activeTab ?? 'feed';
?>
<nav class="app-sidebar">
  <div class="sidebar-nav">
    <a href="index.php" class="nav-item <?php echo $activeTab === 'feed' ? 'active' : ''; ?>" data-tab="feed">
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/>
      </svg>
      <span>Feed</span>
    </a>
    <a href="index.php#markets" class="nav-item <?php echo $activeTab === 'markets' ? 'active' : ''; ?>" data-tab="markets">
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>
      </svg>
      <span>Markets</span>
    </a>
    <a href="events.php" class="nav-item <?php echo $activeTab === 'events' ? 'active' : ''; ?>">
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/><path d="m9 16 2 2 4-4"/>
      </svg>
      <span>Events</span>
    </a>
    <a href="index.php#leaderboard" class="nav-item <?php echo $activeTab === 'leaderboard' ? 'active' : ''; ?>" data-tab="leaderboard">
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6"/><path d="M18 9h1.5a2.5 2.5 0 0 0 0-5H18"/><path d="M4 22h16"/><path d="M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22"/><path d="M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22"/><path d="M18 2H6v7a6 6 0 0 0 12 0V2Z"/>
      </svg>
      <span>Leaderboard</span>
    </a>
    <a href="profile.php" class="nav-item <?php echo $activeTab === 'profile' ? 'active' : ''; ?>" data-tab="profile">
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

