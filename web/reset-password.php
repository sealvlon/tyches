<?php
// reset-password.php
// Password reset landing page - allows user to set a new password using token from email.

declare(strict_types=1);

require_once __DIR__ . '/api/config.php';
require_once __DIR__ . '/api/security.php';
require_once __DIR__ . '/includes/asset-helpers.php';

tyches_start_session();

$token = isset($_GET['token']) ? trim((string)$_GET['token']) : '';
$status = 'form'; // form, success, invalid, missing, error
$errorMessage = '';

// Handle form submission
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $token = isset($_POST['token']) ? trim((string)$_POST['token']) : '';
    $password = $_POST['password'] ?? '';
    $passwordConfirm = $_POST['password_confirm'] ?? '';
    
    // Rate limit password reset attempts
    $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
    
    try {
        // Validate inputs
        if ($token === '') {
            $status = 'missing';
        } elseif ($password === '') {
            $status = 'form';
            $errorMessage = 'Please enter a new password.';
        } elseif (strlen($password) < 8) {
            $status = 'form';
            $errorMessage = 'Password must be at least 8 characters.';
        } elseif ($password !== $passwordConfirm) {
            $status = 'form';
            $errorMessage = 'Passwords do not match.';
        } else {
            $pdo = get_pdo();
            
            // Find user with this token
            $stmt = $pdo->prepare(
                'SELECT id, email_verified_at FROM users WHERE verification_token = :token LIMIT 1'
            );
            $stmt->execute([':token' => $token]);
            $user = $stmt->fetch();
            
            if (!$user) {
                $status = 'invalid';
            } else {
                // Update password and clear token
                $newHash = password_hash($password, PASSWORD_DEFAULT);
                
                $stmtUpd = $pdo->prepare(
                    'UPDATE users
                     SET password_hash = :hash, verification_token = NULL
                     WHERE id = :id
                     LIMIT 1'
                );
                $stmtUpd->execute([
                    ':hash' => $newHash,
                    ':id'   => (int)$user['id'],
                ]);
                
                $status = 'success';
            }
        }
    } catch (Throwable $e) {
        error_log('reset-password.php error: ' . $e->getMessage());
        $status = 'error';
    }
} else {
    // GET request - validate token exists
    if ($token === '') {
        $status = 'missing';
    } else {
        try {
            $pdo = get_pdo();
            $stmt = $pdo->prepare(
                'SELECT id FROM users WHERE verification_token = :token LIMIT 1'
            );
            $stmt->execute([':token' => $token]);
            $user = $stmt->fetch();
            
            if (!$user) {
                $status = 'invalid';
            }
            // else status remains 'form'
        } catch (Throwable $e) {
            error_log('reset-password.php error: ' . $e->getMessage());
            $status = 'error';
        }
    }
}

$csrfToken = tyches_get_csrf_token();
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Reset Password - Tyches</title>
  <meta name="robots" content="noindex, nofollow">
  
  <!-- Resource hints -->
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  
  <!-- Font - Plus Jakarta Sans -->
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  
  <!-- Stylesheet -->
  <?php css_link('styles.css'); ?>
  
  <link rel="icon" href="favicon.ico">
  
  <!-- Google Analytics -->
  <script async src="https://www.googletagmanager.com/gtag/js?id=G-0000000000"></script>
  <script>
    window.dataLayer = window.dataLayer || [];
    function gtag(){dataLayer.push(arguments);}
    gtag('js', new Date());
    gtag('config', 'G-0000000000'); // Google Analytics
  </script>
  <style>
    .reset-body {
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      background: linear-gradient(180deg, #FFFFFF 0%, #F8FAFC 100%);
      padding: 24px;
    }
    .reset-card {
      background: #fff;
      border-radius: 16px;
      box-shadow: 0 4px 24px rgba(0, 0, 0, 0.08);
      padding: 48px 40px;
      max-width: 420px;
      width: 100%;
      text-align: center;
    }
    .reset-icon {
      font-size: 48px;
      margin-bottom: 16px;
    }
    .reset-card h1 {
      font-size: 1.5rem;
      font-weight: 700;
      color: var(--text-primary);
      margin-bottom: 8px;
    }
    .reset-card p {
      color: var(--text-secondary);
      margin-bottom: 24px;
      line-height: 1.5;
    }
    .reset-form {
      text-align: left;
    }
    .reset-form .form-group {
      margin-bottom: 16px;
    }
    .reset-form label {
      display: block;
      font-size: 0.875rem;
      font-weight: 600;
      color: var(--text-primary);
      margin-bottom: 6px;
    }
    .reset-form input {
      width: 100%;
      padding: 12px 14px;
      font-size: 1rem;
      border: 1px solid var(--border);
      border-radius: 10px;
      background: var(--bg-secondary);
      transition: border-color 0.2s, box-shadow 0.2s;
      font-family: inherit;
    }
    .reset-form input:focus {
      outline: none;
      border-color: var(--primary);
      box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
    }
    .reset-form .btn-submit {
      width: 100%;
      padding: 14px;
      font-size: 1rem;
      font-weight: 600;
      color: #fff;
      background: var(--gradient-primary);
      border: none;
      border-radius: 10px;
      cursor: pointer;
      transition: transform 0.2s, box-shadow 0.2s;
      font-family: inherit;
      margin-top: 8px;
    }
    .reset-form .btn-submit:hover {
      transform: translateY(-1px);
      box-shadow: 0 4px 12px rgba(99, 102, 241, 0.3);
    }
    .reset-error {
      background: #fef2f2;
      color: #dc2626;
      padding: 12px 14px;
      border-radius: 8px;
      font-size: 0.875rem;
      margin-bottom: 16px;
      text-align: left;
    }
    .reset-back-btn {
      display: inline-block;
      margin-top: 24px;
      padding: 12px 28px;
      font-size: 0.9375rem;
      font-weight: 600;
      color: #fff;
      background: var(--gradient-primary);
      border: none;
      border-radius: 100px;
      text-decoration: none;
      transition: transform 0.2s, box-shadow 0.2s;
    }
    .reset-back-btn:hover {
      transform: translateY(-1px);
      box-shadow: 0 4px 12px rgba(99, 102, 241, 0.3);
    }
    .password-requirements {
      font-size: 0.8125rem;
      color: var(--text-tertiary);
      margin-top: 4px;
    }
  </style>
</head>
<body class="reset-body">
  <div class="reset-card">
    <?php if ($status === 'success'): ?>
      <div class="reset-icon">✅</div>
      <h1>Password Reset!</h1>
      <p>Your password has been successfully changed. You can now log in with your new password.</p>
      <a href="index.php" class="reset-back-btn">Log In</a>
      
    <?php elseif ($status === 'invalid'): ?>
      <div class="reset-icon">❌</div>
      <h1>Invalid Link</h1>
      <p>This password reset link is invalid or has expired. Please request a new one.</p>
      <a href="index.php" class="reset-back-btn">Back to Tyches</a>
      
    <?php elseif ($status === 'missing'): ?>
      <div class="reset-icon">🔗</div>
      <h1>Missing Token</h1>
      <p>No reset token was provided. Please use the link from your email.</p>
      <a href="index.php" class="reset-back-btn">Back to Tyches</a>
      
    <?php elseif ($status === 'error'): ?>
      <div class="reset-icon">⚠️</div>
      <h1>Something Went Wrong</h1>
      <p>An error occurred while resetting your password. Please try again later.</p>
      <a href="index.php" class="reset-back-btn">Back to Tyches</a>
      
    <?php else: ?>
      <div class="reset-icon">🔐</div>
      <h1>Reset Your Password</h1>
      <p>Enter your new password below.</p>
      
      <?php if ($errorMessage): ?>
        <div class="reset-error"><?php echo htmlspecialchars($errorMessage); ?></div>
      <?php endif; ?>
      
      <form method="POST" action="reset-password.php" class="reset-form">
        <input type="hidden" name="token" value="<?php echo htmlspecialchars($token); ?>">
        <input type="hidden" name="_csrf" value="<?php echo htmlspecialchars($csrfToken); ?>">
        
        <div class="form-group">
          <label for="password">New Password</label>
          <input type="password" id="password" name="password" required minlength="8" autocomplete="new-password">
          <div class="password-requirements">At least 8 characters</div>
        </div>
        
        <div class="form-group">
          <label for="password_confirm">Confirm Password</label>
          <input type="password" id="password_confirm" name="password_confirm" required minlength="8" autocomplete="new-password">
        </div>
        
        <button type="submit" class="btn-submit">Reset Password</button>
      </form>
      
      <a href="index.php" style="display: inline-block; margin-top: 16px; color: var(--text-secondary); font-size: 0.875rem;">← Back to Tyches</a>
    <?php endif; ?>
  </div>
  
  <!-- Cookie Banner -->
  <div id="cookie-banner" class="cookie-banner-dark">
    <div class="cookie-banner-content">
      <div class="cookie-banner-text">
        This site uses cookies. Visit our 
        <a href="privacy.php#cookies">cookies policy page</a> 
        for more information.
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
  </script>
</body>
</html>

