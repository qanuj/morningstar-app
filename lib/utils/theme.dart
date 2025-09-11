// lib/utils/theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // Duggy Blue Brand Colors (from web project)
  static const Color primaryBlue = Color(0xFF003f9b); // Main brand color
  static const Color lightBlue = Color(
    0xFF06aeef,
  ); // Secondary actions, highlights
  static const Color lighterBlue = Color(0xFF4dd0ff); // Tertiary accents
  static const Color darkBlue = Color(0xFF002d6b); // Darker shade for gradients

  // Status Colors
  static const Color successGreen = Color(0xFF16a34a); // Success states
  static const Color errorRed = Color(0xFFdc2626); // Error states
  static const Color warningOrange = Color(0xFFf59e0b); // Warning states

  // Chart Colors (for analytics)
  static const Color chart1 = Color(0xFF003f9b); // Primary data
  static const Color chart2 = Color(0xFF06aeef); // Secondary data
  static const Color chart3 = Color(0xFF4dd0ff); // Tertiary data
  static const Color chart4 = Color(0xFFfbbf24); // Accent data
  static const Color chart5 = Color(0xFFf97316); // Warning data

  // Neutral Colors (from web project)
  static const Color backgroundColor = Color(0xFFffffff); // Main background
  static const Color surfaceColor = Color(0xFFffffff); // Card backgrounds
  static const Color cardColor = Color(0xFFffffff); // Card container
  static const Color secondaryBg = Color(0xFFf8f9fa); // Light backgrounds
  static const Color dividerColor = Color(0xFFdee2e6); // Borders, dividers

  // Text Colors (from web project)
  static const Color primaryTextColor = Color(0xFF000000); // Main headings
  static const Color secondaryTextColor = Color(0xFF6c757d); // Supporting text
  static const Color tertiaryTextColor = Color(0xFF9ca3af); // Subtle text

  // Legacy color aliases for backward compatibility
  static const Color cricketGreen = primaryBlue;
  static const Color darkGreen = darkBlue;
  static const Color lightGreen = lightBlue;
  static const Color accentGreen = lighterBlue;

  static ThemeData get duggyTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.light,
        primary: primaryBlue,
        secondary: lightBlue,
        surface: surfaceColor,
        background: backgroundColor,
        error: errorRed,
      ),
      scaffoldBackgroundColor: backgroundColor,

      // App Bar Theme - Compact
      appBarTheme: AppBarTheme(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 56, // Standard compact height
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        iconTheme: IconThemeData(color: Colors.white, size: 22),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        margin: EdgeInsets.all(0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: dividerColor.withOpacity(0.3), width: 0.5),
        ),
        shadowColor: Colors.black.withOpacity(0.1),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: BorderSide(color: primaryBlue.withOpacity(0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        ),
      ),

      // Input Decoration Theme - Compact but usable
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        isDense: true, // Makes inputs more compact
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: dividerColor.withOpacity(0.5),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: dividerColor.withOpacity(0.5),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        hintStyle: TextStyle(color: secondaryTextColor, fontSize: 12),
        labelStyle: TextStyle(color: secondaryTextColor, fontSize: 12),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryBlue,
        unselectedItemColor: secondaryTextColor,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),

      // Drawer Theme
      drawerTheme: DrawerThemeData(
        backgroundColor: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
      ),

      // List Tile Theme - Compact
      listTileTheme: ListTileThemeData(
        dense: true, // Makes list tiles more compact
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        iconColor: primaryBlue,
        textColor: primaryTextColor,
        minVerticalPadding: 2, // Minimal vertical padding
      ),

      // Chip Theme - Compact
      chipTheme: ChipThemeData(
        backgroundColor: primaryBlue.withOpacity(0.1),
        selectedColor: primaryBlue,
        disabledColor: Colors.grey.withOpacity(0.2),
        secondarySelectedColor: primaryBlue.withOpacity(0.2),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelStyle: TextStyle(
          color: primaryBlue,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        secondaryLabelStyle: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: dividerColor.withOpacity(0.3),
        thickness: 0.5,
        space: 1,
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: TextStyle(
          color: primaryTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        contentTextStyle: TextStyle(color: secondaryTextColor, fontSize: 12),
      ),

      // Snack Bar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryTextColor,
        contentTextStyle: TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: primaryTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        displayMedium: TextStyle(
          color: primaryTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        displaySmall: TextStyle(
          color: primaryTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        headlineLarge: TextStyle(
          color: primaryTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        headlineMedium: TextStyle(
          color: primaryTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        headlineSmall: TextStyle(
          color: primaryTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        titleLarge: TextStyle(
          color: primaryTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        titleMedium: TextStyle(
          color: primaryTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        titleSmall: TextStyle(
          color: primaryTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        bodyLarge: TextStyle(
          color: primaryTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: primaryTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: secondaryTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: TextStyle(
          color: primaryTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        labelMedium: TextStyle(
          color: primaryTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        labelSmall: TextStyle(
          color: secondaryTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryBlue,
        linearTrackColor: cricketGreen.withOpacity(0.2),
        circularTrackColor: cricketGreen.withOpacity(0.2),
      ),

      // Tab Bar Theme
      tabBarTheme: TabBarThemeData(
        labelColor: primaryBlue,
        unselectedLabelColor: secondaryTextColor,
        indicatorColor: primaryBlue,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color?>((
          Set<MaterialState> states,
        ) {
          if (states.contains(MaterialState.selected)) {
            return Colors.white;
          }
          return Colors.white;
        }),
        trackColor: MaterialStateProperty.resolveWith<Color?>((
          Set<MaterialState> states,
        ) {
          if (states.contains(MaterialState.selected)) {
            return primaryBlue;
          }
          return Colors.grey[400]!;
        }),
        overlayColor: MaterialStateProperty.resolveWith<Color?>((
          Set<MaterialState> states,
        ) {
          if (states.contains(MaterialState.selected)) {
            return primaryBlue.withOpacity(0.1);
          }
          return Colors.grey.withOpacity(0.1);
        }),
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color?>((
          Set<MaterialState> states,
        ) {
          if (states.contains(MaterialState.selected)) {
            return primaryBlue;
          }
          return Colors.transparent;
        }),
        checkColor: MaterialStateProperty.all(Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // Radio Theme
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color?>((
          Set<MaterialState> states,
        ) {
          if (states.contains(MaterialState.selected)) {
            return primaryBlue;
          }
          return secondaryTextColor;
        }),
      ),
    );
  }

  // Helper methods for custom styling
  static BoxDecoration get softCardDecoration => BoxDecoration(
    color: surfaceColor,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: dividerColor.withOpacity(0.3), width: 0.5),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 8,
        offset: Offset(0, 2),
      ),
    ],
  );

  static BoxDecoration get elevatedCardDecoration => BoxDecoration(
    color: surfaceColor,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.08),
        blurRadius: 20,
        offset: Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration get gradientDecoration => BoxDecoration(
    gradient: LinearGradient(
      colors: [primaryBlue, darkBlue],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(16),
  );

  static BoxDecoration get softBorderDecoration => BoxDecoration(
    color: surfaceColor,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: dividerColor.withOpacity(0.3), width: 0.5),
  );

  // Ultra-compact helper methods for maximum space efficiency
  static EdgeInsets get ultraCompactPadding => EdgeInsets.all(4);
  static EdgeInsets get compactPadding => EdgeInsets.all(8);
  static EdgeInsets get standardPadding => EdgeInsets.all(12);

  static EdgeInsets get ultraCompactMargin => EdgeInsets.all(2);
  static EdgeInsets get compactMargin => EdgeInsets.all(4);
  static EdgeInsets get standardMargin => EdgeInsets.all(8);

  // Compact spacing constants
  static const double ultraCompactSpacing = 4;
  static const double compactSpacing = 8;
  static const double standardSpacing = 12;
  static const double largeSpacing = 16;

  // Compact box decorations
  static BoxDecoration get ultraCompactCardDecoration => BoxDecoration(
    color: surfaceColor,
    borderRadius: BorderRadius.circular(6),
    border: Border.all(color: dividerColor.withOpacity(0.2), width: 0.5),
  );

  static BoxDecoration get compactListDecoration => BoxDecoration(
    color: surfaceColor,
    borderRadius: BorderRadius.circular(4),
    border: Border.all(color: dividerColor.withOpacity(0.1), width: 0.5),
  );

  // Dark Theme
  static ThemeData get duggyDarkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.dark,
        primary: lightBlue,
        secondary: lighterBlue,
        surface: Color(0xFF1a1a1a),
        background: Color(0xFF121212),
        error: errorRed,
      ),
      scaffoldBackgroundColor: Color(0xFF121212),

      // App Bar Theme - Dark
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF1e1e1e),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 56,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        iconTheme: IconThemeData(color: Colors.white, size: 22),
      ),

      // Card Theme - Dark
      cardTheme: CardThemeData(
        color: Color(0xFF1e1e1e),
        elevation: 0,
        margin: EdgeInsets.all(0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(
            color: Color(0xFF333333).withOpacity(0.3),
            width: 0.5,
          ),
        ),
        shadowColor: Colors.black.withOpacity(0.3),
      ),

      // Elevated Button Theme - Dark
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        ),
      ),

      // Outlined Button Theme - Dark
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightBlue,
          side: BorderSide(color: lightBlue.withOpacity(0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        ),
      ),

      // Text Button Theme - Dark
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lightBlue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        ),
      ),

      // Input Decoration Theme - Dark
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF2a2a2a),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Color(0xFF444444).withOpacity(0.5),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Color(0xFF444444).withOpacity(0.5),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: lightBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: errorRed, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: errorRed, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
        labelStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
      ),

      // Bottom Navigation Bar Theme - Dark
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1e1e1e),
        selectedItemColor: lightBlue,
        unselectedItemColor: Colors.grey[400],
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),

      // Drawer Theme - Dark
      drawerTheme: DrawerThemeData(
        backgroundColor: Color(0xFF1e1e1e),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
      ),

      // List Tile Theme - Dark
      listTileTheme: ListTileThemeData(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        iconColor: lightBlue,
        textColor: Colors.white,
        minVerticalPadding: 2,
      ),

      // Text Theme - Dark
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        displayMedium: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        displaySmall: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        headlineLarge: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        headlineMedium: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        headlineSmall: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        titleLarge: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        titleMedium: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        titleSmall: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        bodyLarge: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: Colors.grey[400],
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        labelMedium: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        labelSmall: TextStyle(
          color: Colors.grey[400],
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),

      // Progress Indicator Theme - Dark
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: lightBlue,
        linearTrackColor: lightBlue.withOpacity(0.2),
        circularTrackColor: lightBlue.withOpacity(0.2),
      ),

      // Divider Theme - Dark
      dividerTheme: DividerThemeData(
        color: Color(0xFF333333).withOpacity(0.3),
        thickness: 0.5,
        space: 1,
      ),

      // Dialog Theme - Dark
      dialogTheme: DialogThemeData(
        backgroundColor: Color(0xFF1e1e1e),
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        contentTextStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
      ),

      // Snack Bar Theme - Dark
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Color(0xFF333333),
        contentTextStyle: TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),
    );
  }

  // Legacy alias for backward compatibility
  static ThemeData get cricketTheme => duggyTheme;
}
