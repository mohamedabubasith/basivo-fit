import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// Frosted tab bar with a gradient indicator that slides to the selected tab.
class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;
  static const tabs = [
    ('Today', LucideIcons.house),
    ('Heart', LucideIcons.heartPulse),
    ('Sleep', LucideIcons.bedDouble),
    ('Activity', LucideIcons.footprints),
    ('Profile', LucideIcons.userRound),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 66 + bottom,
          padding: EdgeInsets.only(bottom: bottom),
          decoration: BoxDecoration(
            color: c.navBg,
            border: Border(top: BorderSide(color: c.border)),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: LayoutBuilder(
                builder: (context, box) {
                  final w = box.maxWidth / tabs.length;
                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutBack,
                        top: 6,
                        left: w * index + w / 2 - 11,
                        child: Container(
                          width: 22,
                          height: 3,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            gradient: c.brand,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < tabs.length; i++)
                            Expanded(
                              child: Semantics(
                                selected: i == index,
                                button: true,
                                label: '${tabs[i].$1} tab',
                                excludeSemantics: true,
                                child: InkResponse(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    onTap(i);
                                  },
                                  radius: 36,
                                  child: SizedBox(
                                    height: 66,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        AnimatedScale(
                                          scale: i == index ? 1.08 : 1,
                                          duration: const Duration(
                                            milliseconds: 320,
                                          ),
                                          curve: Curves.easeOutBack,
                                          child: AnimatedSlide(
                                            offset: Offset(
                                              0,
                                              i == index ? -0.08 : 0,
                                            ),
                                            duration: const Duration(
                                              milliseconds: 320,
                                            ),
                                            curve: Curves.easeOutBack,
                                            child: Icon(
                                              tabs[i].$2,
                                              size: 22,
                                              color: i == index
                                                  ? c.link
                                                  : c.mutedFg,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        AnimatedDefaultTextStyle(
                                          duration: Motion.base,
                                          style: TextStyle(
                                            fontFamily: kSans,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: i == index
                                                ? c.fg
                                                : c.mutedFg,
                                          ),
                                          child: Text(tabs[i].$1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
