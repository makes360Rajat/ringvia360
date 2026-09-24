<?php
declare(strict_types=1);

/**
 * RingVia360 Database Connection Manager
 * Supports Production MySQL on Hostinger and Local SQLite Fallback
 */

function getDatabaseConnection(): array {
    $mysqlHost = 'localhost';
    $mysqlDb = 'u488332847_dn_name';
    $mysqlUser = 'u488332847_payvia360';
    $mysqlPass = 'K6b?qnk2L/';
    
    $db = null;
    $driver = 'sqlite';
    $error = null;

    // 1. Try MySQL Production Connection
    if (extension_loaded('pdo_mysql')) {
        try {
            $dsn = "mysql:host={$mysqlHost};dbname={$mysqlDb};charset=utf8mb4";
            $db = new PDO($dsn, $mysqlUser, $mysqlPass, [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
                PDO::ATTR_TIMEOUT => 3
            ]);
            $driver = 'mysql';
        } catch (Throwable $e) {
            $error = $e->getMessage();
        }
    }

    // 2. Fallback to Local SQLite if MySQL is unavailable (e.g., local development)
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
    }

    return [
        'pdo' => $db,
        'driver' => $driver,
        'mysql_error' => $error
    ];
}
