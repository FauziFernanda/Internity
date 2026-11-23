<?php
require_once __DIR__ . '/../../config/db.php';
require_once __DIR__ . '/../../helpers/mailer.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    jsonResponse(false, 'Metode request tidak diizinkan.', null, 405);
}

$input = json_decode(file_get_contents('php://input'), true);
if (!is_array($input)) {
    $input = $_POST;
}

$email = strtolower(trim($input['email'] ?? ''));

if ($email === '') {
    jsonResponse(false, 'Email wajib diisi.', null, 400);
}

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    jsonResponse(false, 'Format email tidak valid.', null, 400);
}

try {
    $stmt = $pdo->prepare("SELECT id, nama_lengkap, email, role FROM users WHERE email = :email LIMIT 1");
    $stmt->execute([':email' => $email]);
    $user = $stmt->fetch();

    if (!$user) {
        jsonResponse(false, 'Email tidak terdaftar dalam sistem. Hubungi Admin untuk akses masuk.', null, 401);
    }

    // Generate 6 digit OTP acak & masa berlaku 5 menit
    $otpCode   = (string) random_int(100000, 999999);
    $expiresAt = date('Y-m-d H:i:s', strtotime('+5 minutes'));

    $updateStmt = $pdo->prepare("
        UPDATE users 
        SET otp_code = :otp, otp_expires_at = :expires 
        WHERE id = :id
    ");
    $updateStmt->execute([
        ':otp'     => $otpCode,
        ':expires' => $expiresAt,
        ':id'      => $user['id'],
    ]);

    // Kirim OTP ke email user
    $mailResult = sendOtpEmail($user['email'], $user['nama_lengkap'], $otpCode);

    if (!$mailResult['sent']) {
        jsonResponse(false, $mailResult['message'], null, 500);
    }

    $responseData = [
        'email'      => $user['email'],
        'expires_in' => 300, // 5 menit (dalam detik)
    ];

    // Jika mode dev (SMTP_ENABLED = false), sertakan kode OTP agar mudah diuji
    if (!empty($mailResult['dev_mode'])) {
        $responseData['dev_otp'] = $otpCode;
    }

    jsonResponse(true, 'Kode OTP telah dikirim ke email Anda.', $responseData, 200);
} catch (PDOException $e) {
    jsonResponse(false, 'Terjadi kesalahan pada server: ' . $e->getMessage(), null, 500);
}