<?php
require_once __DIR__ . '/../../config/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    jsonResponse(false, 'Metode request tidak diizinkan.', null, 405);
}

$search = trim($_GET['search'] ?? '');
$role   = trim($_GET['role'] ?? '');

try {
    $sql = "SELECT id, nama_lengkap, email, role, created_at FROM users WHERE 1=1";
    $params = [];

    if ($search !== '') {
        $sql .= " AND (nama_lengkap LIKE :search_nama OR email LIKE :search_email)";
        $params[':search_nama']  = "%{$search}%";
        $params[':search_email'] = "%{$search}%";
    }

    if ($role !== '' && in_array($role, ['Admin', 'HRD', 'Intern'], true)) {
        $sql .= " AND role = :role";
        $params[':role'] = $role;
    }

    $sql .= " ORDER BY id DESC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    jsonResponse(true, 'Daftar user berhasil diambil.', $stmt->fetchAll());
} catch (PDOException $e) {
    jsonResponse(false, 'Gagal mengambil data user: ' . $e->getMessage(), null, 500);
}