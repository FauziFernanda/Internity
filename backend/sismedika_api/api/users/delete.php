<?php
require_once __DIR__ . '/../../config/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    jsonResponse(false, 'Metode request tidak diizinkan.', null, 405);
}

$input = json_decode(file_get_contents('php://input'), true);
if (!is_array($input)) {
    $input = $_POST;
}

$id = (int) ($input['id'] ?? 0);
if ($id <= 0) {
    jsonResponse(false, 'ID user tidak valid.', null, 400);
}

try {
    $stmt = $pdo->prepare("DELETE FROM users WHERE id = :id");
    $stmt->execute([':id' => $id]);

    jsonResponse(true, 'User berhasil dihapus.');
} catch (PDOException $e) {
    jsonResponse(false, 'Gagal menghapus user: ' . $e->getMessage(), null, 500);
}