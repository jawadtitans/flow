import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/flow_components.dart';
import '../tasks/task_controller.dart';

class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskControllerProvider);
    final completed = tasks.where((task) => task.completed).length;
    final topInset = MediaQuery.paddingOf(context).top;
    final listTop = topInset + 68;
    final bottomDockInset = MediaQuery.paddingOf(context).bottom + 118;
    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(24, listTop, 24, bottomDockInset),
            children: [
              Text(
                'Good morning 👋',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text('$completed of ${tasks.length} completed'),
              const SizedBox(height: 28),
              Text('TODAY', style: Theme.of(context).textTheme.labelLarge),
              ...tasks.map(
                (task) => CheckboxListTile(
                  value: task.completed,
                  onChanged: (_) =>
                      ref.read(taskControllerProvider.notifier).toggle(task.id),
                  title: Text(task.title),
                ),
              ),
            ],
          ),
          FlowPageSoftEdges(
            topHeight: listTop + 7,
            bottomHeight: bottomDockInset + 7,
          ),
          Positioned(
            top: topInset + 7,
            left: 24,
            right: 24,
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Today',
                    style: TextStyle(
                      fontSize: 26,
                      letterSpacing: -1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FlowHeaderActionSurface(
                  child: FlowIconButton(
                    icon: LucideIcons.plus,
                    onPressed: () => _quickAdd(context, ref),
                    size: 42,
                    iconSize: 20,
                    semanticLabel: 'Add task',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _quickAdd(BuildContext context, WidgetRef ref) {
    final text = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add task'),
        content: TextField(
          controller: text,
          autofocus: true,
          onSubmitted: (_) {
            ref.read(taskControllerProvider.notifier).add(text.text);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(taskControllerProvider.notifier).add(text.text);
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
