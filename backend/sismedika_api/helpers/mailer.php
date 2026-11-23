<?php

// Ubah menjadi true jika sudah mengisi Gmail & App Password di bawah
define('SMTP_ENABLED', false);
define('SMTP_HOST', 'ssl://smtp.gmail.com');
define('SMTP_PORT', 465);
define('SMTP_USER', 'emailkamu@gmail.com');       // Ganti dengan Gmail pengirim
define('SMTP_PASS', 'xxxx xxxx xxxx xxxx');       // Ganti dengan 16 digit App Password Google
define('SMTP_FROM_NAME', 'SISMEDIKA Intern System');

function sendOtpEmail(string $toEmail, string $namaLengkap, string $otpCode): array
{
    if (!SMTP_ENABLED) {
        return [
            'sent'     => true,
            'dev_mode' => true,
            'message'  => 'Mode pengembangan aktif (SMTP belum diaktifkan).'
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

    try {
        $socket = @stream_socket_client(
            SMTP_HOST . ':' . SMTP_PORT,
            $errno,
            $errstr,
            15
        );

        if (!$socket) {
            return ['sent' => false, 'message' => "Gagal terhubung ke server SMTP: {$errstr}"];
        }

        $readResponse = function () use ($socket) {
            $data = '';
            while ($line = fgets($socket, 515)) {
                $data .= $line;
                if (isset($line[3]) && $line[3] === ' ') {
                    break;
                }
            }
            return $data;
        };

        $sendCommand = function (string $cmd) use ($socket, $readResponse) {
            fwrite($socket, $cmd . "\r\n");
            return $readResponse();
        };

        $readResponse(); // Greeting 220
        $sendCommand('EHLO localhost');
        $sendCommand('AUTH LOGIN');
        $sendCommand(base64_encode(SMTP_USER));
        $authResp = $sendCommand(base64_encode(str_replace(' ', '', SMTP_PASS)));

        if (strpos($authResp, '235') === false) {
            fclose($socket);
            return ['sent' => false, 'message' => 'Autentikasi SMTP gagal. Periksa email & App Password.'];
        }

        $sendCommand('MAIL FROM: <' . SMTP_USER . '>');
        $sendCommand('RCPT TO: <' . $toEmail . '>');
        $sendCommand('DATA');

        $headers  = "From: " . SMTP_FROM_NAME . " <" . SMTP_USER . ">\r\n";
        $headers .= "To: {$namaLengkap} <{$toEmail}>\r\n";
        $headers .= "Subject: {$subject}\r\n";
        $headers .= "MIME-Version: 1.0\r\n";
        $headers .= "Content-Type: text/html; charset=UTF-8\r\n\r\n";

        $mailResp = $sendCommand($headers . $htmlBody . "\r\n.");
        $sendCommand('QUIT');
        fclose($socket);

        if (strpos($mailResp, '250') === false) {
            return ['sent' => false, 'message' => 'Server SMTP menolak pengiriman email.'];
        }

        return ['sent' => true, 'dev_mode' => false, 'message' => 'Email OTP terkirim.'];
    } catch (Throwable $e) {
        return ['sent' => false, 'message' => 'Error mailer: ' . $e->getMessage()];
    }
}