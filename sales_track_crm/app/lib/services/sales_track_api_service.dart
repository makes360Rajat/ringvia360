import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sales_track_models.dart';

class SalesTrackApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final String? message;
  final int statusCode;

  SalesTrackApiResponse({
    required this.success,
    this.data,
    this.error,
    this.message,
    required this.statusCode,
  });
}

class SalesTrackApiService {
  static const String _prefServerUrl = 'mks_server_url';
  static const String _prefToken = 'mks_device_token';
  static const String _prefDeviceUid = 'mks_device_uid';
  static const String _prefCookies = 'mks_session_cookies';

  String _serverUrl = 'https://crm.make360.in';
  String? _token;
  String? _deviceUid;
  String? _sessionCookies;

  String get serverUrl => _serverUrl;
  String? get token => _token;
  String? get deviceUid => _deviceUid;
  bool get isPaired => _token != null && _token!.isNotEmpty;

  String get apiBaseUrl {
    var url = _serverUrl.trim();
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.endsWith('/mks_sales_track/api/v1')) {
      return url;
    }
    return '$url/mks_sales_track/api/v1';
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _serverUrl = prefs.getString(_prefServerUrl) ?? 'https://crm.make360.in';
    _token = prefs.getString(_prefToken);
    _deviceUid = prefs.getString(_prefDeviceUid);
    _sessionCookies = prefs.getString(_prefCookies);
  }

  Future<void> saveCredentials({required String serverUrl, required String token, required String deviceUid}) async {
    _serverUrl = serverUrl;
    _token = token;
    _deviceUid = deviceUid;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefServerUrl, serverUrl);
    await prefs.setString(_prefToken, token);
    await prefs.setString(_prefDeviceUid, deviceUid);
  }

  Future<void> clearCredentials() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefToken);
    await prefs.remove(_prefCookies);
  }

  Map<String, String> _buildHeaders({bool isMultipart = false}) {
    final headers = <String, String>{};
    if (!isMultipart) {
      headers['Content-Type'] = 'application/json; charset=UTF-8';
      headers['Accept'] = 'application/json';
    }
    if (_token != null && _token!.isNotEmpty) {
      headers['X-Sales-Track-Token'] = _token!;
      headers['Authorization'] = 'Bearer $_token';
    }
    if (_deviceUid != null && _deviceUid!.isNotEmpty) {
      headers['X-Sales-Track-Device'] = _deviceUid!;
    }
    if (_sessionCookies != null && _sessionCookies!.isNotEmpty) {
      headers['Cookie'] = _sessionCookies!;
    }
    return headers;
  }

  void _saveCookiesFromResponse(http.Response response) async {
    final rawCookie = response.headers['set-cookie'];
    if (rawCookie != null && rawCookie.isNotEmpty) {
      _sessionCookies = rawCookie;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefCookies, rawCookie);
    }
  }

  // 1. PING
  Future<SalesTrackApiResponse<Map<String, dynamic>>> ping(String targetUrl) async {
    try {
      var base = targetUrl.trim();
      if (base.endsWith('/')) base = base.substring(0, base.length - 1);
      final endpoint = base.endsWith('/mks_sales_track/api/v1') ? '$base/ping' : '$base/mks_sales_track/api/v1/ping';

      final response = await http.get(
        Uri.parse(endpoint),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      _saveCookiesFromResponse(response);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return SalesTrackApiResponse(
          success: body['success'] == true,
          data: body,
          statusCode: response.statusCode,
        );
      } else {
        return SalesTrackApiResponse(
          success: false,
          error: 'HTTP_${response.statusCode}',
          message: 'Server returned ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return SalesTrackApiResponse(
        success: false,
        error: 'CONNECTION_ERROR',
        message: e.toString(),
        statusCode: 0,
      );
    }
  }

  // 2. PAIR
  Future<SalesTrackApiResponse<Map<String, dynamic>>> pair({
    required String serverUrl,
    required String code,
    required Map<String, dynamic> deviceInfo,
  }) async {
    try {
      _serverUrl = serverUrl;
      final endpoint = '$apiBaseUrl/pair';
      final payload = {
        'code': code.trim(),
        'device': deviceInfo,
      };

      final response = await http.post(
        Uri.parse(endpoint),
        headers: _buildHeaders(),
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      _saveCookiesFromResponse(response);

      final Map<String, dynamic> body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final token = body['token']?.toString() ?? '';
        final uid = deviceInfo['uid']?.toString() ?? '';
        await saveCredentials(serverUrl: serverUrl, token: token, deviceUid: uid);
        return SalesTrackApiResponse(
          success: true,
          data: body,
          statusCode: response.statusCode,
        );
      } else {
        return SalesTrackApiResponse(
          success: false,
          error: body['error']?.toString() ?? 'PAIRING_FAILED',
          message: body['message']?.toString() ?? 'Pairing failed',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return SalesTrackApiResponse(
        success: false,
        error: 'CONNECTION_ERROR',
        message: e.toString(),
        statusCode: 0,
      );
    }
  }

  // 3. CONFIG / HEARTBEAT
  Future<SalesTrackApiResponse<Map<String, dynamic>>> sendHeartbeat({
    required Map<String, dynamic> health,
    List<Map<String, dynamic>>? acks,
    String? pushToken,
    List<Map<String, dynamic>>? tamperReports,
  }) async {
    if (!isPaired) {
      return SalesTrackApiResponse(success: false, error: 'NOT_PAIRED', statusCode: 401);
    }
    try {
      final endpoint = '$apiBaseUrl/config';
      final payload = <String, dynamic>{
        'health': health,
        'app_version': '1.0.0',
        'os_version': '14',
      };
      if (acks != null && acks.isNotEmpty) {
        payload['acks'] = acks;
      }
      if (pushToken != null) {
        payload['push_token'] = pushToken;
      }
      if (tamperReports != null && tamperReports.isNotEmpty) {
        payload['tamper'] = tamperReports;
      }

      final response = await http.post(
        Uri.parse(endpoint),
        headers: _buildHeaders(),
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      _saveCookiesFromResponse(response);

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        return SalesTrackApiResponse(
          success: body['success'] == true,
          data: body,
          statusCode: response.statusCode,
        );
      } else {
        final Map<String, dynamic> body = jsonDecode(response.body);
        return SalesTrackApiResponse(
          success: false,
          error: body['error']?.toString() ?? 'HEARTBEAT_FAILED',
          message: body['message']?.toString(),
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return SalesTrackApiResponse(
        success: false,
        error: 'CONNECTION_ERROR',
        message: e.toString(),
        statusCode: 0,
      );
    }
  }

  // 4. SYNC EVENTS BATCH
  Future<SalesTrackApiResponse<Map<String, dynamic>>> syncEvents(List<SalesTrackEvent> events) async {
    if (!isPaired || events.isEmpty) {
      return SalesTrackApiResponse(success: false, error: 'NOT_PAIRED_OR_EMPTY', statusCode: 400);
    }
    try {
      final endpoint = '$apiBaseUrl/sync';
      final payload = {
        'events': events.map((e) => e.toApiJson()).toList(),
      };

      final response = await http.post(
        Uri.parse(endpoint),
        headers: _buildHeaders(),
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 25));

      _saveCookiesFromResponse(response);

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        return SalesTrackApiResponse(
          success: body['success'] == true,
          data: body,
          statusCode: response.statusCode,
        );
      } else {
        final Map<String, dynamic> body = jsonDecode(response.body);
        return SalesTrackApiResponse(
          success: false,
          error: body['error']?.toString() ?? 'SYNC_FAILED',
          message: body['message']?.toString(),
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return SalesTrackApiResponse(
        success: false,
        error: 'CONNECTION_ERROR',
        message: e.toString(),
        statusCode: 0,
      );
    }
  }

  // 5. UPLOAD RECORDING
  Future<SalesTrackApiResponse<Map<String, dynamic>>> uploadRecording({
    required String uid,
    required String audioFilePath,
  }) async {
    if (!isPaired) {
      return SalesTrackApiResponse(success: false, error: 'NOT_PAIRED', statusCode: 401);
    }
    try {
      final file = File(audioFilePath);
      if (!await file.exists()) {
        return SalesTrackApiResponse(success: false, error: 'FILE_NOT_FOUND', statusCode: 404);
      }

      final endpoint = '$apiBaseUrl/recording';
      final request = http.MultipartRequest('POST', Uri.parse(endpoint));
      request.headers.addAll(_buildHeaders(isMultipart: true));
      request.fields['uid'] = uid;
      if (token != null && token!.isNotEmpty) {
        request.fields['token'] = token!;
      }
      request.files.add(await http.MultipartFile.fromPath('file', audioFilePath));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse);

      _saveCookiesFromResponse(response);

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        return SalesTrackApiResponse(
          success: body['success'] == true,
          data: body,
          statusCode: response.statusCode,
        );
      } else {
        final Map<String, dynamic> body = jsonDecode(response.body);
        return SalesTrackApiResponse(
          success: false,
          error: body['error']?.toString() ?? 'UPLOAD_FAILED',
          message: body['message']?.toString(),
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return SalesTrackApiResponse(
        success: false,
        error: 'CONNECTION_ERROR',
        message: e.toString(),
        statusCode: 0,
      );
    }
  }

  // 6. SUBMIT OUTCOMES
  Future<SalesTrackApiResponse<Map<String, dynamic>>> submitOutcomes(List<OutcomeSubmission> items) async {
    if (!isPaired || items.isEmpty) {
      return SalesTrackApiResponse(success: false, error: 'NOT_PAIRED_OR_EMPTY', statusCode: 400);
    }
    try {
      final endpoint = '$apiBaseUrl/outcome';
      final payload = {
        'items': items.map((i) => i.toJson()).toList(),
      };

      final response = await http.post(
        Uri.parse(endpoint),
        headers: _buildHeaders(),
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      _saveCookiesFromResponse(response);

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        return SalesTrackApiResponse(
          success: body['success'] == true,
          data: body,
          statusCode: response.statusCode,
        );
      } else {
        final Map<String, dynamic> body = jsonDecode(response.body);
        return SalesTrackApiResponse(
          success: false,
          error: body['error']?.toString() ?? 'OUTCOME_FAILED',
          message: body['message']?.toString(),
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return SalesTrackApiResponse(
        success: false,
        error: 'CONNECTION_ERROR',
        message: e.toString(),
        statusCode: 0,
      );
    }
  }

  // 7. FETCH CALL LISTS
  Future<SalesTrackApiResponse<List<CallListModel>>> fetchLists() async {
    if (!isPaired) {
      return SalesTrackApiResponse(success: false, error: 'NOT_PAIRED', statusCode: 401);
    }
    try {
      final endpoint = '$apiBaseUrl/lists';
      final response = await http.get(
        Uri.parse(endpoint),
        headers: _buildHeaders(),
      ).timeout(const Duration(seconds: 12));

      _saveCookiesFromResponse(response);

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        final rawLists = body['lists'] as List? ?? [];
        final lists = rawLists.map((l) => CallListModel.fromJson(l as Map<String, dynamic>)).toList();
        return SalesTrackApiResponse(success: true, data: lists, statusCode: response.statusCode);
      } else {
        return SalesTrackApiResponse(success: false, error: 'FETCH_LISTS_ERROR', statusCode: response.statusCode);
      }
    } catch (e) {
      return SalesTrackApiResponse(success: false, error: e.toString(), statusCode: 0);
    }
  }

  // 8. DIRECTORY LOOKUP
  Future<SalesTrackApiResponse<Map<String, dynamic>>> lookupNumber(String number) async {
    if (!isPaired) {
      return SalesTrackApiResponse(success: false, error: 'NOT_PAIRED', statusCode: 401);
    }
    try {
      final endpoint = '$apiBaseUrl/lookup?number=${Uri.encodeComponent(number)}';
      final response = await http.get(
        Uri.parse(endpoint),
        headers: _buildHeaders(),
      ).timeout(const Duration(seconds: 8));

      _saveCookiesFromResponse(response);

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        return SalesTrackApiResponse(success: true, data: body, statusCode: response.statusCode);
      } else {
        return SalesTrackApiResponse(success: false, error: 'LOOKUP_FAILED', statusCode: response.statusCode);
      }
    } catch (e) {
      return SalesTrackApiResponse(success: false, error: e.toString(), statusCode: 0);
    }
  }
}
