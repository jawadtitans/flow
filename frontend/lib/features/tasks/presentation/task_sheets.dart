import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/flow_tokens.dart';
import '../../../shared/widgets/flow_components.dart';

Future<void> showTaskFilters(BuildContext context) =>
    showFlowSheet<void>(context: context, builder: (_) => const _FilterSheet());

class _FilterSheet extends StatefulWidget {
  const _FilterSheet();

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  final selected = <String>{'In progress', 'Todo'};

  @override
  Widget build(BuildContext context) => FlowSheetFrame(
    heightFactor: .76,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: FlowSpace.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: FlowColors.selected,
                    borderRadius: BorderRadius.circular(FlowRadius.medium),
                  ),
                  child: const Row(
                    children: [
                      Icon(LucideIcons.sliders_horizontal),
                      SizedBox(width: 12),
                      Text(
                        'Search all filters',
                        style: TextStyle(fontSize: 17, color: FlowColors.muted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FlowHeaderActionSurface(
                child: FlowIconButton(
                  icon: LucideIcons.x,
                  onPressed: () => Navigator.pop(context),
                  size: 42,
                  iconSize: 19,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Applied',
            style: TextStyle(
              color: FlowColors.muted,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
            decoration: BoxDecoration(
              color: FlowColors.selected,
              borderRadius: BorderRadius.circular(FlowRadius.medium),
            ),
            child: const Row(
              children: [
                Text('Status', style: TextStyle(fontSize: 17)),
                SizedBox(width: 12),
                Text(
                  'is any of  2 statuses',
                  style: TextStyle(fontSize: 17, color: FlowColors.muted),
                ),
                Spacer(),
                Icon(LucideIcons.x),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Status',
            style: TextStyle(
              color: FlowColors.muted,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: FlowColors.selected,
                borderRadius: BorderRadius.circular(FlowRadius.medium),
              ),
              child: ListView(
                children: ['Backlog', 'Todo', 'In progress', 'Completed']
                    .map(
                      (label) => _OptionRow(
                        label: label,
                        selected: selected.contains(label),
                        onTap: () => setState(
                          () => selected.contains(label)
                              ? selected.remove(label)
                              : selected.add(label),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x33FFFFFF))),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: FlowMotion.quick,
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? FlowColors.blue : const Color(0xFFD1D2D5),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(6),
              color: selected ? FlowColors.blue : Colors.transparent,
            ),
            child: selected
                ? const Icon(LucideIcons.check, color: Colors.white, size: 17)
                : null,
          ),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(fontSize: 18)),
        ],
      ),
    ),
  );
}

Future<void> showWorkspaceMenu(
  BuildContext context, {
  required ValueChanged<String> onNavigate,
  String? currentLocation,
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final dismissed = Completer<void>();
  late final OverlayEntry entry;

  void close() {
    if (!entry.mounted) return;
    entry.remove();
    if (!dismissed.isCompleted) dismissed.complete();
  }

  entry = OverlayEntry(
    builder: (_) => _WorkspaceMenuOverlay(
      currentLocation: currentLocation,
      onDismissed: close,
      onNavigate: onNavigate,
    ),
  );
  flowNavigationVisible.value = false;
  try {
    overlay.insert(entry);
    await dismissed.future;
  } finally {
    flowNavigationVisible.value = true;
  }
}

class _WorkspaceMenuOverlay extends StatefulWidget {
  const _WorkspaceMenuOverlay({
    required this.onNavigate,
    required this.onDismissed,
    this.currentLocation,
  });

  final ValueChanged<String> onNavigate;
  final VoidCallback onDismissed;
  final String? currentLocation;

  @override
  State<_WorkspaceMenuOverlay> createState() => _WorkspaceMenuOverlayState();
}

class _WorkspaceMenuOverlayState extends State<_WorkspaceMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 180),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_isClosing) return;
    _isClosing = true;
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  Future<void> _select(String destination) async {
    await _dismiss();
    widget.onNavigate(destination);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final destinations = <(IconData, String, String)>[
      (LucideIcons.inbox, 'Inbox', '/inbox'),
      (LucideIcons.focus, 'My tasks', '/today'),
      (LucideIcons.star, 'Favorites', '/favorites'),
      (LucideIcons.search, 'Search', '/search'),
    ];
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              button: true,
              label: 'Close workspace menu',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _dismiss,
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 88,
            bottom: MediaQuery.paddingOf(context).bottom + 22,
            child: FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, .14),
                  end: Offset.zero,
                ).animate(animation),
                child: _WorkspaceMenuCard(
                  dark: dark,
                  destinations: destinations,
                  currentLocation: widget.currentLocation,
                  onSelect: _select,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceMenuCard extends StatelessWidget {
  const _WorkspaceMenuCard({
    required this.dark,
    required this.destinations,
    required this.currentLocation,
    required this.onSelect,
  });

  final bool dark;
  final List<(IconData, String, String)> destinations;
  final String? currentLocation;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(30),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? .28 : .13),
          blurRadius: 32,
          offset: const Offset(0, 15),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: dark ? const Color(0xF2464858) : const Color(0xF7FFFFFF),
            border: Border.all(color: dark ? Colors.white12 : Colors.white),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 12),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 17,
                        backgroundColor: Color(0xFFE98977),
                        child: Text(
                          'F',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Flow workspace',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(LucideIcons.chevron_up, size: 20),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: dark ? Colors.white12 : FlowColors.line,
                ),
                const SizedBox(height: 6),
                ...destinations.map((entry) {
                  final selected = entry.$3 == currentLocation;
                  return Semantics(
                    button: true,
                    selected: selected,
                    label: entry.$2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => onSelect(entry.$2),
                      child: AnimatedContainer(
                        duration: FlowMotion.quick,
                        height: 54,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: selected
                              ? (dark ? Colors.white12 : FlowColors.selected)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(entry.$1, size: 22),
                            const SizedBox(width: 15),
                            Text(
                              entry.$2,
                              style: const TextStyle(fontSize: 17),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
