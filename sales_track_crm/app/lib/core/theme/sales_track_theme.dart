import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Semantic colors for Sales Track CRM adapting dynamically to Light and Dark modes.
class SalesTrackColors {
  final bool isDark;

  // Backgrounds & Surfaces
  final Color background;
  final Color cardBackground;
  final Color cardBackgroundHover;
  final Color surfaceColor;
  final Color surfaceLight;
  final Color border;
  final Color divider;

  // Typography
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  // Primary brand (Emerald)
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color primaryContainer;

  // Secondary brand (Indigo)
  final Color secondary;
  final Color secondaryLight;

  // Brand Accents
  final Color accentCyan;
  final Color whatsappGreen;
  final Color whatsappBusiness;

  // Functional Semantic Colors
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  const SalesTrackColors({
    required this.isDark,
    required this.background,
    required this.cardBackground,
    required this.cardBackgroundHover,
    required this.surfaceColor,
    required this.surfaceLight,
    required this.border,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.primaryContainer,
    required this.secondary,
    required this.secondaryLight,
    required this.accentCyan,
    required this.whatsappGreen,
    required this.whatsappBusiness,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });
}

class SalesTrackTheme {
  // Fixed Brand Colors
  static const Color primary = Color(0xFF10B981); // Emerald 500
  static const Color primaryLight = Color(0xFF34D399); // Emerald 400
  static const Color primaryDark = Color(0xFF059669); // Emerald 600

  static const Color secondary = Color(0xFF6366F1); // Indigo 500
  static const Color secondaryLight = Color(0xFF818CF8); // Indigo 400

  static const Color accentCyan = Color(0xFF06B6D4); // Cyan 500
  static const Color whatsappGreen = Color(0xFF25D366); // WhatsApp Brand
  static const Color whatsappBusiness = Color(0xFF128C7E); // WhatsApp Business Brand

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Fallback dark palette constants for backward compatibility
  static const Color darkBackground = Color(0xFF0B111E);
  static const Color cardBackground = Color(0xFF131D2E);
  static const Color surfaceColor = Color(0xFF1E2D44);
  static const Color surfaceLight = Color(0xFF2B3D5B);
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Modern Dark Theme Palette
  static const SalesTrackColors darkColors = SalesTrackColors(
    isDark: true,
    background: Color(0xFF0B111E), // Slate 950 deep obsidian
    cardBackground: Color(0xFF131D2E), // Slate 900 card surface
    cardBackgroundHover: Color(0xFF1A263D),
    surfaceColor: Color(0xFF1E2D44), // Slate 800 element surface
    surfaceLight: Color(0xFF2B3D5B), // Slate 700 subtle borders
    border: Color(0xFF1E2D44),
    divider: Color(0x1AFFFFFF),
    textPrimary: Color(0xFFF8FAFC), // Slate 50
    textSecondary: Color(0xFF94A3B8), // Slate 400
    textMuted: Color(0xFF64748B), // Slate 500
    primary: Color(0xFF10B981),
    primaryLight: Color(0xFF34D399),
    primaryDark: Color(0xFF059669),
    primaryContainer: Color(0xFF064E3B),
    secondary: Color(0xFF6366F1),
    secondaryLight: Color(0xFF818CF8),
    accentCyan: Color(0xFF06B6D4),
    whatsappGreen: Color(0xFF25D366),
    whatsappBusiness: Color(0xFF128C7E),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    info: Color(0xFF3B82F6),
  );

  // Modern Light Theme Palette
  static const SalesTrackColors lightColors = SalesTrackColors(
    isDark: false,
    background: Color(0xFFF8FAFC), // Slate 50 clean background
    cardBackground: Color(0xFFFFFFFF), // Crisp white card
    cardBackgroundHover: Color(0xFFF1F5F9),
    surfaceColor: Color(0xFFF1F5F9), // Slate 100 soft element background
    surfaceLight: Color(0xFFE2E8F0), // Slate 200 light border
    border: Color(0xFFE2E8F0),
    divider: Color(0x140F172A),
    textPrimary: Color(0xFF0F172A), // Slate 900 high-contrast
    textSecondary: Color(0xFF475569), // Slate 600 readable body
    textMuted: Color(0xFF94A3B8), // Slate 400 soft caption
    primary: Color(0xFF059669), // Emerald 600 (better contrast on light)
    primaryLight: Color(0xFF10B981),
    primaryDark: Color(0xFF047857),
    primaryContainer: Color(0xFFD1FAE5),
    secondary: Color(0xFF4F46E5), // Indigo 600
    secondaryLight: Color(0xFF6366F1),
    accentCyan: Color(0xFF0891B2),
    whatsappGreen: Color(0xFF16A34A),
    whatsappBusiness: Color(0xFF0D9488),
    success: Color(0xFF059669),
    warning: Color(0xFFD97706),
    danger: Color(0xFFDC2626),
    info: Color(0xFF2563EB),
  );

  /// Helper to get current dynamic colors based on context brightness.
  static SalesTrackColors of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkColors : lightColors;
  }

  /// Dark Theme Data
  static ThemeData get darkTheme {
    const colors = darkColors;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colors.background,
      primaryColor: colors.primary,
      colorScheme: ColorScheme.dark(
        primary: colors.primary,
        onPrimary: Colors.white,
        secondary: colors.secondary,
        onSecondary: Colors.white,
        surface: colors.cardBackground,
        onSurface: colors.textPrimary,
        error: colors.danger,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.cardBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: colors.cardBackground,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: colors.primary.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.surfaceLight, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        labelStyle: TextStyle(color: colors.textSecondary),
        hintStyle: TextStyle(color: colors.textMuted),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: colors.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: colors.primaryLight,
        unselectedLabelColor: colors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
        dividerColor: colors.border,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceColor,
        selectedColor: colors.primary.withOpacity(0.2),
        secondarySelectedColor: colors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        labelStyle: TextStyle(color: colors.textPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.transparent),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Light Theme Data
  static ThemeData get lightTheme {
    const colors = lightColors;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: colors.background,
      primaryColor: colors.primary,
      colorScheme: ColorScheme.light(
        primary: colors.primary,
        onPrimary: Colors.white,
        secondary: colors.secondary,
        onSecondary: Colors.white,
        surface: colors.cardBackground,
        onSurface: colors.textPrimary,
        error: colors.danger,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.cardBackground,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: colors.cardBackground,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: colors.primary.withOpacity(0.25),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.border, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        labelStyle: TextStyle(color: colors.textSecondary),
        hintStyle: TextStyle(color: colors.textMuted),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: colors.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: colors.primary,
        unselectedLabelColor: colors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
        dividerColor: colors.border,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceColor,
        selectedColor: colors.primary.withOpacity(0.15),
        secondarySelectedColor: colors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        labelStyle: TextStyle(color: colors.textPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.transparent),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Default theme data (backward compatible)
  static ThemeData get themeData => darkTheme;
}

/// Extension on BuildContext for quick access to dynamic colors
extension SalesTrackThemeContext on BuildContext {
  SalesTrackColors get stColors => SalesTrackTheme.of(this);
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

/// Provider for managing ThemeMode (Light / Dark / System) with persistence
class ThemeProvider extends ChangeNotifier {
  static const String _prefKey = 'sales_track_theme_mode';
  ThemeMode _themeMode = ThemeMode.system;

  ThemeProvider() {
    _loadThemeMode();
  }

  ThemeMode get themeMode => _themeMode;

  bool isDark(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved == 'light') {
        _themeMode = ThemeMode.light;
      } else if (saved == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = mode == ThemeMode.light
          ? 'light'
          : mode == ThemeMode.dark
              ? 'dark'
              : 'system';
      await prefs.setString(_prefKey, val);
    } catch (_) {}
  }

  Future<void> toggleTheme(BuildContext context) async {
    final currentIsDark = isDark(context);
    await setThemeMode(currentIsDark ? ThemeMode.light : ThemeMode.dark);
  }
}
