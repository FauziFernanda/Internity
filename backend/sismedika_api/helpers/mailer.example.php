<?php

// Ubah menjadi true setelah mengisi BREVO_API_KEY dan BREVO_SENDER_EMAIL di bawah
define('BREVO_ENABLED', false);
define('BREVO_API_KEY', 'xkeysib-ISI_API_KEY_BREVO_ANDA_DI_SINI');
define('BREVO_SENDER_EMAIL', 'emailpengirim@gmail.com'); // Wajib sama dengan Sender yang diverifikasi di Brevo
define('BREVO_SENDER_NAME', 'SISMEDIKA Intern System');

function sendOtpEmail(string $toEmail, string $namaLengkap, string $otpCode): array
{
    if (!BREVO_ENABLED) {
        return [
            'sent'     => true,
            'dev_mode' => true,
            'message'  => 'Mode pengembangan aktif (BREVO_ENABLED masih false).'
        ];
    }

    if (!function_exists('curl_init')) {
        return [
            'sent'    => false,
            'message' => 'Ekstensi PHP cURL belum aktif di XAMPP.'
        ];
    }

    $subject = "Kode OTP Login SISMEDIKA Intern: {$otpCode}";
    $htmlBody = "
    <div style='font-family: Arial, sans-serif; max-width: 480px; margin: auto; padding: 24px; border: 1px solid #e2e8f0; border-radius: 12px;'>
        <h2 style='color: #1A64E8; margin-top: 0;'>Verifikasi Login SISMEDIKA</h2>
        <p style='color: #334155;'>Halo <strong>{$namaLengkap}</strong>,</p>
        <p style='color: #334155;'>Gunakan kode OTP berikut untuk masuk ke aplikasi <strong>SISMEDIKA Intern</strong>:</p>
        <div style='background: #EFF6FF; border: 1px dashed #1A64E8; padding: 16px; text-align: center; border-radius: 8px; margin: 20px 0;'>
            <span style='font-size: 28px; font-weight: bold; letter-spacing: 6px; color: #0F172A;'>{$otpCode}</span>
        </div>
        <p style='color: #64748B; font-size: 13px;'>Kode ini berlaku selama <strong>5 menit</strong>. Jangan bagikan kode ini kepada siapa pun.</p>
    </div>";

    $payload = [
        'sender' => [
            'name'  => BREVO_SENDER_NAME,
            'email' => BREVO_SENDER_EMAIL,
        ],
        'to' => [
            [
                'email' => $toEmail,
                'name'  => $namaLengkap,
            ]
        ],
        'subject'     => $subject,
        'htmlContent' => $htmlBody,
    ];

    $ch = curl_init('https://api.brevo.com/v3/smtp/email');
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST           => true,
        CURLOPT_TIMEOUT        => 15,
        CURLOPT_SSL_VERIFYPEER => false, // Menghindari error sertifikat SSL lokal pada XAMPP Windows
        CURLOPT_HTTPHEADER     => [
            'accept: application/json',
            'api-key: ' . BREVO_API_KEY,
            'content-type: application/json',
        ],
        CURLOPT_POSTFIELDS     => json_encode($payload, JSON_UNESCAPED_UNICODE),
    ]);

    $response = curl_exec($ch);
    $curlErr  = curl_error($ch);
    $httpCode = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($response === false) {
        return [
            'sent'    => false,
            'message' => 'Gagal menghubungi server Brevo API: ' . $curlErr,
        ];
    }

    // Brevo mengembalikan HTTP 201 Created jika email berhasil masuk antrean kirim
    if ($httpCode >= 200 && $httpCode < 300) {
        return [
            'sent'     => true,
            'dev_mode' => false,
            'message'  => 'Kode OTP berhasil dikirim ke email melalui Brevo API.',
        ];
    }

    $decoded = json_decode($response, true);
    $apiError = $decoded['message'] ?? ('HTTP Status ' . $httpCode);

    return [
        'sent'    => false,
        'message' => 'Brevo API menolak pengiriman: ' . $apiError,
    ];
}
