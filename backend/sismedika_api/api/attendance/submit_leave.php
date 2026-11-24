<?php
require_once __DIR__ . '/../../config/db.php';
date_default_timezone_set('Asia/Jakarta');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    jsonResponse(false, 'Metode request tidak diizinkan.', null, 405);
}

$input = json_decode(file_get_contents('php://input'), true);
if (!is_array($input)) {
    $input = $_POST;
}

$userId         = (int) ($input['user_id'] ?? 0);
$leaveType      = trim($input['status'] ?? ''); // 'Sakit' atau 'Izin'
$documentBase64 = trim($input['document_base64'] ?? '');

if ($userId <= 0) {
    jsonResponse(false, 'Parameter user_id tidak valid.', null, 400);
}

if (!in_array($leaveType, ['Sakit', 'Izin'], true)) {
    jsonResponse(false, 'Alasan tidak masuk harus berupa Sakit atau Izin.', null, 400);
}

if ($documentBase64 === '') {
    jsonResponse(false, 'Bukti dokumentasi (JPG/JPEG) wajib diunggah.', null, 400);
}

try {
    $today = date('Y-m-d');

    $checkStmt = $pdo->prepare("SELECT id, status FROM attendances WHERE user_id = :user_id AND attendance_date = :today LIMIT 1");
    $checkStmt->execute([':user_id' => $userId, ':today' => $today]);
    $existing = $checkStmt->fetch();

    if ($existing) {
        jsonResponse(false, "Pengajuan ditolak. Anda sudah tercatat '{$existing['status']}' pada hari ini.", null, 409);
    }

    $stmt = $pdo->prepare("
        INSERT INTO attendances (user_id, attendance_date, status, document_base64)
        VALUES (:user_id, :attendance_date, :status, :document_base64)
    ");
    $stmt->execute([
        ':user_id'         => $userId,
        ':attendance_date' => $today,
        ':status'          => $leaveType,
        ':document_base64' => $documentBase64,
    ]);

    jsonResponse(true, "Pengajuan {$leaveType} berhasil disimpan.", [
        'id'              => (int) $pdo->lastInsertId(),
        'attendance_date' => $today,
        'status'          => $leaveType,
    ], 201);
} catch (PDOException $e) {
    jsonResponse(false, 'Gagal menyimpan pengajuan: ' . $e->getMessage(), null, 500);
}