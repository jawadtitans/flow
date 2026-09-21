import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/flow_tokens.dart';
import '../../../features/agent/presentation/agent_composer.dart';
import '../../../features/tasks/task.dart';
import '../../../features/tasks/task_controller.dart';
import '../../../features/tasks/presentation/task_sheets.dart';
import '../../../shared/widgets/flow_components.dart';

enum _TaskScope { assigned, created, subscribed }

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  _TaskScope _scope = _TaskScope.assigned;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _scope.index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = ['Assigned', 'Created', 'Subscribed'];
    final selected = _scope.index;
    final tasks = ref.watch(taskControllerProvider);
    final taskPages = <List<Task>>[
      tasks,
      tasks.reversed.toList(growable: false),
      tasks
          .where((task) => task.priority != TaskPriority.low)
          .toList(growable: false),
    ];
    final topInset = MediaQuery.paddingOf(context).top;
    // Match Inbox: the last row fades into the dock instead of stopping well
    // above it.
    final bottomDockInset = MediaQuery.paddingOf(context).bottom + 52;
    // The feed begins immediately below the tab control, so it can scroll
    // under a short, non-blurred gradient edge just like Inbox.
    final listTop = topInset + 124;
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _TaskScope.values.length,
            onPageChanged: (index) =>
                setState(() => _scope = _TaskScope.values[index]),
            itemBuilder: (context, index) => _TaskScopeList(
              scope: _TaskScope.values[index],
              tasks: taskPages[index],
              contentPadding: EdgeInsets.fromLTRB(
                FlowSpace.page,
                listTop,
                FlowSpace.page,
                bottomDockInset,
              ),
              onToggle: (task) =>
                  ref.read(taskControllerProvider.notifier).toggle(task.id),
            ),
          ),
          FlowPageSoftEdges(
            topHeight: listTop + 7,
            bottomHeight: bottomDockInset + 7,
          ),
          Positioned(
            top: topInset + 7,
            left: FlowSpace.page,
            right: FlowSpace.page,
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'My tasks',
                    style: TextStyle(
                      fontSize: 26,
                      letterSpacing: -1.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                FlowHeaderActionSurface(
                  pill: true,
                  child: FlowPill(
                    padding: EdgeInsets.zero,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FlowHeaderActionIcon(
                          icon: LucideIcons.square_pen,
                          onPressed: () => showAgentComposer(context),
                          size: 42,
                          iconSize: 19,
                        ),
                        FlowHeaderActionIcon(
                          icon: LucideIcons.ellipsis,
                          onPressed: _openWorkspace,
                          size: 42,
                          iconSize: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: topInset + 66,
            left: FlowSpace.page,
            right: FlowSpace.page,
            child: _TaskScopeTabs(
              labels: labels,
              selectedIndex: selected,
              onSelect: (index) => _pageController.animateToPage(
                index,
                duration: FlowMotion.standard,
                curve: Curves.easeOutCubic,
              ),
              onFilter: () => showTaskFilters(context),
            ),
          ),
        ],
      ),
    );
  }

  void _openWorkspace() => showWorkspaceMenu(
    context,
    currentLocation: '/today',
    onNavigate: (destination) => switch (destination) {
      'Inbox' => context.go('/inbox'),
      'My tasks' => context.go('/today'),
      'Favorites' => context.go('/favorites'),
      'Search' => context.go('/search'),
      _ => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$destination is coming soon'))),
    },
  );
}

class _TaskScopeTabs extends StatelessWidget {
  const _TaskScopeTabs({
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
    required this.onFilter,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FlowRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .26 : .14),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(FlowRadius.large),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dark
                    ? const [Color(0x80464858), Color(0x80464858)]
                    : const [Color(0x80FFFFFF), Color(0x80FFFFFF)],
              ),
              borderRadius: BorderRadius.circular(FlowRadius.large),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: .16)
                    : Colors.white.withValues(alpha: .84),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const filterWidth = 42.0;
                  const dividerWidth = 1.0;
                  final tabWidth =
                      (constraints.maxWidth - filterWidth - dividerWidth) /
                      labels.length;
                  return SizedBox(
                    height: 42,
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 360),
                          curve: Curves.easeOutCubic,
                          left: tabWidth * selectedIndex,
                          top: 0,
                          bottom: 0,
                          width: tabWidth,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: dark
                                  ? Colors.white12
                                  : FlowColors.selected,
                              borderRadius: BorderRadius.circular(
                                FlowRadius.pill,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: dark ? .28 : .14,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            for (var index = 0; index < labels.length; index++)
                              SizedBox(
                                width: tabWidth,
                                child: Semantics(
                                  button: true,
                                  selected: selectedIndex == index,
                                  label: labels[index],
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => onSelect(index),
                                    child: Center(
                                      child: AnimatedDefaultTextStyle(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: selectedIndex == index
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: selectedIndex == index
                                              ? (dark
                                                    ? Colors.white
                                                    : FlowColors.ink)
                                              : FlowColors.muted,
                                        ),
                                        child: Text(
                                          labels[index],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            SizedBox(
                              width: dividerWidth,
                              child: Center(
                                child: Container(
                                  width: 1,
                                  height: 27,
                                  color: dark
                                      ? Colors.white12
                                      : FlowColors.line,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: filterWidth,
                              child: Semantics(
                                button: true,
                                label: 'Filter tasks',
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: onFilter,
                                  child: const Center(
                                    child: Icon(
                                      LucideIcons.sliders_horizontal,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

class _TaskScopeList extends StatelessWidget {
  const _TaskScopeList({
    required this.scope,
    required this.tasks,
    required this.contentPadding,
    required this.onToggle,
  });

  final _TaskScope scope;
  final List<Task> tasks;
  final EdgeInsets contentPadding;
  final ValueChanged<Task> onToggle;

  @override
  Widget build(BuildContext context) {
    final label = switch (scope) {
      _TaskScope.assigned => 'Assigned to you',
      _TaskScope.created => 'Created by you',
      _TaskScope.subscribed => 'Subscribed updates',
    };
    return ListView.separated(
      padding: contentPadding.copyWith(
        top: contentPadding.top + 4,
        bottom: contentPadding.bottom + 28,
      ),
      itemCount: tasks.length + 1,
      separatorBuilder: (_, index) =>
          index == 0 ? const SizedBox(height: 4) : const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '$label · ${tasks.length}',
              style: const TextStyle(
                fontSize: 14,
                color: FlowColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }
        final task = tasks[index - 1];
        return FlowTaskTile(task: task, onToggle: () => onToggle(task));
      },
    );
  }
}
