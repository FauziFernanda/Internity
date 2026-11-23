<?php
require_once __DIR__ . '/../../config/db.php';

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
        SELECT id, nama_lengkap, email, role, otp_code, otp_expires_at 
        FROM users 
        WHERE email = :email 
        LIMIT 1
    ");
    $stmt->execute([':email' => $email]);
    $user = $stmt->fetch();

    if (!$user || empty($user['otp_code'])) {
        jsonResponse(false, 'Permintaan OTP tidak ditemukan. Silakan kirim ulang kode OTP.', null, 401);
    }

    // Cek masa berlaku OTP
    if (strtotime($user['otp_expires_at']) < time()) {
        jsonResponse(false, 'Kode OTP sudah kedaluwarsa. Silakan minta kode baru.', null, 401);
    }

    // Cocokkan kode OTP
    if (!hash_equals((string) $user['otp_code'], $otp)) {
        jsonResponse(false, 'Kode OTP yang Anda masukkan salah.', null, 401);
    }

    // Hapus OTP setelah berhasil dipakai (sekali pakai)
    $clearStmt = $pdo->prepare("UPDATE users SET otp_code = NULL, otp_expires_at = NULL WHERE id = :id");
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