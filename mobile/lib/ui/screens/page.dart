import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../state/health_store.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

/// Scrolling page body: safe areas, room for the tab bar, pull to refresh and
/// a staggered entrance for each block.
class TabPage extends StatelessWidget {
  const TabPage({super.key, required this.children, this.onRefresh});
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final wide = MediaQuery.sizeOf(context).width > 640;
    final list = ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: EdgeInsets.fromLTRB(wide ? 32 : Space.s4, pad.top + Space.s4, wide ? 32 : Space.s4, pad.bottom + 96),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: Space.s4),
      itemBuilder: (_, i) => Entrance(index: i, child: children[i]),
    );
    final body = Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: list));
    if (onRefresh == null) return body;
    return RefreshIndicator(onRefresh: onRefresh!, color: context.c.secondary, backgroundColor: context.c.card, edgeOffset: pad.top, child: body);
  }
}

/// Header with the live/demo badge, refresh button and theme switch.
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.title, required this.theme});
  final String title;
  final ThemeController theme;
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final h = s.health;
    return PageHeader(
      title: title,
      theme: theme,
      subtitle: h == null ? null : LiveBadge(live: !s.demo, text: s.demo ? null : 'updated ${_t(h.updatedAt)}'),
      actions: [if (!s.demo) IconBtn(icon: LucideIcons.refreshCw, label: 'Refresh', spinning: s.loading, onTap: s.reload)],
    );
  }
}

String _t(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}
