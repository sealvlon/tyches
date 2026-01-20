<?php
/**
 * Admin Audit Log API
 * Tracks and retrieves admin actions for accountability
 * 
 * This file can be:
 * 1. Called directly as an API endpoint (GET/POST)
 * 2. Included by other files to use logAdminAction()
 */

declare(strict_types=1);

require_once __DIR__ . '/helpers.php';

// Only run API logic if this file is called directly (not included)
if (basename($_SERVER['SCRIPT_FILENAME'] ?? '') === 'admin-audit.php') {
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(200);
        exit;
    }

    try {
        $pdo = get_pdo();
        require_admin($pdo);
        
        $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
        
        if ($method === 'GET') {
            handleGetAuditLog($pdo);
        } elseif ($method === 'POST') {
            handleLogAction($pdo);
        } else {
            json_response(['error' => 'Method not allowed'], 405);
        }
    } catch (Throwable $e) {
        error_log('admin-audit.php error: ' . $e->getMessage());
        json_response(['error' => 'Server error'], 500);
    }
}

/**
 * Get audit log entries
 */
function handleGetAuditLog(PDO $pdo): void {
    ensureAuditTable($pdo);
    
    $actionFilter = $_GET['action'] ?? '';
    $page = max(1, (int)($_GET['page'] ?? 1));
    $pageSize = min(100, max(10, (int)($_GET['page_size'] ?? 50)));
    $offset = ($page - 1) * $pageSize;
    
    $where = '';
    $params = [];
    
    if ($actionFilter) {
        $where = "WHERE al.action LIKE ?";
        $params[] = '%' . $actionFilter . '%';
    }
    
    $countSql = "SELECT COUNT(*) FROM audit_log al {$where}";
    $stmt = $pdo->prepare($countSql);
    $stmt->execute($params);
    $total = (int)$stmt->fetchColumn();
    
    $sql = "
        SELECT 
            al.id, al.admin_id, al.action, al.target_type, al.target_id,
            al.details, al.ip_address, al.created_at,
            u.name AS admin_name, u.username AS admin_username
        FROM audit_log al
        LEFT JOIN users u ON u.id = al.admin_id
        {$where}
        ORDER BY al.created_at DESC
        LIMIT {$pageSize} OFFSET {$offset}
    ";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $entries = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    $formatted = array_map(function($e) {
        return [
            'id' => (int)$e['id'],
            'admin_id' => (int)$e['admin_id'],
            'admin_name' => $e['admin_name'],
            'admin_username' => $e['admin_username'],
            'action' => $e['action'],
            'target_type' => $e['target_type'],
            'target_id' => $e['target_id'],
            'details' => $e['details'],
            'ip_address' => $e['ip_address'],
            'created_at' => $e['created_at']
        ];
    }, $entries);
    
    json_response([
        'entries' => $formatted,
        'pagination' => [
            'page' => $page,
            'page_size' => $pageSize,
            'total' => $total,
            'total_pages' => (int)ceil($total / $pageSize)
        ]
    ]);
}

/**
 * Log an admin action (POST endpoint)
 */
function handleLogAction(PDO $pdo): void {
    tyches_require_csrf();
    
    $input = json_decode(file_get_contents('php://input'), true) ?? [];
    
    $action = $input['action'] ?? '';
    if (!$action) {
        json_response(['error' => 'Action is required'], 400);
    }
    
    $adminId = (int)($_SESSION['user_id'] ?? 0);
    $ipAddress = $_SERVER['REMOTE_ADDR'] ?? '';
    
    ensureAuditTable($pdo);
    
    $stmt = $pdo->prepare("
        INSERT INTO audit_log (admin_id, action, target_type, target_id, details, ip_address)
        VALUES (?, ?, ?, ?, ?, ?)
    ");
    $stmt->execute([
        $adminId,
        $action,
        $input['target_type'] ?? null,
        $input['target_id'] ?? null,
        $input['details'] ?? null,
        $ipAddress
    ]);
    
    json_response(['ok' => true, 'id' => (int)$pdo->lastInsertId()]);
}

/**
 * Ensure audit_log table exists
 */
function ensureAuditTable(PDO $pdo): void {
    static $checked = false;
    if ($checked) return;
    
    try {
        $pdo->exec("
            CREATE TABLE IF NOT EXISTS audit_log (
                id INT AUTO_INCREMENT PRIMARY KEY,
                admin_id INT NOT NULL,
                action VARCHAR(100) NOT NULL,
                target_type VARCHAR(50) NULL,
                target_id VARCHAR(100) NULL,
                details TEXT NULL,
                ip_address VARCHAR(45) NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_admin_id (admin_id),
                INDEX idx_action (action),
                INDEX idx_created_at (created_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");
        $checked = true;
    } catch (Exception $e) {
        error_log('ensureAuditTable error: ' . $e->getMessage());
    }
}

/**
 * Helper function to log admin actions from other endpoints
 */
function logAdminAction(PDO $pdo, string $action, ?string $targetType = null, $targetId = null, ?string $details = null): void {
    try {
        ensureAuditTable($pdo);
        
        $adminId = (int)($_SESSION['user_id'] ?? 0);
        $ipAddress = $_SERVER['REMOTE_ADDR'] ?? '';
        
        $stmt = $pdo->prepare("
            INSERT INTO audit_log (admin_id, action, target_type, target_id, details, ip_address)
            VALUES (?, ?, ?, ?, ?, ?)
        ");
        $stmt->execute([$adminId, $action, $targetType, $targetId, $details, $ipAddress]);
    } catch (Exception $e) {
        error_log('logAdminAction error: ' . $e->getMessage());
    }
}
