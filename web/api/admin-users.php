<?php
// api/admin-users.php
// Admin-only user management

declare(strict_types=1);

require_once __DIR__ . '/security.php';
require_once __DIR__ . '/admin-audit.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

try {
    $pdo = get_pdo();
    $admin = require_admin($pdo);

    if ($method === 'GET') {
        handle_admin_users_list($pdo);
    } elseif ($method === 'POST') {
        handle_admin_users_mutation($pdo, $admin);
    } else {
        json_response(['error' => 'Method not allowed'], 405);
    }
} catch (Throwable $e) {
    error_log('admin-users.php error: ' . $e->getMessage());
    json_response(['error' => 'Server error'], 500);
}

function handle_admin_users_list(PDO $pdo): void {
    $page = max(1, (int)($_GET['page'] ?? 1));
    $pageSize = 25;
    $offset = ($page - 1) * $pageSize;

    $total = (int)$pdo->query('SELECT COUNT(*) FROM users')->fetchColumn();

    $rows = $pdo->query("
        SELECT id, name, username, email, status, is_admin, tokens_balance, created_at 
        FROM users 
        ORDER BY created_at DESC 
        LIMIT {$pageSize} OFFSET {$offset}
    ")->fetchAll(PDO::FETCH_ASSOC);

    $users = [];
    foreach ($rows as $row) {
        $uid = (int)$row['id'];
        $users[] = [
            'id'             => $uid,
            'name'           => $row['name'],
            'username'       => $row['username'],
            'email'          => $row['email'],
            'is_admin'       => (int)$row['is_admin'] === 1,
            'status'         => $row['status'],
            'tokens_balance' => (float)($row['tokens_balance'] ?? 0),
            'created_at'     => $row['created_at'],
            'markets_member' => (int)$pdo->query("SELECT COUNT(*) FROM market_members WHERE user_id = {$uid}")->fetchColumn(),
            'events_created' => (int)$pdo->query("SELECT COUNT(*) FROM events WHERE creator_id = {$uid}")->fetchColumn(),
            'bets_count'     => (int)$pdo->query("SELECT COUNT(*) FROM bets WHERE user_id = {$uid}")->fetchColumn(),
        ];
    }

    json_response([
        'users'      => $users,
        'pagination' => ['page' => $page, 'page_size' => $pageSize, 'total' => $total],
    ]);
}

function handle_admin_users_mutation(PDO $pdo, array $admin): void {
    tyches_require_csrf();

    $data = json_decode(file_get_contents('php://input'), true) ?? $_POST;
    $action = $data['action'] ?? '';
    $userId = (int)($data['user_id'] ?? 0);

    if ($userId <= 0) {
        json_response(['error' => 'user_id required'], 400);
    }

    $adminId = (int)$admin['id'];

    switch ($action) {
        case 'set_admin':
        case 'unset_admin':
            if ($action === 'unset_admin' && $userId === $adminId) {
                json_response(['error' => 'Cannot remove own admin'], 400);
            }
            $isAdmin = $action === 'set_admin' ? 1 : 0;
            $pdo->prepare('UPDATE users SET is_admin = ? WHERE id = ?')->execute([$isAdmin, $userId]);
            logAdminAction($pdo, 'user_role_change', 'user', (string)$userId, $isAdmin ? 'Granted admin' : 'Revoked admin');
            json_response(['id' => $userId, 'is_admin' => (bool)$isAdmin]);
            break;

        case 'set_status':
            $status = $data['status'] ?? '';
            if (!in_array($status, ['active', 'restricted', 'suspended'])) {
                json_response(['error' => 'Invalid status'], 400);
            }
            $pdo->prepare('UPDATE users SET status = ? WHERE id = ?')->execute([$status, $userId]);
            logAdminAction($pdo, 'user_status_change', 'user', (string)$userId, "Status: {$status}");
            json_response(['id' => $userId, 'status' => $status]);
            break;

        case 'adjust_tokens':
            $amount = (float)($data['amount'] ?? 0);
            if ($amount == 0) json_response(['error' => 'Amount required'], 400);
            $current = (float)$pdo->query("SELECT tokens_balance FROM users WHERE id = {$userId}")->fetchColumn();
            $new = $current + $amount;
            if ($new < 0) json_response(['error' => 'Cannot go negative'], 400);
            $pdo->prepare('UPDATE users SET tokens_balance = ? WHERE id = ?')->execute([$new, $userId]);
            logAdminAction($pdo, 'token_adjust', 'user', (string)$userId, "Adjusted: {$amount}");
            json_response(['id' => $userId, 'old_balance' => $current, 'new_balance' => $new]);
            break;

        default:
            json_response(['error' => 'Unknown action'], 400);
    }
}
