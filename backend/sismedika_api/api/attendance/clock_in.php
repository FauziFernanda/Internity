<?php
require_once __DIR__ . '/../../config/db.php';
date_default_timezone_set('Asia/Jakarta');

// Koordinat acuan kantor & radius toleransi geofence
const OFFICE_LAT = -6.3064587;
const OFFICE_LNG = 106.6853194;
const GEOFENCE_RADIUS_METERS = 50.0;
const WORK_START_TIME = '08:00:00';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    jsonResponse(false, 'Metode request tidak diizinkan.', null, 405);
}

$input = json_decode(file_get_contents('php://input'), true);
if (!is_array($input)) {
    $input = $_POST;
}

$userId        = (int) ($input['user_id'] ?? 0);
$lat           = isset($input['latitude']) ? (float) $input['latitude'] : null;
$lng           = isset($input['longitude']) ? (float) $input['longitude'] : null;
$justification = trim($input['justification'] ?? '');
$selfieBase64  = trim($input['selfie_base64'] ?? '');

if ($userId <= 0 || $lat === null || $lng === null) {
    jsonResponse(false, 'Data user dan titik koordinat GPS wajib dikirim.', null, 400);
}

// Hitung jarak menggunakan rumus Haversine (dalam satuan meter)
function calculateDistanceMeters(float $lat1, float $lon1, float $lat2, float $lon2): float
{
    $earthRadius = 6371000.0;
    $dLat = deg2rad($lat2 - $lat1);
    $dLon = deg2rad($lon2 - $lon1);
    $a = sin($dLat / 2) * sin($dLat / 2) +
         cos(deg2rad($lat1)) * cos(deg2rad($lat2)) *
         sin($dLon / 2) * sin($dLon / 2);
    $c = 2 * atan2(sqrt($a), sqrt(1 - $a));
    return round($earthRadius * $c, 2);
}

try {
    $today = date('Y-m-d');
    $nowTime = date('H:i:s');

    // Cek apakah sudah pernah absen / izin hari ini
    $checkStmt = $pdo->prepare("SELECT id, status FROM attendances WHERE user_id = :user_id AND attendance_date = :today LIMIT 1");
    $checkStmt->execute([':user_id' => $userId, ':today' => $today]);
    $existing = $checkStmt->fetch();

    if ($existing) {
        jsonResponse(false, "Anda sudah mencatat kehadiran hari ini dengan status: {$existing['status']}.", null, 409);
    }

    $distanceMeters = calculateDistanceMeters($lat, $lng, OFFICE_LAT, OFFICE_LNG);
    $isOutside = $distanceMeters > GEOFENCE_RADIUS_METERS ? 1 : 0;

    // Jika di luar area kantor, wajib menyertakan alasan & foto selfie Base64
    if ($isOutside === 1) {
        if ($justification === '') {
            jsonResponse(false, 'Alasan di luar kantor wajib diisi.', null, 400);
        }
        if ($selfieBase64 === '') {
            jsonResponse(false, 'Foto wajah di lokasi (selfie) wajib dilampirkan.', null, 400);
        }
    }

    // Tentukan status tepat waktu atau terlambat (batas 08:00:59 WIB)
    $status = (strtotime($nowTime) <= strtotime('08:00:59')) ? 'Tepat Waktu' : 'Terlambat';

    $insertStmt = $pdo->prepare("
        INSERT INTO attendances (
            user_id, attendance_date, clock_in_time, status,
            is_outside_office, latitude, longitude, distance_meters,
            justification, selfie_base64
        ) VALUES (
            :user_id, :attendance_date, :clock_in_time, :status,
            :is_outside_office, :latitude, :longitude, :distance_meters,
            :justification, :selfie_base64
        )
    ");

    $insertStmt->execute([
        ':user_id'           => $userId,
        ':attendance_date'   => $today,
        ':clock_in_time'     => $nowTime,
        ':status'            => $status,
        ':is_outside_office' => $isOutside,
        ':latitude'          => $lat,
        ':longitude'         => $lng,
        ':distance_meters'   => $distanceMeters,
        ':justification'     => $justification !== '' ? $justification : null,
        ':selfie_base64'     => $selfieBase64 !== '' ? $selfieBase64 : null,
    ]);

    jsonResponse(true, 'Clock In berhasil dicatat.', [
        'id'                => (int) $pdo->lastInsertId(),
        'attendance_date'   => $today,
        'clock_in_time'     => $nowTime,
        'status'            => $status,
        'is_outside_office' => $isOutside,
        'distance_meters'   => $distanceMeters,
    ], 201);
} catch (PDOException $e) {
    jsonResponse(false, 'Gagal menyimpan Clock In: ' . $e->getMessage(), null, 500);
}