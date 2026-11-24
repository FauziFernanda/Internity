<?php
require_once __DIR__ . '/../../config/db.php';
date_default_timezone_set('Asia/Jakarta');

const WORK_END_TIME = '17:00:00';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    jsonResponse(false, 'Metode request tidak diizinkan.', null, 405);
}

$input = json_decode(file_get_contents('php://input'), true);
if (!is_array($input)) {
    $input =$_POST;
}

$userId = (int) ($input['user_id'] ?? 0);
if ($userId <= 0) {
    jsonResponse(false, 'Parameter user_id tidak valid.', null, 400);
}

try {
    $today = date('Y-m-d');$nowTime = date('H:i:s');

    // Validasi batas waktu pulang minimal pukul 17:00 WIB
    if (strtotime($nowTime) < strtotime(WORK_END_TIME)) {
        jsonResponse(
            false,
            'Belum jam pulang. Clock Out hanya dapat dilakukan mulai pukul 17:00 WIB.',
            null,
            400
        );
    }

    $stmt =$pdo->prepare("
        SELECT id, status, clock_in_time, clock_out_time 
        FROM attendances 
        WHERE user_id = :user_id AND attendance_date = :today 
        LIMIT 1
    ");
    $stmt->execute([':user_id' => $userId, ':today' =>$today]);
    $row =$stmt->fetch();

    if (!$row || empty($row['clock_in_time'])) {
        jsonResponse(false, 'Anda belum melakukan Clock In hari ini.', null, 400);
    }

    if (!empty($row['clock_out_time'])) {
        jsonResponse(false, 'Anda sudah melakukan Clock Out hari ini pada pukul ' . substr($row['clock_out_time'], 0, 5) . ' WIB.', null, 409);
    }

    $upd =$pdo->prepare("UPDATE attendances SET clock_out_time = :out_time WHERE id = :id");
    $upd->execute([
        ':out_time' => $nowTime,
        ':id'       => $row['id'],
    ]);

    jsonResponse(true, 'Clock Out berhasil dicatat.', [
        'clock_out_time' => $nowTime, ], 200); } catch (PDOException$e) {
    jsonResponse(false, 'Gagal menyimpan Clock Out: ' . $e->getMessage(), null, 500);
}