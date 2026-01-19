<?php
// privacy.php
// Tyches Privacy Policy

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
  <title>Privacy Policy - Tyches</title>
  <meta name="csrf-token" content="<?php echo e(tyches_get_csrf_token()); ?>">
  <meta name="description" content="Tyches Privacy Policy - Learn how we collect, use, and protect your personal information.">
  
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
  <script async src="https://www.googletagmanager.com/gtag/js?id=G-0000000000"></script>
  <script>
    window.dataLayer = window.dataLayer || [];
    function gtag(){dataLayer.push(arguments);}
    gtag('js', new Date());
    gtag('config', 'G-0000000000'); // Google Analytics
  </script>
</head>
<body class="legal-page" data-logged-in="<?php echo $isLoggedIn ? '1' : '0'; ?>">
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
        <a href="contact.php" class="nav-link">Contact</a>
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

  <!-- Legal Content -->
  <main class="legal-content">
    <div class="container">
      <div class="legal-header">
        <h1 style='color:black;'>Privacy Policy</h1>
        <p class="legal-updated">Last updated: <?php echo date('F j, Y'); ?></p>
      </div>

      <div class="legal-body">
        <section class="legal-section">
          <h2>Introduction</h2>
          <p>Tyches ("Company," "we," "us," or "our") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our website, mobile application, and services (collectively, the "Platform").</p>
          <p>Please read this Privacy Policy carefully. By using the Platform, you consent to the data practices described in this policy. If you do not agree with our policies, please do not use the Platform.</p>
        </section>

        <section class="legal-section">
          <h2>1. Information We Collect</h2>
          
          <h3>1.1 Information You Provide</h3>
          <p>We collect information you voluntarily provide when using the Platform:</p>
          <ul>
            <li><strong>Account Information:</strong> Name, username, email address, phone number (optional), and password when you register</li>
            <li><strong>Profile Information:</strong> Profile picture, bio, and other optional details you add</li>
            <li><strong>User Content:</strong> Prediction events you create, comments ("gossip"), and bets you place</li>
            <li><strong>Communications:</strong> Messages you send to us via email or the contact form</li>
            <li><strong>Invitations:</strong> Email addresses of friends you invite to the Platform</li>
          </ul>

          <h3>1.2 Information Collected Automatically</h3>
          <p>When you access the Platform, we automatically collect:</p>
          <ul>
            <li><strong>Device Information:</strong> Device type, operating system, browser type, unique device identifiers</li>
            <li><strong>Log Data:</strong> IP address, access times, pages viewed, links clicked, and referring URLs</li>
            <li><strong>Usage Data:</strong> Features used, predictions made, tokens earned and spent, and interaction patterns</li>
            <li><strong>Location Data:</strong> General geographic location based on IP address (not precise location)</li>
          </ul>

          <h3 id="cookies">1.3 Cookies and Tracking Technologies</h3>
          <p>We use cookies and similar technologies to:</p>
          <ul>
            <li><strong>Essential Cookies:</strong> Maintain your session and remember your login status</li>
            <li><strong>Preference Cookies:</strong> Remember your settings and preferences</li>
            <li><strong>Analytics Cookies:</strong> Understand how you use the Platform and improve our services</li>
          </ul>
          
          <div class="legal-highlight">
            <h4>🍪 Your Cookie Choices</h4>
            <p>You can control cookies through your browser settings. Note that disabling certain cookies may affect Platform functionality. We respect "Do Not Track" signals when technically feasible.</p>
          </div>
        </section>

        <section class="legal-section">
          <h2>2. How We Use Your Information</h2>
          <p>We use collected information to:</p>
          
          <h3>2.1 Provide and Improve Services</h3>
          <ul>
            <li>Create and manage your account</li>
            <li>Process predictions and calculate outcomes</li>
            <li>Manage token balances and leaderboards</li>
            <li>Send notifications about events and activity</li>
            <li>Respond to your inquiries and support requests</li>
            <li>Analyze usage to improve features and user experience</li>
          </ul>

          <h3>2.2 Safety and Security</h3>
          <ul>
            <li>Detect and prevent fraud, abuse, and policy violations</li>
            <li>Verify accounts and authenticate users</li>
            <li>Enforce our Terms and Conditions</li>
            <li>Protect the rights and safety of users</li>
          </ul>

          <h3>2.3 Communications</h3>
          <ul>
            <li>Send service-related emails (verification, password reset, important updates)</li>
            <li>Notify you about activity in your Markets (new events, bets, resolutions)</li>
            <li>Send promotional communications (you can opt out anytime)</li>
          </ul>
        </section>

        <section class="legal-section">
          <h2>3. How We Share Your Information</h2>
          <p>We do not sell your personal information. We may share information in the following circumstances:</p>

          <h3>3.1 With Other Users</h3>
          <ul>
            <li><strong>Within Markets:</strong> Your username, profile picture, predictions, bets, and comments are visible to other members of the same Market</li>
            <li><strong>Leaderboards:</strong> Your username and prediction performance may appear on leaderboards visible to Market members</li>
            <li><strong>Invitations:</strong> When you invite someone, they will see your name as the inviter</li>
          </ul>

          <h3>3.2 With Service Providers</h3>
          <p>We share information with trusted third parties who assist in operating the Platform:</p>
          <ul>
            <li><strong>Hosting Providers:</strong> To store and serve our Platform</li>
            <li><strong>Email Services:</strong> To send transactional and notification emails</li>
            <li><strong>Analytics Providers:</strong> To understand Platform usage (e.g., Google Analytics)</li>
          </ul>
          <p>These providers are contractually obligated to protect your information and use it only for the purposes we specify.</p>

          <h3>3.3 For Legal Reasons</h3>
          <p>We may disclose information if required to:</p>
          <ul>
            <li>Comply with applicable laws, regulations, or legal processes</li>
            <li>Respond to lawful requests from public authorities</li>
            <li>Protect our rights, property, or safety</li>
            <li>Prevent or investigate possible wrongdoing</li>
          </ul>

          <h3>3.4 Business Transfers</h3>
          <p>If Tyches is involved in a merger, acquisition, or sale of assets, your information may be transferred as part of that transaction. We will notify you of any change in ownership or use of your information.</p>
        </section>

        <section class="legal-section">
          <h2>4. Data Retention</h2>
          <p>We retain your information for as long as necessary to:</p>
          <ul>
            <li>Maintain your account and provide services</li>
            <li>Comply with legal obligations</li>
            <li>Resolve disputes and enforce agreements</li>
            <li>Achieve the purposes described in this Privacy Policy</li>
          </ul>
          <p>When you delete your account, we will delete or anonymize your personal information within 30 days, except where retention is required by law or for legitimate business purposes.</p>
        </section>

        <section class="legal-section">
          <h2>5. Data Security</h2>
          <p>We implement appropriate technical and organizational measures to protect your information:</p>
          <ul>
            <li><strong>Encryption:</strong> Data transmitted via HTTPS/TLS encryption</li>
            <li><strong>Password Security:</strong> Passwords are hashed using industry-standard algorithms</li>
            <li><strong>Access Controls:</strong> Limited access to personal data on a need-to-know basis</li>
            <li><strong>Security Monitoring:</strong> Regular monitoring for suspicious activity</li>
            <li><strong>CSRF Protection:</strong> Protection against cross-site request forgery attacks</li>
            <li><strong>Rate Limiting:</strong> Protection against brute force and abuse</li>
          </ul>
          <p>However, no method of transmission or storage is 100% secure. We cannot guarantee absolute security, and you use the Platform at your own risk.</p>
        </section>

        <section class="legal-section">
          <h2>6. Your Rights and Choices</h2>
          
          <h3>6.1 Access and Portability</h3>
          <p>You can access much of your personal information directly through your account settings. You may request a copy of your data by contacting us.</p>

          <h3>6.2 Correction</h3>
          <p>You can update your account information through your profile settings. For other corrections, contact us at <a href="mailto:admin@tyches.us">admin@tyches.us</a>.</p>

          <h3>6.3 Deletion</h3>
          <p>You can request deletion of your account and personal information. Some information may be retained as required by law or for legitimate business purposes.</p>

          <h3>6.4 Communication Preferences</h3>
          <p>You can opt out of promotional emails by clicking "unsubscribe" in any marketing email. Note that you cannot opt out of essential service communications (e.g., security alerts, account verification).</p>

          <h3>6.5 Cookie Preferences</h3>
          <p>You can manage cookie preferences through our cookie banner or your browser settings.</p>
        </section>

        <section class="legal-section">
          <h2>7. International Data Transfers</h2>
          <p>Tyches is based in the United States. If you access the Platform from outside the United States, your information may be transferred to, stored, and processed in the United States or other countries where our service providers operate.</p>
          <p>By using the Platform, you consent to the transfer of your information to countries that may have different data protection laws than your country of residence.</p>
        </section>

        <section class="legal-section">
          <h2>8. Children's Privacy</h2>
          <div class="legal-highlight warning">
            <p><strong>The Platform is not intended for children under 18 years of age.</strong></p>
            <p>We do not knowingly collect personal information from children under 18. If you are a parent or guardian and believe your child has provided us with personal information, please contact us immediately at <a href="mailto:admin@tyches.us">admin@tyches.us</a>. If we learn we have collected information from a child under 18, we will delete it promptly.</p>
          </div>
        </section>

        <section class="legal-section">
          <h2>9. California Privacy Rights (CCPA)</h2>
          <p>If you are a California resident, you have additional rights under the California Consumer Privacy Act (CCPA):</p>
          <ul>
            <li><strong>Right to Know:</strong> Request disclosure of personal information collected about you</li>
            <li><strong>Right to Delete:</strong> Request deletion of your personal information</li>
            <li><strong>Right to Opt-Out:</strong> Opt out of the sale of personal information (we do not sell personal information)</li>
            <li><strong>Right to Non-Discrimination:</strong> We will not discriminate against you for exercising your rights</li>
          </ul>
          <p>To exercise these rights, contact us at <a href="mailto:admin@tyches.us">admin@tyches.us</a>.</p>
        </section>

        <section class="legal-section">
          <h2>10. European Privacy Rights (GDPR)</h2>
          <p>If you are in the European Economic Area (EEA), you have additional rights under the General Data Protection Regulation (GDPR):</p>
          <ul>
            <li><strong>Legal Basis:</strong> We process your data based on consent, contract performance, legitimate interests, and legal obligations</li>
            <li><strong>Right to Access:</strong> Request a copy of your personal data</li>
            <li><strong>Right to Rectification:</strong> Request correction of inaccurate data</li>
            <li><strong>Right to Erasure:</strong> Request deletion of your data ("right to be forgotten")</li>
            <li><strong>Right to Restrict Processing:</strong> Request limitation of processing in certain circumstances</li>
            <li><strong>Right to Data Portability:</strong> Receive your data in a structured, machine-readable format</li>
            <li><strong>Right to Object:</strong> Object to processing based on legitimate interests</li>
            <li><strong>Right to Withdraw Consent:</strong> Withdraw consent at any time</li>
          </ul>
          <p>To exercise these rights or file a complaint, contact us at <a href="mailto:admin@tyches.us">admin@tyches.us</a> or your local data protection authority.</p>
        </section>

        <section class="legal-section">
          <h2>11. Third-Party Links</h2>
          <p>The Platform may contain links to third-party websites or services. We are not responsible for the privacy practices of these third parties. We encourage you to review their privacy policies before providing any personal information.</p>
        </section>

        <section class="legal-section">
          <h2>12. Changes to This Privacy Policy</h2>
          <p>We may update this Privacy Policy from time to time. We will notify you of material changes by:</p>
          <ul>
            <li>Posting the updated policy on the Platform</li>
            <li>Updating the "Last updated" date</li>
            <li>Sending an email notification for significant changes</li>
          </ul>
          <p>Your continued use of the Platform after changes constitutes acceptance of the updated Privacy Policy.</p>
        </section>

        <section class="legal-section">
          <h2>13. Contact Us</h2>
          <p>If you have questions, concerns, or requests regarding this Privacy Policy or our data practices, please contact us:</p>
          <div class="contact-info">
            <p><strong>Email:</strong> <a href="mailto:admin@tyches.us">admin@tyches.us</a></p>
            <p><strong>Contact Form:</strong> <a href="contact.php">tyches.us/contact</a></p>
          </div>
          <p>We will respond to your inquiry within 30 days.</p>
        </section>

        <div class="legal-footer">
          <p>By using Tyches, you acknowledge that you have read and understood this Privacy Policy.</p>
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

