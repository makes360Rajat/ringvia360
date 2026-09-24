<?php
declare(strict_types=1);

function ringviaAuthSecret(): string {
    // Set RINGVIA_AUTH_SECRET in production. The fallback keeps existing installs working
    // until the environment secret is configured.
    return getenv('RINGVIA_AUTH_SECRET') ?: 'ringvia360-rotate-this-production-auth-secret';
}

function ringviaBase64UrlEncode(string $value): string {
    return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
}

function ringviaBase64UrlDecode(string $value): string|false {
    return base64_decode(strtr($value, '-_', '+/'), true);
}

function issueRingviaToken(array $payload): string {
    $encoded = ringviaBase64UrlEncode(json_encode($payload, JSON_UNESCAPED_SLASHES));
    $signature = hash_hmac('sha256', $encoded, ringviaAuthSecret(), true);
    return $encoded . '.' . ringviaBase64UrlEncode($signature);
}

function verifyRingviaToken(?string $header): ?array {
    if (!$header || !preg_match('/^Bearer\\s+(.+)$/i', $header, $match)) return null;
    $parts = explode('.', $match[1], 2);
    if (count($parts) !== 2) return null;
    $expected = ringviaBase64UrlEncode(hash_hmac('sha256', $parts[0], ringviaAuthSecret(), true));
    if (!hash_equals($expected, $parts[1])) return null;
    $payload = json_decode((string) ringviaBase64UrlDecode($parts[0]), true);
    return is_array($payload) && (($payload['exp'] ?? 0) >= time()) ? $payload : null;
}
