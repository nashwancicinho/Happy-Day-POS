import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData getTheme(Color primaryColor, {bool isDarkMode = false}) {
    if (isDarkMode) {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: primaryColor,
        colorScheme: ColorScheme.dark(
          primary: primaryColor,
          surface: const Color(0xFF1F2937),
          onSurface: Colors.white,
          onPrimary: Colors.white,
          surfaceContainer: const Color(0xFF242F3E),
          surfaceContainerHigh: const Color(0xFF2C394B),
          surfaceContainerHighest: const Color(0xFF334155),
          surfaceContainerLow: const Color(0xFF182232),
          surfaceContainerLowest: const Color(0xFF0F172A),
          outline: const Color(0xFF475569),
        ),
        scaffoldBackgroundColor: const Color(0xFF111827),
        cardColor: const Color(0xFF1F2937),
        canvasColor: const Color(0xFF111827),
        dividerColor: const Color(0xFF374151),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFF1F2937),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1F2937),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF1F2937),
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          contentTextStyle: TextStyle(color: Color(0xFFE5E7EB), fontSize: 14),
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: Color(0xFF1F2937),
          surfaceTintColor: Colors.transparent,
          textStyle: TextStyle(color: Colors.white),
        ),
        listTileTheme: const ListTileThemeData(
          textColor: Colors.white,
          iconColor: Color(0xFF9CA3AF),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF242F3E),
          labelStyle: const TextStyle(color: Colors.white),
          side: const BorderSide(color: Color(0xFF475569)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        dataTableTheme: const DataTableThemeData(
          headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          dataTextStyle: TextStyle(color: Color(0xFFF3F4F6)),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Color(0xFF9CA3AF)),
          hintStyle: TextStyle(color: Color(0xFF6B7280)),
          prefixIconColor: Color(0xFF9CA3AF),
          suffixIconColor: Color(0xFF9CA3AF),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Colors.white),
          displayMedium: TextStyle(color: Colors.white),
          displaySmall: TextStyle(color: Colors.white),
          headlineLarge: TextStyle(color: Colors.white),
          headlineMedium: TextStyle(color: Colors.white),
          headlineSmall: TextStyle(color: Colors.white),
          titleLarge: TextStyle(color: Colors.white),
          titleMedium: TextStyle(color: Colors.white),
          titleSmall: TextStyle(color: Colors.white),
          bodyLarge: TextStyle(color: Color(0xFFF3F4F6)),
          bodyMedium: TextStyle(color: Color(0xFFF3F4F6)),
          bodySmall: TextStyle(color: Color(0xFF9CA3AF)),
          labelLarge: TextStyle(color: Colors.white),
          labelMedium: TextStyle(color: Color(0xFFF3F4F6)),
          labelSmall: TextStyle(color: Color(0xFF9CA3AF)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F2937),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        surface: Colors.white,
        onSurface: const Color(0xFF111827),
        onPrimary: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      cardColor: Colors.white,
      canvasColor: const Color(0xFFF5F5F5),
      dividerColor: const Color(0xFFE5E7EB),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(color: Color(0xFF111827), fontSize: 18, fontWeight: FontWeight.bold),
        contentTextStyle: TextStyle(color: Color(0xFF374151), fontSize: 14),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: Color(0xFF111827)),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: Color(0xFF111827),
        iconColor: Color(0xFF4B5563),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF3F4F6),
        labelStyle: const TextStyle(color: Color(0xFF111827)),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFF111827),
      ),
      dataTableTheme: const DataTableThemeData(
        headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111827)),
        dataTextStyle: TextStyle(color: Color(0xFF1F2937)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        labelStyle: TextStyle(color: Color(0xFF4B5563)),
        hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
        prefixIconColor: Color(0xFF4B5563),
        suffixIconColor: Color(0xFF4B5563),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: Color(0xFF111827)),
        displayMedium: TextStyle(color: Color(0xFF111827)),
        displaySmall: TextStyle(color: Color(0xFF111827)),
        headlineLarge: TextStyle(color: Color(0xFF111827)),
        headlineMedium: TextStyle(color: Color(0xFF111827)),
        headlineSmall: TextStyle(color: Color(0xFF111827)),
        titleLarge: TextStyle(color: Color(0xFF111827)),
        titleMedium: TextStyle(color: Color(0xFF111827)),
        titleSmall: TextStyle(color: Color(0xFF111827)),
        bodyLarge: TextStyle(color: Color(0xFF1F2937)),
        bodyMedium: TextStyle(color: Color(0xFF1F2937)),
        bodySmall: TextStyle(color: Color(0xFF4B5563)),
        labelLarge: TextStyle(color: Color(0xFF111827)),
        labelMedium: TextStyle(color: Color(0xFF1F2937)),
        labelSmall: TextStyle(color: Color(0xFF4B5563)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  static ThemeData lightTheme = getTheme(AppColors.primary, isDarkMode: false);
  static ThemeData darkTheme = getTheme(AppColors.primary, isDarkMode: true);
}