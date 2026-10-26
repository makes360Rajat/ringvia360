import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_track_crm/models/sales_track_models.dart';
import 'package:sales_track_crm/services/app_lock_service.dart';
import 'package:sales_track_crm/services/sales_track_api_service.dart';

void main() {
  group('Sales Track Backend Compatibility Tests', () {
    test('Config excluded number detection matching PHP backend sha256', () {
      const salt = 'testsalt123';
      const number = '+91 98765 43210';
      final digits = number.replaceAll(RegExp(r'\D'), '');
      final last10 = digits.substring(digits.length - 10);
      final expectedHash = sha256.convert(utf8.encode(salt + last10)).toString().toLowerCase();

      final config = SalesTrackConfig.fromJson({
        'excluded': {
          'salt': salt,
          'hashes': [expectedHash],
        },
        'match_digits': 10,
      });

      expect(config.isNumberExcluded('+91 98765 43210'), isTrue);
      expect(config.isNumberExcluded('9876543210'), isTrue);
      expect(config.isNumberExcluded('+91 99999 11111'), isFalse);
    });

    test('SalesTrackEvent conforms to backend mks_st_ingest schema', () {
      final callEvent = SalesTrackEvent(
        uid: 'call-101-1791897127494',
        kind: 'call',
        time: 1791897127494,
        direction: 'incoming',
        number: '+919876543210',
        name: 'Sunil Traders',
        sim: 1,
        duration: 95,
        recording: true,
      );

      final json = callEvent.toApiJson();
      expect(json['uid'], equals('call-101-1791897127494'));
      expect(json['kind'], equals('call'));
      expect(json['direction'], equals('incoming'));
      expect(json['number'], equals('+919876543210'));
      expect(json['name'], equals('Sunil Traders'));
      expect(json['duration'], equals(95));
      expect(json['recording'], isTrue);

      final waEvent = SalesTrackEvent(
        uid: 'wacall-1791897127500',
        kind: 'whatsapp_call',
        time: 1791897127500,
        direction: 'outgoing',
        number: '+919876543210',
        name: 'Client Business',
        duration: 120,
        media: 'voice',
        app: 'com.whatsapp.w4b', // WhatsApp Business!
      );

      final waJson = waEvent.toApiJson();
      expect(waJson['kind'], equals('whatsapp_call'));
      expect(waJson['app'], equals('com.whatsapp.w4b'));
      expect(waJson['media'], equals('voice'));
      expect(waJson['duration'], equals(120));
    });

    test('AppLockService verifies PBKDF2-HMAC-SHA256 correctly', () {
      // Generate test hash
      const pin = '1234';
      const salt = '1f0c2d3e';
      const iterations = 1000;
      final derived = AppLockService.pbkdf2HmacSha256(
        password: utf8.encode(pin),
        salt: utf8.encode(salt),
        iterations: iterations,
        derivedKeyLength: 32,
      );
      final hash = derived.map((b) => b.toRadixString(16).padLeft(2, '0')).join('').toLowerCase();

      final config = SalesTrackConfig.fromJson({
        'app_lock': {
          'enabled': true,
          'algorithm': 'pbkdf2-sha256',
          'iterations': iterations,
          'salt': salt,
          'hash': hash,
        }
      });

      expect(AppLockService.verifyPin(pin: '1234', config: config), isTrue);
      expect(AppLockService.verifyPin(pin: '0000', config: config), isFalse);
    });

    test('OutcomeSubmission generates payload expected by mks_outcome', () {
      final submission = OutcomeSubmission(
        uid: 'call-101-1791897127494',
        outcome: 'interested',
        note: 'Customer wants quotation',
        followUpAt: 1791990000000,
        leadStatus: 2,
        createLead: {'name': 'Ravi Enterprises'},
      );

      final json = submission.toJson();
      expect(json['uid'], equals('call-101-1791897127494'));
      expect(json['outcome'], equals('interested'));
      expect(json['note'], equals('Customer wants quotation'));
      expect(json['follow_up_at'], equals(1791990000000));
      expect(json['lead_status'], equals(2));
      expect(json['create_lead'], equals({'name': 'Ravi Enterprises'}));
    });

    test('SalesTrackEvent supports recordingSyncStatus for audio uploads', () {
      final event = SalesTrackEvent(
        uid: 'call-rec-999',
        kind: 'call',
        time: 1791897127494,
        direction: 'outgoing',
        number: '+919988776655',
        name: 'VIP Client',
        duration: 180,
        recording: true,
        recordingPath: '/storage/emulated/0/Recordings/Call/test.m4a',
        syncStatus: 'synced',
        recordingSyncStatus: 'pending',
      );

      final storageJson = event.toStorageJson();
      expect(storageJson['recordingPath'], equals('/storage/emulated/0/Recordings/Call/test.m4a'));
      expect(storageJson['syncStatus'], equals('synced'));
      expect(storageJson['recordingSyncStatus'], equals('pending'));

      final restored = SalesTrackEvent.fromJson(storageJson);
      expect(restored.recordingSyncStatus, equals('pending'));
      expect(restored.syncStatus, equals('synced'));
      expect(restored.recordingPath, equals('/storage/emulated/0/Recordings/Call/test.m4a'));
    });

    test('WhatsApp Message and Notification serialization conforms to CRM backend schema', () {
      final waMsg = SalesTrackEvent(
        uid: 'wamsg-1791897127555',
        kind: 'whatsapp_message',
        time: 1791897127555,
        direction: 'incoming',
        number: '+919876543210',
        name: 'Client Rajesh',
        app: 'com.whatsapp',
        text: 'Hello, please send product catalog',
      );

      final waJson = waMsg.toApiJson();
      expect(waJson['kind'], equals('whatsapp_message'));
      expect(waJson['app'], equals('com.whatsapp'));
      expect(waJson['text'], equals('Hello, please send product catalog'));

      final notif = SalesTrackEvent(
        uid: 'notif-1791897127666',
        kind: 'notification',
        time: 1791897127666,
        direction: 'incoming',
        number: '198',
        name: 'Airtel Service',
        app: 'com.airtel.thanks',
        text: 'Your balance is low',
      );

      final notifJson = notif.toApiJson();
      expect(notifJson['kind'], equals('notification'));
      expect(notifJson['app'], equals('com.airtel.thanks'));
      expect(notifJson['text'], equals('Your balance is low'));
    });

    test('SalesTrackApiService uses configured make360 base URL and normalizes path correctly', () {
      expect(SalesTrackApiService.defaultServerUrl, equals('https://crm.make360.in/mks_sales_track/api/v1/'));
      final api = SalesTrackApiService();
      expect(api.apiBaseUrl, equals('https://crm.make360.in/mks_sales_track/api/v1'));
    });
  });
}
