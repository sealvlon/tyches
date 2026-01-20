<?php
// api/config.php
// Database configuration and PDO helper for Tyches

// IMPORTANT: replace these with your real hosting credentials if needed.
// These values are taken from your previous config example.
const DB_HOST = 'localhost';
const DB_NAME = 'db_name'; // e.g. Database Name
const DB_USER = 'db_user'; // e.g. Database User
const DB_PASS = 'db_password'; // e.g. Database Password    

/**
 * Get a shared PDO instance.
 *
 * @return PDO
 */
function get_pdo(): PDO {
    static $pdo = null;

    if ($pdo === null) {
        $dsn = 'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4';

        $options = array(
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        );

        $pdo = new PDO($dsn, DB_USER, DB_PASS, $options);
    }

    return $pdo;
}




