<?php
// verify.php
// Email verification landing page.

declare(strict_types=1);

require_once __DIR__ . '/api/config.php';
require_once __DIR__ . '/includes/asset-helpers.php';

$token = isset($_GET['token']) ? trim((string)$_GET['token']) : '';
$status = 'pending';

if ($token !== '') {
    try {
        $pdo = get_pdo();
        $stmt = $pdo->prepare(
            'SELECT id, email_verified_at FROM users WHERE verification_token = :token LIMIT 1'
        );
        $stmt->execute([':token' => $token]);
        $user = $stmt->fetch();

        if ($user && $user['email_verified_at'] === null) {
            $stmtUpd = $pdo->prepare(
                'UPDATE users
                 SET email_verified_at = NOW(), verification_token = NULL
                 WHERE id = :id'
            );
            $stmtUpd->execute([':id' => $user['id']]);
            $status = 'verified';
        } elseif ($user) {
            $status = 'already';
        } else {
            $status = 'invalid';
        }
    } catch (Throwable $e) {
        $status = 'error';
    }
} else {
    $status = 'missing';
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Verify Email - Tyches</title>
  
  <!-- Resource hints -->
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  
  <!-- Font - Plus Jakarta Sans -->
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  
  <!-- Stylesheet -->
  <?php css_link('styles.css'); ?>
  
  <link rel="icon" href="favicon.ico">
  
  <!-- Google Analytics -->
  <script async src="https://www.googletagmanager.com/gtag/js?id=G-0000000000"></script> <!-- Google Analytics -->
  <script>
    window.dataLayer = window.dataLayer || [];
    function gtag(){dataLayer.push(arguments);}
    gtag('js', new Date());
    gtag('config', 'G-0000000000'); // Google Analytics
  </script>
</head>
<body class="verify-body">
  <section class="verify-wrapper">
    <div class="verify-card">
      <div class="verify-icon">✨</div>
      <?php if ($status === 'verified'): ?>
        <h1 class="section-title">Email verified!</h1>
        <p class="section-subtitle">You can now log in and start predicting with your friends.</p>
      <?php elseif ($status === 'already'): ?>
        <h1 class="section-title">Already verified</h1>
        <p class="section-subtitle">This email was already verified. You can log in to Tyches.</p>
      <?php elseif ($status === 'invalid'): ?>
        <h1 class="section-title">Invalid link</h1>
        <p class="section-subtitle">This verification link is invalid or has expired.</p>
      <?php elseif ($status === 'missing'): ?>
        <h1 class="section-title">Missing token</h1>
        <p class="section-subtitle">No verification token was provided.</p>
      <?php else: ?>
        <h1 class="section-title">Something went wrong</h1>
        <p class="section-subtitle">Please try the link again or contact support.</p>
      <?php endif; ?>
      <a href="index.php" class="btn-primary verify-back-btn">Back to Tyches</a>
    </div>
  </section>
  <!-- ===== COOKIE BANNER (BLACK THEME) ===== -->
  <div id="cookie-banner" class="fixed bottom-0 inset-x-0 bg-black bg-opacity-95 p-4 shadow-lg z-50">
    <div class="max-w-5xl mx-auto flex flex-col md:flex-row items-start md:items-center justify-between gap-4 text-sm text-gray-200">
      <div>
        This site uses cookies. Visit our cookies
        <a href="privacy.php#cookies" class="underline text-white hover:text-gray-300">policy page</a> 
        information or to change your preferences.
      </div>
      <div class="flex gap-2 mt-2 md:mt-0">
        <button onclick="acceptCookies(true)" class="bg-black bg-opacity-70 text-white border border-white px-4 py-2 rounded hover:bg-white hover:text-black transition">
          Accept all
        </button>
        <button onclick="acceptCookies(false)" class="bg-transparent text-gray-300 border border-gray-500 px-4 py-2 rounded hover:bg-gray-700 hover:text-white transition">
          Essentials
        </button>
      </div>
    </div>
  </div>
  <script>
    function acceptCookies(all) {
      const d = new Date();
      d.setFullYear(d.getFullYear() + 1);
      document.cookie = `cookiesAccepted=${all ? 'all' : 'essential'}; expires=${d.toUTCString()}; path=/`;
      const banner = document.getElementById('cookie-banner');
      if (banner) {
        banner.style.display = 'none';
      }
    }
    window.addEventListener('DOMContentLoaded', () => {
      if (document.cookie.includes('cookiesAccepted')) {
        const banner = document.getElementById('cookie-banner');
        if (banner) {
          banner.style.display = 'none';
        }
      }
    });
  </script>
</body>
</html>




