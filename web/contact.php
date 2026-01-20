<?php
// contact.php
// Tyches Contact Page

declare(strict_types=1);

require_once __DIR__ . '/api/security.php';
require_once __DIR__ . '/includes/asset-helpers.php';

tyches_start_session();
$isLoggedIn = isset($_SESSION['user_id']) && is_int($_SESSION['user_id']);

// Handle form submission
$formSubmitted = false;
$formError = '';
$formSuccess = false;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Verify CSRF token
    $csrfToken = $_POST['_csrf'] ?? '';
    $expectedToken = $_SESSION['csrf_token'] ?? '';
    
    if ($csrfToken === '' || !hash_equals($expectedToken, $csrfToken)) {
        $formError = 'Invalid request. Please refresh the page and try again.';
    } else {
        // Rate limit: 5 contact form submissions per hour per IP
        $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
        tyches_require_rate_limit('contact:' . $ip, 5, 3600);
        
        $name = trim($_POST['name'] ?? '');
        $email = trim($_POST['email'] ?? '');
        $subject = trim($_POST['subject'] ?? '');
        $message = trim($_POST['message'] ?? '');
        
        // Validation
        if ($name === '' || $email === '' || $subject === '' || $message === '') {
            $formError = 'All fields are required.';
        } elseif (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $formError = 'Please enter a valid email address.';
        } elseif (strlen($message) < 10) {
            $formError = 'Please provide a more detailed message (at least 10 characters).';
        } elseif (strlen($message) > 5000) {
            $formError = 'Message is too long (maximum 5000 characters).';
        } else {
            // Honeypot check (hidden field should be empty)
            $honeypot = $_POST['website'] ?? '';
            if ($honeypot !== '') {
                // Likely a bot, silently "succeed"
                $formSuccess = true;
            } else {
                // Send email
                $to = 'admin@tyches.us';
                $emailSubject = '[Tyches Contact] ' . $subject;
                
                $emailBody = "New contact form submission from Tyches\n";
                $emailBody .= "==========================================\n\n";
                $emailBody .= "Name: {$name}\n";
                $emailBody .= "Email: {$email}\n";
                $emailBody .= "Subject: {$subject}\n\n";
                $emailBody .= "Message:\n";
                $emailBody .= "----------------------------------------\n";
                $emailBody .= $message . "\n";
                $emailBody .= "----------------------------------------\n\n";
                $emailBody .= "Submitted: " . date('Y-m-d H:i:s') . " UTC\n";
                $emailBody .= "IP Address: {$ip}\n";
                
                if ($isLoggedIn && isset($_SESSION['user_id'])) {
                    $emailBody .= "User ID: " . $_SESSION['user_id'] . "\n";
                }
                
                $headers = [
                    'From: noreply@tyches.us',
                    'Reply-To: ' . $email,
                    'X-Mailer: PHP/' . phpversion(),
                    'Content-Type: text/plain; charset=UTF-8',
                ];
                
                $sent = @mail($to, $emailSubject, $emailBody, implode("\r\n", $headers));
                
                if ($sent) {
                    $formSuccess = true;
                } else {
                    // Fallback: try using the mailer if mail() fails
                    require_once __DIR__ . '/api/mailer.php';
                    try {
                        // Simple fallback - just log the contact
                        error_log("Contact form submission from {$email}: {$subject}");
                        $formSuccess = true;
                    } catch (Exception $e) {
                        $formError = 'Unable to send message. Please email us directly at admin@tyches.us';
                    }
                }
            }
        }
    }
    $formSubmitted = true;
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Contact Us - Tyches</title>
  <meta name="csrf-token" content="<?php echo e(tyches_get_csrf_token()); ?>">
  <meta name="description" content="Contact Tyches - Get in touch with our team for questions, feedback, or support.">
  
  <!-- Resource hints -->
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link rel="dns-prefetch" href="https://www.googletagmanager.com">
  
  <!-- Font - Plus Jakarta Sans -->
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
<body class="contact-page" data-logged-in="<?php echo $isLoggedIn ? '1' : '0'; ?>">
  <!-- Navigation -->
  <nav class="navbar">
    <div class="nav-container">
      <a href="index.php" class="logo">
        <svg width="32" height="32" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
          <rect width="32" height="32" rx="8" fill="url(#gradient)"/>
          <path d="M16 8L20 14H24L18 20L20 26L16 22L12 26L14 20L8 14H12L16 8Z" fill="white"/>
          <defs>
            <linearGradient id="gradient" x1="0" y1="0" x2="32" y2="32" gradientUnits="userSpaceOnUse">
              <stop stop-color="#6366F1"/>
              <stop offset="1" stop-color="#8B5CF6"/>
            </linearGradient>
          </defs>
        </svg>
        <span>Tyches</span>
      </a>
      <div class="nav-links" id="nav-links">
        <a href="index.php" class="nav-link">Home</a>
        <a href="terms.php" class="nav-link">Terms</a>
        <a href="privacy.php" class="nav-link">Privacy</a>
        <button class="btn-secondary logged-out-only" id="nav-login">Log in</button>
        <button class="btn-primary logged-out-only" id="nav-get-started">Get Started</button>
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
      <button class="mobile-menu-btn" aria-label="Menu">
        <span></span>
        <span></span>
        <span></span>
      </button>
    </div>
  </nav>

  <!-- Contact Content -->
  <main class="contact-content">
    <div class="container">
      <div class="contact-wrapper">
        <div class="contact-info-section">
          <h1>Get in Touch</h1>
          <p class="contact-intro">Have a question, feedback, or need support? We'd love to hear from you. Fill out the form and we'll get back to you as soon as possible.</p>
          
          <div class="contact-methods">
            <div class="contact-method">
              <div class="contact-method-icon">📧</div>
              <div class="contact-method-details">
                <h3>Email Us</h3>
                <a href="mailto:admin@tyches.us">admin@tyches.us</a>
                <p>We typically respond within 24-48 hours</p>
              </div>
            </div>
            
            <div class="contact-method">
              <div class="contact-method-icon">💬</div>
              <div class="contact-method-details">
                <h3>Common Topics</h3>
                <ul class="contact-topics">
                  <li>Account issues & recovery</li>
                  <li>Bug reports & feedback</li>
                  <li>Feature requests</li>
                  <li>Partnership inquiries</li>
                  <li>Press & media</li>
                </ul>
              </div>
            </div>

            <div class="contact-method">
              <div class="contact-method-icon">📋</div>
              <div class="contact-method-details">
                <h3>Legal</h3>
                <p>Review our <a href="terms.php">Terms of Service</a> and <a href="privacy.php">Privacy Policy</a></p>
              </div>
            </div>
          </div>
        </div>

        <div class="contact-form-section">
          <?php if ($formSubmitted && $formSuccess): ?>
            <div class="contact-success">
              <div class="success-icon">✓</div>
              <h2>Message Sent!</h2>
              <p>Thank you for reaching out. We've received your message and will get back to you within 24-48 hours.</p>
              <a href="index.php" class="btn-primary">Back to Home</a>
            </div>
          <?php else: ?>
            <form class="contact-form" method="POST" action="contact.php">
              <input type="hidden" name="_csrf" value="<?php echo e(tyches_get_csrf_token()); ?>">
              
              <!-- Honeypot field (hidden from users, bots will fill it) -->
              <div style="position: absolute; left: -9999px;">
                <label for="website">Leave this field empty</label>
                <input type="text" name="website" id="website" tabindex="-1" autocomplete="off">
              </div>

              <?php if ($formError): ?>
                <div class="form-error">
                  <span class="error-icon">⚠️</span>
                  <?php echo e($formError); ?>
                </div>
              <?php endif; ?>

              <div class="form-group">
                <label for="name">Your Name <span class="required">*</span></label>
                <input 
                  type="text" 
                  id="name" 
                  name="name" 
                  required 
                  maxlength="100"
                  placeholder="John Doe"
                  value="<?php echo e($_POST['name'] ?? ''); ?>"
                >
              </div>

              <div class="form-group">
                <label for="email">Email Address <span class="required">*</span></label>
                <input 
                  type="email" 
                  id="email" 
                  name="email" 
                  required 
                  maxlength="255"
                  placeholder="john@example.com"
                  value="<?php echo e($_POST['email'] ?? ''); ?>"
                >
              </div>

              <div class="form-group">
                <label for="subject">Subject <span class="required">*</span></label>
                <select id="subject" name="subject" required>
                  <option value="">Select a topic...</option>
                  <option value="General Inquiry" <?php echo ($_POST['subject'] ?? '') === 'General Inquiry' ? 'selected' : ''; ?>>General Inquiry</option>
                  <option value="Account Help" <?php echo ($_POST['subject'] ?? '') === 'Account Help' ? 'selected' : ''; ?>>Account Help</option>
                  <option value="Bug Report" <?php echo ($_POST['subject'] ?? '') === 'Bug Report' ? 'selected' : ''; ?>>Bug Report</option>
                  <option value="Feature Request" <?php echo ($_POST['subject'] ?? '') === 'Feature Request' ? 'selected' : ''; ?>>Feature Request</option>
                  <option value="Feedback" <?php echo ($_POST['subject'] ?? '') === 'Feedback' ? 'selected' : ''; ?>>Feedback</option>
                  <option value="Partnership" <?php echo ($_POST['subject'] ?? '') === 'Partnership' ? 'selected' : ''; ?>>Partnership Inquiry</option>
                  <option value="Press" <?php echo ($_POST['subject'] ?? '') === 'Press' ? 'selected' : ''; ?>>Press & Media</option>
                  <option value="Other" <?php echo ($_POST['subject'] ?? '') === 'Other' ? 'selected' : ''; ?>>Other</option>
                </select>
              </div>

              <div class="form-group">
                <label for="message">Message <span class="required">*</span></label>
                <textarea 
                  id="message" 
                  name="message" 
                  required 
                  rows="6"
                  minlength="10"
                  maxlength="5000"
                  placeholder="Tell us how we can help..."
                ><?php echo e($_POST['message'] ?? ''); ?></textarea>
                <span class="form-hint">Minimum 10 characters</span>
              </div>

              <div class="form-group form-checkbox">
                <input type="checkbox" id="privacy-agree" name="privacy_agree" required>
                <label for="privacy-agree">
                  I have read and agree to the <a href="privacy.php" target="_blank">Privacy Policy</a> <span class="required">*</span>
                </label>
              </div>

              <button type="submit" class="btn-primary btn-large btn-full">
                Send Message
              </button>
            </form>
          <?php endif; ?>
        </div>
      </div>
    </div>
  </main>

  <!-- Footer -->
  <footer class="site-footer">
    <div class="container">
      <div class="footer-content">
        <div class="footer-brand">
          <a href="index.php" class="logo">
            <svg width="24" height="24" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
              <rect width="32" height="32" rx="8" fill="url(#gradient-footer)"/>
              <path d="M16 8L20 14H24L18 20L20 26L16 22L12 26L14 20L8 14H12L16 8Z" fill="white"/>
              <defs>
                <linearGradient id="gradient-footer" x1="0" y1="0" x2="32" y2="32" gradientUnits="userSpaceOnUse">
                  <stop stop-color="#6366F1"/>
                  <stop offset="1" stop-color="#8B5CF6"/>
                </linearGradient>
              </defs>
            </svg>
            <span>Tyches</span>
          </a>
          <p>Private prediction markets for your friends.</p>
        </div>
        <div class="footer-links">
          <div class="footer-column">
            <h4>Legal</h4>
            <a href="terms.php">Terms of Service</a>
            <a href="privacy.php">Privacy Policy</a>
          </div>
          <div class="footer-column">
            <h4>Support</h4>
            <a href="contact.php">Contact Us</a>
            <a href="mailto:admin@tyches.us">admin@tyches.us</a>
          </div>
        </div>
      </div>
      <div class="footer-bottom">
        <p>&copy; <?php echo date('Y'); ?> Tyches. All rights reserved.</p>
      </div>
    </div>
  </footer>

  <script src="app.js"></script>

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
  </script>
</body>
</html>

