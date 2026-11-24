import 'package:flutter/material.dart';

/// لوحة الألوان: أسود / بنفسجي / ذهبي فقط (درجات أفتح من نفس العائلة).
class C {
  static const black = Color(0xFF000000);
  static const surface = Color(0xFF0B0713);
  static const card = Color(0xFF150E22);
  static const purple = Color(0xFF5A189A);
  static const purpleLight = Color(0xFF7B2CBF);
  static const gold = Color(0xFFD4AF37);
  static const goldSoft = Color(0xFFE6D08A);
  static const line = Color(0x555A189A);
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: C.black,
    colorScheme: const ColorScheme.dark(
      primary: C.gold,
      onPrimary: C.black,
      secondary: C.purple,
      surface: C.surface,
      onSurface: C.goldSoft,
      outline: C.line,
    ),
    textTheme: base.textTheme.apply(bodyColor: C.goldSoft, displayColor: C.gold),
    appBarTheme: const AppBarTheme(
      backgroundColor: C.black,
      foregroundColor: C.gold,
      elevation: 0,
      centerTitle: true,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: C.surface,
      indicatorColor: C.purple,
      iconTheme: WidgetStateProperty.all(const IconThemeData(color: C.gold)),
      labelTextStyle: WidgetStateProperty.all(
          const TextStyle(color: C.goldSoft, fontSize: 12)),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: C.purple,
      contentTextStyle: TextStyle(color: C.gold),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: C.gold),
    dividerTheme: const DividerThemeData(color: C.line),
    iconTheme: const IconThemeData(color: C.gold),
  );
}
