<?php
// api/mail-config.php
// Email configuration for Tyches

declare(strict_types=1);

// ============================================
// EMAIL CONFIGURATION
// ============================================

// Mail method: 'smtp', 'sendmail', or 'mail' (native PHP mail)
define('MAIL_METHOD', 'smtp');

// SMTP Settings (for MAIL_METHOD = 'smtp')
define('SMTP_HOST', 'https://domain.com');     // Your SMTP server (e.g. https://domain.com)
define('SMTP_PORT', 587);                     // 587 for TLS, 465 for SSL, 25 for plain
define('SMTP_SECURE', 'tls');                 // 'tls', 'ssl', or '' for none
define('SMTP_USERNAME', 'no-reply@domain.com');    // SMTP username (e.g. no-reply@domain.com)
define('SMTP_PASSWORD', 'ExamplePassword');     // SMTP password (e.g. ExamplePassword)

// Sender details
define('MAIL_FROM_ADDRESS', 'no-reply@domain.com');
define('MAIL_FROM_NAME', 'Domain');

// App settings
define('APP_URL', 'https://www.domain.com');      // Your app's base URL (e.g. https://www.domain.com)
define('APP_NAME', 'Tyches');

// Debug mode (set to true to log email errors)
define('MAIL_DEBUG', false);

