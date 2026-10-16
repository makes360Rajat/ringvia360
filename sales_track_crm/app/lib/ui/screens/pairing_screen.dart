import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/sales_track_theme.dart';
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
  final TextEditingController _urlController = TextEditingController(text: 'https://crm.make360.in');
  final TextEditingController _codeController = TextEditingController();

  bool _isPinging = false;
  bool? _pingSuccess;
  String _pingMessage = '';
  bool _isPairing = false;
  String _errorMessage = '';

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
    final code = _codeController.text.trim();

    if (url.isEmpty || code.isEmpty) {
      setState(() => _errorMessage = 'Please enter both CRM Server URL and 6-digit code');
      return;
    }

    setState(() {
      _isPairing = true;
      _errorMessage = '';
    });

    final res = await widget.syncService.pairWithCode(serverUrl: url, code: code);

    if (mounted) {
      setState(() => _isPairing = false);
      if (res.success) {
        widget.onPaired();
      } else {
        setState(() => _errorMessage = res.message ?? 'Pairing failed. Please check the code.');
      }
    }
  }

  void _parseQrPayload(String text) {
    try {
      final json = jsonDecode(text.trim()) as Map<String, dynamic>;
      if (json['url'] != null) {
        _urlController.text = json['url'].toString();
      }
      if (json['code'] != null) {
        _codeController.text = json['code'].toString();
      }
      _pingServer();
    } catch (_) {
      _codeController.text = text.trim();
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
                        '6-Digit Pairing Code or QR Secret',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SalesTrackTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.characters,
                        textAlign: TextAlign.center,
                        enabled: !_isPairing,
                        style: const TextStyle(
                          fontSize: 22,
                          letterSpacing: 4,
                          fontWeight: FontWeight.bold,
                          color: SalesTrackTheme.primaryLight,
                        ),
                        decoration: InputDecoration(
                          hintText: '000000',
                          hintStyle: TextStyle(
                            fontSize: 22,
                            letterSpacing: 4,
                            color: SalesTrackTheme.textMuted.withOpacity(0.5),
                          ),
                          prefixIcon: const Icon(Icons.qr_code_rounded, color: SalesTrackTheme.textMuted),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.content_paste_rounded, color: SalesTrackTheme.textMuted),
                            tooltip: 'Paste Code / QR Payload',
                            onPressed: () async {
                              final clip = await Clipboard.getData('text/plain');
                              if (clip != null && clip.text != null) {
                                _parseQrPayload(clip.text!);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Obtain this code from your Perfex CRM under Sales Track > Devices > Add Device.',
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
