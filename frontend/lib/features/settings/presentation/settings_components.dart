import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/flow_tokens.dart';
import 'flow_pro_banner.dart';
import '../../../shared/widgets/flow_components.dart';

const settingsLightCanvas = Color(0xFFF3F4F6);

class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    required this.title,
    required this.children,
    this.root = false,
    this.allowBack = true,
    this.centerTitle = true,
    this.fallback = '/settings',
    super.key,
  });

  final String title;
  final List<Widget> children;
  final bool root;
  final bool allowBack;
  final bool centerTitle;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final canvas = dark ? FlowColors.darkCanvas : settingsLightCanvas;
    return Scaffold(
      backgroundColor: canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ListView(
            key: PageStorageKey('settings-$title'),
            padding: EdgeInsets.fromLTRB(
              20,
              padding.top + 90,
              20,
              padding.bottom + 40,
            ),
            children: [
              FlowProBanner(
                variant: root
                    ? FlowProBannerVariant.large
                    : FlowProBannerVariant.compact,
              ),
              const SizedBox(height: 24),
              ...children,
            ],
          ),
          FlowPageSoftEdges(
            topHeight: padding.top + 78,
            bottomHeight: padding.bottom + 32,
            canvasColor: canvas,
          ),
          Positioned(
            top: padding.top + 7,
            left: 20,
            right: 20,
            child: Row(
              children: [
                FlowHeaderActionSurface(
                  child: FlowIconButton(
                    icon: root ? LucideIcons.x : LucideIcons.chevron_left,
                    semanticLabel: root ? 'Close settings' : 'Back',
                    size: 44,
                    iconSize: 22,
                    onPressed: !allowBack
                        ? null
                        : () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go(root ? '/today' : fallback);
                            }
                          },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      textAlign: centerTitle
                          ? TextAlign.center
                          : TextAlign.start,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.35,
                      ),
                    ),
                  ),
                ),
                if (centerTitle) const SizedBox(width: 56),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? FlowColors.darkSurface : Colors.white,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: .5,
                indent: 16,
                endIndent: 16,
                color: dark ? Colors.white12 : const Color(0xFFF0F1F3),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.title,
    this.subtitle,
    this.icon,
    this.onTap,
    this.trailing,
    this.destructive = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = destructive
        ? (dark ? const Color(0xFFFF899B) : const Color(0xFFA82443))
        : (dark ? Colors.white : FlowColors.ink);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 23, color: color),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 17, color: color)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: dark ? Colors.white60 : FlowColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null || onTap != null) ...[
                const SizedBox(width: 12),
                trailing ??
                    Icon(
                      LucideIcons.chevron_right,
                      size: 20,
                      color: dark ? Colors.white38 : const Color(0xFFA8AAAE),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 9),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white60
                  : const Color(0xFF707278),
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class FlowSettingsBrand extends StatelessWidget {
  const FlowSettingsBrand({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Flow',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CustomPaint(painter: _FlowMiniMark()),
          ),
          const SizedBox(width: 4),
          const Text(
            'Flow',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

class _FlowMiniMark extends CustomPainter {
  const _FlowMiniMark();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()..color = FlowColors.blue;
    for (final dy in [0.0, 9.0]) {
      final ribbon = Path()
        ..moveTo(1, 9 + dy)
        ..lineTo(7, 9 + dy)
        ..cubicTo(11, 9 + dy, 11, 2 + dy, 15, 2 + dy)
        ..lineTo(23, 2 + dy)
        ..lineTo(23, 7 + dy)
        ..lineTo(17, 7 + dy)
        ..cubicTo(13, 7 + dy, 13, 14 + dy, 9, 14 + dy)
        ..lineTo(1, 14 + dy)
        ..close();
      canvas.drawPath(ribbon, paint);
    }
  }

  @override
  bool shouldRepaint(_FlowMiniMark oldDelegate) => false;
}

class SettingsNote extends StatelessWidget {
  const SettingsNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 14,
        height: 1.6,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white60
            : FlowColors.muted,
      ),
    ),
  );
}

Future<void> saveSettings(
  BuildContext context,
  Future<void> Function() save,
) async {
  try {
    await save();
  } catch (_) {
    if (!context.mounted) return;
    showFlowNotification(
      context,
      title: 'Setting not saved',
      message: 'Couldn’t save this setting. Please try again.',
      type: FlowNotificationType.error,
    );
  }
}
