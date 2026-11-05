import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../data/format.dart';
import '../../state/health_store.dart';
import '../../state/settings.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import '../widgets/pulse.dart';
import 'page.dart';
import 'tabs.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.theme});
  final ThemeController theme;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!context.reduceMotion) _float.repeat(reverse: true);
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context), c = context.c;
    final pad = MediaQuery.paddingOf(context);
    final items = <Widget>[
      Align(
        alignment: Alignment.centerRight,
        child: ThemeToggle(controller: widget.theme),
      ),
      Column(
        children: [
          AnimatedBuilder(
            animation: _float,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, -6 * Curves.easeInOut.transform(_float.value)),
              child: child,
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xB34F46E5),
                    blurRadius: 40,
                    offset: Offset(0, 18),
                    spreadRadius: -16,
                  ),
                ],
              ),
              child: const AppLogo(size: 88),
            ),
          ),
          const SizedBox(height: Space.s3),
          ShaderMask(
            shaderCallback: (r) =>
                LinearGradient(colors: [c.secondary, c.accent]).createShader(r),
            child: Semantics(
              header: true,
              child: const Text(
                'PulseFolio',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.8,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.s1),
          const Muted('Your Fitbit health, beautifully clear.', size: 16),
          const SizedBox(height: Space.s3),
          const Row(
            children: [
              BeatingHeart(bpm: 72, size: 30),
              SizedBox(width: Space.s3),
              Expanded(child: EcgLine(bpm: 72)),
            ],
          ),
        ],
      ),
      _feature(
        context,
        LucideIcons.heartPulse,
        c.heart,
        c.heartBg,
        'Live heart rate',
        'Hour by hour, zones, resting heart rate and HRV',
      ),
      _feature(
        context,
        LucideIcons.bedDouble,
        Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFA78BFA)
            : const Color(0xFF8B5CF6),
        c.accent.withValues(alpha: 0.14),
        'Sleep stages',
        'Deep, light and REM sleep with open quality rules',
      ),
      _feature(
        context,
        LucideIcons.footprints,
        c.up,
        c.upBg,
        'Activity',
        'Steps, distance, calories and zone minutes',
      ),
      if (s.loginMessage != null)
        Container(
          padding: const EdgeInsets.all(Space.s3),
          decoration: BoxDecoration(
            color: c.warnBg,
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          child: Semantics(
            liveRegion: true,
            child: Text(s.loginMessage!, style: const TextStyle(fontSize: 14)),
          ),
        ),
      Column(
        children: [
          if (s.auth.supported)
            GoogleButton(
              onTap: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      await s.signIn();
                      if (mounted) setState(() => _busy = false);
                    },
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Space.s3),
              decoration: BoxDecoration(
                color: c.warnBg,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: const Text(
                'Google sign-in works in the Android and iPhone app. You can try the demo here.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          const SizedBox(height: Space.s3),
          AppButton(label: 'Try the demo', onTap: s.startDemo),
          const SizedBox(height: Space.s3),
          const Muted(
            'Use the Google account linked to your Fitbit or Pixel Watch. Your data goes straight from Google to this phone and is never stored on our servers.',
            size: 12,
            align: TextAlign.center,
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).push(_route(const PrivacyScreen())),
            child: Text(
              'Privacy',
              style: TextStyle(
                color: c.link,
                decoration: TextDecoration.underline,
                decorationColor: c.link,
              ),
            ),
          ),
        ],
      ),
    ];
    return Scaffold(
      body: GlowBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                Space.s5,
                pad.top + Space.s4,
                Space.s5,
                pad.bottom + Space.s5,
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: Space.s4),
              itemBuilder: (_, i) => Entrance(index: i, child: items[i]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _feature(
    BuildContext context,
    IconData icon,
    Color fg,
    Color bg,
    String title,
    String sub,
  ) => AppCard(
    padding: const EdgeInsets.symmetric(
      horizontal: Space.s4,
      vertical: Space.s3,
    ),
    child: MergeSemantics(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExcludeSemantics(child: Icon(icon, size: 20, color: fg)),
          ),
          const SizedBox(width: Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Muted(sub),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// "No device connected", "Permission needed" and loading errors.
class ProblemScreen extends StatelessWidget {
  const ProblemScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context), c = context.c;
    final email = s.user?.email;
    final (icon, warn, title, body, actions) = switch (s.problem) {
      Problem.noDevice => (
        LucideIcons.watch,
        false,
        'No device connected',
        [
          Text.rich(
            TextSpan(
              children: [
                if (email != null)
                  TextSpan(
                    text: email,
                    style: TextStyle(color: c.fg, fontWeight: FontWeight.w600),
                  )
                else
                  const TextSpan(text: 'This Google account'),
                const TextSpan(
                  text: ' does not have a Fitbit or Pixel Watch connected.',
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: c.mutedFg, fontSize: 16),
          ),
          const SizedBox(height: Space.s2),
          const Muted(
            'Sign out and sign in with the Google account you use in the Fitbit or Google Health app.',
            align: TextAlign.center,
          ),
        ],
        [
          GoogleButton(
            label: 'Sign in with another account',
            onTap: () => s.signIn(switching: true),
          ),
          AppButton(label: 'Check again', onTap: s.reload),
          AppButton(label: 'Sign out', kind: BtnKind.text, onTap: s.signOut),
        ],
      ),
      Problem.permission => (
        LucideIcons.keyRound,
        true,
        'Permission needed',
        [
          const Muted(
            'PulseFolio needs permission to read your activity, sleep, heart and device data. Please sign in again and tick all the boxes.',
            size: 16,
            align: TextAlign.center,
          ),
        ],
        [
          GoogleButton(
            label: 'Allow access with Google',
            onTap: () => s.signIn(switching: true),
          ),
          AppButton(label: 'Sign out', kind: BtnKind.text, onTap: s.signOut),
        ],
      ),
      _ => (
        LucideIcons.circleAlert,
        true,
        'Could not load your data',
        [Muted(s.message, size: 16, align: TextAlign.center)],
        [
          AppButton(label: 'Try again', kind: BtnKind.primary, onTap: s.reload),
          AppButton(label: 'Sign out', kind: BtnKind.text, onTap: s.signOut),
        ],
      ),
    };
    final items = <Widget>[
      Center(
        child: _FloatingIcon(icon: icon, warn: warn),
      ),
      Semantics(
        header: true,
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      ...body,
      const SizedBox(height: Space.s2),
      for (final a in actions)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.s3),
          child: a,
        ),
    ];
    return Scaffold(
      body: GlowBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(Space.s5),
                children: [
                  for (var i = 0; i < items.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.s3),
                      child: Entrance(index: i, child: items[i]),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingIcon extends StatefulWidget {
  const _FloatingIcon({required this.icon, required this.warn});
  final IconData icon;
  final bool warn;
  @override
  State<_FloatingIcon> createState() => _FloatingIconState();
}

class _FloatingIconState extends State<_FloatingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!context.reduceMotion) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, -6 * Curves.easeInOut.transform(_c.value)),
          child: child,
        ),
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: widget.warn ? c.warnBg : c.track,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Icon(
            widget.icon,
            size: 36,
            color: widget.warn ? c.warn : c.mutedFg,
          ),
        ),
      ),
    );
  }
}

// ---------------- Profile ----------------
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.theme});
  final ThemeController theme;
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context), c = context.c, h = s.health, u = s.user;
    return TabPage(
      children: [
        PageHeader(title: 'Profile', theme: theme),
        AppCard(
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [c.secondary, c.accent]),
                ),
                child: u?.photoUrl != null
                    ? Image.network(
                        u!.photoUrl!,
                        fit: BoxFit.cover,
                        semanticLabel: 'Profile photo',
                        errorBuilder: (_, _, _) => _initial(u.name),
                      )
                    : _initial(s.demo ? 'D' : (u?.name ?? '?')),
              ),
              const SizedBox(width: Space.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.demo ? 'Demo mode' : (u?.name ?? 'Signed in'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Muted(
                      s.demo
                          ? 'Sign in to see your own Fitbit data.'
                          : (u?.email ?? ''),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (s.demo)
          AppCard(
            child: Column(
              children: [
                if (s.auth.supported) ...[
                  GoogleButton(
                    onTap: () async {
                      s.exitDemo();
                      await s.signIn();
                    },
                  ),
                  const SizedBox(height: Space.s3),
                ],
                AppButton(
                  label: 'Back to start',
                  icon: LucideIcons.logIn,
                  onTap: s.exitDemo,
                ),
              ],
            ),
          )
        else if (h != null)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CardTitle('Devices', icon: LucideIcons.watch),
                const SizedBox(height: Space.s2),
                if (h.devices.isEmpty)
                  const Muted('No device found on this account.'),
                for (final d in h.devices)
                  MergeSemantics(
                    child: SizedBox(
                      height: 56,
                      child: Row(
                        children: [
                          ExcludeSemantics(
                            child: Icon(
                              LucideIcons.batteryMedium,
                              size: 20,
                              color: c.fg,
                            ),
                          ),
                          const SizedBox(width: Space.s3),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (d.lastSync != null)
                                  Muted('Synced ${clock(d.lastSync!)}'),
                              ],
                            ),
                          ),
                          Text(
                            d.battery != null
                                ? '${d.battery}%'
                                : d.batteryStatus,
                            style: mono(context),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CardTitle('Appearance'),
              const SizedBox(height: Space.s3),
              ListenableBuilder(
                listenable: theme,
                builder: (context, _) => Segmented<ThemeMode>(
                  value: theme.mode,
                  options: const [
                    (ThemeMode.system, 'System', LucideIcons.monitor),
                    (ThemeMode.light, 'Light', LucideIcons.sun),
                    (ThemeMode.dark, 'Dark', LucideIcons.moon),
                  ],
                  onChanged: theme.set,
                ),
              ),
            ],
          ),
        ),
        if (!s.demo)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppButton(
                  label: 'Switch account',
                  icon: LucideIcons.refreshCcw,
                  onTap: () => s.signIn(switching: true),
                ),
                const SizedBox(height: Space.s3),
                AppButton(
                  label: 'Sign out',
                  icon: LucideIcons.logOut,
                  kind: BtnKind.danger,
                  onTap: s.signOut,
                ),
                const SizedBox(height: Space.s3),
                const Muted(
                  "Signing out also removes PulseFolio's access to your Google Health data.",
                  size: 12,
                ),
              ],
            ),
          ),
        Pressable(
          onTap: () =>
              Navigator.of(context).push(_route(const PrivacyScreen())),
          semanticLabel: 'Privacy',
          child: AppCard(
            child: SizedBox(
              height: 24,
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(LucideIcons.shieldCheck, size: 20, color: c.fg),
                  ),
                  const SizedBox(width: Space.s3),
                  const Expanded(child: Text('Privacy')),
                  ExcludeSemantics(
                    child: Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: c.mutedFg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Muted(
          'PulseFolio 1.0 · Data from Google Health. Not a medical device.',
          size: 12,
          align: TextAlign.center,
        ),
      ],
    );
  }

  Widget _initial(String name) => Center(
    child: Text(
      name.isEmpty ? '?' : name[0].toUpperCase(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

Route<void> _route(Widget page) => PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 380),
  reverseTransitionDuration: const Duration(milliseconds: 260),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (context, a, _, child) {
    final curved = CurvedAnimation(
      parent: a,
      curve: Motion.ease,
      reverseCurve: Curves.easeIn,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  },
);

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const sections = [
      (
        'What PulseFolio reads',
        'When you sign in with Google, you choose to let PulseFolio read your Google Health data: activity and fitness, sleep, health measurements (such as heart rate, oxygen and weight) and your connected devices. Access is read-only. PulseFolio cannot change or delete your data.',
      ),
      (
        'Where your data goes',
        'Your data goes directly from Google to the PulseFolio app on your device. PulseFolio has no server that receives, stores or shares your health data. Nothing is sold or used for advertising.',
      ),
      (
        'What is saved on your device',
        'Your Google sign-in is managed by your phone. PulseFolio keeps only your theme choice. Signing out cancels PulseFolio\'s access with Google.',
      ),
      (
        'Google API Services User Data Policy',
        "PulseFolio's use of information received from Google APIs follows the Google API Services User Data Policy, including the Limited Use requirements.",
      ),
      (
        'Not medical advice',
        'PulseFolio shows your data to help you understand it. It is not a medical device and does not diagnose anything. Talk to a doctor about health concerns.',
      ),
      (
        'Contact',
        'Questions about privacy: use the developer email shown on the Google sign-in screen.',
      ),
    ];
    return Scaffold(
      body: GlowBackground(
        child: TabPage(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(LucideIcons.arrowLeft, size: 20, color: c.link),
                label: Text(
                  'Back',
                  style: TextStyle(color: c.link, fontSize: 16),
                ),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              ),
            ),
            Semantics(
              header: true,
              child: Text(
                'Privacy',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const Muted('Last updated 5 November 2026'),
            for (final (h, p) in sections)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      h,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: Space.s2),
                  Text(p, style: const TextStyle(fontSize: 16, height: 1.65)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Shell ----------------
class Shell extends StatefulWidget {
  const Shell({super.key, required this.theme});
  final ThemeController theme;
  @override
  State<Shell> createState() => _ShellState();
}

/// Tab to open first (set from a web share link).
int initialTab = 0;

class _ShellState extends State<Shell> {
  int _tab = initialTab;
  void _go(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    if (s.problem != Problem.none && !s.demo) return const ProblemScreen();
    final pages = [
      TodayTab(theme: widget.theme, goTo: _go),
      HeartTab(theme: widget.theme),
      SleepTab(theme: widget.theme),
      ActivityTab(theme: widget.theme, goTo: _go),
      ProfileTab(theme: widget.theme),
    ];
    return Scaffold(
      extendBody: true,
      body: GlowBackground(
        child: AnimatedSwitcher(
          duration: context.reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 280),
          switchInCurve: Motion.ease,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: ScaleTransition(
              scale: Tween(begin: 0.985, end: 1.0).animate(a),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(_tab), child: pages[_tab]),
        ),
      ),
      bottomNavigationBar: BottomNav(index: _tab, onTap: _go),
    );
  }
}
