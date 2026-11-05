import 'package:flutter/material.dart';

/// Semantic colour tokens, matched to the PulseFolio web app (styles.css).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.glow1,
    required this.glow2,
    required this.card,
    required this.card2,
    required this.muted,
    required this.fg,
    required this.mutedFg,
    required this.border,
    required this.borderStrong,
    required this.track,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.link,
    required this.up,
    required this.upBg,
    required this.down,
    required this.downBg,
    required this.warn,
    required this.warnBg,
    required this.heart,
    required this.heartBg,
    required this.navBg,
    required this.zLight,
    required this.zModerate,
    required this.zVigorous,
    required this.zPeak,
    required this.sAwake,
    required this.sRestless,
    required this.sRem,
    required this.sLight,
    required this.sDeep,
    required this.shadow,
  });

  final Color bg, glow1, glow2, card, card2, muted, fg, mutedFg, border, borderStrong, track;
  final Color primary, secondary, accent, link, up, upBg, down, downBg, warn, warnBg, heart, heartBg, navBg;
  final Color zLight, zModerate, zVigorous, zPeak;
  final Color sAwake, sRestless, sRem, sLight, sDeep;
  final List<BoxShadow> shadow;

  static const dark = AppColors(
    bg: Color(0xFF0B1220),
    glow1: Color(0x382563EB),
    glow2: Color(0x297C3AED),
    card: Color(0xFF141C2E),
    card2: Color(0xFF1B2540),
    muted: Color(0xFF0E1628),
    fg: Color(0xFFF8FAFC),
    mutedFg: Color(0xFF9AA8BD),
    border: Color(0x14FFFFFF),
    borderStrong: Color(0x29FFFFFF),
    track: Color(0x2E94A3B8),
    primary: Color(0xFF2563EB),
    secondary: Color(0xFF3B82F6),
    accent: Color(0xFF7C3AED),
    link: Color(0xFF7AB2FF),
    up: Color(0xFF10B981),
    upBg: Color(0x2610B981),
    down: Color(0xFFF87171),
    downBg: Color(0x2BDC2626),
    warn: Color(0xFFFBBF24),
    warnBg: Color(0x26FBBF24),
    heart: Color(0xFFFB7185),
    heartBg: Color(0x24FB7185),
    navBg: Color(0xC70B1220),
    zLight: Color(0xFF4FC3F7),
    zModerate: Color(0xFF4ADE80),
    zVigorous: Color(0xFFFACC15),
    zPeak: Color(0xFFF87171),
    sAwake: Color(0xFFF0A3C0),
    sRestless: Color(0xFFF5B942),
    sRem: Color(0xFFBAE6FD),
    sLight: Color(0xFF93B4F8),
    sDeep: Color(0xFF8B5CD6),
    shadow: [BoxShadow(color: Color(0x99000000), blurRadius: 30, offset: Offset(0, 10), spreadRadius: -12)],
  );

  static const light = AppColors(
    bg: Color(0xFFF6F8FC),
    glow1: Color(0x1A2563EB),
    glow2: Color(0x147C3AED),
    card: Color(0xFFFFFFFF),
    card2: Color(0xFFEEF2F8),
    muted: Color(0xFFF1F4F9),
    fg: Color(0xFF0F172A),
    mutedFg: Color(0xFF4B5568),
    border: Color(0x140F172A),
    borderStrong: Color(0x2E0F172A),
    track: Color(0x29647488),
    primary: Color(0xFF1D4ED8),
    secondary: Color(0xFF2563EB),
    accent: Color(0xFF6D28D9),
    link: Color(0xFF1D4ED8),
    up: Color(0xFF047857),
    upBg: Color(0x1F059669),
    down: Color(0xFFDC2626),
    downBg: Color(0x1ADC2626),
    warn: Color(0xFFB45309),
    warnBg: Color(0x1FD97706),
    heart: Color(0xFFE11D48),
    heartBg: Color(0x1AE11D48),
    navBg: Color(0xD1FFFFFF),
    zLight: Color(0xFF0284C7),
    zModerate: Color(0xFF16A34A),
    zVigorous: Color(0xFFCA8A04),
    zPeak: Color(0xFFDC2626),
    sAwake: Color(0xFFE46A9A),
    sRestless: Color(0xFFD99511),
    sRem: Color(0xFF38BDF8),
    sLight: Color(0xFF5B83E8),
    sDeep: Color(0xFF6D3FC0),
    shadow: [BoxShadow(color: Color(0x2E0F172A), blurRadius: 28, offset: Offset(0, 12), spreadRadius: -14)],
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      bg: l(bg, other.bg), glow1: l(glow1, other.glow1), glow2: l(glow2, other.glow2), card: l(card, other.card),
      card2: l(card2, other.card2), muted: l(muted, other.muted), fg: l(fg, other.fg), mutedFg: l(mutedFg, other.mutedFg),
      border: l(border, other.border), borderStrong: l(borderStrong, other.borderStrong), track: l(track, other.track),
      primary: l(primary, other.primary), secondary: l(secondary, other.secondary), accent: l(accent, other.accent),
      link: l(link, other.link), up: l(up, other.up), upBg: l(upBg, other.upBg), down: l(down, other.down),
      downBg: l(downBg, other.downBg), warn: l(warn, other.warn), warnBg: l(warnBg, other.warnBg), heart: l(heart, other.heart),
      heartBg: l(heartBg, other.heartBg), navBg: l(navBg, other.navBg), zLight: l(zLight, other.zLight),
      zModerate: l(zModerate, other.zModerate), zVigorous: l(zVigorous, other.zVigorous), zPeak: l(zPeak, other.zPeak),
      sAwake: l(sAwake, other.sAwake), sRestless: l(sRestless, other.sRestless), sRem: l(sRem, other.sRem),
      sLight: l(sLight, other.sLight), sDeep: l(sDeep, other.sDeep), shadow: t < 0.5 ? shadow : other.shadow,
    );
  }
}

/// Spacing (4/8 rhythm), radii and motion tokens shared by every screen.
abstract final class Space {
  static const s1 = 4.0, s2 = 8.0, s3 = 12.0, s4 = 16.0, s5 = 24.0, s6 = 32.0;
}

abstract final class Radii {
  static const card = 18.0, sm = 12.0, pill = 999.0;
}

abstract final class Motion {
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 420);
  static const draw = Duration(milliseconds: 1100);
  static const stagger = Duration(milliseconds: 55);
  static const ease = Cubic(0.2, 0, 0, 1);
  static const spring = Curves.easeOutBack;
}

extension AppColorsX on BuildContext {
  AppColors get c => Theme.of(this).extension<AppColors>()!;
  bool get reduceMotion => MediaQuery.maybeOf(this)?.disableAnimations ?? false;
}
