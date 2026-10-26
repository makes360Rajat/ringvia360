import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthPairingService extends ChangeNotifier {
  static const String _prefIsPaired = 'rv360_is_paired';
  static const String _prefToken = 'rv360_auth_token';
  static const String _prefOrgId = 'rv360_org_id';
  static const String _prefOrgName = 'rv360_org_name';
  static const String _prefRepId = 'rv360_rep_id';
  static const String _prefRepName = 'rv360_rep_name';
  static const String _prefRepEmail = 'rv360_rep_email';
  static const String _prefDeviceModel = 'rv360_device_model';
  static const String _prefPrivatizeMe = 'rv360_privatize_me_only';

  final String apiBaseUrl;

  bool _isInitialized = false;
  bool _isPaired = false;
  String? _token;
  String _orgId = 'org-tcs';
  String _orgName = 'Tata Consultancy Services';
  String _repId = 'rep-1';
  String _repName = 'Sneha Kapoor (RingVia360)';
  String _repEmail = 'sneha.kapoor@tcs.com';
  String _deviceModel = 'Android Knox Enterprise';
  bool _privatizeToMeOnly = false;

  AuthPairingService({this.apiBaseUrl = 'https://ringvia360.com/api/auth.php'}) {
    _loadFromPreferences();
  }

  bool get isInitialized => _isInitialized;
  bool get isPaired => _isPaired;
  String? get token => _token;
  String get orgId => _orgId;
  String get orgName => _orgName;
  String get repId => _repId;
  String get repName => _repName;
  String get repEmail => _repEmail;
  String get deviceModel => _deviceModel;
  bool get privatizeToMeOnly => _privatizeToMeOnly;

  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPaired = prefs.getBool(_prefIsPaired) ?? true; // Defaults to paired with demo org for instant preview
      _token = prefs.getString(_prefToken);
      _orgId = prefs.getString(_prefOrgId) ?? 'org-tcs';
      _orgName = prefs.getString(_prefOrgName) ?? 'Tata Consultancy Services';
      _repId = prefs.getString(_prefRepId) ?? 'rep-1';
      _repName = prefs.getString(_prefRepName) ?? 'Sneha Kapoor (RingVia360)';
      _repEmail = prefs.getString(_prefRepEmail) ?? 'sneha.kapoor@tcs.com';
      _deviceModel = prefs.getString(_prefDeviceModel) ?? 'Samsung Knox SM-S928B';
      _privatizeToMeOnly = prefs.getBool(_prefPrivatizeMe) ?? false;
    } catch (_) {}
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _saveToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefIsPaired, _isPaired);
      if (_token != null) await prefs.setString(_prefToken, _token!);
      await prefs.setString(_prefOrgId, _orgId);
      await prefs.setString(_prefOrgName, _orgName);
      await prefs.setString(_prefRepId, _repId);
      await prefs.setString(_prefRepName, _repName);
      await prefs.setString(_prefRepEmail, _repEmail);
      await prefs.setString(_prefDeviceModel, _deviceModel);
      await prefs.setBool(_prefPrivatizeMe, _privatizeToMeOnly);
    } catch (_) {}
  }

  Future<bool> pairWithCode(String code, {String? deviceModel, String? osVersion}) async {
    final cleanCode = code.replaceAll(' ', '').trim();
    if (cleanCode.length < 6) {
      throw 'Please enter a valid 6-digit pairing code';
    }

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl?action=pair_device'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'pair_device',
          'code': cleanCode,
          'deviceModel': deviceModel ?? _deviceModel,
          'osVersion': osVersion ?? 'Android 14 Knox 3.10',
          'batteryLevel': 92,
        }),
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        _isPaired = true;
        _token = data['token']?.toString();
        _orgId = data['orgId']?.toString() ?? 'org-tcs';
        _orgName = data['orgName']?.toString() ?? 'Enterprise Organization';
        _repId = data['repId']?.toString() ?? 'rep-1';
        _repName = data['repName']?.toString() ?? 'Field Sales Rep';
        if (deviceModel != null) _deviceModel = deviceModel;

        await _saveToPreferences();
        notifyListeners();
        return true;
      } else {
        throw data['error']?.toString() ?? 'Pairing failed. Please verify code.';
      }
    } catch (e) {
      if (e is String) rethrow;
      throw 'Connection error during pairing: $e';
    }
  }

  Future<bool> loginWithCredentials(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl?action=login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'login',
          'email': email.trim(),
          'password': password,
        }),
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        _isPaired = true;
        _token = data['token']?.toString();
        _orgId = data['user']?['org_id']?.toString() ?? 'org-tcs';
        _repId = data['user']?['id']?.toString() ?? 'rep-1';
        _repName = data['user']?['name']?.toString() ?? 'Sales Rep';
        _repEmail = data['user']?['email']?.toString() ?? email;

        if (data['org'] is Map && data['org']['name'] != null) {
          _orgName = data['org']['name'].toString();
        }

        await _saveToPreferences();
        notifyListeners();
        return true;
      } else {
        throw data['error']?.toString() ?? 'Invalid email or password';
      }
    } catch (e) {
      if (e is String) rethrow;
      throw 'Authentication error: $e';
    }
  }

  Future<void> setPrivatizeToMeOnly(bool val) async {
    _privatizeToMeOnly = val;
    await _saveToPreferences();
    notifyListeners();
  }

  Future<void> unpair() async {
    _isPaired = false;
    _token = null;
    await _saveToPreferences();
    notifyListeners();
  }
}
