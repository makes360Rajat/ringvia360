import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/sales_track_theme.dart';
import '../../services/telemetry_sync_service.dart';

class CrmWebviewScreen extends StatefulWidget {
  final TelemetrySyncService syncService;
  final bool isTabMode;
  final VoidCallback? onBackToSales;
  final String? initialPage;

  const CrmWebviewScreen({
    super.key,
    required this.syncService,
    this.isTabMode = false,
    this.onBackToSales,
    this.initialPage,
  });

  @override
  State<CrmWebviewScreen> createState() => _CrmWebviewScreenState();
}

class _CrmWebviewScreenState extends State<CrmWebviewScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  int _loadingProgress = 0;
  String? _errorMessage;
  String _currentUrl = '';
  String _pageTitle = 'CRM Portal';
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _isRequestingSession = false;

  String? _errorType;

  @override
  void initState() {
    super.initState();
    _initWebviewSession();
  }

  /// Resolves the URL safely.
  /// If [input] already starts with http:// or https:// (e.g. from CRM settings or API response),
  /// it is returned verbatim and NEVER prefixed with the CRM server URL.
  String _resolveFullUrl(String? input) {
    if (input == null || input.trim().isEmpty) {
      final base = widget.syncService.api.serverUrl.replaceAll(RegExp(r'/+$'), '');
      return '$base/admin';
    }
    final trimmed = input.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final base = widget.syncService.api.serverUrl.replaceAll(RegExp(r'/+$'), '');
    final cleanPath = trimmed.replaceAll(RegExp(r'^/+'), '');
    return '$base/$cleanPath';
  }

  Future<void> _initWebviewSession([String? targetPage]) async {
    if (!mounted || _isRequestingSession) return;
    _isRequestingSession = true;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _errorType = null;
      _loadingProgress = 15;
    });

    try {
      // Do not pass /admin/authentication as requested page: let CRM open its configured start page!
      String? requestedPage = targetPage ?? widget.initialPage;
      if (requestedPage != null) {
        final clean = requestedPage.trim();
        if (clean.isEmpty || clean.contains('admin/authentication')) {
          requestedPage = null;
        }
      }

      debugPrint('=====================================================================');
      debugPrint('[CRM WebView] Requesting webview session for dynamic route: $requestedPage');
      debugPrint('=====================================================================');

      final res = await widget.syncService.api.openCrmSession(
        page: requestedPage,
      );

      if (!mounted) return;

      // 1. Extract the authentic URL directly from the CRM API response
      String? completeUrlFromCrm;
      if (res.data != null) {
        final rawUrl = res.data!['url']?.toString().trim();
        if (rawUrl != null && rawUrl.isNotEmpty) {
          completeUrlFromCrm = _resolveFullUrl(rawUrl);
        } else {
          final rawPage = res.data!['page']?.toString().trim();
          if (rawPage != null && rawPage.isNotEmpty) {
            completeUrlFromCrm = _resolveFullUrl(rawPage);
          }
        }
      }

      if (completeUrlFromCrm != null && completeUrlFromCrm.isNotEmpty) {
        debugPrint('=====================================================================');
        debugPrint('[CRM WebView] >>> OPENING AUTHENTIC CRM URL (FROM CRM API):');
        debugPrint('>>> URL: $completeUrlFromCrm');
        debugPrint('=====================================================================');
        _setupWebViewController(completeUrlFromCrm);
        return;
      }

      // 2. If the CRM API returned 'webview_admin_blocked' or 'webview_disabled':
      // Directly open the CRM web portal in this in-app webview so the user is never blocked!
      if (res.error == 'webview_admin_blocked' || res.error == 'webview_disabled') {
        final rawTarget = res.data?['page']?.toString() ??
            targetPage ??
            widget.initialPage ??
            widget.syncService.config.crmStartPage;

        final directCrmUrl = _resolveFullUrl(rawTarget);

        debugPrint('=====================================================================');
        debugPrint('[CRM WebView] >>> ${res.error}: DIRECTLY OPENING CRM IN APP WEBVIEW:');
        debugPrint('>>> URL: $directCrmUrl');
        debugPrint('=====================================================================');

        _setupWebViewController(directCrmUrl);

        if (res.error == 'webview_admin_blocked') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Admin Account: Opened CRM in app. (To enable 1-click token login, turn on "Also for Administrators" in CRM Settings).'),
                  duration: Duration(seconds: 5),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          });
        }
        return;
      }

      // 3. For true connection or revoked errors: report error state
      debugPrint('=====================================================================');
      debugPrint('[CRM WebView] >>> CRM API DID NOT RETURN A WEBVIEW URL:');
      debugPrint('>>> ERROR   : ${res.error}');
      debugPrint('>>> MESSAGE : ${res.message}');
      debugPrint('>>> STATUS  : ${res.statusCode}');
      debugPrint('=====================================================================');

      setState(() {
        _isLoading = false;
        _errorType = res.error;
        _errorMessage = res.message ?? _buildUserFriendlyErrorMessage(res.error);
      });
    } finally {
      _isRequestingSession = false;
    }
  }

  String _buildUserFriendlyErrorMessage(String? error) {
    switch (error) {
      case 'webview_disabled':
        return 'Opening the CRM in the app is switched off in CRM settings.\n\nAsk your CRM Administrator to turn on "Open CRM in the App" under CallVia360 > Settings > Devices And App.';
      case 'webview_admin_blocked':
        return 'Administrator accounts open the CRM in a browser.\n\nAsk your CRM Administrator to enable "Also for Administrators" in CRM settings.';
      case 'staff_inactive':
        return 'Your CRM staff account is inactive. Please contact your CRM Administrator.';
      case 'device_revoked':
      case 'invalid_token':
        return 'Device pairing was lost or revoked. Please pair the phone again.';
      case 'update_required':
        return 'An app update is required by the CRM server.';
      default:
        return 'CRM server did not return a webview URL. Please check server settings and retry.';
    }
  }

  void _setupWebViewController(String url) {
    final cleanUrl = url.trim();
    debugPrint('[CRM WebView] >>> OPENING EXACT CRM URL IN WEBVIEW: $cleanUrl');

    if (_controller != null) {
      try {
        _controller!.loadRequest(Uri.parse(cleanUrl));
        setState(() {
          _currentUrl = cleanUrl;
          _isLoading = true;
          _errorMessage = null;
        });
        return;
      } catch (e) {
        debugPrint('[CRM WebView] Error reloading webview with existing controller: $e');
      }
    }

    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent('Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36')
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (progress) {
              if (mounted) {
                setState(() {
                  _loadingProgress = progress;
                  if (progress >= 100) {
                    _isLoading = false;
                  }
                });
                _updateNavigationState();
              }
            },
            onPageStarted: (pageUrl) {
              debugPrint('[CRM WebView] Page started: $pageUrl');
              if (mounted) {
                setState(() {
                  _isLoading = true;
                  _currentUrl = pageUrl;
                });
                _updateNavigationState();
              }
            },
            onPageFinished: (pageUrl) {
              debugPrint('[CRM WebView] Page finished loading: $pageUrl');
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _currentUrl = pageUrl;
                });
                _updateNavigationState();
              }
            },
            onWebResourceError: (error) {
              // Ignore benign subresource cancellations
              if (error.errorCode == -999 || error.description.contains('net::ERR_ABORTED')) {
                return;
              }
              debugPrint('[CRM WebView] WebResourceError: ${error.errorCode} - ${error.description}');
              if (mounted && _controller != null) {
                setState(() {
                  _isLoading = false;
                  if (_currentUrl.isEmpty) {
                    _errorMessage = 'Could not load CRM page: ${error.description}';
                  }
                });
              }
            },
            onNavigationRequest: (NavigationRequest request) {
              final destUrl = request.url;
              debugPrint('[CRM WebView] Navigation request: $destUrl');

              // 1. Non-web intents (tel:, mailto:, whatsapp:, intent:, geo:) -> open in native apps
              if (!destUrl.startsWith('http://') && !destUrl.startsWith('https://')) {
                widget.syncService.launchAppUpdateUrl(destUrl);
                return NavigationDecision.prevent;
              }

              // 2. Keep all web browsing strictly inside the in-app webview without blocking
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(cleanUrl));

      setState(() {
        _controller = controller;
        _currentUrl = cleanUrl;
      });
    } catch (e) {
      debugPrint('[CRM WebView] Error initializing webview: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not initialize in-app webview: $e';
      });
    }
  }

  Future<void> _updateNavigationState() async {
    if (_controller == null) return;
    try {
      final canBack = await _controller!.canGoBack();
      final canForward = await _controller!.canGoForward();
      final title = await _controller!.getTitle();
      if (mounted) {
        setState(() {
          _canGoBack = canBack;
          _canGoForward = canForward;
          if (title != null && title.isNotEmpty && !title.startsWith('http')) {
            _pageTitle = title;
          }
        });
      }
    } catch (_) {}
  }

  Future<bool> handleWillPop() async {
    if (_controller != null && await _controller!.canGoBack()) {
      await _controller!.goBack();
      return false;
    }
    if (widget.onBackToSales != null) {
      widget.onBackToSales!();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.stColors;

    return PopScope(
      canPop: !_canGoBack && widget.onBackToSales == null,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          handleWillPop();
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.cardBackground,
          elevation: 0,
          leading: widget.isTabMode
              ? IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
                  tooltip: 'Back to Sales Tracker',
                  onPressed: () {
                    if (widget.onBackToSales != null) {
                      widget.onBackToSales!();
                    }
                  },
                )
              : null,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _pageTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                widget.syncService.staff?.name != null
                    ? 'Signed in as ${widget.syncService.staff!.name}'
                    : 'Perfex CRM Portal',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            // History Back inside webview
            IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: _canGoBack ? colors.textPrimary : colors.textMuted.withOpacity(0.4),
              ),
              tooltip: 'Go Back',
              onPressed: _canGoBack ? () => _controller?.goBack() : null,
            ),

            // History Forward inside webview
            IconButton(
              icon: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: _canGoForward ? colors.textPrimary : colors.textMuted.withOpacity(0.4),
              ),
              tooltip: 'Go Forward',
              onPressed: _canGoForward ? () => _controller?.goForward() : null,
            ),

            // Refresh / Reload current page
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: colors.textPrimary, size: 22),
              tooltip: 'Refresh Page',
              onPressed: () {
                if (_controller != null) {
                  _controller!.reload();
                } else {
                  _initWebviewSession();
                }
              },
            ),

            // Quick Navigation Menu inside In-App Webview
            PopupMenuButton<String>(
              color: colors.cardBackground,
              icon: Icon(Icons.more_vert_rounded, color: colors.textPrimary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: colors.border),
              ),
              onSelected: (val) {
                if (val == 'dashboard') {
                  _initWebviewSession('admin');
                } else if (val == 'leads') {
                  _initWebviewSession('admin/leads');
                } else if (val == 'calls') {
                  _initWebviewSession('admin/mks_sales_track/calls');
                } else if (val == 'whatsapp') {
                  _initWebviewSession('admin/mks_sales_track/whatsapp_messages');
                } else if (val == 'retry_auto_login') {
                  _initWebviewSession();
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'dashboard',
                  child: Row(
                    children: [
                      Icon(Icons.dashboard_rounded, color: colors.primary, size: 20),
                      const SizedBox(width: 10),
                      Text('CRM Dashboard', style: TextStyle(color: colors.textPrimary)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'leads',
                  child: Row(
                    children: [
                      Icon(Icons.people_rounded, color: colors.primary, size: 20),
                      const SizedBox(width: 10),
                      Text('Leads', style: TextStyle(color: colors.textPrimary)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'calls',
                  child: Row(
                    children: [
                      Icon(Icons.call_rounded, color: colors.primary, size: 20),
                      const SizedBox(width: 10),
                      Text('Call Via 360 Calls', style: TextStyle(color: colors.textPrimary)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'whatsapp',
                  child: Row(
                    children: [
                      Icon(Icons.chat_rounded, color: colors.primary, size: 20),
                      const SizedBox(width: 10),
                      Text('WhatsApp Messages', style: TextStyle(color: colors.textPrimary)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'retry_auto_login',
                  child: Row(
                    children: [
                      Icon(Icons.vpn_key_rounded, color: colors.primary, size: 20),
                      const SizedBox(width: 10),
                      Text('Auto Sign-in Link', style: TextStyle(color: colors.textPrimary)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          bottom: true,
          child: Column(
            children: [
              // Loading Progress Bar
              if (_isLoading)
                LinearProgressIndicator(
                  value: _loadingProgress > 0 ? _loadingProgress / 100.0 : null,
                  backgroundColor: colors.surfaceColor,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  minHeight: 3,
                ),

              // Main Web Content or Connection Error
              Expanded(
                child: _errorMessage != null
                    ? _buildErrorView(colors)
                    : (_controller != null
                        ? WebViewWidget(controller: _controller!)
                        : _buildLoadingPlaceholder(colors)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder(SalesTrackColors colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Opening CRM Portal in App...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Loading webview interface',
            style: TextStyle(
              fontSize: 12,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(SalesTrackColors colors) {
    final isDisabled = _errorType == 'webview_disabled';
    final isAdminBlocked = _errorType == 'webview_admin_blocked';

    final Color statusColor = (isDisabled || isAdminBlocked) ? colors.warning : colors.danger;
    final IconData statusIcon = isDisabled
        ? Icons.lock_outline_rounded
        : (isAdminBlocked ? Icons.admin_panel_settings_rounded : Icons.cloud_off_rounded);
    final String statusTitle = isDisabled
        ? 'CRM In-App Portal Disabled'
        : (isAdminBlocked ? 'CRM Administrator Account' : 'Connection Error');

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withOpacity(0.12),
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                statusTitle,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Unable to connect to CRM. Check your internet connection.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Try Again'),
                    onPressed: () {
                      setState(() => _errorMessage = null);
                      _initWebviewSession();
                    },
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.web_rounded, size: 18),
                    label: const Text('Open In-App Webview'),
                    onPressed: () {
                      final rawTarget = widget.syncService.config.crmStartPage;
                      _setupWebViewController(_resolveFullUrl(rawTarget));
                    },
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Sales Tracker'),
                    onPressed: () {
                      if (widget.onBackToSales != null) {
                        widget.onBackToSales!();
                      } else if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
