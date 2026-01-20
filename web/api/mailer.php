<?php
// api/mailer.php
// Email sending functionality for Tyches

declare(strict_types=1);

require_once __DIR__ . '/mail-config.php';

/**
 * Send an email using the configured method.
 *
 * @param string $to Recipient email
 * @param string $subject Email subject
 * @param string $htmlBody HTML content
 * @param string $textBody Plain text content (optional)
 * @return bool Success status
 */
function send_email(string $to, string $subject, string $htmlBody, string $textBody = ''): bool {
    // Generate text body from HTML if not provided
    if (empty($textBody)) {
        $textBody = strip_tags(str_replace(['<br>', '<br/>', '<br />'], "\n", $htmlBody));
    }
    
    switch (MAIL_METHOD) {
        case 'smtp':
            return send_email_smtp($to, $subject, $htmlBody, $textBody);
        case 'sendmail':
            return send_email_sendmail($to, $subject, $htmlBody, $textBody);
        default:
            return send_email_native($to, $subject, $htmlBody, $textBody);
    }
}

/**
 * Send email using native PHP mail() function
 */
function send_email_native(string $to, string $subject, string $htmlBody, string $textBody): bool {
    $boundary = md5(time() . rand());
    
    $headers = [
        'From: ' . MAIL_FROM_NAME . ' <' . MAIL_FROM_ADDRESS . '>',
        'Reply-To: ' . MAIL_FROM_ADDRESS,
        'MIME-Version: 1.0',
        'Content-Type: multipart/alternative; boundary="' . $boundary . '"',
        'X-Mailer: Tyches/1.0',
    ];
    
    $body = "--{$boundary}\r\n";
    $body .= "Content-Type: text/plain; charset=UTF-8\r\n";
    $body .= "Content-Transfer-Encoding: 8bit\r\n\r\n";
    $body .= $textBody . "\r\n\r\n";
    
    $body .= "--{$boundary}\r\n";
    $body .= "Content-Type: text/html; charset=UTF-8\r\n";
    $body .= "Content-Transfer-Encoding: 8bit\r\n\r\n";
    $body .= $htmlBody . "\r\n\r\n";
    
    $body .= "--{$boundary}--";
    
    $result = @mail($to, $subject, $body, implode("\r\n", $headers));
    
    if (!$result && MAIL_DEBUG) {
        error_log("Mail failed to: {$to}, subject: {$subject}");
    }
    
    return $result;
}

/**
 * Send email using SMTP (requires stream_socket_client)
 */
function send_email_smtp(string $to, string $subject, string $htmlBody, string $textBody): bool {
    try {
        $socket = @stream_socket_client(
            (SMTP_SECURE === 'ssl' ? 'ssl://' : '') . SMTP_HOST . ':' . SMTP_PORT,
            $errno,
            $errstr,
            30
        );
        
        if (!$socket) {
            throw new Exception("Could not connect to SMTP server: {$errstr}");
        }
        
        // Read greeting
        smtp_read($socket);
        
        // EHLO
        smtp_write($socket, 'EHLO ' . gethostname());
        smtp_read($socket);
        
        // STARTTLS if needed
        if (SMTP_SECURE === 'tls') {
            smtp_write($socket, 'STARTTLS');
            smtp_read($socket);
            stream_socket_enable_crypto($socket, true, STREAM_CRYPTO_METHOD_TLS_CLIENT);
            smtp_write($socket, 'EHLO ' . gethostname());
            smtp_read($socket);
        }
        
        // AUTH LOGIN
        if (SMTP_USERNAME && SMTP_PASSWORD) {
            smtp_write($socket, 'AUTH LOGIN');
            smtp_read($socket);
            smtp_write($socket, base64_encode(SMTP_USERNAME));
            smtp_read($socket);
            smtp_write($socket, base64_encode(SMTP_PASSWORD));
            smtp_read($socket);
        }
        
        // MAIL FROM
        smtp_write($socket, 'MAIL FROM:<' . MAIL_FROM_ADDRESS . '>');
        smtp_read($socket);
        
        // RCPT TO
        smtp_write($socket, 'RCPT TO:<' . $to . '>');
        smtp_read($socket);
        
        // DATA
        smtp_write($socket, 'DATA');
        smtp_read($socket);
        
        // Build email content
        $boundary = md5(time() . rand());
        $headers = [
            'Date: ' . date('r'),
            'From: ' . MAIL_FROM_NAME . ' <' . MAIL_FROM_ADDRESS . '>',
            'To: ' . $to,
            'Subject: ' . $subject,
            'MIME-Version: 1.0',
            'Content-Type: multipart/alternative; boundary="' . $boundary . '"',
            'X-Mailer: Tyches/1.0',
        ];
        
        $message = implode("\r\n", $headers) . "\r\n\r\n";
        
        $message .= "--{$boundary}\r\n";
        $message .= "Content-Type: text/plain; charset=UTF-8\r\n\r\n";
        $message .= $textBody . "\r\n\r\n";
        
        $message .= "--{$boundary}\r\n";
        $message .= "Content-Type: text/html; charset=UTF-8\r\n\r\n";
        $message .= $htmlBody . "\r\n\r\n";
        
        $message .= "--{$boundary}--\r\n.";
        
        smtp_write($socket, $message);
        smtp_read($socket);
        
        // QUIT
        smtp_write($socket, 'QUIT');
        fclose($socket);
        
        return true;
        
    } catch (Throwable $e) {
        if (MAIL_DEBUG) {
            error_log("SMTP error: " . $e->getMessage());
        }
        
        // Fallback to native mail
        return send_email_native($to, $subject, $htmlBody, $textBody);
    }
}

function smtp_write($socket, string $data): void {
    fwrite($socket, $data . "\r\n");
}

function smtp_read($socket): string {
    $response = '';
    while ($line = fgets($socket, 515)) {
        $response .= $line;
        if (substr($line, 3, 1) === ' ') {
            break;
        }
    }
    return $response;
}

/**
 * Send email using sendmail
 */
function send_email_sendmail(string $to, string $subject, string $htmlBody, string $textBody): bool {
    $boundary = md5(time() . rand());
    
    $headers = [
        'From: ' . MAIL_FROM_NAME . ' <' . MAIL_FROM_ADDRESS . '>',
        'Reply-To: ' . MAIL_FROM_ADDRESS,
        'To: ' . $to,
        'Subject: ' . $subject,
        'MIME-Version: 1.0',
        'Content-Type: multipart/alternative; boundary="' . $boundary . '"',
    ];
    
    $message = implode("\r\n", $headers) . "\r\n\r\n";
    
    $message .= "--{$boundary}\r\n";
    $message .= "Content-Type: text/plain; charset=UTF-8\r\n\r\n";
    $message .= $textBody . "\r\n\r\n";
    
    $message .= "--{$boundary}\r\n";
    $message .= "Content-Type: text/html; charset=UTF-8\r\n\r\n";
    $message .= $htmlBody . "\r\n\r\n";
    
    $message .= "--{$boundary}--";
    
    $sendmail = popen('/usr/sbin/sendmail -t', 'w');
    if (!$sendmail) {
        return send_email_native($to, $subject, $htmlBody, $textBody);
    }
    
    fwrite($sendmail, $message);
    $result = pclose($sendmail);
    
    return $result === 0;
}

// ============================================
// EMAIL TEMPLATES
// ============================================

/**
 * Get the base email template wrapper
 */
function email_template(string $title, string $content, string $preheader = ''): string {
    $appName = APP_NAME;
    $appUrl = APP_URL;
    $year = date('Y');
    
    return <<<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{$title}</title>
  <style>
    body { margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f8fafc; }
    .wrapper { max-width: 600px; margin: 0 auto; padding: 40px 20px; }
    .card { background: #ffffff; border-radius: 16px; box-shadow: 0 4px 6px rgba(0,0,0,0.05); padding: 40px; }
    .logo { text-align: center; margin-bottom: 30px; }
    .logo-icon { width: 48px; height: 48px; background: linear-gradient(135deg, #6366F1 0%, #8B5CF6 100%); border-radius: 12px; display: inline-flex; align-items: center; justify-content: center; }
    .logo-icon svg { width: 28px; height: 28px; }
    .logo-text { font-size: 24px; font-weight: 700; color: #0f172a; margin-top: 12px; }
    h1 { font-size: 24px; font-weight: 700; color: #0f172a; margin: 0 0 16px 0; }
    p { font-size: 16px; line-height: 1.6; color: #475569; margin: 0 0 16px 0; }
    .btn { display: inline-block; background: linear-gradient(135deg, #6366F1 0%, #8B5CF6 100%); color: #ffffff !important; text-decoration: none; padding: 14px 28px; border-radius: 10px; font-weight: 600; font-size: 16px; margin: 20px 0; }
    .btn:hover { opacity: 0.9; }
    .footer { text-align: center; padding-top: 30px; color: #94a3b8; font-size: 14px; }
    .footer a { color: #6366F1; text-decoration: none; }
    .preheader { display: none; max-width: 0; max-height: 0; overflow: hidden; font-size: 1px; line-height: 1px; color: #fff; }
  </style>
</head>
<body>
  <div class="preheader">{$preheader}</div>
  <div class="wrapper">
    <div class="card">
      <div class="logo">
        <img src="{$appUrl}/logo.png" alt="{$appName}" width="48" height="48" style="width: 48px; height: 48px; border-radius: 12px; display: block; margin: 0 auto;">
        <div class="logo-text">{$appName}</div>
      </div>
      {$content}
    </div>
    <div class="footer">
      <p>&copy; {$year} {$appName}. All rights reserved.</p>
      <p><a href="{$appUrl}">Visit {$appName}</a></p>
    </div>
  </div>
</body>
</html>
HTML;
}

/**
 * Send email verification email
 */
function send_verification_email(string $to, string $name, string $token): bool {
    $verifyUrl = APP_URL . '/verify.php?token=' . urlencode($token);
    
    $content = <<<HTML
<h1>Verify your email</h1>
<p>Hi {$name},</p>
<p>Thanks for signing up for Tyches! Please verify your email address to get started.</p>
<p style="text-align: center;">
  <a href="{$verifyUrl}" class="btn">Verify Email Address</a>
</p>
<p>If you didn't create an account, you can safely ignore this email.</p>
<p style="margin-top: 30px; font-size: 14px; color: #94a3b8;">
  If the button doesn't work, copy and paste this link:<br>
  <a href="{$verifyUrl}" style="color: #6366F1; word-break: break-all;">{$verifyUrl}</a>
</p>
HTML;

    $html = email_template('Verify your email - Tyches', $content, 'Please verify your email to get started with Tyches');
    
    return send_email($to, 'Verify your email - Tyches', $html);
}

/**
 * Send password reset email
 */
function send_password_reset_email(string $to, string $name, string $token): bool {
    $resetUrl = APP_URL . '/reset-password.php?token=' . urlencode($token);
    
    $content = <<<HTML
<h1>Reset your password</h1>
<p>Hi {$name},</p>
<p>We received a request to reset your password. Click the button below to choose a new password.</p>
<p style="text-align: center;">
  <a href="{$resetUrl}" class="btn">Reset Password</a>
</p>
<p>This link will expire in 1 hour.</p>
<p>If you didn't request a password reset, you can safely ignore this email.</p>
<p style="margin-top: 30px; font-size: 14px; color: #94a3b8;">
  If the button doesn't work, copy and paste this link:<br>
  <a href="{$resetUrl}" style="color: #6366F1; word-break: break-all;">{$resetUrl}</a>
</p>
HTML;

    $html = email_template('Reset your password - Tyches', $content, 'Reset your Tyches password');
    
    return send_email($to, 'Reset your password - Tyches', $html);
}

/**
 * Send market invite email
 */
function send_market_invite_email(string $to, string $inviterName, string $marketName, string $marketId): bool {
    $marketUrl = APP_URL . '/market.php?id=' . urlencode($marketId);
    $signupUrl = APP_URL . '/index.php';
    
    $content = <<<HTML
<h1>You're invited! 🎯</h1>
<p><strong>{$inviterName}</strong> invited you to join <strong>{$marketName}</strong> on Tyches.</p>
<p>Tyches is where friends make predictions and place friendly bets on the things that matter to your group.</p>
<p style="text-align: center; margin: 30px 0;">
  <a href="{$marketUrl}" class="btn" style="display: inline-block; background: linear-gradient(135deg, #6366F1 0%, #8B5CF6 100%); color: #ffffff !important; text-decoration: none; padding: 14px 28px; border-radius: 10px; font-weight: 600; font-size: 16px;">Join {$marketName}</a>
</p>
<p style="text-align: center; margin-top: 20px;">
  <a href="{$marketUrl}" style="color: #6366F1; text-decoration: underline;">{$marketUrl}</a>
</p>
<p style="font-size: 14px; color: #64748b; margin-top: 20px;">If you don't have a Tyches account yet, <a href="{$signupUrl}" style="color: #6366F1; text-decoration: underline;">sign up here</a> and you'll automatically be added to this market.</p>
HTML;

    $html = email_template("You're invited to {$marketName} - Tyches", $content, "{$inviterName} invited you to predict together on Tyches");
    
    return send_email($to, "You're invited to {$marketName} on Tyches", $html);
}

/**
 * Send event resolved notification
 */
function send_event_resolved_email(string $to, string $name, string $eventTitle, string $result, float $payout): bool {
    $payoutFormatted = number_format($payout, 2);
    
    $content = <<<HTML
<h1>Event Resolved!</h1>
<p>Hi {$name},</p>
<p>An event you participated in has been resolved:</p>
<div style="background: #f1f5f9; padding: 20px; border-radius: 12px; margin: 20px 0;">
  <p style="font-weight: 600; color: #0f172a; margin: 0 0 8px 0;">{$eventTitle}</p>
  <p style="font-size: 24px; font-weight: 700; color: #059669; margin: 0;">Result: {$result}</p>
</div>
<p>Your payout: <strong>\${$payoutFormatted}</strong></p>
<p style="text-align: center;">
  <a href="{APP_URL}" class="btn">View Your Profile</a>
</p>
HTML;

    $html = email_template('Event Resolved - Tyches', $content, "The event \"{$eventTitle}\" has been resolved");
    
    return send_email($to, "Event Resolved: {$eventTitle}", $html);
}

/**
 * Send notification email (generic)
 */
function send_notification_email(string $to, string $name, string $title, string $message, string $ctaText = '', string $ctaUrl = ''): bool {
    $cta = '';
    if ($ctaText && $ctaUrl) {
        $cta = '<p style="text-align: center;"><a href="' . htmlspecialchars($ctaUrl) . '" class="btn">' . htmlspecialchars($ctaText) . '</a></p>';
    }
    
    $content = <<<HTML
<h1>{$title}</h1>
<p>Hi {$name},</p>
<p>{$message}</p>
{$cta}
HTML;

    $html = email_template($title . ' - Tyches', $content, $message);
    
    return send_email($to, $title . ' - Tyches', $html);
}

