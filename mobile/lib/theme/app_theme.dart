import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'tokens.dart';

const kSans = 'Manrope';

/// Display face for headings and every metric (tabular figures).
const kMono = 'SpaceGrotesk';
const kDisplay = kMono;

/// Metric numbers (Space Grotesk with tabular figures) used for every value.
TextStyle mono(
  BuildContext context, {
  double size = 15,
  Color? color,
  FontWeight weight = FontWeight.w500,
}) => TextStyle(
  fontFamily: kMono,
  fontSize: size,
  color: color ?? context.c.fg,
  fontWeight: weight == FontWeight.w500 && size >= 22
      ? FontWeight.w600
      : weight,
  fontFeatures: const [FontFeature.tabularFigures()],
  height: 1.1,
  letterSpacing: size >= 26 ? -1.0 : (size >= 18 ? -0.3 : 0),
);

ThemeData buildTheme(Brightness b) {
  final c = b == Brightness.dark ? AppColors.dark : AppColors.light;
  final base = ThemeData(
    brightness: b,
    useMaterial3: true,
    fontFamily: kSans,
    scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.secondary,
      brightness: b,
      surface: c.card,
      primary: c.secondary,
      onPrimary: b == Brightness.dark ? c.onBrand : Colors.white,
    ),
    textSelectionTheme: TextSelectionThemeData(cursorColor: c.secondary),
    splashFactory: InkSparkle.splashFactory,
    extensions: [c],
  );
  final t = base.textTheme.apply(
    bodyColor: c.fg,
    displayColor: c.fg,
    fontFamily: kSans,
  );
  return base.copyWith(
    textTheme: t.copyWith(
      headlineMedium: t.headlineMedium?.copyWith(
        fontFamily: kDisplay,
        fontSize: 30,
        fontWeight: FontWeight.w600,
        height: 1.1,
        letterSpacing: -0.9,
      ),
      titleMedium: t.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      bodyLarge: t.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
      bodyMedium: t.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
      bodySmall: t.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.4,
        color: c.mutedFg,
      ),
    ),
    dividerColor: c.border,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
