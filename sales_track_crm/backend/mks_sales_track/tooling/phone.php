<?php

/**
 * MKS Sales Track - phone simulator.
 *
 * Talks to a live CRM exactly the way the Android and iOS apps will, so the
 * API can be exercised, and the app contract checked, without a phone:
 *
 *   php tooling/phone.php ping   --url=https://crm.example.com/
 *   php tooling/phone.php pair   --url=https://crm.example.com/ --code=483920
 *   php tooling/phone.php config --url=https://crm.example.com/ [--ack=<command id>] [--app_version=1.0.0]
 *   php tooling/phone.php sync   --url=https://crm.example.com/ [--count=20] [--number=+919876543210]
 *   php tooling/phone.php record --url=https://crm.example.com/ --uid=<call uid> --file=call.m4a
 *
 * pair takes the 6-digit code of a device added in the CRM (Devices > Add
 * Device), stores the token in the system temp folder (or --state=path), and
 * the other commands reuse it. Add --platform=ios to pair as an iPhone.
 * config prints any commands queued for the phone; --ack acknowledges one.
 *
 * Command line only: refused outright over the web, and tooling/ also ships
 * with Deny from all.
 */

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

$args    = mks_phone_args($argv);
$command = isset($argv[1]) ? $argv[1] : 'help';
$url     = isset($args['url']) ? rtrim($args['url'], '/') . '/' : '';
$state   = isset($args['state']) ? $args['state'] : sys_get_temp_dir() . '/mks_sales_track_phone.json';

if ($url === '' && $command !== 'help') {
    fwrite(STDERR, "--url is required\n");
    exit(2);
}

$api   = $url . 'mks_sales_track/api/v1/';
$saved = is_file($state) ? json_decode((string) file_get_contents($state), true) : [];
$saved = is_array($saved) ? $saved : [];
$token = isset($args['token']) ? $args['token'] : (isset($saved['token']) ? $saved['token'] : '');

switch ($command) {
    case 'ping':
        mks_phone_print(mks_phone_request('GET', $api . 'ping'));
        break;

    case 'pair':
        $uid = isset($args['uid']) ? $args['uid'] : 'sim-' . bin2hex(random_bytes(8));
        $ios = isset($args['platform']) && $args['platform'] === 'ios';

        $reply = mks_phone_request('POST', $api . 'pair', [
            'code'   => isset($args['code']) ? $args['code'] : '',
            'device' => [
                'uid'          => $uid,
                'platform'     => $ios ? 'ios' : 'android',
                'manufacturer' => $ios ? 'Apple' : 'Google',
                'model'        => $ios ? 'iPhone Simulator' : 'Pixel Simulator',
                'os_version'   => $ios ? '18.1' : '14',
                'app_version'  => '0.0.1-sim',
                'sims'         => $ios ? [] : [['slot' => 1, 'label' => 'Jio'], ['slot' => 2, 'label' => 'Airtel']],
            ],
        ]);

        if (!empty($reply['body']['token'])) {
            file_put_contents($state, json_encode(['token' => $reply['body']['token'], 'uid' => $uid, 'url' => $url]));
        }

        mks_phone_print($reply);
        break;

    case 'config':
        mks_phone_print(mks_phone_request('POST', $api . 'config', [
            'acks'        => isset($args['ack']) ? [['id' => $args['ack'], 'status' => 'done']] : [],
            'app_version' => isset($args['app_version']) ? $args['app_version'] : '0.0.1-sim',
            'health'      => [
                'permissions' => [
                    'call_log'             => true,
                    'phone_state'          => true,
                    'contacts'             => true,
                    'sms'                  => true,
                    'notifications'        => true,
                    'recordings'           => true,
                    'battery_unrestricted' => false,
                ],
                'battery'  => 76,
                'charging' => false,
                'queue'    => 0,
                'network'  => 'wifi',
            ],
        ], $token));
        break;

    case 'sync':
        $count  = isset($args['count']) ? max(1, min(200, (int) $args['count'])) : 12;
        $number = isset($args['number']) ? $args['number'] : '';
        $events = [];
        $now    = (int) round(microtime(true) * 1000);
        $kinds  = ['call', 'call', 'call', 'whatsapp_call', 'sms'];

        for ($i = 0; $i < $count; $i++) {
            $kind  = $kinds[$i % count($kinds)];
            $phone = $number !== '' ? $number : '+9198' . str_pad((string) random_int(0, 99999999), 8, '0', STR_PAD_LEFT);
            $event = [
                'uid'  => $kind . '-' . ($now - $i * 60000) . '-' . $i,
                'kind' => $kind,
                'time' => $now - $i * 60000,
            ];

            {
                $event += [
                    'direction' => ['incoming', 'outgoing', 'missed'][$i % 3],
                    'number'    => $phone,
                    'name'      => $i % 2 ? 'Simulated Contact' : '',
                    'duration'  => $i % 3 === 2 ? 0 : 30 + $i * 7,
                    'sim'       => 1,
                ];

                if ($kind === 'call') {
                    $event['recording'] = $i % 3 !== 2;
                }

                if ($kind === 'whatsapp_call') {
                    $event['media'] = 'voice';
                    $event['app']   = 'com.whatsapp';
                }

                if ($kind === 'sms') {
                    $event['text'] = 'Simulated SMS ' . $i;
                }
            }

            $events[] = $event;
        }

        mks_phone_print(mks_phone_request('POST', $api . 'sync', ['events' => $events], $token));
        break;

    case 'record':
        if (empty($args['uid']) || empty($args['file']) || !is_file($args['file'])) {
            fwrite(STDERR, "--uid and an existing --file are required\n");
            exit(2);
        }

        mks_phone_print(mks_phone_request('POST', $api . 'recording', [
            'uid'  => $args['uid'],
            'file' => new CURLFile($args['file']),
        ], $token, true));
        break;

    default:
        echo "Commands: ping, pair, config, sync, record. See the top of this file.\n";
}

/**
 * --key=value pairs.
 *
 * @param  array $argv
 *
 * @return array
 */
function mks_phone_args(array $argv)
{
    $out = [];

    foreach (array_slice($argv, 2) as $arg) {
        if (preg_match('/^--([a-z_]+)=(.*)$/', $arg, $m)) {
            $out[$m[1]] = $m[2];
        }
    }

    return $out;
}

/**
 * @param  string     $method
 * @param  string     $url
 * @param  array|null $body
 * @param  string     $token
 * @param  bool       $multipart
 *
 * @return array status, body
 */
function mks_phone_request($method, $url, $body = null, $token = '', $multipart = false)
{
    $curl    = curl_init($url);
    $headers = ['Accept: application/json'];

    if ($token !== '') {
        $headers[] = 'X-Sales-Track-Token: ' . $token;
    }

    curl_setopt($curl, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($curl, CURLOPT_TIMEOUT, 60);
    curl_setopt($curl, CURLOPT_CUSTOMREQUEST, $method);

    if ($body !== null && $method !== 'GET') {
        if ($multipart) {
            curl_setopt($curl, CURLOPT_POSTFIELDS, $body);
        } else {
            $headers[] = 'Content-Type: application/json';
            curl_setopt($curl, CURLOPT_POSTFIELDS, json_encode($body));
        }
    }

    curl_setopt($curl, CURLOPT_HTTPHEADER, $headers);

    $raw    = curl_exec($curl);
    $status = (int) curl_getinfo($curl, CURLINFO_HTTP_CODE);

    curl_close($curl);

    $decoded = is_string($raw) ? json_decode($raw, true) : null;

    return ['status' => $status, 'body' => is_array($decoded) ? $decoded : ['raw' => $raw]];
}

/**
 * @param  array $reply
 *
 * @return void
 */
function mks_phone_print(array $reply)
{
    echo 'HTTP ' . $reply['status'] . "\n" . json_encode($reply['body'], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n";
}
