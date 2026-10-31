import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/sales_track_theme.dart';
import '../../services/sales_track_api_service.dart';
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
  String? _errorType;
  String _currentUrl = '';
  String _pageTitle = 'CRM Portal';
  bool _canGoBack = false;
  bool _canGoForward = false;

  @override
  void initState() {
    super.initState();
    _initWebviewSession();
  }

  Future<void> _initWebviewSession([String? targetPage]) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _errorType = null;
      _loadingProgress = 10;
    });

    final res = await widget.syncService.api.openCrmSession(
      page: targetPage ?? widget.initialPage,
    );

    if (!mounted) return;

    if (!res.success) {
      _handleSessionError(res);
      return;
    }

    final sessionUrl = res.data?['url']?.toString() ?? '';
    if (sessionUrl.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid CRM sign-in link received. Please try again.';
      });
      return;
    }

    _setupWebViewController(sessionUrl);
  }

  void _handleSessionError(SalesTrackApiResponse<Map<String, dynamic>> res) {
    setState(() {
      _isLoading = false;
      _errorType = res.error;
    });

    switch (res.error) {
      case 'webview_disabled':
        _errorMessage =
            'Opening the CRM in the app is switched off.\n\nAsk your CRM Administrator to enable "Open CRM in the App" under Settings > Devices And App.';
        break;
      case 'webview_admin_blocked':
        _errorMessage =
            'Administrator accounts open the CRM in a browser.\n\nYour CRM account has administrator privileges. You can open the CRM directly in your web browser.';
        break;
      case 'staff_inactive':
        _errorMessage = 'Your CRM staff account is inactive. Please contact your CRM Administrator.';
        break;
      case 'device_revoked':
      case 'invalid_token':
      case 'device_mismatch':
        _errorMessage = 'Device pairing was lost or revoked. Please unpair and re-pair with the CRM.';
        widget.syncService.unpair();
        break;
      case 'update_required':
        _errorMessage = 'An app update is required to access the CRM portal. Please update your app.';
        widget.syncService.checkForAppUpdate(manual: true);
        break;
      default:
        _errorMessage = res.message?.isNotEmpty == true
            ? res.message!
            : 'Unable to connect to CRM. Please check your internet connection and try again.';
        break;
    }
  }

  void _setupWebViewController(String url) {
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
              if (mounted) {
                setState(() {
                  _isLoading = true;
                  _currentUrl = pageUrl;
                });
                _updateNavigationState();
              }
            },
            onPageFinished: (pageUrl) {
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
              if (mounted && _controller != null) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            onNavigationRequest: (NavigationRequest request) {
              final destUrl = request.url;

              // 1. Non-web intents (tel:, mailto:, whatsapp:, intent:, geo:) -> open externally
              if (!destUrl.startsWith('http://') && !destUrl.startsWith('https://')) {
                widget.syncService.launchAppUpdateUrl(destUrl);
                return NavigationDecision.prevent;
              }

              // 2. Session expired (redirected to Perfex CRM login page) -> auto re-authenticate
              if (destUrl.contains('/admin/authentication')) {
                _initWebviewSession();
                return NavigationDecision.prevent;
              }

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
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load webview: $e';
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

            // Refresh / Reload session
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: colors.textPrimary, size: 22),
              tooltip: 'Refresh CRM',
              onPressed: () {
                if (_controller != null) {
                  _controller!.reload();
                } else {
                  _initWebviewSession();
                }
              },
            ),

            // More Options (Open in browser, fresh sign-in)
            PopupMenuButton<String>(
              color: colors.cardBackground,
              icon: Icon(Icons.more_vert_rounded, color: colors.textPrimary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: colors.border),
              ),
              onSelected: (val) {
                if (val == 'open_browser') {
                  final target = _currentUrl.isNotEmpty
                      ? _currentUrl
                      : widget.syncService.api.serverUrl;
                  widget.syncService.launchAppUpdateUrl(target);
                } else if (val == 'new_session') {
                  _initWebviewSession();
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'new_session',
                  child: Row(
                    children: [
                      Icon(Icons.vpn_key_rounded, color: colors.primary, size: 20),
                      const SizedBox(width: 10),
                      Text('Get Fresh Sign-in Link', style: TextStyle(color: colors.textPrimary)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'open_browser',
                  child: Row(
                    children: [
                      Icon(Icons.open_in_browser_rounded, color: colors.primary, size: 20),
                      const SizedBox(width: 10),
                      Text('Open in Browser', style: TextStyle(color: colors.textPrimary)),
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

              // Main Web Content or Error/Disabled Card
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
            'Opening secure CRM session...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Authenticating via one-time token',
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
    final isAdminBlocked = _errorType == 'webview_admin_blocked';
    final isDisabled = _errorType == 'webview_disabled';

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
                  color: (isAdminBlocked ? colors.primary : (isDisabled ? colors.warning : colors.danger))
                      .withOpacity(0.12),
                ),
                child: Icon(
                  isAdminBlocked
                      ? Icons.admin_panel_settings_rounded
                      : (isDisabled ? Icons.lock_outline_rounded : Icons.cloud_off_rounded),
                  color: isAdminBlocked
                      ? colors.primary
                      : (isDisabled ? colors.warning : colors.danger),
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isAdminBlocked
                    ? 'CRM Administrator Account'
                    : (isDisabled ? 'CRM In-App Portal Disabled' : 'Connection Error'),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Unable to connect to CRM.',
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
                  if (isAdminBlocked) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                      label: const Text('Open in Browser', style: TextStyle(fontWeight: FontWeight.w600)),
                      onPressed: () {
                        widget.syncService.launchAppUpdateUrl(widget.syncService.api.serverUrl);
                      },
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textPrimary,
                        side: BorderSide(color: colors.border),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Try Again'),
                      onPressed: _initWebviewSession,
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

