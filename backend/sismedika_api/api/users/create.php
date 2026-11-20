<?php
require_once __DIR__ . '/../../config/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    jsonResponse(false, 'Metode request tidak diizinkan.', null, 405);
}

$input = json_decode(file_get_contents('php://input'), true);
if (!is_array($input)) {
    $input = $_POST;
}

$namaLengkap = trim($input['nama_lengkap'] ?? '');
$email       = strtolower(trim($input['email'] ?? ''));
$role        = trim($input['role'] ?? '');

if ($namaLengkap === '' || $email === '' || $role === '') {
    jsonResponse(false, 'Nama lengkap, email, dan role wajib diisi.', null, 400);
}

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    jsonResponse(false, 'Format email tidak valid.', null, 400);
}

if (!in_array($role, ['Admin', 'HRD', 'Intern'], true)) {
    jsonResponse(false, 'Role harus berupa Admin, HRD, atau Intern.', null, 400);
}

try {
    $check = $pdo->prepare("SELECT id FROM users WHERE email = :email LIMIT 1");
    $check->execute([':email' => $email]);
    if ($check->fetch()) {
        jsonResponse(false, 'Email sudah terdaftar.', null, 409);
    }

    $stmt = $pdo->prepare("INSERT INTO users (nama_lengkap, email, role) VALUES (:nama, :email, :role)");
    $stmt->execute([':nama' => $namaLengkap, ':email' => $email, ':role' => $role]);

    jsonResponse(true, 'User berhasil ditambahkan.', [
        'id'           => (int) $pdo->lastInsertId(),
        'nama_lengkap' => $namaLengkap,
        'email'        => $email,
        'role'         => $role,
    ], 201);
} catch (PDOException $e) {
    jsonResponse(false, 'Gagal menambahkan user: ' . $e->getMessage(), null, 500);
}