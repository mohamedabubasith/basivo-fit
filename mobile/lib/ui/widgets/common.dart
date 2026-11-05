import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../state/settings.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../reveal.dart';
import 'motion.dart';

/// Page background with two soft colour glows, as on the web app.
class GlowBackground extends StatelessWidget {
  const GlowBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DecoratedBox(
      decoration: BoxDecoration(color: c.bg),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(-1, -1), radius: 1.3, colors: [c.glow1, c.glow1.withValues(alpha: 0)])),
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(1, -0.75), radius: 1.0, colors: [c.glow2, c.glow2.withValues(alpha: 0)])),
          child: child,
        ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(Space.s4), this.gradient, this.borderColor});
  final Widget child;
  final EdgeInsets padding;
  final Gradient? gradient;
  final Color? borderColor;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AnimatedContainer(
      duration: Motion.base,
      curve: Motion.ease,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? c.card : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: borderColor ?? c.border),
        boxShadow: c.shadow,
      ),
      child: child,
    );
  }
}

class CardTitle extends StatelessWidget {
  const CardTitle(this.text, {super.key, this.icon, this.trailing});
  final String text;
  final IconData? icon;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(children: [
        if (icon != null) ...[ExcludeSemantics(child: Icon(icon, size: 18, color: context.c.fg)), const SizedBox(width: Space.s2)],
        Expanded(child: Semantics(header: true, child: Text(text, style: Theme.of(context).textTheme.titleMedium))),
        ?trailing,
      ]);
}

class Muted extends StatelessWidget {
  const Muted(this.text, {super.key, this.size = 14, this.align});
  final String text;
  final double size;
  final TextAlign? align;
  @override
  Widget build(BuildContext context) => Text(text, textAlign: align, style: TextStyle(color: context.c.mutedFg, fontSize: size, height: 1.45));
}

/// Square icon button with a 48dp hit area and an accessible name.
class IconBtn extends StatelessWidget {
  const IconBtn({super.key, required this.icon, required this.label, this.onTap, this.spinning = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool spinning;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final enabled = onTap != null;
    return Tooltip(
      message: label,
      child: Pressable(
        onTap: onTap,
        semanticLabel: label,
        borderRadius: 14,
        child: AnimatedOpacity(
          duration: Motion.base,
          opacity: enabled ? 1 : 0.35,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border), boxShadow: c.shadow),
            child: Center(child: _Spin(spinning: spinning, child: ExcludeSemantics(child: Icon(icon, size: 20, color: c.fg)))),
          ),
        ),
      ),
    );
  }
}

class _Spin extends StatefulWidget {
  const _Spin({required this.spinning, required this.child});
  final bool spinning;
  final Widget child;
  @override
  State<_Spin> createState() => _SpinState();
}

class _SpinState extends State<_Spin> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  @override
  void didUpdateWidget(_Spin old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.spinning && _c.isAnimating) {
      _c.forward(from: _c.value).then((_) => _c.reset());
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(turns: _c, child: widget.child);
}

/// Light/dark switch with a spinning icon and the circular reveal.
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key, required this.controller});
  final ThemeController controller;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final next = dark ? 'light' : 'dark';
    return Builder(builder: (btn) {
      return Tooltip(
        message: 'Switch to $next mode',
        child: Pressable(
          semanticLabel: 'Switch to $next mode',
          onTap: () {
            HapticFeedback.lightImpact();
            final box = btn.findRenderObject() as RenderBox;
            final origin = box.localToGlobal(box.size.center(Offset.zero));
            void change() => controller.set(dark ? ThemeMode.light : ThemeMode.dark);
            final reveal = ThemeReveal.of(context);
            reveal == null ? change() : reveal.run(origin, change);
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: context.c.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.c.border), boxShadow: context.c.shadow),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (child, a) => RotationTransition(
                  turns: Tween(begin: -0.33, end: 0.0).animate(a),
                  child: ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: child)),
                ),
                child: ExcludeSemantics(
                  key: ValueKey(dark),
                  child: Icon(dark ? LucideIcons.sun : LucideIcons.moon, size: 20, color: context.c.fg),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, required this.theme, this.subtitle, this.actions = const []});
  final String title;
  final Widget? subtitle;
  final ThemeController theme;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: Space.s2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.headlineMedium)),
              if (subtitle != null) Padding(padding: const EdgeInsets.only(top: Space.s1), child: subtitle),
            ]),
          ),
          for (final a in actions) ...[a, const SizedBox(width: Space.s2)],
          ThemeToggle(controller: theme),
        ]),
      );
}

/// "Live · updated 11:38 PM" pill with a pulsing dot, or "Demo data".
class LiveBadge extends StatefulWidget {
  const LiveBadge({super.key, required this.live, this.text});
  final bool live;
  final String? text;
  @override
  State<LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<LiveBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!context.reduceMotion && widget.live) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = widget.live ? c.up : c.mutedFg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: widget.live ? c.upBg : c.track, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (widget.live) ...[
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) => Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(shape: BoxShape.circle, color: fg, boxShadow: [
                  BoxShadow(color: fg.withValues(alpha: (1 - _c.value) * 0.6), spreadRadius: _c.value * 5),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(widget.live ? 'Live${widget.text == null ? '' : ' · ${widget.text}'}' : 'Demo data',
            style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Google's sign-in button (white in light mode, near-black in dark mode).
class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.onTap, this.label = 'Sign in with Google'});
  final VoidCallback? onTap;
  final String label;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      borderRadius: Radii.sm,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF131314) : Colors.white,
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(color: dark ? const Color(0xFF8E918F) : const Color(0xFF747775)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const ExcludeSemantics(child: SizedBox.square(dimension: 20, child: CustomPaint(painter: _GLogo()))),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: dark ? const Color(0xFFE3E3E3) : const Color(0xFF1F1F1F), fontWeight: FontWeight.w500, fontSize: 15)),
        ]),
      ),
    );
  }
}

class _GLogo extends CustomPainter {
  const _GLogo();
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 48;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9.6 * s;
    final r = Rect.fromCircle(center: Offset(24 * s, 24 * s), radius: 19.2 * s);
    canvas.drawArc(r, -2.36, 1.62, false, stroke..color = const Color(0xFFEA4335));
    canvas.drawArc(r, 2.36, 1.62, false, stroke..color = const Color(0xFF34A853));
    canvas.drawArc(r, 2.0, 0.6, false, stroke..color = const Color(0xFFFBBC05));
    canvas.drawArc(r, 3.9, -1.0, false, stroke..color = const Color(0xFFFBBC05));
    canvas.drawArc(r, -0.15, 0.95, false, stroke..color = const Color(0xFF4285F4));
    canvas.drawRect(Rect.fromLTWH(24 * s, 19.6 * s, 22.4 * s, 8.8 * s), Paint()..color = const Color(0xFF4285F4));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum BtnKind { primary, ghost, danger, text }

class AppButton extends StatelessWidget {
  const AppButton({super.key, required this.label, required this.onTap, this.icon, this.kind = BtnKind.ghost});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final BtnKind kind;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg, border, grad) = switch (kind) {
      BtnKind.primary => (null, Colors.white, null, LinearGradient(colors: [c.secondary, c.accent])),
      BtnKind.ghost => (Colors.transparent, c.fg, c.borderStrong, null),
      BtnKind.danger => (c.downBg, c.down, null, null),
      BtnKind.text => (Colors.transparent, c.mutedFg, null, null),
    };
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      borderRadius: Radii.sm,
      child: Container(
        height: 50,
        decoration: BoxDecoration(color: bg, gradient: grad, borderRadius: BorderRadius.circular(Radii.sm), border: border == null ? null : Border.all(color: border)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[ExcludeSemantics(child: Icon(icon, size: 18, color: fg)), const SizedBox(width: Space.s2)],
          Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 15,
              decoration: kind == BtnKind.text ? TextDecoration.underline : null, decorationColor: fg)),
        ]),
      ),
    );
  }
}

/// Small metric tile used in grids (vitals, today at a glance).
class Tile extends StatelessWidget {
  const Tile({super.key, required this.icon, required this.label, required this.value, required this.sub});
  final IconData icon;
  final String label, value;
  final Widget sub;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return MergeSemantics(
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(Space.s4, Space.s3, Space.s4, Space.s3),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: c.muted, borderRadius: BorderRadius.circular(10)),
            child: ExcludeSemantics(child: Icon(icon, size: 18, color: c.link)),
          ),
          const SizedBox(height: Space.s2),
          Muted(label),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: mono(context, size: 22))),
          const SizedBox(height: 2),
          DefaultTextStyle.merge(style: TextStyle(color: c.mutedFg, fontSize: 12), child: sub),
        ]),
      ),
    );
  }
}

/// Two-column grid that keeps tiles in a row the same height.
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: children[i]),
          const SizedBox(width: Space.s3),
          Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
        ]),
      ));
      if (i + 2 < children.length) rows.add(const SizedBox(height: Space.s3));
    }
    return Column(children: rows);
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.fg, required this.bg});
  final String text;
  final Color fg, bg;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.pill)),
        child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}
