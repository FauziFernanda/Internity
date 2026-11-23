<?php
require_once __DIR__ . '/../../config/db.php';

const MAX_OTP_ATTEMPTS = 3;

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    jsonResponse(false, 'Metode request tidak diizinkan.', null, 405);
}

$input = json_decode(file_get_contents('php://input'), true);
if (!is_array($input)) {
    $input = $_POST;
}

$email = strtolower(trim($input['email'] ?? ''));
$otp   = trim($input['otp'] ?? '');

if ($email === '' || $otp === '') {
    jsonResponse(false, 'Email dan kode OTP wajib diisi.', null, 400);
}

try {
    $stmt = $pdo->prepare("
        SELECT id, nama_lengkap, email, role, otp_code, otp_expires_at, otp_attempts 
        FROM users 
        WHERE email = :email 
        LIMIT 1
    ");
    $stmt->execute([':email' => $email]);
    $user = $stmt->fetch();

    if (!$user || empty($user['otp_code'])) {
        jsonResponse(false, 'Kode OTP tidak aktif atau sudah dibatalkan. Silakan minta kode OTP baru.', null, 401);
    }

    // 1. Cek jika batas percobaan sudah terlampaui sebelumnya
    if ((int) $user['otp_attempts'] >= MAX_OTP_ATTEMPTS) {
        $clearStmt = $pdo->prepare("UPDATE users SET otp_code = NULL, otp_expires_at = NULL, otp_attempts = 0 WHERE id = :id");
        $clearStmt->execute([':id' => $user['id']]);
        jsonResponse(false, 'Batas percobaan OTP (3x) telah terlampaui. Kode OTP dibatalkan, silakan minta kode baru.', null, 429);
    }

    // 2. Cek masa berlaku OTP
    if (strtotime($user['otp_expires_at']) < time()) {
        $clearStmt = $pdo->prepare("UPDATE users SET otp_code = NULL, otp_expires_at = NULL, otp_attempts = 0 WHERE id = :id");
        $clearStmt->execute([':id' => $user['id']]);
        jsonResponse(false, 'Kode OTP sudah kedaluwarsa. Silakan minta kode baru.', null, 401);
    }

    // 3. Cocokkan kode OTP
    if (!hash_equals((string) $user['otp_code'], $otp)) {
        $newAttempts = (int) $user['otp_attempts'] + 1;
        $remaining   = MAX_OTP_ATTEMPTS - $newAttempts;

        if ($remaining <= 0) {
            // Percobaan ke-3 gagal: langsung hanguskan OTP aktif
            $lockStmt = $pdo->prepare("UPDATE users SET otp_code = NULL, otp_expires_at = NULL, otp_attempts = 0 WHERE id = :id");
            $lockStmt->execute([':id' => $user['id']]);
            jsonResponse(false, 'Kode OTP salah. Batas 3 kali percobaan habis dan kode OTP dibatalkan. Silakan kirim ulang kode baru.', null, 429);
        }

        $incStmt = $pdo->prepare("UPDATE users SET otp_attempts = :attempts WHERE id = :id");
        $incStmt->execute([
            ':attempts' => $newAttempts,
            ':id'       => $user['id'],
        ]);

        jsonResponse(false, "Kode OTP yang Anda masukkan salah. Sisa percobaan: {$remaining} kali.", null, 401);
    }

    // 4. Berhasil: hapus OTP & reset penghitung percobaan
    $clearStmt = $pdo->prepare("UPDATE users SET otp_code = NULL, otp_expires_at = NULL, otp_attempts = 0 WHERE id = :id");
    $clearStmt->execute([':id' => $user['id']]);

    jsonResponse(true, 'Verifikasi berhasil. Selamat datang!', [
        'id'           => (int) $user['id'],
        'nama_lengkap' => $user['nama_lengkap'],
        'email'        => $user['email'],
        'role'         => $user['role'],
    ], 200);
} catch (PDOException $e) {
    jsonResponse(false, 'Terjadi kesalahan pada server: ' . $e->getMessage(), null, 500);
}