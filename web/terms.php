<?php
// terms.php
// Tyches Terms and Conditions

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
  <title>Terms and Conditions - Tyches</title>
  <meta name="csrf-token" content="<?php echo e(tyches_get_csrf_token()); ?>">
  <meta name="description" content="Tyches Terms and Conditions - Read our terms of service for using our private prediction market platform.">
  
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
  <script async src="https://www.googletagmanager.com/gtag/js?id=G-0000000000"></script> <!-- Google Analytics -->
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
        <a href="privacy.php" class="nav-link">Privacy</a>
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
        <h1>Terms and Conditions</h1>
        <p class="legal-updated">Last updated: <?php echo date('F j, Y'); ?></p>
      </div>

      <div class="legal-body">
        <section class="legal-section">
          <h2>1. Agreement to Terms</h2>
          <p>Welcome to Tyches ("Company," "we," "us," or "our"). By accessing or using our website, mobile application, and services (collectively, the "Platform"), you agree to be bound by these Terms and Conditions ("Terms"). If you do not agree to these Terms, you must not access or use the Platform.</p>
          <p>These Terms constitute a legally binding agreement between you and Tyches. Please read them carefully before using our services.</p>
        </section>

        <section class="legal-section">
          <h2>2. Description of Service</h2>
          <p>Tyches is a <strong>social prediction market platform</strong> that allows users to create private groups ("Markets") with friends and make predictions on future events using <strong>virtual play-money tokens</strong>.</p>
          
          <div class="legal-highlight">
            <h3>⚠️ Important: No Real Money or Gambling</h3>
            <p>Tyches is <strong>NOT</strong> a gambling platform. Our service uses only virtual tokens with no monetary value. You cannot:</p>
            <ul>
              <li>Purchase tokens with real money</li>
              <li>Convert tokens to real money or cryptocurrency</li>
              <li>Transfer tokens for value outside the Platform</li>
              <li>Redeem tokens for prizes, goods, or services</li>
            </ul>
            <p>Tokens are provided solely for entertainment and social engagement purposes. Any attempt to assign monetary value to tokens is a violation of these Terms.</p>
          </div>
          
          <p>Key features of the Platform include:</p>
          <ul>
            <li><strong>Markets:</strong> Private groups where friends can create and participate in predictions</li>
            <li><strong>Events:</strong> Prediction questions (binary yes/no or multiple choice) created by users</li>
            <li><strong>Betting:</strong> Placing virtual token bets on prediction outcomes</li>
            <li><strong>Gossip:</strong> Discussion threads for each event</li>
            <li><strong>Leaderboards:</strong> Rankings based on prediction accuracy</li>
          </ul>
        </section>

        <section class="legal-section">
          <h2>3. Eligibility</h2>
          <p>To use Tyches, you must:</p>
          <ul>
            <li>Be at least 18 years of age (or the age of majority in your jurisdiction)</li>
            <li>Have the legal capacity to enter into a binding agreement</li>
            <li>Not be prohibited from using the Platform under applicable laws</li>
            <li>Not have been previously suspended or banned from the Platform</li>
          </ul>
          <p>By using the Platform, you represent and warrant that you meet all eligibility requirements.</p>
        </section>

        <section class="legal-section">
          <h2>4. User Accounts</h2>
          <h3>4.1 Account Registration</h3>
          <p>To access certain features, you must create an account. When registering, you agree to:</p>
          <ul>
            <li>Provide accurate, current, and complete information</li>
            <li>Maintain and promptly update your account information</li>
            <li>Keep your password secure and confidential</li>
            <li>Notify us immediately of any unauthorized access</li>
            <li>Accept responsibility for all activities under your account</li>
          </ul>

          <h3>4.2 Account Security</h3>
          <p>You are solely responsible for maintaining the confidentiality of your login credentials. We recommend using a strong, unique password and enabling any additional security features we may offer.</p>

          <h3>4.3 One Account Per Person</h3>
          <p>Each user may maintain only one account. Creating multiple accounts to gain additional tokens, manipulate predictions, or circumvent suspensions is strictly prohibited and grounds for immediate termination.</p>
        </section>

        <section class="legal-section">
          <h2>5. Virtual Tokens</h2>
          <h3>5.1 Token Allocation</h3>
          <p>Users receive virtual tokens through various activities on the Platform:</p>
          <ul>
            <li><strong>Account creation:</strong> Initial token allocation</li>
            <li><strong>Inviting friends:</strong> Bonus tokens for successful referrals</li>
            <li><strong>Creating Markets:</strong> Tokens for establishing new groups</li>
            <li><strong>Creating Events:</strong> Tokens for posting prediction questions</li>
            <li><strong>Winning bets:</strong> Proportional share of the prediction pool</li>
          </ul>

          <h3>5.2 Token Properties</h3>
          <p>Virtual tokens:</p>
          <ul>
            <li>Have <strong>no cash value</strong> and cannot be redeemed</li>
            <li>Are non-transferable outside Platform mechanics</li>
            <li>May be adjusted, reset, or removed at our discretion</li>
            <li>Do not constitute property and grant no ownership rights</li>
            <li>May expire or be forfeited upon account termination</li>
          </ul>

          <h3>5.3 No Purchases</h3>
          <p>Tyches does not sell tokens. Any offer to sell or buy tokens from third parties is fraudulent and not associated with our Platform.</p>
        </section>

        <section class="legal-section">
          <h2>6. User Conduct</h2>
          <p>You agree not to use the Platform to:</p>
          <ul>
            <li>Violate any applicable laws or regulations</li>
            <li>Harass, abuse, threaten, or intimidate other users</li>
            <li>Post content that is defamatory, obscene, hateful, or discriminatory</li>
            <li>Impersonate any person or entity</li>
            <li>Manipulate predictions through collusion or insider information abuse</li>
            <li>Create events about illegal activities or that encourage harm</li>
            <li>Spam, phish, or distribute malware</li>
            <li>Attempt to gain unauthorized access to systems or accounts</li>
            <li>Interfere with or disrupt the Platform's operation</li>
            <li>Use automated scripts, bots, or scrapers without permission</li>
            <li>Reverse engineer or attempt to extract source code</li>
            <li>Circumvent any security measures or rate limits</li>
          </ul>
        </section>

        <section class="legal-section">
          <h2>7. User Content</h2>
          <h3>7.1 Your Content</h3>
          <p>You retain ownership of content you create (event questions, comments, etc.). By posting content, you grant Tyches a worldwide, non-exclusive, royalty-free license to use, display, reproduce, and distribute your content in connection with the Platform.</p>

          <h3>7.2 Content Standards</h3>
          <p>All user content must comply with our <a href="privacy.php">Privacy Policy</a> and these Terms. We reserve the right to remove any content that violates our policies or that we deem inappropriate.</p>

          <h3>7.3 Reporting</h3>
          <p>If you encounter content that violates these Terms, please report it to us at <a href="mailto:admin@tyches.us">admin@tyches.us</a>.</p>
        </section>

        <section class="legal-section">
          <h2>8. Privacy</h2>
          <p>Your privacy is important to us. Our collection and use of personal information is governed by our <a href="privacy.php">Privacy Policy</a>, which is incorporated into these Terms by reference. By using the Platform, you consent to our data practices as described in the Privacy Policy.</p>
        </section>

        <section class="legal-section">
          <h2>9. Intellectual Property</h2>
          <h3>9.1 Our Property</h3>
          <p>The Platform, including its design, features, content, logos, trademarks, and underlying technology, is owned by Tyches and protected by intellectual property laws. "Tyches" and our logo are trademarks of Tyches.</p>

          <h3>9.2 Limited License</h3>
          <p>We grant you a limited, non-exclusive, non-transferable, revocable license to access and use the Platform for personal, non-commercial purposes in accordance with these Terms.</p>

          <h3>9.3 Restrictions</h3>
          <p>You may not copy, modify, distribute, sell, or lease any part of the Platform or its content without our express written permission.</p>
        </section>

        <section class="legal-section">
          <h2>10. Third-Party Services</h2>
          <p>The Platform may contain links to third-party websites or services. We are not responsible for the content, privacy policies, or practices of third parties. Your interactions with third-party services are governed by their respective terms.</p>
        </section>

        <section class="legal-section">
          <h2>11. Disclaimers</h2>
          <div class="legal-highlight warning">
            <p>THE PLATFORM IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED. WE DISCLAIM ALL WARRANTIES, INCLUDING BUT NOT LIMITED TO:</p>
            <ul>
              <li>MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE</li>
              <li>NON-INFRINGEMENT</li>
              <li>ACCURACY OR COMPLETENESS OF CONTENT</li>
              <li>UNINTERRUPTED OR ERROR-FREE OPERATION</li>
              <li>SECURITY OR FREEDOM FROM VIRUSES</li>
            </ul>
          </div>
          <p>We do not guarantee the accuracy of predictions, user-generated content, or any information on the Platform. Predictions are for entertainment only and should not be relied upon for any decision-making.</p>
        </section>

        <section class="legal-section">
          <h2>12. Limitation of Liability</h2>
          <div class="legal-highlight warning">
            <p>TO THE MAXIMUM EXTENT PERMITTED BY LAW, TYCHES AND ITS OFFICERS, DIRECTORS, EMPLOYEES, AND AGENTS SHALL NOT BE LIABLE FOR ANY:</p>
            <ul>
              <li>INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES</li>
              <li>LOSS OF PROFITS, DATA, USE, OR GOODWILL</li>
              <li>DAMAGES RESULTING FROM USER CONTENT OR CONDUCT</li>
              <li>DAMAGES FROM UNAUTHORIZED ACCESS TO YOUR ACCOUNT</li>
              <li>DAMAGES EXCEEDING $100 USD OR THE AMOUNT YOU PAID US (IF ANY)</li>
            </ul>
          </div>
          <p>Some jurisdictions do not allow limitation of liability for certain damages, so some of the above may not apply to you.</p>
        </section>

        <section class="legal-section">
          <h2>13. Indemnification</h2>
          <p>You agree to indemnify, defend, and hold harmless Tyches and its affiliates, officers, directors, employees, and agents from any claims, damages, losses, liabilities, costs, and expenses (including attorneys' fees) arising from:</p>
          <ul>
            <li>Your use of the Platform</li>
            <li>Your violation of these Terms</li>
            <li>Your violation of any third-party rights</li>
            <li>Your user content</li>
          </ul>
        </section>

        <section class="legal-section">
          <h2>14. Termination</h2>
          <h3>14.1 By You</h3>
          <p>You may terminate your account at any time by contacting us at <a href="mailto:admin@tyches.us">admin@tyches.us</a>. Upon termination, your right to use the Platform ceases immediately.</p>

          <h3>14.2 By Us</h3>
          <p>We may suspend or terminate your account at any time, with or without cause or notice, including for:</p>
          <ul>
            <li>Violation of these Terms</li>
            <li>Conduct harmful to other users or the Platform</li>
            <li>Extended periods of inactivity</li>
            <li>Legal or regulatory requirements</li>
          </ul>

          <h3>14.3 Effect of Termination</h3>
          <p>Upon termination, all licenses granted to you end, your tokens are forfeited, and we may delete your account and content. Sections that by their nature should survive will survive termination.</p>
        </section>

        <section class="legal-section">
          <h2>15. Dispute Resolution</h2>
          <h3>15.1 Informal Resolution</h3>
          <p>Before filing any formal claim, you agree to contact us at <a href="mailto:admin@tyches.us">admin@tyches.us</a> and attempt to resolve the dispute informally for at least 30 days.</p>

          <h3>15.2 Arbitration</h3>
          <p>Any disputes not resolved informally shall be resolved through binding arbitration in accordance with the rules of the American Arbitration Association. The arbitration shall be conducted in English, and the arbitrator's decision shall be final and binding.</p>

          <h3>15.3 Class Action Waiver</h3>
          <p>You agree to resolve disputes on an individual basis only. You waive any right to participate in class actions, class arbitrations, or representative actions.</p>
        </section>

        <section class="legal-section">
          <h2>16. Governing Law</h2>
          <p>These Terms shall be governed by and construed in accordance with the laws of the United States, without regard to conflict of law principles. Any legal proceedings shall be brought exclusively in the state or federal courts located in the United States.</p>
        </section>

        <section class="legal-section">
          <h2>17. Changes to Terms</h2>
          <p>We may modify these Terms at any time. We will notify you of material changes by:</p>
          <ul>
            <li>Posting the updated Terms on the Platform</li>
            <li>Updating the "Last updated" date</li>
            <li>Sending an email notification for significant changes</li>
          </ul>
          <p>Your continued use of the Platform after changes constitutes acceptance of the modified Terms. If you do not agree to the changes, you must stop using the Platform.</p>
        </section>

        <section class="legal-section">
          <h2>18. General Provisions</h2>
          <ul>
            <li><strong>Entire Agreement:</strong> These Terms, together with our Privacy Policy, constitute the entire agreement between you and Tyches.</li>
            <li><strong>Severability:</strong> If any provision is found unenforceable, the remaining provisions remain in effect.</li>
            <li><strong>Waiver:</strong> Our failure to enforce any right does not waive that right.</li>
            <li><strong>Assignment:</strong> You may not assign these Terms. We may assign them freely.</li>
            <li><strong>Force Majeure:</strong> We are not liable for delays or failures due to circumstances beyond our control.</li>
          </ul>
        </section>

        <section class="legal-section">
          <h2>19. Contact Us</h2>
          <p>If you have questions about these Terms, please contact us:</p>
          <div class="contact-info">
            <p><strong>Email:</strong> <a href="mailto:admin@tyches.us">admin@tyches.us</a></p>
            <p><strong>Website:</strong> <a href="contact.php">tyches.us/contact</a></p>
          </div>
        </section>

        <div class="legal-footer">
          <p>By using Tyches, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.</p>
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

