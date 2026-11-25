<?php
require_once __DIR__ . '/../../config/db.php';
date_default_timezone_set('Asia/Jakarta');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    jsonResponse(false, 'Metode request tidak diizinkan.', null, 405);
}

$input = json_decode(file_get_contents('php://input'), true);
if (!is_array($input)) {
    $input =$_POST;
}

$userId           = (int) ($input['user_id'] ?? 0);
$title            = trim((string) ($input['title'] ?? ''));
$description      = trim((string) ($input['description'] ?? ''));
$attachmentName   = trim((string) ($input['attachment_name'] ?? ''));
$attachmentBase64 = trim((string) ($input['attachment_base64'] ?? ''));

if ($userId <= 0) {
    jsonResponse(false, 'Parameter user_id tidak valid.', null, 400);
}

if ($title === '') {
    jsonResponse(false, 'Judul pekerjaan wajib diisi.', null, 400);
}

if ($description === '') {
    jsonResponse(false, 'Keterangan pekerjaan wajib diisi.', null, 400);
}

try {
    $today = date('Y-m-d');

    // 1. Pastikan user sudah Clock Out hari ini (sebelum pukul 23:59:59 WIB)
    $stmt =$pdo->prepare("
        SELECT id, clock_in_time, clock_out_time 
        FROM attendances 
        WHERE user_id = :user_id AND attendance_date = :today 
        LIMIT 1
    ");
    $stmt->execute([
        ':user_id' => $userId,
        ':today'   => $today,
    ]);
    $attendance =$stmt->fetch();

    if (!$attendance || empty($attendance['clock_out_time'])) {
        jsonResponse(
            false,
            'Pengisian tugas hanya dapat dilakukan setelah Clock Out dan sebelum pukul 23:59 WIB.',
            null,
            400
        );
    }

    // 2. Cegah duplikasi jika tugas hari ini sudah pernah dikirim
    $checkDup =$pdo->prepare("
        SELECT id FROM daily_tasks 
        WHERE user_id = :user_id AND task_date = :today 
        LIMIT 1
    ");
    $checkDup->execute([
        ':user_id' => $userId,
        ':today'   => $today,
    ]);
    if ($checkDup->fetch()) {
        jsonResponse(
            false,
            'Tugas hari ini sudah diisi dan tersimpan.',
            null,
            409
        );
    }

    // 3. Validasi lampiran PDF / Word opsional (maksimal 2 MB)
    $storedBase64 = null;
    $storedName   = null;
    if ($attachmentBase64 !== '') {
        $ext = strtolower(pathinfo($attachmentName, PATHINFO_EXTENSION));
        if (!in_array($ext, ['pdf', 'doc', 'docx'], true)) {
            jsonResponse(false, 'Format lampiran harus berupa PDF atau Word (.doc, .docx).', null, 400);
        }

        $rawBase64 =$attachmentBase64;
        if (strpos($attachmentBase64, ',') !== false) {
            [, $rawBase64] = explode(',',$attachmentBase64, 2);
        }

        $decoded = base64_decode($rawBase64, true);
        if ($decoded === false) {
            jsonResponse(false, 'Format data lampiran tidak valid.', null, 400);
        }

        $maxBytes = 2 * 1024 * 1024; // 2 MB
        if (strlen($decoded) >$maxBytes) {
            jsonResponse(false, 'Ukuran lampiran melebihi batas maksimal 2 MB.', null, 400);
        }

        $storedBase64 =$attachmentBase64;
        $storedName   =$attachmentName !== '' ? $attachmentName : ('lampiran_tugas.' .$ext);
    }

    $ins =$pdo->prepare("
        INSERT INTO daily_tasks (user_id, attendance_id, task_date, title, description, attachment_name, attachment_base64)
        VALUES (:user_id, :attendance_id, :task_date, :title, :description, :attachment_name, :attachment_base64)
    ");
    $ins->execute([
        ':user_id'           => $userId,
        ':attendance_id'     => $attendance['id'],
        ':task_date'         => $today,
        ':title'             => $title,
        ':description'       => $description,
        ':attachment_name'   => $storedName,
        ':attachment_base64' => $storedBase64,
    ]);

    jsonResponse(true, 'Tugas hari ini berhasil disimpan.', [
        'id'        => (int) $pdo->lastInsertId(),
        'task_date' => $today, ], 201); } catch (PDOException$e) {
    jsonResponse(false, 'Gagal menyimpan tugas: ' . $e->getMessage(), null, 500);
}