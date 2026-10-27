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
  static const String _prefApiPath = 'mks_api_path';
  static const String _prefToken = 'mks_device_token';
  static const String _prefDeviceUid = 'mks_device_uid';
  static const String _prefCookies = 'mks_session_cookies';

  /// The install-specific CRM host. Each customer enters this during pairing.
  static const String defaultServerUrl = 'https://crm.make360.in';
  /// The Sales Track module route. This is normally identical for every CRM,
  /// but is editable for installations that use a custom module route.
  static const String defaultApiPath = '/mks_sales_track/api/v1';

  String _serverUrl = defaultServerUrl;
  String _apiPath = defaultApiPath;
  String? _token;
  String? _deviceUid;
  String? _sessionCookies;

  String get serverUrl => _serverUrl;
  String get apiPath => _apiPath;
  String? get token => _token;
  String? get deviceUid => _deviceUid;
  bool get isPaired => _token != null && _token!.isNotEmpty;

  String get apiBaseUrl => '${normalizeServerUrl(_serverUrl)}${normalizeApiPath(_apiPath)}';

  /// The CRM's own address from whatever was typed, pasted or scanned:
  /// "crm.make360.in", "https://crm.make360.in/admin/mks_sales_track/devices"
  /// and "https://crm.make360.in/mks_sales_track/api/v1/" all become
  /// "https://crm.make360.in". A CRM in a folder or behind index.php keeps it.
  static String normalizeServerUrl(String input) {
    var url = input.trim().replaceAll(RegExp(r'\s+'), '');
    if (url.isEmpty) return url;
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(url)) {
      url = 'https://$url';
    }
    url = url.replaceFirst(RegExp(r'[?#].*$'), '');
    url = url.replaceFirst(RegExp(r'(/mks_sales_track/api/v1|/admin)(/.*)?$', caseSensitive: false), '');
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Makes an API route safe to append to a CRM host.
  static String normalizeApiPath(String input) {
    var path = input.trim().replaceAll(RegExp(r'\s+'), '');
    if (path.isEmpty) return defaultApiPath;
    final uri = Uri.tryParse(path);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      path = uri.path;
    }
    path = path.replaceFirst(RegExp(r'[?#].*$'), '');
    if (!path.startsWith('/')) path = '/$path';
    while (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return path.isEmpty || path == '/' ? defaultApiPath : path;
  }

  /// Splits a QR/API URL into the CRM host and its module route.
  static String serverUrlFromApiUrl(String input) {
    final normalized = input.trim().replaceAll(RegExp(r'\s+'), '');
    final candidate = RegExp(r'^https?://', caseSensitive: false).hasMatch(normalized)
        ? normalized
        : 'https://$normalized';
    final uri = Uri.tryParse(candidate);
    if (uri == null || uri.host.isEmpty) return normalizeServerUrl(input);
    const standardPath = '/mks_sales_track/api/v1';
    final index = uri.path.toLowerCase().indexOf(standardPath);
    final crmPrefix = index >= 0 ? uri.path.substring(0, index) : '';
    return normalizeServerUrl('${uri.scheme}://${uri.authority}$crmPrefix');
  }

  static String apiPathFromApiUrl(String input) {
    final normalized = input.trim().replaceAll(RegExp(r'\s+'), '');
    final candidate = RegExp(r'^https?://', caseSensitive: false).hasMatch(normalized)
        ? normalized
        : 'https://$normalized';
    final uri = Uri.tryParse(candidate);
    if (uri == null || uri.host.isEmpty) return defaultApiPath;
    const standardPath = '/mks_sales_track/api/v1';
    final index = uri.path.toLowerCase().indexOf(standardPath);
    return normalizeApiPath(index >= 0 ? uri.path.substring(index) : uri.path);
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
    final savedServerUrl = prefs.getString(_prefServerUrl) ?? defaultServerUrl;
    final savedApiPath = prefs.getString(_prefApiPath);
    // Upgrade existing devices that stored one combined API address.
    _serverUrl = serverUrlFromApiUrl(savedServerUrl);
    _apiPath = savedApiPath == null
        ? apiPathFromApiUrl(savedServerUrl)
        : normalizeApiPath(savedApiPath);
    _token = prefs.getString(_prefToken);
    _deviceUid = prefs.getString(_prefDeviceUid);
    _sessionCookies = prefs.getString(_prefCookies);
  }

  Future<void> saveCredentials({required String serverUrl, required String apiPath, required String token, required String deviceUid}) async {
    _serverUrl = normalizeServerUrl(serverUrl);
    _apiPath = normalizeApiPath(apiPath);
    _token = token;
    _deviceUid = deviceUid;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefServerUrl, _serverUrl);
    await prefs.setString(_prefApiPath, _apiPath);
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
  Future<SalesTrackApiResponse<Map<String, dynamic>>> ping(String serverUrl, {String apiPath = defaultApiPath}) async {
    try {
      final endpoint = '${normalizeServerUrl(serverUrl)}${normalizeApiPath(apiPath)}/ping';

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
    required String apiPath,
    required String code,
    required Map<String, dynamic> deviceInfo,
  }) async {
    try {
      _serverUrl = normalizeServerUrl(serverUrl);
      _apiPath = normalizeApiPath(apiPath);
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
        await saveCredentials(serverUrl: _serverUrl, apiPath: _apiPath, token: token, deviceUid: uid);
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
}
