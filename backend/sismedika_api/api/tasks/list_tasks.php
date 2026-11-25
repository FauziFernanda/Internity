<?php
require_once __DIR__ . '/../../config/db.php';
date_default_timezone_set('Asia/Jakarta');

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    jsonResponse(false, 'Metode request tidak diizinkan.', null, 405);
}

$userId = (int) ($_GET['user_id'] ?? 0);
if ($userId <= 0) {
    jsonResponse(false, 'Parameter user_id tidak valid.', null, 400);
}

try {
    $stmt = $pdo->prepare("
        SELECT id, user_id, attendance_id, task_date, title, description, attachment_name, attachment_base64, created_at
        FROM daily_tasks
        WHERE user_id = :user_id
        ORDER BY task_date DESC, created_at DESC
    ");
    $stmt->execute([':user_id' => $userId]);
    $tasks = $stmt->fetchAll();

    jsonResponse(true, 'Daftar tugas berhasil dimuat.', [
        'tasks' => $tasks,
    ], 200);
} catch (PDOException $e) {
    jsonResponse(false, 'Gagal memuat daftar tugas: ' . $e->getMessage(), null, 500);
}