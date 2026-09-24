<?php
declare(strict_types=1);

/**
 * RingVia360 Database Connection Manager
 * Supports Production MySQL on Hostinger and Local SQLite Fallback
 */

function getDatabaseConnection(): array {
    $mysqlDb = 'u488332847_dn_name';
    $hosts = ['localhost', 'auth-db1260.hstgr.io', '127.0.0.1'];
    // Primary username provided: u488332847_ringvia360 (fallback to u488332847_payvia360 if needed)
    $usernames = ['u488332847_ringvia360', 'u488332847_payvia360'];
    $mysqlPass = 'K6b?qnk2L/';
    
    $db = null;
    $driver = 'sqlite';
    $activeUser = null;
    $activeHost = null;
    $errors = [];

    // 1. Try MySQL Production Connection with configured hosts & users
    if (extension_loaded('pdo_mysql')) {
        foreach ($hosts as $host) {
            foreach ($usernames as $user) {
                try {
                    $dsn = "mysql:host={$host};dbname={$mysqlDb};charset=utf8mb4";
                    $pdo = new PDO($dsn, $user, $mysqlPass, [
                        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                        PDO::ATTR_EMULATE_PREPARES => false,
                        PDO::ATTR_TIMEOUT => 3
                    ]);
                    $db = $pdo;
                    $driver = 'mysql';
                    $activeUser = $user;
                    $activeHost = $host;
                    break 2;
                } catch (Throwable $e) {
                    $errors["{$user}@{$host}"] = $e->getMessage();
                }
            }
        }
    }

    // 2. Fallback to Local SQLite if MySQL is unavailable (e.g. local development or during maintenance)
    if ($db === null) {
        $dataDir = __DIR__ . '/data';
        if (!is_dir($dataDir)) {
            mkdir($dataDir, 0755, true);
        }
        $sqlitePath = $dataDir . '/ringvia_calls.sqlite';
        $db = new PDO('sqlite:' . $sqlitePath);
        $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $db->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
        $driver = 'sqlite';
        $activeUser = 'sqlite_local';
    }

    return [
        'pdo' => $db,
        'driver' => $driver,
        'user' => $activeUser,
        'host' => $activeHost,
        'errors' => $errors
    ];
}
