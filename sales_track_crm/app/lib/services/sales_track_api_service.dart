import 'dart:async';
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

  static const String defaultServerUrl = 'https://crm.make360.in';
  static const String currentAppVersion = '1.0.2';

  String _serverUrl = defaultServerUrl;
  String? _token;
  String? _deviceUid;
  String? _sessionCookies;

  String get serverUrl => _serverUrl;
  String? get token => _token;
  String? get deviceUid => _deviceUid;
  bool get isPaired => _token != null && _token!.isNotEmpty;

  String get apiBaseUrl {
    final effective = _serverUrl.isNotEmpty ? _serverUrl : defaultServerUrl;
    final normalized = normalizeServerUrl(effective);
    if (normalized.isEmpty || !normalized.startsWith('http')) {
      return 'https://crm.make360.in/mks_sales_track/api/v1';
    }
    return '$normalized/mks_sales_track/api/v1';
  }

  String get safeApiBaseUrl => apiBaseUrl;

  /// The CRM's own address from whatever was typed, pasted or scanned:
  /// e.g. "https://crm.yourcompany.com", "https://crm.yourcompany.com/admin/mks_sales_track/devices"
  /// and "https://crm.yourcompany.com/mks_sales_track/api/v1/" all become
  /// "https://crm.yourcompany.com". A CRM in a folder or behind index.php keeps it.
  static String normalizeServerUrl(String input) {
    var url = input.trim().replaceAll(RegExp(r'\s+'), '');
    if (url.isEmpty || url == 'https://' || url == 'http://') return '';
    // Fix accidental duplicate protocol prefixes e.g. https://https://
    url = url.replaceAll(RegExp(r'^(https?://)+', caseSensitive: false), 'https://');
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(url)) {
      if (url.startsWith('localhost') ||
          url.startsWith('10.') ||
          url.startsWith('192.168.') ||
          url.contains(':8080') ||
          url.contains(':3000') ||
          url.contains(':8000')) {
        url = 'http://$url';
      } else {
        url = 'https://$url';
      }
    }
    url = url.replaceFirst(RegExp(r'[?#].*$'), '');
    url = url.replaceFirst(RegExp(r'(/mks_sales_track/api/v1|/admin)(/.*)?$', caseSensitive: false), '');
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url == 'https:/' || url == 'https:' || url == 'http:/' || url == 'http:') {
      return '';
    }
    return url;
  }

  /// What a failed pairing means, in words a rep can act on.
  static String pairingMessage(int status, String? error, String? message) {
    switch (error) {
      case 'invalid_code':
        return 'That code is not right, or it was already used. Get a new code from the device in the CRM (Devices > the phone > New Code).';
      case 'code_expired':
        return 'That code has expired. Open the device in the CRM and get a new code.';
      case 'too_many_attempts':
        return 'Too many wrong codes. Wait a few minutes, then try again.';
      case 'api_disabled':
        return 'App connections are switched off in the CRM (Sales Track > Settings > Devices And App).';
      case 'module_disabled':
      case 'module_incomplete':
        return 'Sales Track is switched off or still updating in the CRM. Try again in a minute.';
      case 'invalid_device':
        return 'The CRM could not read this phone\'s details. Update the app and try again.';
    }
    if (message != null && message.isNotEmpty) return message;
    return 'Pairing failed (HTTP $status).';
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    var savedUrl = prefs.getString(_prefServerUrl);
    if (savedUrl == null || savedUrl.trim().isEmpty) {
      savedUrl = defaultServerUrl;
      await prefs.setString(_prefServerUrl, savedUrl);
    }
    _serverUrl = savedUrl;
    _token = prefs.getString(_prefToken);
    _deviceUid = prefs.getString(_prefDeviceUid);
    _sessionCookies = prefs.getString(_prefCookies);
  }

  Future<void> saveCredentials({required String serverUrl, required String token, required String deviceUid}) async {
    _serverUrl = serverUrl.isNotEmpty ? serverUrl : defaultServerUrl;
    _token = token;
    _deviceUid = deviceUid;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefServerUrl, _serverUrl);
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

  /// Told when the CRM no longer accepts this phone: revoked, deleted, or
  /// paired again on another phone. The sync service unpairs.
  void Function(String reason)? onPairingLost;

  /// Told when the CRM indicates that the app is out of date (mandatory or optional).
  void Function(AppUpdateInfo info, bool isMandatory)? onUpdateRequired;

  // The CRM's only answers that mean this phone is no longer paired: revoked,
  // deleted (its token is unknown) or paired again on another phone. A 403
  // (a feature switched off, an inactive staff account) or any other error
  // never unpairs the phone.
  static const Set<String> _pairingLostErrors = {'device_revoked', 'invalid_token', 'device_mismatch'};

  void _watchAuth(http.Response response) {
    if (response.statusCode != 401 || onPairingLost == null || _token == null || _token!.isEmpty) return;
    try {
      final body = jsonDecode(response.body);
      final err = body is Map ? body['error']?.toString() : null;
      if (err != null && _pairingLostErrors.contains(err)) {
        onPairingLost!(err);
      }
    } catch (_) {}
  }

  void _watchUpdate(http.Response response) {
    if (onUpdateRequired == null) return;
    if (response.statusCode == 426) {
      try {
        final body = jsonDecode(response.body);
        final info = body is Map<String, dynamic> ? AppUpdateInfo.fromJson(body) : const AppUpdateInfo();
        onUpdateRequired!(info, true);
      } catch (_) {
        onUpdateRequired!(const AppUpdateInfo(), true);
      }
    } else {
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['update_required'] == true) {
          final app = body['config'] is Map && body['config']['app'] is Map
              ? AppUpdateInfo.fromJson(body['config']['app'])
              : const AppUpdateInfo();
          onUpdateRequired!(app, true);
        }
      } catch (_) {}
    }
  }

  void _saveCookiesFromResponse(http.Response response) async {
    _watchAuth(response);
    _watchUpdate(response);
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
      final normalized = normalizeServerUrl(targetUrl);
      if (normalized.isEmpty) {
        return SalesTrackApiResponse(
          success: false,
          error: 'EMPTY_URL',
          message: 'Please enter a server URL',
          statusCode: 0,
        );
      }
      final endpoint = '$normalized/mks_sales_track/api/v1/ping';

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

  // 2. APP UPDATE (GET, no token): update dialog
  Future<SalesTrackApiResponse<AppUpdateInfo>> fetchAppUpdate({String? targetUrl}) async {
    try {
      final base = targetUrl != null ? normalizeServerUrl(targetUrl) : normalizeServerUrl(_serverUrl);
      if (base.isEmpty) {
        return SalesTrackApiResponse(
          success: false,
          error: 'EMPTY_URL',
          message: 'Please enter a server URL',
          statusCode: 0,
        );
      }
      final endpoint = '$base/mks_sales_track/api/v1/app_update';

      final response = await http.get(
        Uri.parse(endpoint),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      _saveCookiesFromResponse(response);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final updateInfo = AppUpdateInfo.fromJson(body);
        return SalesTrackApiResponse(
          success: body['success'] != false,
          data: updateInfo,
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

  // 3. PAIR
  Future<SalesTrackApiResponse<Map<String, dynamic>>> pair({
    required String serverUrl,
    required String code,
    required Map<String, dynamic> deviceInfo,
  }) async {
    try {
      _serverUrl = normalizeServerUrl(serverUrl);
      final cleanCode = code.replaceAll(RegExp(r'[\s-]+'), '');
      final endpoint = '$apiBaseUrl/pair';
      final payload = {
        'code': cleanCode,
        'device': deviceInfo,
      };

      // A fresh start: no token, device id or cookie from an earlier pairing.
      final response = await http.post(
        Uri.parse(endpoint),
        headers: const {'Content-Type': 'application/json; charset=UTF-8', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      // A redirect (http to https, another host) is not followed for a POST:
      // say where the CRM really is instead of failing on an HTML page.
      if (response.statusCode >= 300 && response.statusCode < 400) {
        final to = response.headers['location'] ?? '';
        return SalesTrackApiResponse(
          success: false,
          error: 'REDIRECTED',
          message: to.isNotEmpty ? 'The CRM moved to $to. Enter that address and try again.' : 'The CRM address redirects elsewhere. Check the address.',
          statusCode: response.statusCode,
        );
      }

      Map<String, dynamic> body;
      try {
        final decoded = jsonDecode(response.body);
        body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      } catch (_) {
        body = <String, dynamic>{};
      }

      if (body.isEmpty) {
        return SalesTrackApiResponse(
          success: false,
          error: 'NOT_SALES_TRACK',
          message: response.statusCode == 404
              ? 'Sales Track was not found at $_serverUrl. Check the CRM address, and that the module is active.'
              : 'The CRM answered with an error page (HTTP ${response.statusCode}). Check the address, or ask the CRM administrator.',
          statusCode: response.statusCode,
        );
      }

      _saveCookiesFromResponse(response);

      if (response.statusCode == 200 && body['success'] == true && (body['token']?.toString() ?? '').isNotEmpty) {
        final token = body['token'].toString();
        final uid = deviceInfo['uid']?.toString() ?? '';
        await saveCredentials(serverUrl: _serverUrl, token: token, deviceUid: uid);
        return SalesTrackApiResponse(
          success: true,
          data: body,
          statusCode: response.statusCode,
        );
      }

      return SalesTrackApiResponse(
        success: false,
        error: body['error']?.toString() ?? 'PAIRING_FAILED',
        message: pairingMessage(response.statusCode, body['error']?.toString(), body['message']?.toString()),
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      return SalesTrackApiResponse(
        success: false,
        error: 'TIMEOUT',
        message: 'The CRM did not answer in 30 seconds. Check the internet connection and try again.',
        statusCode: 0,
      );
    } catch (e) {
      final text = e.toString();
      return SalesTrackApiResponse(
        success: false,
        error: 'CONNECTION_ERROR',
        message: text.contains('SocketException') || text.contains('Failed host lookup')
            ? 'Cannot reach $_serverUrl. Check the address and the internet connection.'
            : (text.contains('HandshakeException') || text.contains('CERTIFICATE')
                ? 'The CRM\'s security certificate was refused. Use its https address exactly as in the browser.'
                : text),
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
    String? appVersion,
    String? osVersion,
    String? manufacturer,
    String? model,
    List<Map<String, dynamic>>? sims,
  }) async {
    if (!isPaired) {
      return SalesTrackApiResponse(success: false, error: 'NOT_PAIRED', statusCode: 401);
    }
    try {
      final endpoint = '$apiBaseUrl/config';
      final payload = <String, dynamic>{
        'health': health,
        'app_version': appVersion ?? currentAppVersion,
        'os_version': osVersion ?? '14',
      };
      if (_token != null && _token!.isNotEmpty) {
        payload['token'] = _token;
      }
      if (_deviceUid != null && _deviceUid!.isNotEmpty) {
        payload['device_uid'] = _deviceUid;
      }
      if (acks != null && acks.isNotEmpty) {
        payload['acks'] = acks;
      }
      if (pushToken != null) {
        payload['push_token'] = pushToken;
      }
      if (tamperReports != null && tamperReports.isNotEmpty) {
        payload['tamper'] = tamperReports;
      }
      if (manufacturer != null && manufacturer.isNotEmpty) {
        payload['manufacturer'] = manufacturer;
      }
      if (model != null && model.isNotEmpty) {
        payload['model'] = model;
      }
      if (sims != null && sims.isNotEmpty) {
        payload['sims'] = sims;
      }

      final response = await http.post(
        Uri.parse(endpoint),
        headers: _buildHeaders(),
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

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
  Future<SalesTrackApiResponse<Map<String, dynamic>>> syncEvents(
    List<SalesTrackEvent> events, {
    Map<String, dynamic>? health,
  }) async {
    if (!isPaired || events.isEmpty) {
      return SalesTrackApiResponse(success: false, error: 'NOT_PAIRED_OR_EMPTY', statusCode: 400);
    }
    try {
      final endpoint = '$apiBaseUrl/sync';
      final payload = <String, dynamic>{
        'events': events.map((e) => e.toApiJson()).toList(),
      };
      if (health != null && health.isNotEmpty) {
        payload['health'] = health;
      }
      if (_token != null && _token!.isNotEmpty) {
        payload['token'] = _token;
      }
      if (_deviceUid != null && _deviceUid!.isNotEmpty) {
        payload['device_uid'] = _deviceUid;
      }

      final response = await http.post(
        Uri.parse(endpoint),
        headers: _buildHeaders(),
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 60));

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
      final payload = <String, dynamic>{
        'items': items.map((i) => i.toJson()).toList(),
      };
      if (_token != null && _token!.isNotEmpty) {
        payload['token'] = _token;
      }
      if (_deviceUid != null && _deviceUid!.isNotEmpty) {
        payload['device_uid'] = _deviceUid;
      }

      final response = await http.post(
        Uri.parse(endpoint),
        headers: _buildHeaders(),
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 20));

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

  // 9. FETCH SERVER EVENTS
  Future<SalesTrackApiResponse<Map<String, dynamic>>> fetchEvents({
    String? kind,
    int limit = 100,
    int page = 1,
    String? since,
  }) async {
    if (!isPaired) {
      return SalesTrackApiResponse(success: false, error: 'NOT_PAIRED', statusCode: 401);
    }
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'page': page.toString(),
      };
      if (kind != null && kind.isNotEmpty) queryParams['kind'] = kind;
      if (since != null && since.isNotEmpty) queryParams['since'] = since;

      final uri = Uri.parse('$apiBaseUrl/events').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: _buildHeaders(),
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
        return SalesTrackApiResponse(
          success: false,
          error: 'FETCH_EVENTS_FAILED',
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

  // 10. OPEN CRM WEBVIEW SESSION
  /// Requests a one-time 60-second sign-in link to open the CRM portal directly inside the app.
  /// POST /webview
  /// Optional [page] parameter to open a specific CRM route (e.g. 'admin/leads', 'admin/mks_sales_track/whatsapp_messages')
  Future<SalesTrackApiResponse<Map<String, dynamic>>> openCrmSession({String? page}) async {
    if (!isPaired) {
      return SalesTrackApiResponse(
        success: false,
        error: 'device_revoked',
        message: 'Device is not paired with CRM.',
        statusCode: 401,
      );
    }
    try {
      final endpoint = '$apiBaseUrl/webview';
      final payload = <String, dynamic>{};
      if (page != null && page.trim().isNotEmpty) {
        payload['page'] = page.trim();
      }

      final response = await http.post(
        Uri.parse(endpoint),
        headers: _buildHeaders(),
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      _saveCookiesFromResponse(response);

      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      if (response.statusCode == 200 && body['success'] == true) {
        return SalesTrackApiResponse(
          success: true,
          data: body,
          statusCode: response.statusCode,
        );
      } else {
        return SalesTrackApiResponse(
          success: false,
          error: body['error']?.toString() ?? 'webview_failed',
          message: body['message']?.toString(),
          data: body,
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
}
