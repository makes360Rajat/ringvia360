import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/sales_track_theme.dart';
import '../../models/sales_track_models.dart';
import '../../services/sales_track_api_service.dart';
import '../../services/telemetry_sync_service.dart';
import '../widgets/app_update_dialog.dart';

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
  late final TextEditingController _urlController;
  final TextEditingController _codeController = TextEditingController();

  bool _isPinging = false;
  bool? _pingSuccess;
  String _pingMessage = '';
  bool _isPairing = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    final currentUrl = widget.syncService.api.serverUrl;
    final initialUrl = (currentUrl.isNotEmpty && !currentUrl.contains('crm.make360.in'))
        ? SalesTrackApiService.normalizeServerUrl(currentUrl)
        : 'https://';

    _urlController = TextEditingController(text: initialUrl);
    _urlController.selection = TextSelection.fromPosition(
      TextPosition(offset: _urlController.text.length),
    );

    // Only test connection automatically if a valid custom CRM domain was already configured
    if (initialUrl.isNotEmpty && initialUrl != 'https://' && initialUrl != 'http://') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pingServer();
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _pingServer() async {
    final rawUrl = _urlController.text.trim();
    final url = SalesTrackApiService.normalizeServerUrl(rawUrl);
    if (url.isEmpty || url == 'https://' || url == 'http://') {
      setState(() {
        _isPinging = false;
        _pingSuccess = false;
        _pingMessage = 'Please enter your CRM server address';
        _errorMessage = '';
      });
      return;
    }

    setState(() {
      _isPinging = true;
      _pingSuccess = null;
      _pingMessage = 'Testing CRM server connection...';
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

      // Check for app update in the background after pinging
      widget.syncService.api.fetchAppUpdate(targetUrl: url).then((upRes) {
        if (!mounted) return;
        if (upRes.success && upRes.data != null && upRes.data!.isNotEmpty) {
          final info = upRes.data!;
          final current = SalesTrackApiService.currentAppVersion;
          final isBelowMin = info.minVersion.isNotEmpty &&
              compareAppVersions(current, info.minVersion) < 0;
          final isBelowLatest = info.latestVersion.isNotEmpty &&
              compareAppVersions(current, info.latestVersion) < 0;

          if (isBelowMin || isBelowLatest) {
            showDialog(
              context: context,
              barrierDismissible: !isBelowMin,
              builder: (dCtx) => AppUpdateDialog(
                updateInfo: info,
                isMandatory: isBelowMin,
                onUpdate: () => widget.syncService.launchAppUpdateUrl(info.urlAndroid),
                onDismiss: () => Navigator.of(dCtx).pop(),
              ),
            );
          }
        }
      });
    }
  }

  Future<void> _pairDevice() async {
    final rawUrl = _urlController.text.trim();
    final url = SalesTrackApiService.normalizeServerUrl(rawUrl);
    final rawCode = _codeController.text.trim();
    final code = rawCode.replaceAll(RegExp(r'[\s-]+'), '');

    if (url.isEmpty || url == 'https://' || url == 'http://') {
      setState(() => _errorMessage = 'Please enter your CRM server address');
      return;
    }

    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter the 6-digit pairing code');
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
          if (res.data?['update_required'] == true) {
            final app = res.data?['config'] is Map && res.data?['config']['app'] is Map
                ? AppUpdateInfo.fromJson(res.data!['config']['app'])
                : const AppUpdateInfo();
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (dCtx) => AppUpdateDialog(
                updateInfo: app,
                isMandatory: true,
                onUpdate: () => widget.syncService.launchAppUpdateUrl(app.urlAndroid),
              ),
            );
          } else {
            widget.onPaired();
          }
        } else {
          if (res.statusCode == 426) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (dCtx) => AppUpdateDialog(
                updateInfo: const AppUpdateInfo(),
                isMandatory: true,
                onUpdate: () => widget.syncService.launchAppUpdateUrl(),
              ),
            );
          } else {
            setState(() => _errorMessage = res.message ?? 'Pairing failed. Please verify the code.');
          }
        }
      }
    } catch (e) {
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
    final colors = context.stColors;
    final isDark = context.isDarkMode;
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Theme toggle top action
            Positioned(
              top: 12,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    color: colors.textPrimary,
                    size: 20,
                  ),
                  tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                  onPressed: () => themeProvider.toggleTheme(context),
                ),
              ),
            ),

            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),

                      // Logo & Branding Hero
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colors.primary,
                                colors.secondary,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withOpacity(0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.phonelink_ring_rounded,
                            size: 42,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Center(
                        child: Text(
                          'CallVia360',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      Center(
                        child: Text(
                          'Pair your device with CRM to automatically track calls, audio recordings, SMS, and WhatsApp activity in real time.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: colors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Status Badge Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: colors.warning.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.warning.withOpacity(0.35)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: colors.warning,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.warning.withOpacity(0.5),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Device Status: Unpaired',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: colors.warning,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    (widget.syncService.pairingLostMessage ?? '').isNotEmpty
                                        ? widget.syncService.pairingLostMessage!
                                        : 'Connect this phone to begin tracking sales telemetry.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Main Pairing Card Container
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: colors.cardBackground,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: colors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Server URL field
                            Text(
                              'CRM SERVER ADDRESS',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: colors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _urlController,
                              keyboardType: TextInputType.url,
                              style: TextStyle(
                                fontSize: 14,
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                              onChanged: (val) {
                                if (_pingMessage.isNotEmpty || _pingSuccess != null) {
                                  setState(() {
                                    _pingMessage = '';
                                    _pingSuccess = null;
                                  });
                                } else {
                                  setState(() {});
                                }
                              },
                              decoration: InputDecoration(
                                hintText: 'https://yourcrm.com',
                                prefixIcon: Icon(Icons.dns_rounded, color: colors.textMuted, size: 20),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_urlController.text.isNotEmpty && _urlController.text != 'https://')
                                      IconButton(
                                        icon: Icon(Icons.backspace_outlined, color: colors.textMuted, size: 18),
                                        tooltip: 'Reset to https://',
                                        onPressed: () {
                                          setState(() {
                                            _urlController.text = 'https://';
                                            _urlController.selection = TextSelection.fromPosition(
                                              const TextPosition(offset: 8),
                                            );
                                            _pingMessage = '';
                                            _pingSuccess = null;
                                          });
                                        },
                                      ),
                                    IconButton(
                                      icon: _isPinging
                                          ? SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                                              ),
                                            )
                                          : Icon(Icons.sync_rounded, color: colors.primary, size: 20),
                                      tooltip: 'Test Server Connection',
                                      onPressed: _pingServer,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_pingMessage.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    _pingSuccess == true ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                                    size: 15,
                                    color: _pingSuccess == true ? colors.success : colors.warning,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _pingMessage,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: _pingSuccess == true ? colors.success : colors.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 20),

                            // Pairing Code
                            Text(
                              '6-DIGIT PAIRING CODE',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: colors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _codeController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              textAlign: TextAlign.center,
                              enabled: !_isPairing,
                              style: TextStyle(
                                fontSize: 28,
                                letterSpacing: 10,
                                fontWeight: FontWeight.bold,
                                color: colors.primary,
                              ),
                              decoration: InputDecoration(
                                hintText: '000000',
                                hintStyle: TextStyle(
                                  fontSize: 28,
                                  letterSpacing: 10,
                                  color: colors.textMuted.withOpacity(0.4),
                                ),
                                prefixIcon: Icon(Icons.pin_rounded, color: colors.textMuted, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.content_paste_rounded, color: colors.textMuted, size: 20),
                                  tooltip: 'Paste Code from Clipboard',
                                  onPressed: () async {
                                    final clip = await Clipboard.getData('text/plain');
                                    if (clip != null && clip.text != null) {
                                      final text = clip.text!.trim();
                                      if (text.startsWith('{')) {
                                        _parseQrPayload(text);
                                      } else {
                                        final digits = text.replaceAll(RegExp(r'\D'), '');
                                        _codeController.text =
                                            digits.length > 6 ? digits.substring(0, 6) : digits;
                                      }
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'In your Perfex CRM, go to Sales Track > Devices > Add Device to generate this code.',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textMuted,
                                height: 1.4,
                              ),
                            ),

                            if (_errorMessage.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colors.danger.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: colors.danger.withOpacity(0.35)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline_rounded, color: colors.danger, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _errorMessage,
                                        style: TextStyle(
                                          color: colors.danger,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isPairing ? null : _pairDevice,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isPairing
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.link_rounded, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            'Pair & Connect Device',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Quick Step Guide
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.help_outline_rounded, size: 16, color: colors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'Quick Pairing Instructions',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildInstructionStep(
                              colors: colors,
                              stepNumber: '1',
                              text: 'Open Perfex CRM on your computer and navigate to Sales Track.',
                            ),
                            const SizedBox(height: 6),
                            _buildInstructionStep(
                              colors: colors,
                              stepNumber: '2',
                              text: 'Go to Devices tab and click "Add Device" to select representative.',
                            ),
                            const SizedBox(height: 6),
                            _buildInstructionStep(
                              colors: colors,
                              stepNumber: '3',
                              text: 'Enter the 6-digit code or paste it above to link this phone instantly.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep({
    required SalesTrackColors colors,
    required String stepNumber,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: colors.primary.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            stepNumber,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: colors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
