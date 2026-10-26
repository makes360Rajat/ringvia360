import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/sales_track_theme.dart';
import '../../services/sales_track_api_service.dart';
import '../../services/telemetry_sync_service.dart';

class PairingScreen extends StatefulWidget {
  final TelemetrySyncService syncService;
  final VoidCallback onPaired;

  const PairingScreen({
    super.key,
    required this.syncService,
    required this.onPaired,
  });

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final TextEditingController _urlController = TextEditingController(text: 'https://crm.make360.in/mks_sales_track/api/v1/');
  final TextEditingController _codeController = TextEditingController();

  bool _isPinging = false;
  bool? _pingSuccess;
  String _pingMessage = '';
  bool _isPairing = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Arriving here because the CRM revoked or deleted this phone: say so.
    final currentUrl = widget.syncService.api.serverUrl;
    if (currentUrl.isNotEmpty) {
      _urlController.text = SalesTrackApiService.normalizeServerUrl(currentUrl);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pingServer();
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _pingServer() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isPinging = true;
      _pingSuccess = null;
      _pingMessage = 'Pinging CRM server...';
      _errorMessage = '';
    });

    final res = await widget.syncService.api.ping(url);
    if (mounted) {
      setState(() {
        _isPinging = false;
        _pingSuccess = res.success;
        if (res.success && res.data != null) {
          final modVer = res.data!['module_version']?.toString() ?? '1.0.0';
          _pingMessage = 'Connected to Sales Track v$modVer';
        } else {
          _pingMessage = 'Server unreachable: ${res.message ?? res.error}';
        }
      });
    }
  }

  Future<void> _pairDevice() async {
    final url = _urlController.text.trim();
    final rawCode = _codeController.text.trim();
    final code = rawCode.replaceAll(RegExp(r'[\s-]+'), '');

    if (url.isEmpty || code.isEmpty) {
      setState(() => _errorMessage = 'Please enter both CRM Server URL and pairing code');
      return;
    }

    if (code.length < 6) {
      setState(() => _errorMessage = 'The pairing code must be 6 digits. Check the code in your CRM.');
      return;
    }

    setState(() {
      _isPairing = true;
      _errorMessage = '';
    });

    try {
      final res = await widget.syncService.pairWithCode(serverUrl: url, code: code);

      if (mounted) {
        setState(() => _isPairing = false);
        if (res.success) {
          widget.onPaired();
        } else {
          setState(() => _errorMessage = res.message ?? 'Pairing failed. Please check the code.');
        }
      }
    } catch (e) {
      // Whatever happens, the button comes back and says why.
      if (mounted) {
        setState(() {
          _isPairing = false;
          _errorMessage = 'Pairing could not finish: $e';
        });
      }
    }
  }

  void _parseQrPayload(String text) {
    try {
      final json = jsonDecode(text.trim()) as Map<String, dynamic>;
      // The CRM's QR carries the exact API address ("api"); it is right even
      // for a CRM in a folder or behind index.php, so it wins over "url".
      if (json['api'] != null && json['api'].toString().isNotEmpty) {
        _urlController.text = json['api'].toString();
      } else if (json['url'] != null) {
        _urlController.text = json['url'].toString();
      }
      if (json['code'] != null) {
        _codeController.text = json['code'].toString().replaceAll(RegExp(r'[\s-]+'), '');
      }
      _pingServer();
    } catch (_) {
      _codeController.text = text.trim().replaceAll(RegExp(r'[\s-]+'), '');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo & Header
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          SalesTrackTheme.primaryDark.withOpacity(0.8),
                          SalesTrackTheme.primaryLight,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: SalesTrackTheme.primary.withOpacity(0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.phonelink_ring_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Sales Track CRM',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: SalesTrackTheme.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Pair your mobile device with the Perfex CRM to automatically sense calls, recordings, SMS, and WhatsApp activity.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: SalesTrackTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Where this phone stands: unpaired, and why when the CRM removed it.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.45)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Status: Inactive (Unpaired)',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (widget.syncService.pairingLostMessage ?? '').isNotEmpty
                                  ? widget.syncService.pairingLostMessage!
                                  : 'This device is not paired with the CRM yet.',
                              style: const TextStyle(fontSize: 13, color: SalesTrackTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Card Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: SalesTrackTheme.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: SalesTrackTheme.surfaceColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Server URL field
                      const Text(
                        'CRM Server Address',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SalesTrackTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _urlController,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          hintText: 'https://crm.yourcompany.com',
                          prefixIcon: const Icon(Icons.dns_rounded, color: SalesTrackTheme.textMuted),
                          suffixIcon: IconButton(
                            icon: _isPinging
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.sync_rounded, color: SalesTrackTheme.primaryLight),
                            tooltip: 'Test Connection',
                            onPressed: _pingServer,
                          ),
                        ),
                      ),
                      if (_pingMessage.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              _pingSuccess == true ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                              size: 15,
                              color: _pingSuccess == true ? SalesTrackTheme.success : SalesTrackTheme.warning,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _pingMessage,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _pingSuccess == true ? SalesTrackTheme.success : SalesTrackTheme.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),

                      // Pairing Code
                      const Text(
                        '6-Digit Pairing Code',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SalesTrackTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _codeController,
                        // Digits only, six at most: the code from the CRM.
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        textAlign: TextAlign.center,
                        enabled: !_isPairing,
                        style: const TextStyle(
                          fontSize: 26,
                          letterSpacing: 10,
                          fontWeight: FontWeight.bold,
                          color: SalesTrackTheme.primaryLight,
                        ),
                        decoration: InputDecoration(
                          hintText: '000000',
                          hintStyle: TextStyle(
                            fontSize: 26,
                            letterSpacing: 10,
                            color: SalesTrackTheme.textMuted.withOpacity(0.5),
                          ),
                          prefixIcon: const Icon(Icons.pin_rounded, color: SalesTrackTheme.textMuted),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.content_paste_rounded, color: SalesTrackTheme.textMuted),
                            tooltip: 'Paste Code',
                            onPressed: () async {
                              final clip = await Clipboard.getData('text/plain');
                              if (clip != null && clip.text != null) {
                                final text = clip.text!.trim();
                                if (text.startsWith('{')) {
                                  _parseQrPayload(text);
                                } else {
                                  final digits = text.replaceAll(RegExp(r'\D'), '');
                                  _codeController.text = digits.length > 6 ? digits.substring(0, 6) : digits;
                                }
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter the 6-digit code from CRM under Sales Track > Devices > Add Device.',
                        style: TextStyle(fontSize: 12, color: SalesTrackTheme.textMuted),
                      ),

                      if (_errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: SalesTrackTheme.danger.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: SalesTrackTheme.danger.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: SalesTrackTheme.danger, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage,
                                  style: const TextStyle(color: SalesTrackTheme.danger, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isPairing ? null : _pairDevice,
                          child: _isPairing
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.link_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text('Pair & Connect Phone', style: TextStyle(fontSize: 16)),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
