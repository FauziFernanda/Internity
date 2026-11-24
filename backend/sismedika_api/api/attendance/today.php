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

/**
 * Mencatat status 'Alfa' secara otomatis pada hari kerja (Senin-Jumat)
 * yang tidak memiliki catatan Clock In maupun Izin/Sakit.
 */
function syncAlfaRecords(PDO $pdo, int $userId): void
{
    $today   = date('Y-m-d');
    $nowTime = date('H:i:s');

    // 1. Cek hari kerja yang terlewat sejak catatan kehadiran pertama hingga kemarin
    $minStmt = $pdo->prepare("SELECT MIN(attendance_date) FROM attendances WHERE user_id = :user_id");
    $minStmt->execute([':user_id' => $userId]);
    $firstDate = $minStmt->fetchColumn();

    if ($firstDate) {
        $cursor    = strtotime($firstDate);
        $yesterday = strtotime('-1 day', strtotime($today));

        $insertAlfa = $pdo->prepare("
            INSERT IGNORE INTO attendances (user_id, attendance_date, status)
            VALUES (:user_id, :att_date, 'Alfa')
        ");

        while ($cursor <= $yesterday) {
            $dayOfWeek = (int) date('N', $cursor); // 1 (Senin) - 5 (Jumat)
            if ($dayOfWeek >= 1 && $dayOfWeek <= 5) {
                $insertAlfa->execute([
                    ':user_id'  => $userId,
                    ':att_date' => date('Y-m-d', $cursor),
                ]);
            }
            $cursor = strtotime('+1 day', $cursor);
        }
    }

    // 2. Cek hari ini: jika hari kerja (Senin-Jumat) dan sudah lewat 17:00 WIB tanpa absen/izin
    $todayDayOfWeek = (int) date('N');
    if ($todayDayOfWeek >= 1 && $todayDayOfWeek <= 5 && strtotime($nowTime) > strtotime('17:00:00')) {
        $insertTodayAlfa = $pdo->prepare("
            INSERT IGNORE INTO attendances (user_id, attendance_date, status)
            VALUES (:user_id, :today, 'Alfa')
        ");
        $insertTodayAlfa->execute([
            ':user_id' => $userId,
            ':today'   => $today,
        ]);
    }
}

try {
    // Sinkronisasi otomatis status Alfa sebelum membaca data
    syncAlfaRecords($pdo, $userId);

    $today = date('Y-m-d');

    // Ambil data kehadiran hari ini
    $stmt = $pdo->prepare("
        SELECT id, user_id, attendance_date, clock_in_time, clock_out_time,
               status, is_outside_office, latitude, longitude, distance_meters, justification
        FROM attendances
        WHERE user_id = :user_id AND attendance_date = :today
        LIMIT 1
    ");
    $stmt->execute([
        ':user_id' => $userId,
        ':today'   => $today,
    ]);
    $todayData = $stmt->fetch();

    if ($todayData) {
        $todayData['id'] = (int) $todayData['id'];
        $todayData['user_id'] = (int) $todayData['user_id'];
        $todayData['is_outside_office'] = (int) $todayData['is_outside_office'];
        $todayData['distance_meters'] = $todayData['distance_meters'] !== null ? (float) $todayData['distance_meters'] : null;
    }

    // Ambil 15 riwayat kehadiran terakhir untuk fitur Log Harian
    $logStmt = $pdo->prepare("
        SELECT id, attendance_date, clock_in_time, clock_out_time, status, is_outside_office, distance_meters, justification
        FROM attendances
        WHERE user_id = :user_id
        ORDER BY attendance_date DESC
        LIMIT 15
    ");
    $logStmt->execute([':user_id' => $userId]);
    $logs = $logStmt->fetchAll();

    jsonResponse(true, 'Data kehadiran berhasil dimuat.', [
        'server_date' => $today,
        'server_time' => date('H:i:s'),
        'today'       => $todayData ?: null,
        'logs'        => $logs,
    ], 200);
} catch (PDOException $e) {
    jsonResponse(false, 'Gagal memuat data kehadiran: ' . $e->getMessage(), null, 500);
}