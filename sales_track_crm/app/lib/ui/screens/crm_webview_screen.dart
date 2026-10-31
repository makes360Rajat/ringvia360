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
  bool _isAutoLoginWorking = false;

  @override
  void initState() {
    super.initState();
    _initWebviewSession();
  }

  /// Resolves the URL dynamically from the CRM server URL and route.
  /// If the target is already a complete URL returned by the CRM API, it is used directly.
  /// No domain or page is hardcoded.
  String _getDynamicUrl([String? target]) {
    if (target != null && (target.startsWith('http://') || target.startsWith('https://'))) {
      return target;
    }
    final base = widget.syncService.api.serverUrl.replaceAll(RegExp(r'/+$'), '');
    final path = (target ?? widget.initialPage ?? widget.syncService.config.crmStartPage ?? 'admin')
        .replaceAll(RegExp(r'^/+'), '');
    return '$base/$path';
  }

  Future<void> _initWebviewSession([String? targetPage]) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loadingProgress = 15;
    });

    final requestedPage = targetPage ?? widget.initialPage ?? widget.syncService.config.crmStartPage;
    debugPrint('[CRM WebView] Requesting webview session for dynamic route: $requestedPage');

    final res = await widget.syncService.api.openCrmSession(
      page: requestedPage,
    );

    if (!mounted) return;

    if (res.success && res.data != null && res.data!['url'] != null) {
      final sessionUrl = res.data!['url'].toString();
      final pageUrl = res.data?['page']?.toString();
      debugPrint('====================================================');
      debugPrint('[CRM WebView] DYNAMIC ONE-TIME SIGN-IN URL: $sessionUrl');
      if (pageUrl != null) {
        debugPrint('[CRM WebView] DYNAMIC START PAGE: $pageUrl');
      }
      debugPrint('====================================================');
      if (sessionUrl.isNotEmpty) {
        _isAutoLoginWorking = true;
        _setupWebViewController(sessionUrl);
        return;
      }
    }

    // If auto-login fails (e.g. webview_disabled in CRM settings, admin blocked, etc.)
    // DO NOT block the user or send to external browser!
    // Fall back to loading the dynamic CRM URL directly inside this in-app webview.
    _isAutoLoginWorking = false;
    final dynamicFallbackUrl = _getDynamicUrl(res.data?['page']?.toString() ?? targetPage);
    debugPrint('[CRM WebView] Fallback dynamic CRM URL from server: $dynamicFallbackUrl');
    _setupWebViewController(dynamicFallbackUrl);

    // If setting is disabled in CRM, inform the rep once via a subtle floating snackbar
    if (res.error == 'webview_disabled') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('CRM Auto-Sign-In is switched off in CRM settings. Browsing directly inside app.'),
              duration: Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    } else if (res.error == 'webview_admin_blocked') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Administrator account: browsing CRM directly inside app.'),
              duration: Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    }
  }

  void _setupWebViewController(String url) {
    debugPrint('[CRM WebView] Initializing WebViewController with dynamic URL: $url');
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
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

              // 2. If session expired & auto-login is active on server, try auto-login once
              if (destUrl.contains('/admin/authentication') && _isAutoLoginWorking) {
                _isAutoLoginWorking = false; // avoid loop
                _initWebviewSession();
                return NavigationDecision.prevent;
              }

              // 3. Keep all web browsing strictly inside the in-app webview
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(url));

      setState(() {
        _controller = controller;
        _currentUrl = url;
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

  void _loadCrmPage(String route) {
    final fullUrl = _getDynamicUrl(route);
    debugPrint('[CRM WebView] Navigating to dynamic route: $fullUrl');
    if (_controller != null) {
      _controller!.loadRequest(Uri.parse(fullUrl));
    } else {
      _setupWebViewController(fullUrl);
    }
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
                  _loadCrmPage('admin');
                } else if (val == 'leads') {
                  _loadCrmPage('admin/leads');
                } else if (val == 'calls') {
                  _loadCrmPage('admin/mks_sales_track/calls');
                } else if (val == 'whatsapp') {
                  _loadCrmPage('admin/mks_sales_track/whatsapp_messages');
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
                  color: colors.danger.withOpacity(0.12),
                ),
                child: Icon(
                  Icons.cloud_off_rounded,
                  color: colors.danger,
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Connection Error',
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
