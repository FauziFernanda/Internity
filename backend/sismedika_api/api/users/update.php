<?php
require_once __DIR__ . '/../../config/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    jsonResponse(false, 'Metode request tidak diizinkan.', null, 405);
}

$input = json_decode(file_get_contents('php://input'), true);
if (!is_array($input)) {
    $input = $_POST;
}

$id          = (int) ($input['id'] ?? 0);
$namaLengkap = trim($input['nama_lengkap'] ?? '');
$email       = strtolower(trim($input['email'] ?? ''));
$role        = trim($input['role'] ?? '');

if ($id <= 0 || $namaLengkap === '' || $email === '' || $role === '') {
    jsonResponse(false, 'Data tidak lengkap.', null, 400);
}

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    jsonResponse(false, 'Format email tidak valid.', null, 400);
}

if (!in_array($role, ['Admin', 'HRD', 'Intern'], true)) {
    jsonResponse(false, 'Role harus berupa Admin, HRD, atau Intern.', null, 400);
}

try {
    $dup = $pdo->prepare("SELECT id FROM users WHERE email = :email AND id != :id LIMIT 1");
    $dup->execute([':email' => $email, ':id' => $id]);
    if ($dup->fetch()) {
        jsonResponse(false, 'Email sudah digunakan oleh user lain.', null, 409);
    }

    $stmt = $pdo->prepare("UPDATE users SET nama_lengkap = :nama, email = :email, role = :role WHERE id = :id");
    $stmt->execute([':nama' => $namaLengkap, ':email' => $email, ':role' => $role, ':id' => $id]);

    jsonResponse(true, 'User berhasil diperbarui.', [
        'id'           => $id,
        'nama_lengkap' => $namaLengkap,
        'email'        => $email,
        'role'         => $role,
    ]);
} catch (PDOException $e) {
    jsonResponse(false, 'Gagal memperbarui user: ' . $e->getMessage(), null, 500);
}