import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'tokens.dart';

const kSans = 'FiraSans';
const kMono = 'FiraCode';

/// Monospace numbers (Fira Code, weight 500, tabular figures) used for every metric.
TextStyle mono(
  BuildContext context, {
  double size = 15,
  Color? color,
  FontWeight weight = FontWeight.w500,
}) => TextStyle(
  fontFamily: kMono,
  fontSize: size,
  color: color ?? context.c.fg,
  fontWeight: weight,
  fontVariations: [FontVariation.weight(weight.value.toDouble())],
  fontFeatures: const [FontFeature.tabularFigures()],
  height: 1.15,
  letterSpacing: size >= 26 ? -0.5 : 0,
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
    ),
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
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.15,
        letterSpacing: -0.3,
      ),
      titleMedium: t.titleMedium?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
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
