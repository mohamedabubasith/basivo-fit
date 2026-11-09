import 'package:flutter/material.dart';

/// Semantic colour tokens for Basivo Fit: ink background, volt (lime to teal) brand.
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
    required this.brandA,
    required this.brandB,
    required this.onBrand,
    required this.shadow,
  });

  final Color bg,
      glow1,
      glow2,
      card,
      card2,
      muted,
      fg,
      mutedFg,
      border,
      borderStrong,
      track;
  final Color primary,
      secondary,
      accent,
      link,
      up,
      upBg,
      down,
      downBg,
      warn,
      warnBg,
      heart,
      heartBg,
      navBg;
  final Color zLight, zModerate, zVigorous, zPeak;
  final Color sAwake, sRestless, sRem, sLight, sDeep;

  /// Brand gradient (start, end) and the text colour that sits on it.
  final Color brandA, brandB, onBrand;
  final List<BoxShadow> shadow;

  LinearGradient get brand => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandA, brandB],
  );

  static const dark = AppColors(
    bg: Color(0xFF07080C),
    glow1: Color(0x24C6F24E),
    glow2: Color(0x1F2FD9B9),
    card: Color(0xFF111319),
    card2: Color(0xFF191C24),
    muted: Color(0xFF0C0E13),
    fg: Color(0xFFF3F5F7),
    mutedFg: Color(0xFF969DAA),
    border: Color(0x12FFFFFF),
    borderStrong: Color(0x26FFFFFF),
    track: Color(0x26A1A8B5),
    primary: Color(0xFFC6F24E),
    secondary: Color(0xFFC6F24E),
    accent: Color(0xFF8B7CFF),
    link: Color(0xFFC6F24E),
    up: Color(0xFF34D399),
    upBg: Color(0x2634D399),
    down: Color(0xFFFF6B6B),
    downBg: Color(0x29FF6B6B),
    warn: Color(0xFFFBBF24),
    warnBg: Color(0x24FBBF24),
    heart: Color(0xFFFF5C7A),
    heartBg: Color(0x24FF5C7A),
    navBg: Color(0xD907080C),
    zLight: Color(0xFF4FC3F7),
    zModerate: Color(0xFF4ADE80),
    zVigorous: Color(0xFFFACC15),
    zPeak: Color(0xFFF87171),
    sAwake: Color(0xFFF0A3C0),
    sRestless: Color(0xFFF5B942),
    sRem: Color(0xFFBAE6FD),
    sLight: Color(0xFF93B4F8),
    sDeep: Color(0xFF8B7CFF),
    brandA: Color(0xFFDDFB62),
    brandB: Color(0xFF2FD9B9),
    onBrand: Color(0xFF07080C),
    shadow: [
      BoxShadow(
        color: Color(0x80000000),
        blurRadius: 24,
        offset: Offset(0, 12),
        spreadRadius: -14,
      ),
    ],
  );

  static const light = AppColors(
    bg: Color(0xFFF3F4EF),
    glow1: Color(0x2EB5E43A),
    glow2: Color(0x1F2FD9B9),
    card: Color(0xFFFFFFFF),
    card2: Color(0xFFEDEFE7),
    muted: Color(0xFFF0F2EC),
    fg: Color(0xFF0B0D12),
    mutedFg: Color(0xFF4F5562),
    border: Color(0x140B0D12),
    borderStrong: Color(0x2E0B0D12),
    track: Color(0x24646C78),
    primary: Color(0xFF4D7C0F),
    secondary: Color(0xFF4D7C0F),
    accent: Color(0xFF5B4BE0),
    link: Color(0xFF3F6212),
    up: Color(0xFF047857),
    upBg: Color(0x1F059669),
    down: Color(0xFFDC2626),
    downBg: Color(0x1ADC2626),
    warn: Color(0xFFB45309),
    warnBg: Color(0x1FD97706),
    heart: Color(0xFFE11D48),
    heartBg: Color(0x1AE11D48),
    navBg: Color(0xE6FFFFFF),
    zLight: Color(0xFF0284C7),
    zModerate: Color(0xFF16A34A),
    zVigorous: Color(0xFFCA8A04),
    zPeak: Color(0xFFDC2626),
    sAwake: Color(0xFFE46A9A),
    sRestless: Color(0xFFD99511),
    sRem: Color(0xFF38BDF8),
    sLight: Color(0xFF5B83E8),
    sDeep: Color(0xFF5B4BE0),
    brandA: Color(0xFFC9F23F),
    brandB: Color(0xFF26CDAE),
    onBrand: Color(0xFF07080C),
    shadow: [
      BoxShadow(
        color: Color(0x1F0B0D12),
        blurRadius: 24,
        offset: Offset(0, 10),
        spreadRadius: -14,
      ),
    ],
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      bg: l(bg, other.bg),
      glow1: l(glow1, other.glow1),
      glow2: l(glow2, other.glow2),
      card: l(card, other.card),
      card2: l(card2, other.card2),
      muted: l(muted, other.muted),
      fg: l(fg, other.fg),
      mutedFg: l(mutedFg, other.mutedFg),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      track: l(track, other.track),
      primary: l(primary, other.primary),
      secondary: l(secondary, other.secondary),
      accent: l(accent, other.accent),
      link: l(link, other.link),
      up: l(up, other.up),
      upBg: l(upBg, other.upBg),
      down: l(down, other.down),
      downBg: l(downBg, other.downBg),
      warn: l(warn, other.warn),
      warnBg: l(warnBg, other.warnBg),
      heart: l(heart, other.heart),
      heartBg: l(heartBg, other.heartBg),
      navBg: l(navBg, other.navBg),
      zLight: l(zLight, other.zLight),
      zModerate: l(zModerate, other.zModerate),
      zVigorous: l(zVigorous, other.zVigorous),
      zPeak: l(zPeak, other.zPeak),
      sAwake: l(sAwake, other.sAwake),
      sRestless: l(sRestless, other.sRestless),
      sRem: l(sRem, other.sRem),
      sLight: l(sLight, other.sLight),
      sDeep: l(sDeep, other.sDeep),
      brandA: l(brandA, other.brandA),
      brandB: l(brandB, other.brandB),
      onBrand: l(onBrand, other.onBrand),
      shadow: t < 0.5 ? shadow : other.shadow,
    );
  }
}

/// Spacing (4/8 rhythm), radii and motion tokens shared by every screen.
abstract final class Space {
  static const s1 = 4.0, s2 = 8.0, s3 = 12.0, s4 = 16.0, s5 = 24.0, s6 = 32.0;
}

abstract final class Radii {
  static const card = 22.0, sm = 14.0, pill = 999.0;
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
