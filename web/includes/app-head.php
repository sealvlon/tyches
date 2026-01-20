<?php
/**
 * App Shell - Head section
 * Include this in the <head> of pages that use the app shell (logged-in experience)
 */
require_once __DIR__ . '/asset-helpers.php';
?>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="csrf-token" content="<?php echo e(tyches_get_csrf_token()); ?>">

<!-- Resource hints for critical third-party resources -->
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
